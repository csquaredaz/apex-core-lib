/**
 * @description Decides whether a failed attempt is retried, and how many times (Strategy).
 * Subclass it and pass the subclass to `CalloutClient` to change the rules for one integration.
 *
 * Defaults (ADR 0007):
 * - At most 2 retries, so 3 attempts. Apex can't sleep, so retries fire immediately. They absorb
 *   short blips inside one transaction; real backoff is asynchronous and belongs to the caller.
 * - Retried: a transport error (timeout, connection reset), 408, 500, 502, 503 and 504.
 * - Not retried: 429. An immediate retry hits the same rate limit; the caller reads
 *   `getRetryAfterSeconds()` and retries later. Nor any other status, including 501 and 505,
 *   which won't change on a retry.
 * - Only idempotent requests are retried (`CalloutRequest.isIdempotent()`), so a POST without an
 *   idempotency key is never sent twice.
 * @group Public API
 */
public virtual with sharing class RetryPolicy {
  /** @description The most retries any policy may make, to protect the transaction's callout budget. */
  public static final Integer MAX_RETRIES_CAP = 2;

  private static final Set<Integer> TRANSIENT_STATUSES = new Set<Integer>{ 408, 500, 502, 503, 504 };

  private final Integer maxRetries;

  /** @description The default policy: up to 2 retries. */
  public RetryPolicy() {
    this(MAX_RETRIES_CAP);
  }

  /**
   * @description A policy with a custom retry count.
   * @param maxRetries 0 (never retry) to 2.
   * @throws CalloutClientException If `maxRetries` is out of range.
   */
  public RetryPolicy(Integer maxRetries) {
    if (maxRetries == null || maxRetries < 0 || maxRetries > MAX_RETRIES_CAP) {
      throw new CalloutClientException(
        'A retry policy allows 0 to ' + MAX_RETRIES_CAP + ' retries, not ' + maxRetries + '.'
      );
    }
    this.maxRetries = maxRetries;
  }

  /**
   * @description How many retries the client may make after the first attempt.
   * @return The retry count.
   */
  public virtual Integer getMaxRetries() {
    return maxRetries;
  }

  /**
   * @description Whether an attempt's outcome is worth retrying, ignoring how many retries are left.
   * @param request The request.
   * @param statusCode The response status, or null when the attempt threw a transport error.
   * @return True if the request is idempotent and the failure is transient.
   */
  public virtual Boolean isRetryable(CalloutRequest request, Integer statusCode) {
    return request.isIdempotent() && (statusCode == null || TRANSIENT_STATUSES.contains(statusCode));
  }
}
