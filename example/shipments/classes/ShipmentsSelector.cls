/**
 * @description Owns every `Shipment__c` query, in user mode (`SObjectSelector`). Bound by the
 * `DI_Binding.Shipments_Selector` row.
 */
public with sharing class ShipmentsSelector extends SObjectSelector implements IShipmentsSelector {
  /** @description @return `Shipment__c`. */
  public override SObjectType getSObjectType() {
    return Shipment__c.SObjectType;
  }

  /** @description @return The fields every shipment query selects. */
  public override List<SObjectField> getSObjectFieldList() {
    return new List<SObjectField>{
      Shipment__c.Name,
      Shipment__c.Order__c,
      Shipment__c.Status__c,
      Shipment__c.Weight_Kg__c,
      Shipment__c.Carrier_Reference__c
    };
  }

  /**
   * @description Shipments still waiting for a carrier booking. Limits: 1 SOQL.
   * @param ids Shipment Ids.
   * @return The `Pending` shipments among them.
   */
  public List<Shipment__c> selectPendingById(Set<Id> ids) {
    return (List<Shipment__c>) query(
      'Id IN :ids AND Status__c = :status',
      new Map<String, Object>{ 'ids' => ids, 'status' => ShipmentsDomain.STATUS_PENDING }
    );
  }
}
