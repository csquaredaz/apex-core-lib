@IsTest
private class UnitOfWorkTest {
  private static final List<SObjectType> COMMIT_ORDER = new List<SObjectType>{ Account.SObjectType, Order.SObjectType };

  // Records every DML call in order and assigns fake Ids on insert and on upsert of records
  // without one, so ordering and relationship resolution can be asserted without the database.
  private class FakeDml implements IDml {
    private final List<String> log = new List<String>();
    private final Map<String, List<SObject>> recordsByCall = new Map<String, List<SObject>>();
    private final Map<String, SObjectField> keyByCall = new Map<String, SObjectField>();

    public void dmlInsert(List<SObject> records) {
      for (SObject record : records) {
        record.Id = FakeId.generate(record.getSObjectType());
      }
      record('insert', records);
    }

    public void dmlUpdate(List<SObject> records) {
      record('update', records);
    }

    public void dmlUpsert(List<SObject> records, SObjectField externalIdField) {
      for (SObject record : records) {
        if (record.Id == null) {
          record.Id = FakeId.generate(record.getSObjectType());
        }
      }
      record('upsert', records);
      keyByCall.put('upsert ' + records[0].getSObjectType(), externalIdField);
    }

    public void dmlDelete(List<SObject> records) {
      record('delete', records);
    }

    private void record(String operation, List<SObject> records) {
      String call = operation + ' ' + records[0].getSObjectType();
      log.add(call);
      recordsByCall.put(call, records);
    }
  }

  private class LogWork implements IDoWork {
    private final List<String> log;
    private LogWork(List<String> log) {
      this.log = log;
    }
    public void doWork() {
      log.add('work');
    }
  }

  private class WorkFailedException extends Exception {
  }

  private class FailingWork implements IDoWork {
    public void doWork() {
      throw new WorkFailedException('Event bus unavailable');
    }
  }

  private static String expectError(UnitOfWork uow, String operation, SObject record) {
    try {
      if (operation == 'new') {
        uow.registerNew(record);
      } else if (operation == 'dirty') {
        uow.registerDirty(record);
      } else if (operation == 'deleted') {
        uow.registerDeleted(record);
      } else {
        uow.commitWork();
      }
      Assert.fail('Expected UnitOfWorkException');
    } catch (UnitOfWorkException e) {
      return e.getMessage();
    }
    return null;
  }

  private static String expectUpsertError(UnitOfWork uow, List<SObject> records, SObjectField key) {
    try {
      uow.registerUpsert(records, key);
      Assert.fail('Expected UnitOfWorkException');
    } catch (UnitOfWorkException e) {
      return e.getMessage();
    }
    return null;
  }

  private static List<Order> ordersWithReferences(Id accountId, Integer count, String name) {
    List<Order> orders = new List<Order>();
    for (Integer i = 0; i < count; i++) {
      Order row = DataTestFixtures.draftOrder();
      row.AccountId = accountId;
      row.OrderReferenceNumber = 'REF-' + String.valueOf(i).leftPad(3, '0');
      row.Name = name;
      orders.add(row);
    }
    return orders;
  }

  private static Account withId() {
    return new Account(Id = FakeId.generate(Account.SObjectType), Name = 'Existing');
  }

  // ---- Commit ordering and relationships (fake DML) ----

  @IsTest
  static void commitWork_200ParentsAndChildren_insertsParentsFirstAndResolvesLookups() {
    FakeDml dml = new FakeDml();
    UnitOfWork uow = new UnitOfWork(COMMIT_ORDER, dml);
    List<Account> accounts = DataTestFixtures.accounts(200);
    List<Order> orders = new List<Order>();
    for (Account account : accounts) {
      Order child = DataTestFixtures.draftOrder();
      uow.registerNew(child, Order.AccountId, account);
      orders.add(child);
    }
    uow.registerNew(accounts);

    uow.commitWork();

    Assert.areEqual(new List<String>{ 'insert Account', 'insert Order' }, dml.log, 'Commit order, one call per type');
    for (Integer i = 0; i < 200; i++) {
      Assert.areEqual(accounts[i].Id, orders[i].AccountId, 'Lookup resolved to the parent inserted earlier');
    }
  }

