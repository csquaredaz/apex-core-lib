@IsTest
private class ApplicationTest {
  @IsTest
  static void service_logger_defaultsToDebugLogger() {
    Object logger = Application.Service.newInstance(ILogger.class);

    Assert.isInstanceOfType(logger, DebugLogger.class, 'ILogger is bound to DebugLogger by default');
  }

  @IsTest
  static void service_alertSink_defaultsToNoOpAlertSink() {
    Object sink = Application.Service.newInstance(IAlertSink.class);

    Assert.isInstanceOfType(sink, NoOpAlertSink.class, 'IAlertSink is bound to NoOpAlertSink by default');
  }
}
