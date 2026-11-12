@IsTest
private class RetryPolicyTest {
  private static final CalloutRequest GET_REQUEST = CalloutRequest.get('Carrier', '/rates');

  @IsTest
  static void isRetryable_transientStatusesAndTransportErrors_onIdempotentRequest() {
    RetryPolicy policy = new RetryPolicy();

    for (Integer statusCode : new List<Integer>{ 408, 500, 502, 503, 504 }) {
      Assert.isTrue(policy.isRetryable(GET_REQUEST, statusCode), String.valueOf(statusCode));
    }
    Assert.isTrue(policy.isRetryable(GET_REQUEST, null), 'Transport error');
  }

  @IsTest
  static void isRetryable_otherStatuses_areNot() {
    RetryPolicy policy = new RetryPolicy();

    for (Integer statusCode : new List<Integer>{ 200, 201, 400, 401, 404, 409, 429, 501, 505 }) {
      Assert.isFalse(policy.isRetryable(GET_REQUEST, statusCode), String.valueOf(statusCode));
    }
  }

  @IsTest
  static void isRetryable_nonIdempotentRequest_neverRetries() {
    CalloutRequest post = CalloutRequest.post('Carrier', '/shipments');

    Assert.isFalse(new RetryPolicy().isRetryable(post, 503), '503');
    Assert.isFalse(new RetryPolicy().isRetryable(post, null), 'Transport error');
  }

  @IsTest
  static void constructor_retryCount_isBoundedByTheCap() {
    Assert.areEqual(RetryPolicy.MAX_RETRIES_CAP, new RetryPolicy().getMaxRetries(), 'Default');
    Assert.areEqual(0, new RetryPolicy(0).getMaxRetries(), 'Never retry');
    for (Integer retries : new List<Integer>{ null, -1, RetryPolicy.MAX_RETRIES_CAP + 1 }) {
      try {
        new RetryPolicy(retries);
        Assert.fail('Expected CalloutClientException for ' + retries);
      } catch (CalloutClientException e) {
        Assert.isTrue(e.getMessage().contains('0 to 2 retries'), e.getMessage());
      }
    }
  }
}
