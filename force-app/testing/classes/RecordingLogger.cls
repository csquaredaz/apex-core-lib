/**
 * @description In-memory `ILogger` test double that records every entry, so tests can assert on
 * what was logged. Use it instead of `Mocks` for `ILogger`: the Stub API can't stub a method that
 * takes the base `Exception` type, which `ILogger.error` does (ADR 0002).
 *
 * ```apex
 * RecordingLogger log = new RecordingLogger();
 * Application.Service.setMock(ILogger.class, log);
 * // ... act ...
 * Assert.areEqual(1, log.entries(LoggingLevel.ERROR).size());
 * ```
 * @group Testing
 */
@IsTest
public class RecordingLogger implements ILogger {
  private final List<Entry> recorded = new List<Entry>();
  private Integer flushes = 0;

  /** @description One recorded log call. */
  public class Entry {
    /** @description The level the entry was logged at. */
    public final LoggingLevel level;
    /** @description The entry text. */
    public final String message;
    /** @description The exception for `error` entries; otherwise null. */
    public final Exception cause;

    private Entry(LoggingLevel level, String message, Exception cause) {
      this.level = level;
      this.message = message;
      this.cause = cause;
    }
  }

  /** @description Records a DEBUG entry. @param message The entry text. */
  public void debug(String message) {
    recorded.add(new Entry(LoggingLevel.DEBUG, message, null));
  }

  /** @description Records an INFO entry. @param message The entry text. */
  public void info(String message) {
    recorded.add(new Entry(LoggingLevel.INFO, message, null));
  }

  /** @description Records a WARN entry. @param message The entry text. */
  public void warn(String message) {
    recorded.add(new Entry(LoggingLevel.WARN, message, null));
  }

  /**
   * @description Records an ERROR entry.
   * @param message The entry text.
   * @param cause The exception, or null.
   */
  public void error(String message, Exception cause) {
    recorded.add(new Entry(LoggingLevel.ERROR, message, cause));
  }

  /** @description Counts the flush; see `flushCount()`. */
  public void flush() {
    flushes++;
  }

  /**
   * @description Every entry, in the order logged.
   * @return The entries.
   */
  public List<Entry> entries() {
    return new List<Entry>(recorded);
  }

  /**
   * @description Entries at one level, in the order logged.
   * @param level The level to filter by.
   * @return The matching entries.
   */
  public List<Entry> entries(LoggingLevel level) {
    List<Entry> matching = new List<Entry>();
    for (Entry entry : recorded) {
      if (entry.level == level) {
        matching.add(entry);
      }
    }
    return matching;
  }

  /**
   * @description How many times `flush()` was called.
   * @return The flush count.
   */
  public Integer flushCount() {
    return flushes;
  }
}
