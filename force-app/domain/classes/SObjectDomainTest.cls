@IsTest
private class SObjectDomainTest {
  private static DomainTestFixtures.AccountsDomain accountsDomain(Integer count) {
    return new DomainTestFixtures.AccountsDomain(DomainTestFixtures.accountsWithIds(count));
  }

  @IsTest
  static void handleBeforeInsert_appliesDefaultsBeforeTheInsertHook() {
    accountsDomain(3).handleBeforeInsert();

    Assert.areEqual(new List<String>{ 'onApplyDefaults:3', 'onBeforeInsert:3' }, DomainTestFixtures.hookLog, 'Order');
  }

  @IsTest
  static void handleAfterInsert_validatesBeforeTheInsertHook() {
    accountsDomain(3).handleAfterInsert();

    Assert.areEqual(new List<String>{ 'onValidate:3', 'onAfterInsert:3' }, DomainTestFixtures.hookLog, 'Order');
  }

  @IsTest
  static void handleAfterUpdate_defaultUpdateValidationCallsOnValidate() {
    DomainTestFixtures.AccountsDomain domain = accountsDomain(3);

    domain.handleAfterUpdate(new Map<Id, SObject>(domain.getRecords()));

    Assert.areEqual(
      new List<String>{ 'onValidate:3', 'onAfterUpdate:3:3' },
      DomainTestFixtures.hookLog,
      'onValidate(existingRecords) falls back to onValidate()'
    );
  }

  @IsTest
  static void handleOtherEvents_callTheirOneHook() {
    DomainTestFixtures.AccountsDomain domain = accountsDomain(2);
    Map<Id, SObject> existing = new Map<Id, SObject>(domain.getRecords());

    domain.handleBeforeUpdate(existing);
    domain.handleBeforeDelete();
    domain.handleAfterDelete();
    domain.handleAfterUndelete();

    Assert.areEqual(
      new List<String>{ 'onBeforeUpdate:2:2', 'onBeforeDelete:2', 'onAfterDelete:2', 'onAfterUndelete:2' },
      DomainTestFixtures.hookLog,
      'One hook per event'
    );
  }

  @IsTest
  static void defaultHooks_doNothingAndKeepRecords() {
    List<Order> orders = new List<Order>{ new Order(Id = FakeId.generate(Order.SObjectType)) };
    IDomain domain = new DomainTestFixtures.MinimalOrdersDomain(orders);
    Map<Id, SObject> existing = new Map<Id, SObject>(orders);

    domain.handleBeforeInsert();
    domain.handleBeforeUpdate(existing);
    domain.handleBeforeDelete();
    domain.handleAfterInsert();
    domain.handleAfterUpdate(existing);
    domain.handleAfterDelete();
    domain.handleAfterUndelete();

    Assert.isTrue(domain.getRecords() === orders, 'The domain holds the list it was given');
    Assert.areEqual(Order.SObjectType, domain.getSObjectType(), 'Type');
  }

  @IsTest
  static void constructor_nullRecords_throws() {
    try {
      new DomainTestFixtures.AccountsDomain(null);
      Assert.fail('Expected ApplicationException');
    } catch (ApplicationException e) {
      Assert.isTrue(e.getMessage().contains('empty list'), e.getMessage());
    }
  }
}
