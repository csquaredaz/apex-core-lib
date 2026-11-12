/**
 * @description Queries for `Shipment__c`. Extends `ISelector` so `Application.Selector` can return
 * it and tests can mock it with `Application.Selector.setMock`.
 */
public interface IShipmentsSelector extends ISelector {
  /**
   * @description Shipments still waiting for a carrier booking.
   * @param ids Shipment Ids.
   * @return The `Pending` shipments among them that the running user can see.
   */
  List<Shipment__c> selectPendingById(Set<Id> ids);
}
