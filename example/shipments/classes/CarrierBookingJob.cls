/**
 * @description The asynchronous hop between saving shipments and calling the carrier: triggers
 * can't make callouts, so `ShipmentsService.requestBooking` queues this job. It holds only Ids and
 * delegates to the service, so all the logic stays unit-testable without async execution.
 *
 * Retry here is the synchronous kind in `CalloutClient` (ADR 0007). Re-enqueueing with a delay
 * after a persistent failure, and a `System.Finalizer` to recover a job that dies on a limit,
 * are `apex-event-ingestion`'s job. This example deliberately has neither and leaves failed
 * shipments `Pending`.
 */
public with sharing class CarrierBookingJob implements Queueable, Database.AllowsCallouts {
  private final Set<Id> shipmentIds;

  /** @description @param shipmentIds The shipments to book. */
  public CarrierBookingJob(Set<Id> shipmentIds) {
    this.shipmentIds = shipmentIds;
  }

  /** @description Books the shipments. @param context The queueable context. */
  public void execute(QueueableContext context) {
    ((IShipmentsService) Application.Service.newInstance(IShipmentsService.class)).bookShipments(shipmentIds);
  }
}
