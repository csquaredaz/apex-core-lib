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

  @IsTest
  static void dmlUpsert_userWithoutFieldAccess_stillWritesTheField() {
    Account existing = new Account(Name = 'Existing');
    insert existing;
    Account created = new Account(Name = 'Created', Phone = '555-0101');
    existing.Phone = '555-0100';

    System.runAs(DataTestFixtures.restrictedUser(true)) {
      new SystemDml().dmlUpsert(new List<Account>{ existing, created }, Account.Id);
    }

    Assert.areEqual('555-0100', [SELECT Phone FROM Account WHERE Id = :existing.Id].Phone, 'Matched and updated');
    Assert.areEqual('555-0101', [SELECT Phone FROM Account WHERE Id = :created.Id].Phone, 'Created');
  }
}
