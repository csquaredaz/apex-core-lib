/**
 * @description Sends `CalloutRequest`s through Named Credentials, with bounded synchronous retry
 * (Retry, Strategy via `RetryPolicy`). The default `ICalloutClient` binding.
 *
 * Outcomes of `send`:
 * - **A response the policy won't retry**, such as 2xx, 4xx, 429, or a 5xx on a non-idempotent
 *   request, is returned. Check `isSuccess()`.
 * - **A transient failure that persists** after the policy's retries throws
 *   `CalloutClientException` with the attempt count and last response.
 * - **A transport error the policy won't retry** (a timeout on a POST without an idempotency key)
 *   throws `CalloutClientException` after one attempt, because the request may have reached the server.
 *
 * Each retryable failure is logged as a warning through `ILogger`, with the correlation id. Retries stop early
 * if the transaction has no callouts left.
 *
 * Deliberately omitted: a circuit breaker. It needs state shared across transactions, which costs
 * a DML or Platform Cache, and belongs to a consumer that owns the integration (ADR 0007).
 *
 * Limits: up to `1 + RetryPolicy.getMaxRetries()` callouts per `send`; no SOQL or DML.
 * @group Public API
 */
public with sharing class CalloutClient implements ICalloutClient {
  private final RetryPolicy policy;

  /** @description A client with the default `RetryPolicy`. */
  public CalloutClient() {
    this(new RetryPolicy());
  }

  /**
   * @description A client with a custom retry policy.
   * @param policy The policy; use `new RetryPolicy(0)` to never retry.
   * @throws CalloutClientException If the policy is null.
   */
  public CalloutClient(RetryPolicy policy) {
    if (policy == null) {
      throw new CalloutClientException('A callout client needs a retry policy.');
    }
    this.policy = policy;
  }

  /**
   * @description Sends the request, retrying transient failures as the policy allows.
   * @param request The request.
   * @return The response that ended the retries.
   * @throws CalloutClientException If the request is null, transient failures outlast the retries,
   * or a non-retryable attempt hits a transport error.
   */
  public CalloutResponse send(CalloutRequest request) {
    if (request == null) {
      throw new CalloutClientException('Cannot send a null callout request.');
    }
    Http http = new Http();
    Integer maxAttempts = 1 + policy.getMaxRetries();
    Attempt last;
    do {
      last = new Attempt(http, request, last == null ? 1 : last.ordinal + 1);
      if (!policy.isRetryable(request, last.statusCode())) {
        return last.responseOrThrow(request);
      }
      logFailure(request, last, maxAttempts);
    } while (last.ordinal < maxAttempts && Limits.getCallouts() < Limits.getLimitCallouts());
    throw CalloutClientException.failed(request, last.ordinal, last.response, last.transportError);
  }

  /** One attempt's outcome: a response, or the transport error that replaced it. */
  private class Attempt {
    private final Integer ordinal;
    private CalloutResponse response;
    private System.CalloutException transportError;

    private Attempt(Http http, CalloutRequest request, Integer ordinal) {
      this.ordinal = ordinal;
      try {
        response = new CalloutResponse(http.send(request.toHttpRequest()), ordinal, request.getCorrelationId());
      } catch (System.CalloutException e) {
        transportError = e;
      }
    }

    private Integer statusCode() {
      return response == null ? null : response.getStatusCode();
    }

    private CalloutResponse responseOrThrow(CalloutRequest request) {
      if (transportError != null) {
        throw CalloutClientException.failed(request, ordinal, null, transportError);
      }
      return response;
    }
  }

  private static void logFailure(CalloutRequest request, Attempt attempt, Integer maxAttempts) {
    logger()
      .warn(
        request.getMethod() +
          ' ' +
          request.getEndpoint() +
          ' attempt ' +
          attempt.ordinal +
          ' of ' +
          maxAttempts +
          ' failed (' +
          (attempt.response == null ? 'transport error' : 'HTTP ' + attempt.statusCode()) +
          ') [' +
          CalloutRequest.CORRELATION_ID_HEADER +
          ' ' +
          request.getCorrelationId() +
          ']'
      );
  }

  private static ILogger logger() {
    return (ILogger) Application.Service.newInstance(ILogger.class);
  }
}
