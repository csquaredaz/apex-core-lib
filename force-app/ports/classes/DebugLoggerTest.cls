@IsTest
private class DebugLoggerTest {
  @IsTest
  static void format_withoutCause_prefixesLevel() {
    Assert.areEqual(
      '[INFO] Order fulfilled',
      DebugLogger.format(LoggingLevel.INFO, 'Order fulfilled', null),
      'Level prefix and message'
    );
  }

  @IsTest
  static void format_nullMessage_rendersEmpty() {
    Assert.areEqual(
      '[DEBUG] ',
      DebugLogger.format(LoggingLevel.DEBUG, null, null),
      'A null message does not print "null"'
    );
  }

  @IsTest
  static void format_withCause_appendsTypeAndMessage() {
    String entry = DebugLogger.format(LoggingLevel.ERROR, 'Commit failed', new DmlException('Required field missing'));

    Assert.isTrue(entry.startsWith('[ERROR] Commit failed | System.DmlException: Required field missing'), entry);
  }

  @IsTest
  static void everyLevel_writesWithoutSideEffects() {
    ILogger logger = new DebugLogger();

    Test.startTest();
    logger.debug('d');
    logger.info('i');
    logger.warn('w');
    logger.error('e', new IllegalArgumentException('bad'));
    logger.flush();
    Test.stopTest();

    Assert.areEqual(0, Limits.getDmlStatements(), 'Debug logging performs no DML');
    Assert.areEqual(0, Limits.getPublishImmediateDML(), 'Debug logging publishes no events');
  }
}
