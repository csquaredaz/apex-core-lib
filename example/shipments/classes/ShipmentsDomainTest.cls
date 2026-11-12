@IsTest
private class ShipmentsDomainTest {
  private static ShipmentsDomain domainOf(List<Shipment__c> shipments) {
    return (ShipmentsDomain) Application.Domain.newInstance(shipments);
  }

  @IsTest
  static void bindingRow_resolvesShipmentsDomain() {
    Assert.isInstanceOfType(
      Application.Domain.newInstance(new List<Shipment__c>()),
      ShipmentsDomain.class,
      'DI_Binding.Shipments_Domain names ShipmentsDomain.Constructor'
    );
  }

  @IsTest
  static void onApplyDefaults_newShipment_isPendingUnlessStatusSet() {
    List<Shipment__c> shipments = TestDataFactory.shipments(2, null, TestDataFactory.VALID_WEIGHT_KG);
    shipments[1].Status__c = ShipmentsDomain.STATUS_BOOKED;

    domainOf(shipments).onApplyDefaults();

    Assert.areEqual(ShipmentsDomain.STATUS_PENDING, shipments[0].Status__c, 'Defaulted');
    Assert.areEqual(ShipmentsDomain.STATUS_BOOKED, shipments[1].Status__c, 'Caller value kept');
  }

  @IsTest
  static void onValidate_missingZeroOrNegativeWeight_isRejected() {
    List<Shipment__c> shipments = new List<Shipment__c>{
      new Shipment__c(Weight_Kg__c = null),
      new Shipment__c(Weight_Kg__c = 0),
      new Shipment__c(Weight_Kg__c = -1),
      new Shipment__c(Weight_Kg__c = 0.01)
    };

    domainOf(shipments).onValidate();

    for (Integer i = 0; i < 3; i++) {
      Assert.isTrue(shipments[i].hasErrors(), 'Rejected: ' + shipments[i].Weight_Kg__c);
      Assert.areEqual('Weight must be greater than zero.', shipments[i].getErrors()[0].getMessage(), 'Message');
    }
    Assert.isFalse(shipments[3].hasErrors(), 'A positive weight passes');
  }

  @IsTest
  static void onAfterInsert_requestsBookingForValidPendingShipmentsOnly() {
    Mocks serviceMock = new Mocks();
    Application.Service.setMock(IShipmentsService.class, serviceMock.stub(IShipmentsService.class));
    List<Shipment__c> shipments = TestDataFactory.fakeShipments(3);
    shipments[1].addError('Rejected earlier in the transaction');
    shipments[2].Status__c = ShipmentsDomain.STATUS_BOOKED;

    domainOf(shipments).onAfterInsert();

    serviceMock.verify('requestBooking', 1);
    Assert.areEqual(
      new Set<Id>{ shipments[0].Id },
      (Set<Id>) serviceMock.argumentsOf('requestBooking', 0)[0],
      'Only the valid pending shipment'
    );
  }
}
