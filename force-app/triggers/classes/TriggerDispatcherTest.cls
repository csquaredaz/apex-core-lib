@IsTest
private class TriggerDispatcherTest {
  private static final Integer BULK_SIZE = 200;

  private static void bindAccounts(String constructorName) {
    TriggerDispatcher.domains = DomainTestFixtures.factory(new Map<String, String>{ 'Account' => constructorName });
  }

  private static TriggerContext beforeInsert(Integer count) {
    return new TriggerContext(TriggerOperation.BEFORE_INSERT, DomainTestFixtures.accountsWithIds(count), null);
  }

  private static String expectError(TriggerContext context) {
    try {
      TriggerDispatcher.run(context);
      Assert.fail('Expected ApplicationException');
    } catch (ApplicationException e) {
      return e.getMessage();
    }
    return null;
  }

  @IsTest
  static void run_everyEventWith200Records_callsEachHookOnceOverAllRecords() {
    bindAccounts('DomainTestFixtures.AccountsDomainConstructor');
    List<Account> oldRecords = DomainTestFixtures.accountsWithIds(BULK_SIZE);
    List<Account> newRecords = oldRecords.deepClone(true);

    Test.startTest();
    TriggerDispatcher.run(new TriggerContext(TriggerOperation.BEFORE_INSERT, newRecords, null));
    TriggerDispatcher.run(new TriggerContext(TriggerOperation.AFTER_INSERT, newRecords, null));
    TriggerDispatcher.run(new TriggerContext(TriggerOperation.BEFORE_UPDATE, newRecords, oldRecords));
    TriggerDispatcher.run(new TriggerContext(TriggerOperation.AFTER_UPDATE, newRecords, oldRecords));
    TriggerDispatcher.run(new TriggerContext(TriggerOperation.BEFORE_DELETE, null, oldRecords));
    TriggerDispatcher.run(new TriggerContext(TriggerOperation.AFTER_DELETE, null, oldRecords));
    TriggerDispatcher.run(new TriggerContext(TriggerOperation.AFTER_UNDELETE, newRecords, null));
    Integer queries = Limits.getQueries();
    Test.stopTest();

    Assert.areEqual(
      new List<String>{
        'onApplyDefaults:200',
        'onBeforeInsert:200',
        'onValidate:200',
        'onAfterInsert:200',
        'onBeforeUpdate:200:200',
        'onValidate:200',
        'onAfterUpdate:200:200',
        'onBeforeDelete:200',
        'onAfterDelete:200',
        'onAfterUndelete:200'
      },
      DomainTestFixtures.hookLog,
      'Each hook once, in order, over all 200 records'
    );
    Assert.areEqual(0, queries, 'Dispatch itself runs no SOQL');
  }

  @IsTest
  static void run_mockDomainThroughApplication_isCalledForTheEvent() {
    Mocks domainMock = new Mocks();
    Application.Domain.setMock(Account.SObjectType, (IDomain) domainMock.stub(IDomain.class));
    List<Account> oldRecords = DomainTestFixtures.accountsWithIds(2);
    TriggerContext context = new TriggerContext(TriggerOperation.AFTER_UPDATE, oldRecords.deepClone(true), oldRecords);

    TriggerDispatcher.run(context);

    domainMock.verify('handleAfterUpdate', 1);
    Assert.isTrue(domainMock.argumentsOf('handleAfterUpdate', 0)[0] === context.oldMap, 'Passes Trigger.oldMap');
  }

  @IsTest
  static void run_killSwitchOff_callsNoHooks() {
    bindAccounts('DomainTestFixtures.AccountsDomainConstructor');
    TriggerDispatcher.settingRows = new List<Trigger_Setting__mdt>{
      new Trigger_Setting__mdt(SObject_Type__c = 'Account', Is_Active__c = true),
      new Trigger_Setting__mdt(SObject_Type__c = ' account ', Is_Active__c = false)
    };

    TriggerDispatcher.run(beforeInsert(BULK_SIZE));

    Assert.isFalse(TriggerDispatcher.isEnabled(Account.SObjectType), 'Any inactive row wins, case-insensitively');
    Assert.areEqual(0, DomainTestFixtures.hookLog.size(), 'No hooks while switched off');
  }

  @IsTest
  static void run_killSwitchOff_skipsBeforeResolvingABrokenBinding() {
    TriggerDispatcher.domains = DomainTestFixtures.factory(new Map<String, String>());
    TriggerDispatcher.settingRows = new List<Trigger_Setting__mdt>{
      new Trigger_Setting__mdt(SObject_Type__c = 'Account', Is_Active__c = false)
    };

    TriggerDispatcher.run(beforeInsert(1));

    Assert.areEqual(0, DomainTestFixtures.hookLog.size(), 'Switched off, so the missing binding never throws');
  }

  @IsTest
  static void run_activeOrNoSettingRow_runsHooks() {
    bindAccounts('DomainTestFixtures.AccountsDomainConstructor');
    TriggerDispatcher.settingRows = new List<Trigger_Setting__mdt>{
      new Trigger_Setting__mdt(SObject_Type__c = 'Account', Is_Active__c = true),
      new Trigger_Setting__mdt(SObject_Type__c = 'Order', Is_Active__c = false)
    };

    TriggerDispatcher.run(beforeInsert(1));

    Assert.isTrue(TriggerDispatcher.isEnabled(Account.SObjectType), 'Active row');
    Assert.isTrue(TriggerDispatcher.isEnabled(Contact.SObjectType), 'No row means active');
    Assert.areEqual(2, DomainTestFixtures.hookLog.size(), 'Before-insert hooks ran');
  }

