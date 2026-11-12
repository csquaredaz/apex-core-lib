@IsTest
private class CalloutClientTest {
  private static RecordingLogger logger;

  private static CalloutClient client() {
    logger = new RecordingLogger();
    Application.Service.setMock(ILogger.class, logger);
    return new CalloutClient();
  }

  private static CalloutClientException expectFailure(CalloutClient client, CalloutRequest request) {
    try {
      client.send(request);
      Assert.fail('Expected CalloutClientException');
    } catch (CalloutClientException e) {
      return e;
    }
    return null;
  }

  @IsTest
  static void send_success_returnsTypedResponseAfterOneAttempt() {
    CalloutTestFixtures.SequenceMock mock = CalloutTestFixtures.script(
      new List<HttpResponse>{ CalloutTestFixtures.status(200) }
    );
    CalloutRequest request = CalloutRequest.get('Carrier', '/rates?zip=85001').withTimeout(5000);

    CalloutResponse response = client().send(request);

    Assert.isTrue(response.isSuccess(), 'Success');
    Assert.areEqual(1, response.getAttempts(), 'One attempt');
    Assert.areEqual(request.getCorrelationId(), response.getCorrelationId(), 'Correlation id carried over');
    Assert.areEqual('callout:Carrier/rates?zip=85001', mock.requests[0].getEndpoint(), 'Named Credential endpoint');
    Assert.areEqual(5000, request.getTimeoutMillis(), 'Timeout kept (HttpRequest exposes no getter)');
    Assert.areEqual(
      request.getCorrelationId(),
      mock.requests[0].getHeader(CalloutRequest.CORRELATION_ID_HEADER),
      'Header sent'
    );
  }

  @IsTest
  static void send_clientError_isReturnedWithoutRetry() {
    CalloutTestFixtures.SequenceMock mock = CalloutTestFixtures.script(
      new List<HttpResponse>{ CalloutTestFixtures.status(404) }
    );

    CalloutResponse response = client().send(CalloutRequest.get('Carrier', '/shipments/1'));

    Assert.areEqual(404, response.getStatusCode(), 'Returned, not thrown');
    Assert.areEqual(1, mock.requests.size(), 'No retry on 4xx');
  }

  @IsTest
  static void send_tooManyRequests_isReturnedWithoutRetry() {
    HttpResponse throttled = CalloutTestFixtures.status(429);
    throttled.setHeader('Retry-After', '30');
    CalloutTestFixtures.SequenceMock mock = CalloutTestFixtures.script(new List<HttpResponse>{ throttled });

    CalloutResponse response = client().send(CalloutRequest.get('Carrier', '/rates'));

    Assert.areEqual(1, mock.requests.size(), 'An immediate retry would hit the same limit');
    Assert.areEqual(30, response.getRetryAfterSeconds(), 'The caller can schedule its own retry');
  }

  @IsTest
  static void send_transientThenSuccess_retriesOnceWithSameCorrelationId() {
    CalloutTestFixtures.SequenceMock mock = CalloutTestFixtures.script(
      new List<HttpResponse>{ CalloutTestFixtures.status(503), CalloutTestFixtures.status(200) }
    );

    CalloutResponse response = client().send(CalloutRequest.get('Carrier', '/rates'));

    Assert.areEqual(2, response.getAttempts(), 'Second attempt succeeded');
    Assert.areEqual(
      mock.requests[0].getHeader(CalloutRequest.CORRELATION_ID_HEADER),
      mock.requests[1].getHeader(CalloutRequest.CORRELATION_ID_HEADER),
      'Same correlation id on the retry'
    );
    List<RecordingLogger.Entry> warnings = logger.entries(LoggingLevel.WARN);
    Assert.areEqual(1, warnings.size(), 'The failed attempt is logged');
    Assert.isTrue(warnings[0].message.contains('attempt 1 of 3 failed (HTTP 503)'), warnings[0].message);
  }

  @IsTest
  static void send_transientEveryTime_throwsAfterThreeAttempts() {
    CalloutTestFixtures.SequenceMock mock = CalloutTestFixtures.script(
      new List<HttpResponse>{ CalloutTestFixtures.status(503) }
    );

    CalloutClientException error = expectFailure(client(), CalloutRequest.get('Carrier', '/rates'));

    Assert.areEqual(3, mock.requests.size(), 'First attempt plus 2 retries');
    Assert.areEqual(3, error.getAttempts(), 'Attempts on the exception');
    Assert.areEqual(503, error.getLastResponse().getStatusCode(), 'Last response kept');
    Assert.isTrue(error.getMessage().contains('failed after 3 attempt(s), HTTP 503'), error.getMessage());
    Assert.areEqual(3, logger.entries(LoggingLevel.WARN).size(), 'Every failed attempt is logged');
  }

