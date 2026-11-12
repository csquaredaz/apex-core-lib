@IsTest
private class RecordingLoggerTest {
  @IsTest
  static void entries_recordEveryCallInOrder() {
    RecordingLogger log = new RecordingLogger();
    DmlException cause = new DmlException('boom');

    log.debug('d');
    log.info('i');
    log.warn('w');
    log.error('e', cause);
    log.flush();

    List<RecordingLogger.Entry> all = log.entries();
    Assert.areEqual(4, all.size(), 'One entry per log call');
    Assert.areEqual(LoggingLevel.DEBUG, all[0].level, 'Order is preserved');
    Assert.areEqual('w', log.entries(LoggingLevel.WARN)[0].message, 'Filter by level');
    Assert.areEqual(cause, log.entries(LoggingLevel.ERROR)[0].cause, 'The exception is kept');
    Assert.areEqual(1, log.flushCount(), 'Flushes are counted');
  }

  @IsTest
  static void setMock_injectsRecordingLoggerThroughTheFactory() {
    RecordingLogger log = new RecordingLogger();
    Application.Service.setMock(ILogger.class, log);

    ((ILogger) Application.Service.newInstance(ILogger.class)).info('via factory');

    Assert.areEqual('via factory', log.entries(LoggingLevel.INFO)[0].message, 'Code under test logs into the double');
  }
}
