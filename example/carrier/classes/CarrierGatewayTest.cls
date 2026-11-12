@IsTest
private class CarrierGatewayTest {
  @IsTest
  static void book_carrierAccepts_mapsReferencesFromOneIdempotentPost() {
    CarrierApiMock mock = CarrierApiMock.install(200);
    List<Shipment__c> shipments = TestDataFactory.fakeShipments(3);

    Map<Id, String> referencesById = new CarrierGateway().book(shipments);

    Assert.areEqual(3, referencesById.size(), 'Every shipment booked');
    Assert.areEqual('CR-1', referencesById.get(shipments[0].Id), 'Reference mapped by shipment Id');
    Assert.areEqual(1, mock.requests.size(), 'One callout for the batch');
    HttpRequest sent = mock.requests[0];
    Assert.areEqual('POST', sent.getMethod(), 'Method');
    Assert.areEqual('callout:Carrier/v1/bookings', sent.getEndpoint(), 'Named Credential endpoint');
    Assert.areEqual(
      CarrierGateway.idempotencyKey(shipments),
      sent.getHeader(CalloutRequest.IDEMPOTENCY_KEY_HEADER),
      'Idempotency key sent'
    );
  }

  @IsTest
  static void idempotencyKey_sameShipmentsInAnyOrder_isStable() {
    List<Shipment__c> shipments = TestDataFactory.fakeShipments(3);
    List<Shipment__c> reversed = new List<Shipment__c>{ shipments[2], shipments[1], shipments[0] };

    Assert.areEqual(CarrierGateway.idempotencyKey(shipments), CarrierGateway.idempotencyKey(reversed), 'Stable');
    Assert.areNotEqual(
      CarrierGateway.idempotencyKey(shipments),
      CarrierGateway.idempotencyKey(TestDataFactory.fakeShipments(3)),
      'Different shipments, different key'
    );
  }

  @IsTest
  static void book_carrierRejects_throwsWithTheResponse() {
    CarrierApiMock mock = CarrierApiMock.install(422);

    try {
      new CarrierGateway().book(TestDataFactory.fakeShipments(1));
      Assert.fail('Expected CalloutClientException');
    } catch (CalloutClientException e) {
      Assert.areEqual(422, e.getLastResponse().getStatusCode(), 'Rejection kept');
      Assert.areEqual(1, e.getAttempts(), 'A 4xx is not retried');
    }
    Assert.areEqual(1, mock.requests.size(), 'One callout');
  }

  @IsTest
  static void book_noShipments_returnsEmptyWithoutCallout() {
    CarrierApiMock mock = CarrierApiMock.install(200);

    Assert.isTrue(new CarrierGateway().book(new List<Shipment__c>()).isEmpty(), 'Nothing booked');
    Assert.areEqual(0, mock.requests.size(), 'No callout');
  }
}
