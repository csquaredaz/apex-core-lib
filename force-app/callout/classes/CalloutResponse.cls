/**
 * @description A typed, read-only view of an HTTP response, plus how many attempts it took.
 * Header lookup is case-insensitive.
 * @group Public API
 */
public with sharing class CalloutResponse {
  private final Integer statusCode;
  private final String status;
  private final String body;
  private final Integer attempts;
  private final String correlationId;
  private final Map<String, String> headersByKey = new Map<String, String>();

  /**
   * @description Wraps a platform response. Public so consumers' tests can build responses for a
   * mocked `ICalloutClient`.
   * @param response The platform response.
   * @param attempts How many attempts the client made, at least 1.
   * @param correlationId The request's correlation id.
   * @throws CalloutClientException If the response is null.
   */
  public CalloutResponse(HttpResponse response, Integer attempts, String correlationId) {
    if (response == null) {
      throw new CalloutClientException('Cannot wrap a null HTTP response.');
    }
    this.statusCode = response.getStatusCode();
    this.status = response.getStatus();
    this.body = response.getBody();
    this.attempts = attempts;
    this.correlationId = correlationId;
    for (String name : response.getHeaderKeys()) {
      if (name != null) {
        headersByKey.put(name.toLowerCase(), response.getHeader(name));
      }
    }
  }

  /** @description @return The HTTP status code. */
  public Integer getStatusCode() {
    return statusCode;
  }

  /** @description @return The HTTP status text, for example `Service Unavailable`. */
  public String getStatus() {
    return status;
  }

  /** @description @return The response body. */
  public String getBody() {
    return body;
  }

  /** @description @return Attempts made, including the one that produced this response. */
  public Integer getAttempts() {
    return attempts;
  }

  /** @description @return The correlation id sent with the request. */
  public String getCorrelationId() {
    return correlationId;
  }

  /**
   * @description A response header.
   * @param name The header name (case-insensitive).
   * @return The value, or null if absent.
   */
  public String getHeader(String name) {
    return name == null ? null : headersByKey.get(name.toLowerCase());
  }

  /** @description @return True for a 2xx status. */
  public Boolean isSuccess() {
    return statusCode >= 200 && statusCode < 300;
  }

  /**
   * @description The `Retry-After` header in seconds, for a caller that schedules its own retry
   * (for example an async re-enqueue after a 429). The HTTP-date form isn't parsed.
   * @return The delay in seconds, or null if the header is absent or not a whole number.
   */
  public Integer getRetryAfterSeconds() {
    String value = getHeader('Retry-After');
    return value != null && value.trim().isNumeric() ? Integer.valueOf(value.trim()) : null;
  }

  /**
   * @description Deserialises a JSON body into a concrete Apex type. `JSON.deserialize` rejects
   * `Map<String, Object>`; for an untyped read use `JSON.deserializeUntyped(getBody())`.
   * @param apexType The type to deserialise into, for example `CarrierQuote.class`.
   * @return The deserialised value.
   */
  public Object readJson(Type apexType) {
    return JSON.deserialize(body, apexType);
  }
}
