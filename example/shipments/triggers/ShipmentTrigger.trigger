/**
 * @description The only trigger in the example, and it holds no logic: `TriggerDispatcher` builds
 * `ShipmentsDomain` from its `DI_Binding__mdt` row and calls the hook for the event.
 */
trigger ShipmentTrigger on Shipment__c(
  before insert,
  before update,
  before delete,
  after insert,
  after update,
  after delete,
  after undelete
) {
  TriggerDispatcher.run();
}
