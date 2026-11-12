/**
 * @description End-to-end with real DML: service → Unit of Work (user mode) → trigger →
 * dispatcher → domain → queueable → selector → gateway → callout client → Unit of Work. Runs as
 * least-privilege users, and only the carrier's HTTP is mocked.
 */
@IsTest
private class ShipmentsIntegrationTest {
  private static final Integer BULK_SIZE = 200;

  private static IShipmentsService service() {
    return (IShipmentsService) Application.Service.newInstance(IShipmentsService.class);
  }

  private static List<Shipment__c> savedShipments() {
    // System mode: the test user (an admin) has no field permissions on the example fields in a scratch org.
    return [SELECT Status__c, Carrier_Reference__c FROM Shipment__c WITH SYSTEM_MODE];
  }

  @IsTest
  static void createShipments_200AsManager_bookedAsynchronouslyWithinLimits() {
    User manager = TestDataFactory.shipmentManager();
    Order customerOrder = TestDataFactory.insertOrder();
    CarrierApiMock carrier = CarrierApiMock.install(200);
    Integer queries;
    Integer dmlStatements;
    Integer queuedJobs;

    System.runAs(manager) {
      Test.startTest();
      service()
        .createShipments(TestDataFactory.shipments(BULK_SIZE, customerOrder.Id, TestDataFactory.VALID_WEIGHT_KG));
      queries = Limits.getQueries();
      dmlStatements = Limits.getDmlStatements();
      queuedJobs = Limits.getQueueableJobs();
      Test.stopTest();
    }

    Assert.areEqual(
      0,
      queries,
      'Saving 200 shipments runs no SOQL: bindings and settings come from the metadata cache'
    );
    Assert.isTrue(dmlStatements <= 2, 'One bulk insert plus the Unit of Work savepoint, got ' + dmlStatements);
    Assert.areEqual(1, queuedJobs, 'One booking job for the whole batch');
    Assert.areEqual(1, carrier.requests.size(), 'One carrier call for the batch');
    List<Shipment__c> saved = savedShipments();
    Assert.areEqual(BULK_SIZE, saved.size(), 'All saved');
    for (Shipment__c shipment : saved) {
      Assert.areEqual(ShipmentsDomain.STATUS_BOOKED, shipment.Status__c, 'Booked by the job');
      Assert.isTrue(shipment.Carrier_Reference__c.startsWith('CR-'), 'Carrier reference stored');
    }
  }

  @IsTest
  static void createShipments_carrierUnavailable_shipmentsStayPending() {
    User manager = TestDataFactory.shipmentManager();
    CarrierApiMock carrier = CarrierApiMock.install(503);

    System.runAs(manager) {
      Test.startTest();
      service().createShipments(TestDataFactory.shipments(3, null, TestDataFactory.VALID_WEIGHT_KG));
      Test.stopTest();
    }

    Assert.areEqual(3, carrier.requests.size(), 'The idempotent POST was retried twice');
    for (Shipment__c shipment : savedShipments()) {
      Assert.areEqual(ShipmentsDomain.STATUS_PENDING, shipment.Status__c, 'Left for a later retry');
      Assert.isNull(shipment.Carrier_Reference__c, 'No reference');
    }
  }

  @IsTest
  static void createShipments_zeroWeight_rejectedByTheDomain() {
    User manager = TestDataFactory.shipmentManager();
    Exception failure;

    System.runAs(manager) {
      try {
        service().createShipments(TestDataFactory.shipments(1, null, 0));
      } catch (Exception e) {
        failure = e;
      }
    }

    Assert.isNotNull(failure, 'The insert failed');
    Assert.isTrue(failure.getMessage().contains('Weight must be greater than zero.'), failure.getMessage());
    Assert.areEqual(0, savedShipments().size(), 'Nothing saved');
  }

  @IsTest
  static void createShipments_userWithoutPermissionSet_isDenied() {
    User noAccess = TestDataFactory.userWithoutAccess();
    Exception failure;

    System.runAs(noAccess) {
      try {
        service().createShipments(TestDataFactory.shipments(1, null, TestDataFactory.VALID_WEIGHT_KG));
      } catch (Exception e) {
        failure = e;
      }
    }

    Assert.isNotNull(failure, 'User mode DML enforces object permissions');
    Assert.areEqual(0, savedShipments().size(), 'Nothing saved');
  }

  @IsTest
  static void createShipments_triggerBypassed_skipsDomainLogic() {
    User manager = TestDataFactory.shipmentManager();
    Integer queuedJobs;

    System.runAs(manager) {
      TriggerDispatcher.bypass(Shipment__c.SObjectType);
      try {
        service().createShipments(TestDataFactory.shipments(1, null, TestDataFactory.VALID_WEIGHT_KG));
        queuedJobs = Limits.getQueueableJobs();
      } finally {
        TriggerDispatcher.clearBypass(Shipment__c.SObjectType);
      }
    }

    Assert.areEqual(0, queuedJobs, 'No booking requested');
    Assert.isNull(savedShipments()[0].Status__c, 'No default applied');
  }
}
