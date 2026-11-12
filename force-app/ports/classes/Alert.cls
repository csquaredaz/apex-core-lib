/**
 * @description An immutable alert passed to an `IAlertSink`.
 * @group Public API
 */
public with sharing class Alert {
  /**
   * @description How urgently a human should act.
   */
  public enum Severity {
    INFO,
    WARNING,
    CRITICAL
  }

  /** @description How urgently a human should act. */
  public final Severity severity;
  /** @description One-line summary. */
  public final String title;
  /** @description Supporting detail; may be blank. */
  public final String detail;
  /** @description The component that raised the alert, for example a class name. */
  public final String source;

  /**
   * @description Creates an alert.
   * @param severity How urgently a human should act; required.
   * @param title One-line summary; required.
   * @param detail Supporting detail; may be blank.
   * @param source The component that raised the alert.
   * @throws IllegalArgumentException If severity or title is missing.
   */
  public Alert(Severity severity, String title, String detail, String source) {
    if (severity == null || String.isBlank(title)) {
      throw new IllegalArgumentException('An alert needs a severity and a title.');
    }
    this.severity = severity;
    this.title = title;
    this.detail = detail;
    this.source = source;
  }
}
