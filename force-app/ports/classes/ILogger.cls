/**
 * @description Logging port (Ports and Adapters). Library and consumer code log through this
 * interface; the adapter decides where entries go. The default adapter is `DebugLogger`.
 * `apex-platform-logging` rebinds it with one `DI_Binding__mdt` row.
 *
 * Adapters may buffer entries; callers call `flush()` at the end of a unit of work.
 * @group Public API
 */
public interface ILogger {
  /**
   * @description Records diagnostic detail.
   * @param message The entry text.
   */
  void debug(String message);

  /**
   * @description Records a notable business or technical event.
   * @param message The entry text.
   */
  void info(String message);

  /**
   * @description Records something unexpected that the code recovered from.
   * @param message The entry text.
   */
  void warn(String message);

  /**
   * @description Records a failure.
   * @param message The entry text.
   * @param cause The exception, or null when there isn't one.
   */
  void error(String message, Exception cause);

  /**
   * @description Writes any buffered entries. A no-op for unbuffered adapters.
   */
  void flush();
}
