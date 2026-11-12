@IsTest
private class SystemDmlTest {
  @IsTest
  static void dmlInsert_userWithoutFieldAccess_stillWritesTheField() {
    User restricted = DataTestFixtures.restrictedUser(true);
    Account account = new Account(Name = 'Audit', Phone = '555-0100');

    System.runAs(restricted) {
      new SystemDml().dmlInsert(new List<Account>{ account });
    }

    Assert.areEqual('555-0100', [SELECT Phone FROM Account WHERE Id = :account.Id].Phone, 'System mode skips FLS');
  }

  @IsTest
  static void updateAndDelete_roundTrip() {
    IDml dml = new SystemDml();
    Account account = new Account(Name = 'Audit');
    dml.dmlInsert(new List<Account>{ account });

    account.Name = 'Audit (updated)';
    dml.dmlUpdate(new List<Account>{ account });
    String name = [SELECT Name FROM Account WHERE Id = :account.Id].Name;
    dml.dmlDelete(new List<Account>{ account });

    Assert.areEqual('Audit (updated)', name, 'Updated');
    Assert.areEqual(0, [SELECT COUNT() FROM Account], 'Deleted');
  }
}
