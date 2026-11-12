/**
 * @description Default `ILogger` adapter: writes each entry to the debug log immediately.
 * Entries don't survive a rollback and aren't queryable, which is why `apex-platform-logging`
 * exists. This adapter keeps the library usable without it.
 * @group Public API
 */
public with sharing class DebugLogger implements ILogger {
  /** @description See `ILogger.debug`. @param message The entry text. */
  public void debug(String message) {
    write(LoggingLevel.DEBUG, message, null);
  }

  /** @description See `ILogger.info`. @param message The entry text. */
  public void info(String message) {
    write(LoggingLevel.INFO, message, null);
  }

  /** @description See `ILogger.warn`. @param message The entry text. */
  public void warn(String message) {
    write(LoggingLevel.WARN, message, null);
  }

  /**
   * @description See `ILogger.error`.
   * @param message The entry text.
   * @param cause The exception, or null.
   */
  public void error(String message, Exception cause) {
    write(LoggingLevel.ERROR, message, cause);
  }

  /** @description Nothing is buffered, so there's nothing to flush. */
  public void flush() {
    return;
  }

  private void write(LoggingLevel level, String message, Exception cause) {
    System.debug(level, format(level, message, cause));
  }

  @TestVisible
  private static String format(LoggingLevel level, String message, Exception cause) {
    String entry = '[' + level.name() + '] ' + (message == null ? '' : message);
    if (cause != null) {
      entry += ' | ' + cause.getTypeName() + ': ' + cause.getMessage() + '\n' + cause.getStackTraceString();
    }
    return entry;
  }
}