  @IsTest
  static void send_postWithoutIdempotencyKey_isNeverRetried() {
    CalloutTestFixtures.SequenceMock mock = CalloutTestFixtures.script(
      new List<HttpResponse>{ CalloutTestFixtures.status(503), CalloutTestFixtures.status(200) }
    );

    CalloutResponse response = client()
      .send(CalloutRequest.post('Carrier', '/shipments').withJsonBody(new Map<String, Object>()));

    Assert.areEqual(503, response.getStatusCode(), 'The 503 is returned; the server may have acted');
    Assert.areEqual(1, mock.requests.size(), 'Not sent twice');
  }

  @IsTest
  static void send_postWithIdempotencyKey_isRetried() {
    CalloutTestFixtures.SequenceMock mock = CalloutTestFixtures.script(
      new List<HttpResponse>{ CalloutTestFixtures.status(502), CalloutTestFixtures.status(201) }
    );

    CalloutResponse response = client()
      .send(CalloutRequest.post('Carrier', '/shipments').withIdempotencyKey('shipment-0001'));

    Assert.areEqual(201, response.getStatusCode(), 'Created on the retry');
    Assert.areEqual('shipment-0001', mock.requests[1].getHeader(CalloutRequest.IDEMPOTENCY_KEY_HEADER), 'Same key');
  }

  @IsTest
  static void send_transportErrorThenSuccess_retries() {
    CalloutTestFixtures.SequenceMock mock = CalloutTestFixtures.script(
      new List<HttpResponse>{ null, CalloutTestFixtures.status(200) }
    );

    CalloutResponse response = client().send(CalloutRequest.get('Carrier', '/rates'));

    Assert.areEqual(2, mock.requests.size(), 'Retried after the timeout');
    Assert.isTrue(response.isSuccess(), 'Then succeeded');
    Assert.isTrue(logger.entries(LoggingLevel.WARN)[0].message.contains('(transport error)'), 'Logged');
  }

  @IsTest
  static void send_transportErrorEveryTime_throwsWithCause() {
    CalloutTestFixtures.script(new List<HttpResponse>{ null });

    CalloutClientException error = expectFailure(client(), CalloutRequest.get('Carrier', '/rates'));

    Assert.areEqual(3, error.getAttempts(), 'All attempts used');
    Assert.isNull(error.getLastResponse(), 'No response');
    Assert.isInstanceOfType(error.getCause(), System.CalloutException.class, 'Platform error kept as the cause');
    Assert.isTrue(error.getMessage().contains('transport error: Read timed out'), error.getMessage());
  }

  @IsTest
  static void send_transportErrorOnNonIdempotentRequest_throwsAfterOneAttempt() {
    CalloutTestFixtures.SequenceMock mock = CalloutTestFixtures.script(new List<HttpResponse>{ null });

    CalloutClientException error = expectFailure(client(), CalloutRequest.patch('Carrier', '/shipments/1'));

    Assert.areEqual(1, mock.requests.size(), 'Not retried');
    Assert.areEqual(1, error.getAttempts(), 'One attempt');
  }

  @IsTest
  static void send_policyWithNoRetries_throwsOnFirstTransientFailure() {
    CalloutTestFixtures.SequenceMock mock = CalloutTestFixtures.script(
      new List<HttpResponse>{ CalloutTestFixtures.status(504) }
    );
    Application.Service.setMock(ILogger.class, new RecordingLogger());

    CalloutClientException error = expectFailure(
      new CalloutClient(new RetryPolicy(0)),
      CalloutRequest.get('Carrier', '/')
    );

    Assert.areEqual(1, mock.requests.size(), 'No retry');
    Assert.areEqual(504, error.getLastResponse().getStatusCode(), 'Gave up on the 504');
  }

  @IsTest
  static void send_nullRequestOrPolicy_throws() {
    try {
      client().send(null);
      Assert.fail('Expected CalloutClientException');
    } catch (CalloutClientException e) {
      Assert.isTrue(e.getMessage().contains('null callout request'), e.getMessage());
    }
    try {
      new CalloutClient(null);
      Assert.fail('Expected CalloutClientException');
    } catch (CalloutClientException e) {
      Assert.isTrue(e.getMessage().contains('needs a retry policy'), e.getMessage());
    }
  }

  @IsTest
  static void application_calloutClient_defaultsToCalloutClient() {
    Assert.isInstanceOfType(
      Application.Service.newInstance(ICalloutClient.class),
      CalloutClient.class,
      'ICalloutClient is bound to CalloutClient by default'
    );
  }
}
