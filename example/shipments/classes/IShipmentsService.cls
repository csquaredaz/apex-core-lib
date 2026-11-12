/**
 * @description Shipment use cases. Resolved through `Application.Service`, so domains, jobs and
 * tests depend on this interface rather than on `ShipmentsService`.
 */
public interface IShipmentsService {
  /**
   * @description Saves new shipments in user mode, which fires the trigger and queues their booking.
   * @param shipments Unsaved shipments.
   */
  void createShipments(List<Shipment__c> shipments);

  /**
   * @description Queues one asynchronous carrier booking for the shipments; does nothing for none.
   * @param shipmentIds Saved shipment Ids.
   */
  void requestBooking(Set<Id> shipmentIds);

  /**
   * @description Books pending shipments with the carrier and marks them `Booked`. A failed
   * callout is logged and leaves them `Pending`.
   * @param shipmentIds Shipment Ids; ones no longer pending are skipped.
   */
  void bookShipments(Set<Id> shipmentIds);
}