  @IsTest
  static void run_bypassed_skipsUntilClearBypass() {
    bindAccounts('DomainTestFixtures.AccountsDomainConstructor');

    TriggerDispatcher.bypass(Account.SObjectType);
    TriggerDispatcher.run(beforeInsert(1));
    Boolean wasBypassed = TriggerDispatcher.isBypassed(Account.SObjectType);
    Integer hooksWhileBypassed = DomainTestFixtures.hookLog.size();
    TriggerDispatcher.clearBypass(Account.SObjectType);
    TriggerDispatcher.run(beforeInsert(1));

    Assert.isTrue(wasBypassed, 'Bypass recorded');
    Assert.areEqual(0, hooksWhileBypassed, 'No hooks while bypassed');
    Assert.isFalse(TriggerDispatcher.isBypassed(Account.SObjectType), 'Bypass cleared');
    Assert.areEqual(2, DomainTestFixtures.hookLog.size(), 'Hooks run again after clearBypass');
  }

  @IsTest
  static void run_bypassOfAnotherType_doesNotSkip() {
    bindAccounts('DomainTestFixtures.AccountsDomainConstructor');
    TriggerDispatcher.bypass(Order.SObjectType);

    TriggerDispatcher.run(beforeInsert(1));

    Assert.areEqual(2, DomainTestFixtures.hookLog.size(), 'Account still dispatches');
  }

  @IsTest
  static void run_reentryBeyondDefaultDepth_isSkippedAndLogged() {
    bindAccounts('DomainTestFixtures.ReentrantAccountsDomainConstructor');
    RecordingLogger logger = new RecordingLogger();
    Application.Service.setMock(ILogger.class, logger);

    TriggerDispatcher.run(beforeInsert(BULK_SIZE));

    Assert.areEqual(
      TriggerDispatcher.DEFAULT_MAX_DEPTH,
      DomainTestFixtures.hookLog.size(),
      'Outer run plus one re-entry'
    );
    List<RecordingLogger.Entry> warnings = logger.entries(LoggingLevel.WARN);
    Assert.areEqual(1, warnings.size(), 'The skipped run is logged once');
    Assert.isTrue(warnings[0].message.contains('re-entry depth 3 exceeds 2'), warnings[0].message);
  }

  @IsTest
  static void run_afterNestedRunsFinish_depthIsResetForTheNextEvent() {
    bindAccounts('DomainTestFixtures.ReentrantAccountsDomainConstructor');
    Application.Service.setMock(ILogger.class, new RecordingLogger());

    TriggerDispatcher.run(beforeInsert(1));
    TriggerDispatcher.run(beforeInsert(1));

    Assert.areEqual(4, DomainTestFixtures.hookLog.size(), 'Each top-level run gets the full depth again');
  }

  @IsTest
  static void run_domainThrows_depthIsStillReset() {
    bindAccounts('DomainTestFixtures.ReentrantAccountsDomainConstructor');
    Application.Service.setMock(ILogger.class, new RecordingLogger());
    TriggerDispatcher.setMaxDepth(Account.SObjectType, 1);
    TriggerContext context = new TriggerContext(TriggerOperation.BEFORE_INSERT, new List<Account>(), null);
    TriggerDispatcher.domains.setMock(
      Account.SObjectType,
      (IDomain) new Mocks().stubThrow('handleBeforeInsert', new ApplicationException('boom')).stub(IDomain.class)
    );

    Assert.areEqual('boom', expectError(context), 'The domain error propagates');
    TriggerDispatcher.domains = DomainTestFixtures.factory(
      new Map<String, String>{ 'Account' => 'DomainTestFixtures.AccountsDomainConstructor' }
    );
    TriggerDispatcher.run(beforeInsert(1));

    Assert.areEqual(2, DomainTestFixtures.hookLog.size(), 'Depth was released by the failed run');
  }

  @IsTest
  static void run_maxDepthOne_neverReenters() {
    bindAccounts('DomainTestFixtures.ReentrantAccountsDomainConstructor');
    Application.Service.setMock(ILogger.class, new RecordingLogger());
    TriggerDispatcher.setMaxDepth(Account.SObjectType, 1);

    TriggerDispatcher.run(beforeInsert(1));

    Assert.areEqual(1, DomainTestFixtures.hookLog.size(), 'Only the outer run');
  }

  @IsTest
  static void run_missingDomainBinding_throws() {
    TriggerDispatcher.domains = DomainTestFixtures.factory(new Map<String, String>());

    Assert.isTrue(expectError(beforeInsert(1)).startsWith('No domain binding for Account'), 'Missing binding');
  }

  @IsTest
  static void run_domainForWrongType_throws() {
    bindAccounts('DomainTestFixtures.MinimalOrdersDomainConstructor');

    Assert.isTrue(expectError(beforeInsert(1)).contains('owns Order'), 'Wrong type');
  }

  @IsTest
  static void run_nullContextOrOutsideTrigger_throws() {
    Assert.isTrue(expectError(null).contains('needs a trigger context'), 'Null context');
    try {
      TriggerDispatcher.run();
      Assert.fail('Expected ApplicationException');
    } catch (ApplicationException e) {
      Assert.isTrue(e.getMessage().contains('from a trigger'), e.getMessage());
    }
  }

  @IsTest
  static void setMaxDepth_belowOneOrNullType_throws() {
    try {
      TriggerDispatcher.setMaxDepth(Account.SObjectType, 0);
      Assert.fail('Expected ApplicationException');
    } catch (ApplicationException e) {
      Assert.isTrue(e.getMessage().contains('at least 1'), e.getMessage());
    }
    try {
      TriggerDispatcher.bypass(null);
      Assert.fail('Expected ApplicationException');
    } catch (ApplicationException e) {
      Assert.isTrue(e.getMessage().contains('needs an SObject type'), e.getMessage());
    }
  }
}
