/**
 * @description An outbound HTTP request, built fluently (Builder). The endpoint is always
 * `callout:<NamedCredential><path>`, so credentials and hosts live in a Named Credential and never
 * in code. Every request carries an `X-Correlation-Id` header, generated unless the caller sets
 * one, and the same value is sent on every retry.
 *
 * ```apex
 * CalloutRequest request = CalloutRequest.post('Carrier', '/shipments')
 *   .withJsonBody(payload)
 *   .withIdempotencyKey(shipment.Id)
 *   .withTimeout(5000);
 * ```
 * @group Public API
 */
public with sharing class CalloutRequest {
  /** @description Header that carries the correlation id. */
  public static final String CORRELATION_ID_HEADER = 'X-Correlation-Id';
  /** @description Header that makes a POST or PATCH safe to retry. */
  public static final String IDEMPOTENCY_KEY_HEADER = 'Idempotency-Key';
  /** @description Timeout used unless `withTimeout` sets another, in milliseconds. */
  public static final Integer DEFAULT_TIMEOUT_MILLIS = 10000;
  /** @description The platform's maximum callout timeout, in milliseconds. */
  public static final Integer MAX_TIMEOUT_MILLIS = 120000;

  private static final Set<String> IDEMPOTENT_METHODS = new Set<String>{ 'GET', 'HEAD', 'OPTIONS', 'PUT', 'DELETE' };
  private static final Set<String> SUPPORTED_METHODS = new Set<String>{
    'GET',
    'HEAD',
    'OPTIONS',
    'PUT',
    'DELETE',
    'POST',
    'PATCH'
  };
  private static final Pattern NAMED_CREDENTIAL = Pattern.compile('^[A-Za-z][A-Za-z0-9_]*$');

  private final String method;
  private final String namedCredential;
  private final String path;
  private final Map<String, String> headerNamesByKey = new Map<String, String>();
  private final Map<String, String> headerValuesByKey = new Map<String, String>();
  private String body;
  private Integer timeoutMillis = DEFAULT_TIMEOUT_MILLIS;

  /**
   * @description Creates a request for any supported verb; the shortcuts below cover the common ones.
   * @param method GET, HEAD, OPTIONS, PUT, DELETE, POST or PATCH (case-insensitive).
   * @param namedCredential The Named Credential's API name, for example `Carrier`.
   * @param path The path and query after the Named Credential's URL; empty, or starting with `/` or `?`.
   * @throws CalloutClientException If an argument is missing or invalid.
   */
  public CalloutRequest(String method, String namedCredential, String path) {
    this.method = requireMethod(method);
    this.namedCredential = requireNamedCredential(namedCredential);
    this.path = requirePath(path);
    withHeader(CORRELATION_ID_HEADER, UUID.randomUUID().toString());
  }

  /**
   * @description A GET request.
   * @param namedCredential The Named Credential's API name.
   * @param path The path and query.
   * @return The request.
   */
  public static CalloutRequest get(String namedCredential, String path) {
    return new CalloutRequest('GET', namedCredential, path);
  }

  /**
   * @description A POST request. It is retried only if it has an idempotency key.
   * @param namedCredential The Named Credential's API name.
   * @param path The path and query.
   * @return The request.
   */
  public static CalloutRequest post(String namedCredential, String path) {
    return new CalloutRequest('POST', namedCredential, path);
  }

  /**
   * @description A PUT request.
   * @param namedCredential The Named Credential's API name.
   * @param path The path and query.
   * @return The request.
   */
  public static CalloutRequest put(String namedCredential, String path) {
    return new CalloutRequest('PUT', namedCredential, path);
  }

  /**
   * @description A PATCH request. It is retried only if it has an idempotency key.
   * @param namedCredential The Named Credential's API name.
   * @param path The path and query.
   * @return The request.
   */
  public static CalloutRequest patch(String namedCredential, String path) {
    return new CalloutRequest('PATCH', namedCredential, path);
  }

  /**
   * @description Sets a header, replacing any value under the same name (case-insensitive).
   * @param name The header name.
   * @param value The header value; null removes the header.
   * @return This request.
   * @throws CalloutClientException If the name is blank.
   */
  public CalloutRequest withHeader(String name, String value) {
    if (String.isBlank(name)) {
      throw new CalloutClientException('A header needs a name.');
    }
    String key = name.toLowerCase();
    if (value == null) {
      headerNamesByKey.remove(key);
      headerValuesByKey.remove(key);
    } else {
      headerNamesByKey.put(key, name);
      headerValuesByKey.put(key, value);
    }
    return this;
  }

  /**
   * @description Sets the correlation id, for example one received from an inbound request.
   * @param correlationId The id.
   * @return This request.
   */
  public CalloutRequest withCorrelationId(String correlationId) {
    return withHeader(CORRELATION_ID_HEADER, correlationId);
  }

  /**
   * @description Sets the `Idempotency-Key` header, which makes a POST or PATCH safe to retry.
   * The server must honour the key; use a value stable across retries, such as a record Id.
   * @param key The idempotency key.
   * @return This request.
   */
  public CalloutRequest withIdempotencyKey(String key) {
    return withHeader(IDEMPOTENCY_KEY_HEADER, key);
  }

  /**
   * @description Sets a raw body and its content type.
   * @param body The body.
   * @param contentType The `Content-Type` header value.
   * @return This request.
   */
  public CalloutRequest withBody(String body, String contentType) {
    this.body = body;
    return withHeader('Content-Type', contentType);
  }

  /**
   * @description Serialises a value to JSON as the body.
   * @param payload The value to serialise.
   * @return This request.
   */
  public CalloutRequest withJsonBody(Object payload) {
    return withBody(JSON.serialize(payload), 'application/json');
  }

  /**
   * @description Sets the timeout for each attempt.
   * @param timeoutMillis Between 1 and 120000 milliseconds.
   * @return This request.
   * @throws CalloutClientException If the timeout is out of range.
   */
  public CalloutRequest withTimeout(Integer timeoutMillis) {
    if (timeoutMillis == null || timeoutMillis < 1 || timeoutMillis > MAX_TIMEOUT_MILLIS) {
      throw new CalloutClientException(
        'A callout timeout must be 1 to ' + MAX_TIMEOUT_MILLIS + ' ms, not ' + timeoutMillis + '.'
      );
    }
    this.timeoutMillis = timeoutMillis;
    return this;
  }

  /** @description @return The HTTP verb, upper case. */
  public String getMethod() {
    return method;
  }

  /** @description @return `callout:<NamedCredential><path>`. */
  public String getEndpoint() {
    return 'callout:' + namedCredential + path;
  }

  /**
   * @description A header value.
   * @param name The header name (case-insensitive).
   * @return The value, or null if not set.
   */
  public String getHeader(String name) {
    return name == null ? null : headerValuesByKey.get(name.toLowerCase());
  }

  /** @description @return The body, or null. */
  public String getBody() {
    return body;
  }

  /** @description @return The per-attempt timeout in milliseconds. */
  public Integer getTimeoutMillis() {
    return timeoutMillis;
  }

  /** @description @return The `X-Correlation-Id` value. */
  public String getCorrelationId() {
    return getHeader(CORRELATION_ID_HEADER);
  }

  /**
   * @description Whether sending the request twice has the same effect as sending it once.
   * @return True for GET, HEAD, OPTIONS, PUT and DELETE, and for POST or PATCH with an idempotency key.
   */
  public Boolean isIdempotent() {
    return IDEMPOTENT_METHODS.contains(method) || String.isNotBlank(getHeader(IDEMPOTENCY_KEY_HEADER));
  }

  /**
   * @description Builds the platform request. Each call returns a new `HttpRequest`.
   * @return The request, ready for `Http.send`.
   */
  public HttpRequest toHttpRequest() {
    HttpRequest request = new HttpRequest();
    request.setMethod(method);
    request.setEndpoint(getEndpoint());
    request.setTimeout(timeoutMillis);
    for (String key : headerValuesByKey.keySet()) {
      request.setHeader(headerNamesByKey.get(key), headerValuesByKey.get(key));
    }
    if (body != null) {
      request.setBody(body);
    }
    return request;
  }

  private static String requireMethod(String method) {
    if (String.isBlank(method) || !SUPPORTED_METHODS.contains(method.toUpperCase())) {
      throw new CalloutClientException('Unsupported HTTP method: ' + method);
    }
    return method.toUpperCase();
  }

  private static String requireNamedCredential(String namedCredential) {
    if (String.isBlank(namedCredential) || !NAMED_CREDENTIAL.matcher(namedCredential).matches()) {
      throw new CalloutClientException(
        'Pass a Named Credential API name, not a URL or a callout: endpoint. Got: ' + namedCredential
      );
    }
    return namedCredential;
  }

  private static String requirePath(String path) {
    String safePath = path == null ? '' : path;
    if (String.isNotEmpty(safePath) && !safePath.startsWith('/') && !safePath.startsWith('?')) {
      throw new CalloutClientException('A callout path must be empty or start with / or ?. Got: ' + path);
    }
    return safePath;
  }
}
