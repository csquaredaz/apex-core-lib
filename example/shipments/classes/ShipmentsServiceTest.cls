@IsTest
private class ShipmentsServiceTest {
  private static Mocks selectorMock;
  private static Mocks gatewayMock;
  private static Mocks unitOfWorkMock;

  private static void mockCollaborators(List<Shipment__c> pending) {
    selectorMock = new Mocks().stubReturn('selectPendingById', pending);
    gatewayMock = new Mocks();
    unitOfWorkMock = new Mocks();
    Application.Selector.setMock(Shipment__c.SObjectType, (ISelector) selectorMock.stub(IShipmentsSelector.class));
    Application.Service.setMock(ICarrierGateway.class, gatewayMock.stub(ICarrierGateway.class));
    Application.UnitOfWork.setMock((IUnitOfWork) unitOfWorkMock.stub(IUnitOfWork.class));
  }

  @IsTest
  static void bookShipments_carrierBooksSome_marksThoseBookedInOneCommit() {
    List<Shipment__c> pending = TestDataFactory.fakeShipments(2);
    mockCollaborators(pending);
    gatewayMock.stubReturn('book', new Map<Id, String>{ pending[0].Id => 'CR-1' });

    new ShipmentsService().bookShipments(new Map<Id, Shipment__c>(pending).keySet());

    unitOfWorkMock.verify('registerDirty', 1);
    Shipment__c booked = (Shipment__c) unitOfWorkMock.argumentsOf('registerDirty', 0)[0];
    Assert.areEqual(pending[0].Id, booked.Id, 'Only the booked shipment');
    Assert.areEqual(ShipmentsDomain.STATUS_BOOKED, booked.Status__c, 'Status');
    Assert.areEqual('CR-1', booked.Carrier_Reference__c, 'Reference');
    unitOfWorkMock.verify('commitWork', 1);
  }

  @IsTest
  static void bookShipments_carrierFails_logsAndWritesNothing() {
    mockCollaborators(TestDataFactory.fakeShipments(2));
    gatewayMock.stubThrow('book', new CalloutClientException('Carrier unavailable'));
    RecordingLogger logger = new RecordingLogger();
    Application.Service.setMock(ILogger.class, logger);

    new ShipmentsService().bookShipments(new Set<Id>{ FakeId.generate(Shipment__c.SObjectType) });

    unitOfWorkMock.verify('commitWork', 0);
    List<RecordingLogger.Entry> errors = logger.entries(LoggingLevel.ERROR);
    Assert.areEqual(1, errors.size(), 'The failure is logged');
    Assert.isTrue(errors[0].message.contains('2 shipment(s); they stay Pending'), errors[0].message);
    Assert.areEqual('Carrier unavailable', errors[0].cause.getMessage(), 'With its cause');
  }

  @IsTest
  static void bookShipments_nothingPending_doesNotCallTheCarrier() {
    mockCollaborators(new List<Shipment__c>());

    new ShipmentsService().bookShipments(new Set<Id>{ FakeId.generate(Shipment__c.SObjectType) });

    Assert.areEqual(0, gatewayMock.callCount('book'), 'No carrier call');
    Assert.areEqual(0, unitOfWorkMock.callCount('commitWork'), 'No write');
  }

  @IsTest
  static void createShipments_registersNewAndCommitsOnce() {
    mockCollaborators(new List<Shipment__c>());
    List<Shipment__c> shipments = TestDataFactory.shipments(2, null, TestDataFactory.VALID_WEIGHT_KG);

    new ShipmentsService().createShipments(shipments);

    Assert.isTrue(unitOfWorkMock.argumentsOf('registerNew', 0)[0] === shipments, 'All shipments registered');
    unitOfWorkMock.verify('commitWork', 1);
  }

  @IsTest
  static void requestBooking_queuesOneJobOrNoneForNoIds() {
    // The queued job resolves IShipmentsService too; the mock keeps it from booking at stopTest.
    Mocks jobTarget = new Mocks();
    Application.Service.setMock(IShipmentsService.class, jobTarget.stub(IShipmentsService.class));
    Test.startTest();
    new ShipmentsService().requestBooking(new Set<Id>());
    Integer afterEmpty = Limits.getQueueableJobs();
    new ShipmentsService().requestBooking(new Set<Id>{ FakeId.generate(Shipment__c.SObjectType) });
    Integer afterOne = Limits.getQueueableJobs();
    Test.stopTest();

    Assert.areEqual(0, afterEmpty, 'No job for no shipments');
    Assert.areEqual(1, afterOne, 'One job');
    jobTarget.verify('bookShipments', 1);
  }
}
