@IsTest
private class TriggerContextTest {
  private static String expectError(TriggerOperation operation, List<SObject> newRecords, List<SObject> oldRecords) {
    try {
      new TriggerContext(operation, newRecords, oldRecords);
      Assert.fail('Expected ApplicationException');
    } catch (ApplicationException e) {
      return e.getMessage();
    }
    return null;
  }

  @IsTest
  static void constructor_update_keepsBothListsAndBuildsOldMap() {
    List<Account> oldRecords = DomainTestFixtures.accountsWithIds(3);
    List<Account> newRecords = oldRecords.deepClone(true);

    TriggerContext context = new TriggerContext(TriggerOperation.AFTER_UPDATE, newRecords, oldRecords);

    Assert.areEqual(TriggerOperation.AFTER_UPDATE, context.operation, 'Operation');
    Assert.isTrue(context.records() === newRecords, 'Update records are the new ones');
    Assert.areEqual(new Map<Id, SObject>(oldRecords).keySet(), context.oldMap.keySet(), 'oldMap by Id');
    Assert.areEqual(Account.SObjectType, context.sObjectType, 'Type');
  }

  @IsTest
  static void constructor_delete_usesOldRecords() {
    List<Account> oldRecords = DomainTestFixtures.accountsWithIds(2);

    TriggerContext context = new TriggerContext(TriggerOperation.BEFORE_DELETE, null, oldRecords);

    Assert.isTrue(context.records() === oldRecords, 'Delete records are the old ones');
    Assert.areEqual(Account.SObjectType, context.sObjectType, 'Type from the old records');
  }

  @IsTest
  static void constructor_insert_hasNoOldMap() {
    TriggerContext context = new TriggerContext(TriggerOperation.BEFORE_INSERT, new List<Account>(), null);

    Assert.isNull(context.oldMap, 'No old records on insert');
    Assert.areEqual(Account.SObjectType, context.sObjectType, 'Type from an empty typed list');
  }

  @IsTest
  static void constructor_untypedNonEmptyList_infersTypeFromFirstRecord() {
    List<SObject> records = new List<SObject>{ new Order() };

    Assert.areEqual(
      Order.SObjectType,
      new TriggerContext(TriggerOperation.AFTER_INSERT, records, null).sObjectType,
      'Inferred'
    );
  }

  @IsTest
  static void constructor_invalidArguments_throw() {
    Assert.isTrue(expectError(null, new List<Account>(), null).contains('needs an operation'), 'Null operation');
    Assert.isTrue(
      expectError(TriggerOperation.BEFORE_INSERT, null, null).contains('needs new records'),
      'Insert without new'
    );
    Assert.isTrue(
      expectError(TriggerOperation.AFTER_UPDATE, new List<Account>(), null).contains('needs old records'),
      'Update without old'
    );
    Assert.isTrue(
      expectError(TriggerOperation.AFTER_DELETE, null, null).contains('needs old records'),
      'Delete without old'
    );
    Assert.isTrue(
      expectError(TriggerOperation.BEFORE_INSERT, new List<SObject>(), null).contains('Cannot infer'),
      'Empty untyped list'
    );
  }

  @IsTest
  static void current_outsideTrigger_throws() {
    try {
      TriggerContext.current();
      Assert.fail('Expected ApplicationException');
    } catch (ApplicationException e) {
      Assert.isTrue(e.getMessage().contains('from a trigger'), e.getMessage());
    }
  }
}
