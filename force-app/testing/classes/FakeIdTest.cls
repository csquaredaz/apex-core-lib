@IsTest
private class FakeIdTest {
  @IsTest
  static void generate_returnsIdOfRequestedType() {
    Id accountId = FakeId.generate(Account.SObjectType);

    Assert.areEqual(Account.SObjectType, accountId.getSObjectType(), 'Id carries the Account key prefix');
  }

  @IsTest
  static void generate_200Calls_areUnique() {
    Set<Id> ids = new Set<Id>();
    for (Integer i = 0; i < 200; i++) {
      ids.add(FakeId.generate(Order.SObjectType));
    }

    Assert.areEqual(200, ids.size(), 'Every generated Id is unique');
  }
}