  @IsTest
  static void commitWork_updatesFollowCommitOrderAndDeletesRunInReverse() {
    FakeDml dml = new FakeDml();
    UnitOfWork uow = new UnitOfWork(COMMIT_ORDER, dml);
    uow.registerDeleted(withId());
    uow.registerDeleted(new Order(Id = FakeId.generate(Order.SObjectType)));
    uow.registerDirty(new Order(Id = FakeId.generate(Order.SObjectType)));
    uow.registerDirty(withId());

    uow.commitWork();

    Assert.areEqual(
      new List<String>{ 'update Account', 'update Order', 'delete Order', 'delete Account' },
      dml.log,
      'Updates parents first; deletes children first'
    );
  }

  // ---- Upserts (fake DML) ----

  @IsTest
  static void commitWork_upsertsFollowEachTypesInsertsAndPrecedeUpdates() {
    FakeDml dml = new FakeDml();
    UnitOfWork uow = new UnitOfWork(COMMIT_ORDER, dml);
    Account parent = new Account(Name = 'New');
    uow.registerDeleted(new Order(Id = FakeId.generate(Order.SObjectType)));
    uow.registerDirty(withId());
    uow.registerUpsert(new List<Order>{ DataTestFixtures.draftOrder() }, Order.OrderReferenceNumber);
    uow.registerNew(DataTestFixtures.draftOrder(), Order.AccountId, parent);
    uow.registerUpsert(new List<Account>{ withId() }, Account.Id);
    uow.registerNew(parent);

    uow.commitWork();

    Assert.areEqual(
      new List<String>{
        'insert Account',
        'upsert Account',
        'insert Order',
        'upsert Order',
        'update Account',
        'delete Order'
      },
      dml.log,
      'Per type: inserts then upserts; then updates; then deletes in reverse'
    );
    Assert.areEqual(Order.OrderReferenceNumber, dml.keyByCall.get('upsert Order'), 'The registered key is passed');
  }

  @IsTest
  static void registerUpsert_childOfAnUpsertedParent_resolvesTheLookup() {
    FakeDml dml = new FakeDml();
    UnitOfWork uow = new UnitOfWork(COMMIT_ORDER, dml);
    Account parent = new Account(Name = 'Upserted');
    Order child = DataTestFixtures.draftOrder();
    uow.registerUpsert(new List<Account>{ parent }, Account.Id);
    uow.registerUpsert(new List<Order>{ child }, Order.OrderReferenceNumber);
    uow.registerRelationship(child, Order.AccountId, parent);

    uow.commitWork();

    Assert.isNotNull(parent.Id, 'The parent was upserted first');
    Assert.areEqual(parent.Id, child.AccountId, 'The child resolved its lookup to the upserted parent');
  }

  @IsTest
  static void registerUpsert_200RecordsInTwoCalls_isOneUpsertStatement() {
    FakeDml dml = new FakeDml();
    UnitOfWork uow = new UnitOfWork(COMMIT_ORDER, dml);
    List<Account> accounts = DataTestFixtures.accounts(200);
    uow.registerUpsert(new List<Account>{ accounts[0] }, Account.Id);
    accounts.remove(0);
    uow.registerUpsert(accounts, Account.Id);

    uow.commitWork();

    Assert.areEqual(new List<String>{ 'upsert Account' }, dml.log, 'One upsert for the type');
    Assert.areEqual(200, dml.recordsByCall.get('upsert Account').size(), 'Every registered record');
  }

  @IsTest
  static void registerUpsert_emptyList_spendsNoDml() {
    FakeDml dml = new FakeDml();
    UnitOfWork uow = new UnitOfWork(COMMIT_ORDER, dml);
    uow.registerUpsert(new List<Account>(), Account.Id);

    uow.commitWork();

    Assert.areEqual(0, dml.log.size(), 'Nothing to write');
    Assert.areEqual(0, Limits.getDmlStatements(), 'Not even a savepoint');
  }

  @IsTest
  static void registerUpsert_invalidArguments_throw() {
    UnitOfWork uow = new UnitOfWork(COMMIT_ORDER, new FakeDml());
    List<Account> accounts = DataTestFixtures.accounts(1);

    Assert.isTrue(expectUpsertError(uow, null, Account.Id).contains('needs records'), 'Null records');
    Assert.isTrue(expectUpsertError(uow, accounts, null).contains('needs records'), 'Null key');
    Assert.isTrue(
      expectUpsertError(uow, new List<Contact>{ new Contact(LastName = 'Out') }, Contact.Id)
        .contains('not in this Unit of Work'),
      'Type outside the commit order'
    );
    Assert.isTrue(
      expectUpsertError(uow, accounts, Account.Name)
        .contains('Name is not an External Id or idLookup field of Account'),
      'Not an idLookup field'
    );
    Assert.isTrue(
      expectUpsertError(uow, accounts, Order.OrderReferenceNumber).contains('of Account'),
      'A field of another type'
    );
  }

