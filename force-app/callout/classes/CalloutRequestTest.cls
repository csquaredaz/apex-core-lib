@IsTest
private class CalloutRequestTest {
  private static String expectError(String method, String namedCredential, String path) {
    try {
      new CalloutRequest(method, namedCredential, path);
      Assert.fail('Expected CalloutClientException');
    } catch (CalloutClientException e) {
      return e.getMessage();
    }
    return null;
  }

  @IsTest
  static void toHttpRequest_builtRequest_hasEndpointMethodHeadersAndBody() {
    CalloutRequest request = CalloutRequest.put('Carrier', '/shipments/1')
      .withBody('<shipment/>', 'application/xml')
      .withHeader('Accept', 'application/xml');

    HttpRequest built = request.toHttpRequest();

    Assert.areEqual('PUT', built.getMethod(), 'Method');
    Assert.areEqual('callout:Carrier/shipments/1', built.getEndpoint(), 'Endpoint');
    Assert.areEqual('<shipment/>', built.getBody(), 'Body');
    Assert.areEqual('application/xml', built.getHeader('Content-Type'), 'Content type');
    Assert.areEqual('application/xml', built.getHeader('Accept'), 'Custom header');
    Assert.areEqual(CalloutRequest.DEFAULT_TIMEOUT_MILLIS, request.getTimeoutMillis(), 'Default timeout');
    Assert.isTrue(String.isNotBlank(built.getHeader(CalloutRequest.CORRELATION_ID_HEADER)), 'Correlation id');
  }

  @IsTest
  static void withJsonBody_serialisesAndSetsContentType() {
    CalloutRequest request = CalloutRequest.post('Carrier', '/quotes')
      .withJsonBody(new Map<String, Object>{ 'weightKg' => 2 });

    Assert.areEqual('{"weightKg":2}', request.getBody(), 'JSON body');
    Assert.areEqual('application/json', request.getHeader('content-type'), 'Header lookup ignores case');
  }

  @IsTest
  static void correlationId_isGeneratedPerRequestAndCanBeSet() {
    CalloutRequest first = CalloutRequest.get('Carrier', '');
    CalloutRequest second = CalloutRequest.get('Carrier', '').withCorrelationId('inbound-123');

    Assert.areNotEqual(first.getCorrelationId(), CalloutRequest.get('Carrier', '').getCorrelationId(), 'Unique');
    Assert.areEqual('inbound-123', second.getCorrelationId(), 'Caller-supplied id wins');
  }

  @IsTest
  static void withHeader_sameNameDifferentCase_replacesAndNullRemoves() {
    CalloutRequest request = CalloutRequest.get('Carrier', '/').withHeader('X-Trace', 'a').withHeader('x-trace', 'b');

    Assert.areEqual('b', request.toHttpRequest().getHeader('x-trace'), 'Replaced');
    Assert.isNull(request.withHeader('X-TRACE', null).getHeader('X-Trace'), 'Removed');
  }

  @IsTest
  static void isIdempotent_followsVerbAndIdempotencyKey() {
    Assert.isTrue(CalloutRequest.get('Carrier', '/').isIdempotent(), 'GET');
    Assert.isTrue(CalloutRequest.put('Carrier', '/').isIdempotent(), 'PUT');
    Assert.isTrue(new CalloutRequest('delete', 'Carrier', '/1').isIdempotent(), 'DELETE, any case');
    Assert.isFalse(CalloutRequest.post('Carrier', '/').isIdempotent(), 'POST');
    Assert.isFalse(CalloutRequest.patch('Carrier', '/').isIdempotent(), 'PATCH');
    Assert.isTrue(CalloutRequest.post('Carrier', '/').withIdempotencyKey('k-1').isIdempotent(), 'POST with key');
    Assert.isTrue(
      CalloutRequest.patch('Carrier', '/').withHeader('idempotency-key', 'k-2').isIdempotent(),
      'Key set as a raw header'
    );
  }

  @IsTest
  static void constructor_invalidArguments_throw() {
    Assert.isTrue(expectError('TRACE', 'Carrier', '/').contains('Unsupported HTTP method'), 'Method');
    Assert.isTrue(expectError(null, 'Carrier', '/').contains('Unsupported HTTP method'), 'Null method');
    Assert.isTrue(expectError('GET', 'https://api.example.com', '/').contains('Named Credential'), 'URL');
    Assert.isTrue(expectError('GET', 'callout:Carrier', '/').contains('Named Credential'), 'callout: prefix');
    Assert.isTrue(expectError('GET', ' ', '/').contains('Named Credential'), 'Blank');
    Assert.isTrue(expectError('GET', 'Carrier', '@evil.example.com/').contains('start with / or ?'), 'Host injection');
  }

  @IsTest
  static void constructor_nullPathOrQueryOnly_isAccepted() {
    Assert.areEqual('callout:Carrier', new CalloutRequest('GET', 'Carrier', null).getEndpoint(), 'Null path');
    Assert.areEqual('callout:Carrier?page=2', CalloutRequest.get('Carrier', '?page=2').getEndpoint(), 'Query');
  }

  @IsTest
  static void withTimeout_outOfRange_throws() {
    for (Integer timeout : new List<Integer>{ null, 0, CalloutRequest.MAX_TIMEOUT_MILLIS + 1 }) {
      try {
        CalloutRequest.get('Carrier', '/').withTimeout(timeout);
        Assert.fail('Expected CalloutClientException for ' + timeout);
      } catch (CalloutClientException e) {
        Assert.isTrue(e.getMessage().contains('1 to 120000 ms'), e.getMessage());
      }
    }
    Assert.areEqual(120000, CalloutRequest.get('Carrier', '/').withTimeout(120000).getTimeoutMillis(), 'Max allowed');
  }

  @IsTest
  static void withHeader_blankName_throws() {
    try {
      CalloutRequest.get('Carrier', '/').withHeader('', 'x');
      Assert.fail('Expected CalloutClientException');
    } catch (CalloutClientException e) {
      Assert.isTrue(e.getMessage().contains('needs a name'), e.getMessage());
      Assert.areEqual(0, e.getAttempts(), 'An invalid request made no attempts');
    }
    Assert.isNull(CalloutRequest.get('Carrier', '/').getHeader(null), 'Null lookup');
  }
}
