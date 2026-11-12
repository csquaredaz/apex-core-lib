/**
 * @description Alerting port (Ports and Adapters): sends alerts that a human should act on.
 * The default adapter is `NoOpAlertSink`. `apex-platform-logging` provides a Slack adapter.
 * Takes a list so adapters can batch their callouts or events.
 * @group Public API
 */
public interface IAlertSink {
  /**
   * @description Sends the alerts. Adapters must not throw on delivery failure; they log it.
   * @param alerts The alerts to send; null or empty is a no-op.
   */
  void send(List<Alert> alerts);
}