  @IsTest
  static void registerUpsert_secondKeyForTheSameType_throws() {
    UnitOfWork uow = new UnitOfWork(COMMIT_ORDER, new FakeDml());
    uow.registerUpsert(new List<Order>{ DataTestFixtures.draftOrder() }, Order.Id);

    String message = expectUpsertError(
      uow,
      new List<Order>{ DataTestFixtures.draftOrder() },
      Order.OrderReferenceNumber
    );

    Assert.isTrue(message.contains('already upserted by Id'), message);
  }

  @IsTest
  static void registerWork_runsAfterAllDml() {
    FakeDml dml = new FakeDml();
    UnitOfWork uow = new UnitOfWork(COMMIT_ORDER, dml);
    uow.registerWork(new LogWork(dml.log));
    uow.registerNew(DataTestFixtures.accounts(1));

    uow.commitWork();

    Assert.areEqual(new List<String>{ 'insert Account', 'work' }, dml.log, 'Work runs last, inside the commit');
  }

  @IsTest
  static void registerDirty_twoPathsWithFieldLists_mergeIntoOneSparseUpdate() {
    FakeDml dml = new FakeDml();
    UnitOfWork uow = new UnitOfWork(COMMIT_ORDER, dml);
    Id accountId = FakeId.generate(Account.SObjectType);

    uow.registerDirty(
      new Account(Id = accountId, Name = 'Renamed', Phone = 'ignored'),
      new List<SObjectField>{ Account.Name }
    );
    uow.registerDirty(new Account(Id = accountId, Phone = '555-0100'), new List<SObjectField>{ Account.Phone });
    uow.commitWork();

    List<SObject> updated = dml.recordsByCall.get('update Account');
    Assert.areEqual(1, updated.size(), 'One record per Id');
    Assert.areEqual('Renamed', updated[0].get('Name'), 'First path\'s field');
    Assert.areEqual('555-0100', updated[0].get('Phone'), 'Second path\'s field, not the ignored value');
  }

  @IsTest
  static void registerDirty_sameInstanceTwice_isOneUpdate() {
    FakeDml dml = new FakeDml();
    UnitOfWork uow = new UnitOfWork(COMMIT_ORDER, dml);
    Account account = withId();

    uow.registerDirty(new List<Account>{ account, account });
    uow.commitWork();

    Assert.areEqual(1, dml.recordsByCall.get('update Account').size(), 'Registering the same instance is idempotent');
  }

  @IsTest
  static void registerDeleted_list_deletesEach() {
    FakeDml dml = new FakeDml();
    UnitOfWork uow = new UnitOfWork(COMMIT_ORDER, dml);

    uow.registerDeleted(new List<Account>{ withId(), withId() });
    uow.commitWork();

    Assert.areEqual(2, dml.recordsByCall.get('delete Account').size(), 'Both deleted in one call');
  }

  @IsTest
  static void commitWork_nothingRegistered_spendsNoDml() {
    UnitOfWork uow = new UnitOfWork(COMMIT_ORDER, new FakeDml());

    Test.startTest();
    uow.commitWork();
    Integer dmlStatements = Limits.getDmlStatements();
    Test.stopTest();

    Assert.areEqual(0, dmlStatements, 'No savepoint and no DML for an empty unit');
  }

  // ---- Registration mistakes fail fast ----

  @IsTest
  static void registerNew_recordWithId_throws() {
    String message = expectError(new UnitOfWork(COMMIT_ORDER, new FakeDml()), 'new', withId());

    Assert.isTrue(message.contains('without an Id'), message);
  }

  @IsTest
  static void registerDirtyOrDeleted_recordWithoutId_throws() {
    UnitOfWork uow = new UnitOfWork(COMMIT_ORDER, new FakeDml());

    Assert.isTrue(expectError(uow, 'dirty', new Account(Name = 'New')).contains('needs a record with an Id'), 'Dirty');
    Assert.isTrue(
      expectError(uow, 'deleted', new Account(Name = 'New')).contains('needs a record with an Id'),
      'Deleted'
    );
  }

