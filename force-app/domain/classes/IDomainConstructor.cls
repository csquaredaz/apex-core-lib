/**
 * @description Builds a domain over a list of records. `Type.newInstance()` only calls no-argument
 * constructors, so each domain ships a small constructor class that `DomainFactory` instantiates
 * and calls; the domain itself then takes its records in a real constructor and keeps them
 * `final` (the FFLIB `IConstructable` pattern).
 *
 * Bind it with a `DI_Binding__mdt` row: `Kind__c` = `Domain`, `Interface__c` = the SObject API
 * name, `Implementation__c` = the constructor class, for example `ShipmentsDomain.Constructor`.
 *
 * ```apex
 * public with sharing class ShipmentsDomain extends SObjectDomain {
 *   public ShipmentsDomain(List<SObject> records) {
 *     super(records);
 *   }
 *   public override SObjectType getSObjectType() {
 *     return Shipment__c.SObjectType;
 *   }
 *   public class Constructor implements IDomainConstructor {
 *     public IDomain construct(List<SObject> records) {
 *       return new ShipmentsDomain(records);
 *     }
 *   }
 * }
 * ```
 * @group Public API
 */
public interface IDomainConstructor {
  /**
   * @description Creates the domain.
   * @param records The records the domain owns, never null.
   * @return The domain.
   */
  IDomain construct(List<SObject> records);
}
