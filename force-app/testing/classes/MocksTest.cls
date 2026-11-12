@IsTest
private class MocksTest {
  // Return-value cases call the StubProvider contract directly: the package has no stubbable
  // top-level type with a non-void method, and @IsTest classes can't be virtual. The Stub API
  // round trip is covered through IAlertSink below.
  private static Object call(Mocks mock, String methodName, List<Object> args) {
    return mock.handleMethodCall(null, methodName, String.class, new List<Type>(), new List<String>(), args);
  }

  @IsTest
  static void stubReturn_configuredMethod_returnsValue() {
    Mocks mock = new Mocks().stubReturn('greet', 'Mocked');

    Assert.areEqual(
      'Mocked',
      call(mock, 'GREET', new List<Object>{ 'Ada' }),
      'Returns the stubbed value, matched case-insensitively'
    );
  }

  @IsTest
  static void unstubbedMethod_returnsNull() {
    Assert.isNull(call(new Mocks(), 'greet', null), 'Unstubbed methods return null');
  }

  @IsTest
  static void calls_areRecordedWithArgumentsInOrder() {
    Mocks mock = new Mocks();

    call(mock, 'greet', new List<Object>{ 'Ada' });
    call(mock, 'greet', new List<Object>{ 'Grace' });

    mock.verify('greet', 2);
    Assert.areEqual('Grace', mock.argumentsOf('greet', 1)[0], 'Arguments are kept per call, in order');
  }

  @IsTest
  static void stub_alertSink_routesCallsThroughTheStubApi() {
    Mocks sinkMock = new Mocks();
    IAlertSink sink = (IAlertSink) sinkMock.stub(IAlertSink.class);
    List<Alert> alerts = new List<Alert>{ new Alert(Alert.Severity.INFO, 'Hi', null, 'Test') };

    sink.send(alerts);

    sinkMock.verify('send', 1);
    Assert.areEqual(alerts, sinkMock.argumentsOf('send', 0)[0], 'The stub records the real arguments');
  }

  @IsTest
  static void stubThrow_configuredMethod_throwsAndStillRecords() {
    Mocks sinkMock = new Mocks().stubThrow('send', new CalloutException('sink down'));
    IAlertSink sink = (IAlertSink) sinkMock.stub(IAlertSink.class);

    try {
      sink.send(new List<Alert>());
      Assert.fail('Expected CalloutException');
    } catch (CalloutException e) {
      Assert.areEqual('sink down', e.getMessage(), 'Throws the stubbed exception');
    }
    sinkMock.verify('send', 1);
  }

  @IsTest
  static void verify_neverCalledMethod_countsZero() {
    Assert.areEqual(0, new Mocks().callCount('send'), 'No calls recorded');
  }
}