  @IsTest
  static void register_typeOutsideCommitOrder_throws() {
    String message = expectError(new UnitOfWork(COMMIT_ORDER, new FakeDml()), 'new', new Contact(LastName = 'Ng'));

    Assert.isTrue(message.contains('Contact is not in this Unit of Work'), message);
  }

  @IsTest
  static void register_nullRecord_throws() {
    String message = expectError(new UnitOfWork(COMMIT_ORDER, new FakeDml()), 'new', null);

    Assert.isTrue(message.contains('null record'), message);
  }

  @IsTest
  static void registerDirty_differentInstancesWithoutFieldList_throws() {
    UnitOfWork uow = new UnitOfWork(COMMIT_ORDER, new FakeDml());
    Account first = withId();
    uow.registerDirty(first);

    String message = expectError(uow, 'dirty', new Account(Id = first.Id, Name = 'Other'));

    Assert.isTrue(message.contains('registerDirty(record, dirtyFields)'), message);
  }

  @IsTest
  static void registerDeleted_recordAlreadyDirty_throws() {
    UnitOfWork uow = new UnitOfWork(COMMIT_ORDER, new FakeDml());
    Account account = withId();
    uow.registerDirty(account);

    Assert.isTrue(expectError(uow, 'deleted', account).contains('both dirty and deleted'), 'Conflict');
  }

  @IsTest
  static void registerRelationship_fieldIsNotALookupToTheParent_throws() {
    UnitOfWork uow = new UnitOfWork(COMMIT_ORDER, new FakeDml());

    try {
      uow.registerRelationship(DataTestFixtures.draftOrder(), Order.AccountId, DataTestFixtures.draftOrder());
      Assert.fail('Expected UnitOfWorkException');
    } catch (UnitOfWorkException e) {
      Assert.isTrue(e.getMessage().contains('is not a lookup to Order'), e.getMessage());
    }
  }

  @IsTest
  static void registerRelationship_missingArguments_throw() {
    UnitOfWork uow = new UnitOfWork(COMMIT_ORDER, new FakeDml());

    try {
      uow.registerRelationship(DataTestFixtures.draftOrder(), Order.AccountId, null);
      Assert.fail('Expected UnitOfWorkException');
    } catch (UnitOfWorkException e) {
      Assert.isTrue(e.getMessage().contains('needs a lookup field and a parent'), e.getMessage());
    }
  }

  @IsTest
  static void registerWork_null_throws() {
    try {
      new UnitOfWork(COMMIT_ORDER, new FakeDml()).registerWork(null);
      Assert.fail('Expected UnitOfWorkException');
    } catch (UnitOfWorkException e) {
      Assert.isTrue(e.getMessage().contains('non-null work'), e.getMessage());
    }
  }

  @IsTest
  static void commitWork_parentLaterInCommitOrder_throwsNamingTheFix() {
    UnitOfWork uow = new UnitOfWork(new List<SObjectType>{ Order.SObjectType, Account.SObjectType }, new FakeDml());
    uow.registerNew(DataTestFixtures.draftOrder(), Order.AccountId, new Account(Name = 'Later'));

    String message = expectError(uow, 'commit', null);

    Assert.isTrue(message.contains('Put Account earlier in the commit order'), message);
  }

  @IsTest
  static void commitWork_calledTwice_throws() {
    UnitOfWork uow = new UnitOfWork(COMMIT_ORDER, new FakeDml());
    uow.commitWork();

    Assert.isTrue(expectError(uow, 'commit', null).contains('already called'), 'One commit per operation');
  }

  @IsTest
  static void constructor_emptyCommitOrderOrNullDml_throws() {
    try {
      new UnitOfWork(new List<SObjectType>(), new FakeDml());
      Assert.fail('Expected UnitOfWorkException');
    } catch (UnitOfWorkException e) {
      Assert.isTrue(e.getMessage().contains('non-empty commit order'), e.getMessage());
    }
  }

  // ---- Integration: real DML in user mode ----

  @IsTest
  static void commitWork_realDml_200AccountsWithOrders_commitsInThreeStatements() {
    IUnitOfWork uow = new UnitOfWork(COMMIT_ORDER);
    for (Account account : DataTestFixtures.accounts(200)) {
      uow.registerNew(account);
      uow.registerNew(DataTestFixtures.draftOrder(), Order.AccountId, account);
    }

    Test.startTest();
    uow.commitWork();
    Integer dmlStatements = Limits.getDmlStatements();
    Test.stopTest();

    Assert.areEqual(200, [SELECT COUNT() FROM Order WHERE AccountId != NULL], 'Every order linked to its account');
    Assert.areEqual(3, dmlStatements, 'Savepoint plus one insert per type');
  }

