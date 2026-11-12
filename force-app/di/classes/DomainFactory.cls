/**
 * @description Creates domains by SObject type (Abstract Factory), so the trigger dispatcher and
 * services can build the domain for any type, and tests can swap in a mock. Bind a domain with a
 * `DI_Binding__mdt` row: `Kind__c` = `Domain`, `Interface__c` = the SObject API name,
 * `Implementation__c` = the domain's `IDomainConstructor` class, for example
 * `ShipmentsDomain.Constructor`.
 *
 * Usage: `ShipmentsDomain shipments = (ShipmentsDomain) Application.Domain.newInstance(records);`
 * @group Public API
 */
public with sharing class DomainFactory {
  private final BindingRegistry registry;
  private final Map<SObjectType, IDomain> mocksByType = new Map<SObjectType, IDomain>();

  /**
   * @description Creates a factory that resolves domain constructors through the given registry.
   * @param registry A `DOMAIN` binding registry.
   */
  public DomainFactory(BindingRegistry registry) {
    this.registry = registry;
  }

  /**
   * @description Returns the domain for a list of records, inferring the type from the list.
   * @param records A typed list (`List<Shipment__c>`), or a non-empty list of one SObject type.
   * @return The mock registered for the type, or a new domain over the records.
   * @throws ApplicationException If the list is null, its type can't be inferred, or the binding is invalid.
   */
  public IDomain newInstance(List<SObject> records) {
    if (records == null) {
      throw new ApplicationException('Cannot create a domain for a null record list.');
    }
    SObjectType sObjectType = records.getSObjectType();
    if (sObjectType == null && !records.isEmpty()) {
      sObjectType = records[0].getSObjectType();
    }
    if (sObjectType == null) {
      throw new ApplicationException(
        'Cannot infer the SObject type of an empty, untyped list; call newInstance(records, sObjectType).'
      );
    }
    return newInstance(records, sObjectType);
  }

  /**
   * @description Returns a domain with no records, for type-level behaviour.
   * @param sObjectType The domain's SObject type.
   * @return The mock registered for the type, or a new domain over an empty typed list.
   * @throws ApplicationException If the type is null, unbound, or bound to a domain for another type.
   */
  public IDomain newInstance(SObjectType sObjectType) {
    if (sObjectType == null) {
      throw new ApplicationException('Cannot create a domain for a null SObject type.');
    }
    List<SObject> empty = (List<SObject>) Type.forName('List<' + sObjectType + '>').newInstance();
    return newInstance(empty, sObjectType);
  }

  /**
   * @description Returns the domain bound to an SObject type, over the given records.
   * @param records The records the domain owns, all of `sObjectType`.
   * @param sObjectType The domain's SObject type.
   * @return The mock registered for the type (which ignores `records`), or a new domain.
   * @throws ApplicationException If an argument is null, the type is unbound, or the bound domain owns another type.
   */
  public IDomain newInstance(List<SObject> records, SObjectType sObjectType) {
    if (records == null || sObjectType == null) {
      throw new ApplicationException('Cannot create a domain for a null record list or SObject type.');
    }
    if (mocksByType.containsKey(sObjectType)) {
      return mocksByType.get(sObjectType);
    }
    IDomainConstructor constructor = (IDomainConstructor) registry.resolve(
        String.valueOf(sObjectType),
        IDomainConstructor.class
      )
      .newInstance();
    IDomain domain = constructor.construct(records);
    if (domain == null || domain.getSObjectType() != sObjectType) {
      throw new ApplicationException(
        'The domain bound to ' +
          sObjectType +
          ' owns ' +
          (domain == null ? null : domain.getSObjectType()) +
          '. Fix its DI_Binding__mdt row.'
      );
    }
    return domain;
  }

  /**
   * @description Registers a test double for an SObject type, for the rest of the transaction.
   * The mock is returned as is, whatever records are passed to `newInstance`.
   * @param sObjectType The type the mock domain stands in for.
   * @param mock The mock domain.
   * @throws ApplicationException If either argument is null.
   */
  public void setMock(SObjectType sObjectType, IDomain mock) {
    if (sObjectType == null || mock == null) {
      throw new ApplicationException('setMock requires a non-null SObject type and domain.');
    }
    mocksByType.put(sObjectType, mock);
  }
}
