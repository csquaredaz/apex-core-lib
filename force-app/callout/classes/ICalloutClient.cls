/**
 * @description Port for outbound HTTP callouts, so services depend on an interface and tests can
 * swap in a Stub API mock: `Application.Service.setMock(ICalloutClient.class, mock)`. The default
 * binding is `CalloutClient`.
 * @group Public API
 */
public interface ICalloutClient {
  /**
   * @description Sends a request through its Named Credential, retrying transient failures as
   * the client's retry policy allows.
   * @param request The request.
   * @return The response, including any non-2xx response that wasn't retried.
   */
  CalloutResponse send(CalloutRequest request);
}
