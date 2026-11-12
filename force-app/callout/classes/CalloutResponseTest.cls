@IsTest
private class CalloutResponseTest {
  private static CalloutResponse wrap(Integer statusCode, String retryAfter) {
    HttpResponse response = CalloutTestFixtures.status(statusCode);
    if (retryAfter != null) {
      response.setHeader('Retry-After', retryAfter);
    }
    return new CalloutResponse(response, 2, 'corr-1');
  }

  @IsTest
  static void constructor_copiesStatusBodyHeadersAndAttempts() {
    HttpResponse raw = CalloutTestFixtures.status(200);
    raw.setHeader('X-Request-Id', 'abc');

    CalloutResponse response = new CalloutResponse(raw, 2, 'corr-1');

    Assert.areEqual(200, response.getStatusCode(), 'Status code');
    Assert.areEqual('OK', response.getStatus(), 'Status text');
    Assert.areEqual('{"code":200}', response.getBody(), 'Body');
    Assert.areEqual('abc', response.getHeader('x-request-id'), 'Header lookup ignores case');
    Assert.isNull(response.getHeader(null), 'Null lookup');
    Assert.areEqual(2, response.getAttempts(), 'Attempts');
    Assert.areEqual('corr-1', response.getCorrelationId(), 'Correlation id');
  }

  @IsTest
  static void isSuccess_onlyFor2xx() {
    Assert.isTrue(wrap(200, null).isSuccess(), '200');
    Assert.isTrue(wrap(299, null).isSuccess(), '299');
    Assert.isFalse(wrap(199, null).isSuccess(), '199');
    Assert.isFalse(wrap(300, null).isSuccess(), '300');
    Assert.isFalse(wrap(503, null).isSuccess(), '503');
  }

  @IsTest
  static void getRetryAfterSeconds_parsesWholeSecondsOnly() {
    Assert.areEqual(30, wrap(429, ' 30 ').getRetryAfterSeconds(), 'Seconds');
    Assert.isNull(wrap(429, 'Wed, 21 Oct 2026 07:28:00 GMT').getRetryAfterSeconds(), 'HTTP-date not parsed');
    Assert.isNull(wrap(429, null).getRetryAfterSeconds(), 'Absent');
  }

  @IsTest
  static void readJson_deserialisesBody() {
    CalloutTestFixtures.StatusBody parsed = (CalloutTestFixtures.StatusBody) wrap(200, null)
      .readJson(CalloutTestFixtures.StatusBody.class);

    Assert.areEqual(200, parsed.code, 'Parsed into the typed class');
  }

  @IsTest
  static void constructor_nullResponse_throws() {
    try {
      new CalloutResponse(null, 1, 'corr-1');
      Assert.fail('Expected CalloutClientException');
    } catch (CalloutClientException e) {
      Assert.isTrue(e.getMessage().contains('null HTTP response'), e.getMessage());
    }
  }
}
