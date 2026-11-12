/**
 * @description Default `IAlertSink` adapter (Null Object): accepts alerts and discards them, so
 * code can always raise alerts without checking whether an alerting adapter is installed.
 * @group Public API
 */
public with sharing class NoOpAlertSink implements IAlertSink {
  /**
   * @description Discards the alerts. No DML, events or callouts.
   * @param alerts The alerts to discard.
   */
  public void send(List<Alert> alerts) {
    return;
  }
}
