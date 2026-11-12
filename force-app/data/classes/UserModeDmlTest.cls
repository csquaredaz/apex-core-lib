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
}
