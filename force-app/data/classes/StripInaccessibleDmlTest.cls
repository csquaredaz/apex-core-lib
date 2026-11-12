@IsTest
private class StripInaccessibleDmlTest {
  @IsTest
  static void dmlInsert_fieldWithoutAccess_stripsLogsAndCopiesIdBack() {
    User restricted = DataTestFixtures.restrictedUser(true);
    RecordingLogger log = new RecordingLogger();
    Account account = new Account(Name = 'Self-service', Phone = '555-0100');

    System.runAs(restricted) {
      new StripInaccessibleDml(new UserModeDml(), log).dmlInsert(new List<Account>{ account });
    }

    Assert.isNotNull(account.Id, 'The Id is copied back onto the caller\'s record');
    Assert.isNull([SELECT Phone FROM Account WHERE Id = :account.Id].Phone, 'Phone was stripped, not written');
    List<RecordingLogger.Entry> warnings = log.entries(LoggingLevel.WARN);
    Assert.areEqual(1, warnings.size(), 'One warning per stripped SObject type');
    Assert.isTrue(warnings[0].message.contains('insert of Account: Phone'), warnings[0].message);
  }

  @IsTest
  static void dmlUpdate_fieldWithoutAccess_updatesTheRestAndLogs() {
    User restricted = DataTestFixtures.restrictedUser(true);
    RecordingLogger log = new RecordingLogger();
    Account account = new Account(Name = 'Before');

    System.runAs(restricted) {
      IDml dml = new StripInaccessibleDml(new UserModeDml(), log);
      dml.dmlInsert(new List<Account>{ account });
      account.Name = 'After';
      account.Phone = '555-0100';
      dml.dmlUpdate(new List<Account>{ account });
    }

    Account saved = [SELECT Name, Phone FROM Account WHERE Id = :account.Id];
    Assert.areEqual('After', saved.Name, 'Accessible fields are updated');
    Assert.isNull(saved.Phone, 'The inaccessible field is not');
    Assert.isTrue(log.entries(LoggingLevel.WARN)[0].message.contains('update of Account: Phone'), 'Logged');
  }

  @IsTest
  static void dmlInsert_nothingInaccessible_logsNothing() {
    RecordingLogger log = new RecordingLogger();

    new StripInaccessibleDml(new UserModeDml(), log).dmlInsert(DataTestFixtures.accounts(1));

    Assert.areEqual(0, log.entries().size(), 'No warning when nothing is stripped');
  }

  @IsTest
  static void dmlInsert_200Records_delegatesOnce() {
    Mocks innerMock = new Mocks();
    IDml dml = new StripInaccessibleDml((IDml) innerMock.stub(IDml.class), new RecordingLogger());

    dml.dmlInsert(DataTestFixtures.accounts(200));

    innerMock.verify('dmlInsert', 1);
    Assert.areEqual(200, ((List<SObject>) innerMock.argumentsOf('dmlInsert', 0)[0]).size(), 'One bulk statement');
  }

  @IsTest
  static void dmlDelete_passesTheSameRecordsThrough() {
    Mocks innerMock = new Mocks();
    IDml dml = new StripInaccessibleDml((IDml) innerMock.stub(IDml.class), new RecordingLogger());
    List<Account> records = new List<Account>{ new Account(Id = FakeId.generate(Account.SObjectType)) };

    dml.dmlDelete(records);

    Assert.isTrue(innerMock.argumentsOf('dmlDelete', 0)[0] === records, 'Deletes are not field-level');
  }

  @IsTest
  static void defaultConstructor_logsThroughTheBoundLogger() {
    RecordingLogger log = new RecordingLogger();
    Application.Service.setMock(ILogger.class, log);
    User restricted = DataTestFixtures.restrictedUser(true);

    System.runAs(restricted) {
      new StripInaccessibleDml(new UserModeDml())
        .dmlInsert(new List<Account>{ new Account(Name = 'Bound', Phone = '555-0100') });
    }

    Assert.areEqual(1, log.entries(LoggingLevel.WARN).size(), 'Resolved ILogger through Application.Service');
  }

  @IsTest
  static void constructor_nullArguments_throw() {
    try {
      new StripInaccessibleDml(null, new RecordingLogger());
      Assert.fail('Expected IllegalArgumentException');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(e.getMessage().contains('wrapped IDml'), e.getMessage());
    }
  }
}
