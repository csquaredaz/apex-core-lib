/**
 * @description Thrown by the callout layer. Two cases:
 * - **Invalid request:** a bad method, Named Credential, path, header or timeout. A coding defect.
 * - **Failed callout:** retries ran out on a transient failure, or a request that can't be
 *   retried hit a transport error. `getAttempts()` and `getLastResponse()` say what happened,
 *   and `getCause()` holds the platform `System.CalloutException` when there was one. Callers
 *   that can wait, such as a Queueable, catch this and retry later.
 *
 * Named so it doesn't shadow `System.CalloutException`.
 * @group Public API
 */
public with sharing class CalloutClientException extends Exception {
  private Integer attempts = 0;
  private CalloutResponse lastResponse;

  /**
   * @description Builds the exception for a callout that failed after one or more attempts.
   * @param request The request.
   * @param attempts Attempts made.
   * @param lastResponse The last response, or null if the last attempt threw.
   * @param cause The last transport error, or null.
   * @return The exception.
   */
  public static CalloutClientException failed(
    CalloutRequest request,
    Integer attempts,
    CalloutResponse lastResponse,
    System.CalloutException cause
  ) {
    String outcome = lastResponse != null
      ? 'HTTP ' + lastResponse.getStatusCode()
      : 'transport error: ' + (cause == null ? 'unknown' : cause.getMessage());
    CalloutClientException error = new CalloutClientException(
      request.getMethod() +
        ' ' +
        request.getEndpoint() +
        ' failed after ' +
        attempts +
        ' attempt(s), ' +
        outcome +
        ' [' +
        CalloutRequest.CORRELATION_ID_HEADER +
        ' ' +
        request.getCorrelationId() +
        ']'
    );
    if (cause != null) {
      error.initCause(cause);
    }
    error.attempts = attempts;
    error.lastResponse = lastResponse;
    return error;
  }

  /** @description @return Attempts made; 0 for an invalid request. */
  public Integer getAttempts() {
    return attempts;
  }

  /** @description @return The last response, or null if there was none. */
  public CalloutResponse getLastResponse() {
    return lastResponse;
  }
}
