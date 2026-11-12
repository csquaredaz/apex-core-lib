@IsTest
private class UserModeDmlTest {
  @IsTest
  static void insertUpdateDelete_permittedUser_roundTrip() {
    IDml dml = new UserModeDml();
    List<Account> accounts = DataTestFixtures.accounts(200);

    Test.startTest();
    dml.dmlInsert(accounts);
    for (Account account : accounts) {
      account.Phone = '555-0100';
    }
    dml.dmlUpdate(accounts);
    Integer phonesSet = [SELECT COUNT() FROM Account WHERE Phone = '555-0100'];
    dml.dmlDelete(accounts);
    Integer dmlStatements = Limits.getDmlStatements();
    Test.stopTest();

    Assert.areEqual(200, phonesSet, 'Insert then update reached every record');
    Assert.areEqual(0, [SELECT COUNT() FROM Account], 'Delete removed every record');
    Assert.areEqual(3, dmlStatements, 'One statement per operation for 200 records');
  }

  @IsTest
  static void dmlInsert_fieldWithoutFieldAccess_throwsAndInsertsNothing() {
    User restricted = DataTestFixtures.restrictedUser(true);
    Exception failure;

    System.runAs(restricted) {
      try {
        new UserModeDml().dmlInsert(new List<Account>{ new Account(Name = 'Blocked', Phone = '555-0100') });
      } catch (Exception e) {
        failure = e;
      }
    }

    Assert.isNotNull(failure, 'User mode rejects a field the user cannot edit');
    Assert.areEqual(0, [SELECT COUNT() FROM Account], 'All or none: nothing was inserted');
  }

  @IsTest
  static void dmlInsert_noObjectAccess_throws() {
    User restricted = DataTestFixtures.restrictedUser(false);
    Exception failure;

    System.runAs(restricted) {
      try {
        new UserModeDml().dmlInsert(new List<Account>{ new Account(Name = 'Blocked') });
      } catch (Exception e) {
        failure = e;
      }
    }

    Assert.isNotNull(failure, 'User mode enforces object permissions');
  }

  @IsTest
  static void dmlUpsert_byOrderReference_updatesMatchesAndCreatesTheRest() {
    Account account = new Account(Name = 'Customer');
    insert account;
    List<Order> existing = new List<Order>();
    for (Integer i = 0; i < 100; i++) {
      existing.add(referencedOrder(account.Id, i, 'Before'));
    }
    insert existing;
    List<SObject> incoming = new List<SObject>();
    for (Integer i = 0; i < 200; i++) {
      incoming.add(referencedOrder(account.Id, i, 'After'));
    }

    Test.startTest();
    new UserModeDml().dmlUpsert(incoming, Order.OrderReferenceNumber);
    Integer dmlStatements = Limits.getDmlStatements();
    Test.stopTest();

    Assert.areEqual(existing[0].Id, incoming[0].Id, 'A matched record gets the existing Id');
    Assert.isNotNull(incoming[199].Id, 'A created record gets a new Id');
    Assert.areEqual(200, [SELECT COUNT() FROM Order], '100 matched, 100 created');
    Assert.areEqual(200, [SELECT COUNT() FROM Order WHERE Name = 'After'], 'Every row was written');
    Assert.areEqual(1, dmlStatements, 'One statement for 200 records');
  }

  @IsTest
  static void dmlUpsert_fieldWithoutFieldAccess_throwsAndWritesNothing() {
    User restricted = DataTestFixtures.restrictedUser(true);
    Exception failure;

    System.runAs(restricted) {
      try {
        new UserModeDml().dmlUpsert(new List<Account>{ new Account(Name = 'Blocked', Phone = '555-0100') }, Account.Id);
      } catch (Exception e) {
        failure = e;
      }
    }

    Assert.isNotNull(failure, 'User mode rejects a field the user cannot edit');
    Assert.areEqual(0, [SELECT COUNT() FROM Account], 'All or none: nothing was written');
  }

  private static Order referencedOrder(Id accountId, Integer i, String name) {
    Order row = DataTestFixtures.draftOrder();
    row.AccountId = accountId;
    row.OrderReferenceNumber = 'REF-' + String.valueOf(i).leftPad(3, '0');
    row.Name = name;
    return row;
  }
}
