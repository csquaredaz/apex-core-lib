/**
 * @description Stateless shipment use cases. Collaborators are resolved per call through the
 * `Application` factories: the selector by SObject type, the gateway and logger by interface, and a
 * Unit of Work for every write. Bound by the `DI_Binding.Shipments_Service` row.
 */
public with sharing class ShipmentsService implements IShipmentsService {
  private static final List<SObjectType> COMMIT_ORDER = new List<SObjectType>{ Shipment__c.SObjectType };

  /**
   * @description Saves new shipments in user mode. Limits: 1 DML statement.
   * @param shipments Unsaved shipments.
   */
  public void createShipments(List<Shipment__c> shipments) {
    IUnitOfWork unitOfWork = Application.UnitOfWork.newInstance(COMMIT_ORDER);
    unitOfWork.registerNew(shipments);
    unitOfWork.commitWork();
  }

  /**
   * @description Queues one `CarrierBookingJob` for the shipments. Limits: 1 queueable job.
   * @param shipmentIds Saved shipment Ids.
   */
  public void requestBooking(Set<Id> shipmentIds) {
    if (shipmentIds == null || shipmentIds.isEmpty()) {
      return;
    }
    System.enqueueJob(new CarrierBookingJob(shipmentIds));
  }

  /**
   * @description Books pending shipments in one carrier call, then marks them `Booked` with their
   * references. A `CalloutClientException` is logged and nothing is written, so the shipments stay
   * `Pending` for a later retry. Limits: 1 SOQL, 1 to 3 callouts, at most 1 DML statement.
   * @param shipmentIds Shipment Ids.
   */
  public void bookShipments(Set<Id> shipmentIds) {
    IShipmentsSelector selector = (IShipmentsSelector) Application.Selector.newInstance(Shipment__c.SObjectType);
    List<Shipment__c> pending = selector.selectPendingById(shipmentIds);
    if (pending.isEmpty()) {
      return;
    }
    Map<Id, String> referencesById;
    try {
      referencesById = ((ICarrierGateway) Application.Service.newInstance(ICarrierGateway.class)).book(pending);
    } catch (CalloutClientException e) {
      ((ILogger) Application.Service.newInstance(ILogger.class))
        .error('Carrier booking failed for ' + pending.size() + ' shipment(s); they stay Pending.', e);
      return;
    }
    IUnitOfWork unitOfWork = Application.UnitOfWork.newInstance(COMMIT_ORDER);
    for (Shipment__c shipment : pending) {
      String reference = referencesById.get(shipment.Id);
      if (reference != null) {
        unitOfWork.registerDirty(
          new Shipment__c(Id = shipment.Id, Status__c = ShipmentsDomain.STATUS_BOOKED, Carrier_Reference__c = reference)
        );
      }
    }
    unitOfWork.commitWork();
  }
}