  @IsTest
  static void commitWork_childInsertFails_rollsBackParentsAndClearsTheirIds() {
    IUnitOfWork uow = new UnitOfWork(COMMIT_ORDER);
    Account account = new Account(Name = 'Rolled back');
    Order invalid = new Order(Status = 'Draft'); // EffectiveDate is required
    uow.registerNew(account);
    uow.registerNew(invalid, Order.AccountId, account);

    try {
      uow.commitWork();
      Assert.fail('Expected DmlException');
    } catch (DmlException e) {
      Assert.isTrue(
        e.getMessage().contains('REQUIRED_FIELD_MISSING'),
        'The original exception is rethrown: ' + e.getMessage()
      );
    }

    Assert.areEqual(0, [SELECT COUNT() FROM Account], 'The parent insert was rolled back');
    Assert.isNull(account.Id, 'The rolled-back Id is cleared so it cannot be reused');
  }

  @IsTest
  static void commitWork_realDml_upsertTwiceByReference_updatesTheSameRows() {
    Account account = new Account(Name = 'Customer');
    IUnitOfWork first = new UnitOfWork(COMMIT_ORDER);
    first.registerNew(account);
    List<Order> created = ordersWithReferences(null, 200, 'First');
    first.registerUpsert(created, Order.OrderReferenceNumber);
    for (Order row : created) {
      first.registerRelationship(row, Order.AccountId, account);
    }
    first.commitWork();

    Test.startTest();
    IUnitOfWork second = new UnitOfWork(COMMIT_ORDER);
    List<Order> again = ordersWithReferences(account.Id, 200, 'Second');
    second.registerUpsert(again, Order.OrderReferenceNumber);
    second.commitWork();
    Integer dmlStatements = Limits.getDmlStatements();
    Test.stopTest();

    Assert.areEqual(200, [SELECT COUNT() FROM Order], 'Matched on the reference, so no duplicates');
    Assert.areEqual(200, [SELECT COUNT() FROM Order WHERE Name = 'Second'], 'Every row was updated');
    Assert.areEqual(created[199].Id, again[199].Id, 'Matched records get the existing Id');
    Assert.areEqual(2, dmlStatements, 'Savepoint plus one upsert');
  }

  @IsTest
  static void commitWork_failsAfterAnUpsert_rollsBackAndClearsOnlyAssignedIds() {
    Account existing = new Account(Name = 'Existing');
    insert existing;
    Id existingId = existing.Id;
    existing.Name = 'Renamed';
    Account created = new Account(Name = 'Created');
    IUnitOfWork uow = new UnitOfWork(COMMIT_ORDER);
    uow.registerUpsert(new List<Account>{ existing, created }, Account.Id);
    uow.registerNew(new Order(Status = 'Draft'), Order.AccountId, created); // EffectiveDate is required

    try {
      uow.commitWork();
      Assert.fail('Expected DmlException');
    } catch (DmlException e) {
      Assert.isTrue(e.getMessage().contains('REQUIRED_FIELD_MISSING'), e.getMessage());
    }

    Assert.areEqual(1, [SELECT COUNT() FROM Account], 'The created account was rolled back');
    Assert.areEqual('Existing', [SELECT Name FROM Account WHERE Id = :existingId].Name, 'The update was rolled back');
    Assert.isNull(created.Id, 'The Id the upsert assigned is cleared');
    Assert.areEqual(existingId, existing.Id, 'A record that already had an Id keeps it');
  }

  @IsTest
  static void commitWork_registeredWorkFails_rollsBackAllDml() {
    IUnitOfWork uow = new UnitOfWork(COMMIT_ORDER);
    uow.registerNew(DataTestFixtures.accounts(1));
    uow.registerWork(new FailingWork());

    try {
      uow.commitWork();
      Assert.fail('Expected WorkFailedException');
    } catch (WorkFailedException e) {
      Assert.areEqual('Event bus unavailable', e.getMessage(), 'The work\'s exception is rethrown');
    }

    Assert.areEqual(0, [SELECT COUNT() FROM Account], 'DML before the failing work was rolled back');
  }
}
