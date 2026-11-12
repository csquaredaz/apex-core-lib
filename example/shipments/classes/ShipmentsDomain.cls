/**
 * @description Shipment behaviour across a list of records (Table Module). New shipments start
 * `Pending`, must weigh more than zero, and are handed to `IShipmentsService` for carrier booking
 * once saved. No SOQL, DML or callouts here: booking is asynchronous because a trigger can't call out.
 * Bound by the `DI_Binding.Shipments_Domain` row, which names `ShipmentsDomain.Constructor`.
 */
public with sharing class ShipmentsDomain extends SObjectDomain {
  /** @description Status of a shipment the carrier hasn't confirmed yet. */
  public static final String STATUS_PENDING = 'Pending';
  /** @description Status once the carrier has returned a booking reference. */
  public static final String STATUS_BOOKED = 'Booked';

  /** @description @param records The shipments. */
  public ShipmentsDomain(List<Shipment__c> records) {
    super(records);
  }

  /** @description @return `Shipment__c`. */
  public override SObjectType getSObjectType() {
    return Shipment__c.SObjectType;
  }

  /** @description New shipments start `Pending` unless the caller set a status. */
  public override void onApplyDefaults() {
    for (Shipment__c shipment : (List<Shipment__c>) records) {
      if (shipment.Status__c == null) {
        shipment.Status__c = STATUS_PENDING;
      }
    }
  }

  /** @description Rejects a missing, zero or negative weight on insert and update. */
  public override void onValidate() {
    for (Shipment__c shipment : (List<Shipment__c>) records) {
      if (shipment.Weight_Kg__c == null || shipment.Weight_Kg__c <= 0) {
        shipment.addError(Shipment__c.Weight_Kg__c, 'Weight must be greater than zero.');
      }
    }
  }

  /** @description Requests a carrier booking for every new shipment that passed validation. */
  public override void onAfterInsert() {
    Set<Id> bookable = new Set<Id>();
    for (Shipment__c shipment : (List<Shipment__c>) records) {
      if (!shipment.hasErrors() && shipment.Status__c == STATUS_PENDING) {
        bookable.add(shipment.Id);
      }
    }
    ((IShipmentsService) Application.Service.newInstance(IShipmentsService.class)).requestBooking(bookable);
  }

  /** @description Builds the domain for `DomainFactory` (records must arrive in the constructor). */
  public class Constructor implements IDomainConstructor {
    /** @description @param records The shipments. @return The domain. */
    public IDomain construct(List<SObject> records) {
      return new ShipmentsDomain((List<Shipment__c>) records);
    }
  }
}
