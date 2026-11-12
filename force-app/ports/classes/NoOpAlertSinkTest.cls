@IsTest
private class NoOpAlertSinkTest {
  @IsTest
  static void send_alertsOrNull_hasNoSideEffects() {
    IAlertSink sink = new NoOpAlertSink();

    Test.startTest();
    sink.send(new List<Alert>{ new Alert(Alert.Severity.WARNING, 'Retrying', null, 'Test') });
    sink.send(null);
    Test.stopTest();

    Assert.areEqual(0, Limits.getDmlStatements(), 'Null Object: no DML');
    Assert.areEqual(0, Limits.getPublishImmediateDML(), 'Null Object: no events');
    Assert.areEqual(0, Limits.getCallouts(), 'Null Object: no callouts');
  }
}
