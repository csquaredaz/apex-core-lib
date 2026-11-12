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

  @IsTest
  static void selector_unboundType_throws() {
    try {
      Application.Selector.newInstance(Account.SObjectType);
      Assert.fail('Expected ApplicationException');
    } catch (ApplicationException e) {
      Assert.isTrue(e.getMessage().startsWith('No selector binding for Account'), e.getMessage());
    }
  }

  @IsTest
  static void unitOfWork_returnsUnitOfWork() {
    Assert.isInstanceOfType(
      Application.UnitOfWork.newInstance(new List<SObjectType>{ Account.SObjectType }),
      UnitOfWork.class,
      'Default Unit of Work'
    );
  }
}
