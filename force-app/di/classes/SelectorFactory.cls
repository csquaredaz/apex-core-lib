/**
 * @description Creates selectors by SObject type (Abstract Factory), so generic code can query
 * any type and tests can swap in a mock selector. Bind a selector with a `DI_Binding__mdt` row:
 * `Kind__c` = `Selector`, `Interface__c` = the SObject API name, `Implementation__c` = the class.
 *
 * Usage: `IShipmentsSelector shipments = (IShipmentsSelector) Application.Selector.newInstance(Shipment__c.SObjectType);`
 * @group Public API
 */
public with sharing class SelectorFactory {
  private final BindingRegistry registry;
  private final Map<SObjectType, ISelector> mocksByType = new Map<SObjectType, ISelector>();

  /**
   * @description Creates a factory that resolves selectors through the given registry.
   * @param registry A `SELECTOR` binding registry.
   */
  public SelectorFactory(BindingRegistry registry) {
    this.registry = registry;
  }

  /**
   * @description Returns the selector bound to an SObject type.
   * @param sObjectType The type to query.
   * @return The mock registered for the type, or a new instance of its bound selector.
   * @throws ApplicationException If the type is null, unbound, or bound to a selector for another type.
   */
  public ISelector newInstance(SObjectType sObjectType) {
    if (sObjectType == null) {
      throw new ApplicationException('Cannot create a selector for a null SObject type.');
    }
    if (mocksByType.containsKey(sObjectType)) {
      return mocksByType.get(sObjectType);
    }
    ISelector selector = (ISelector) registry.resolve(String.valueOf(sObjectType), ISelector.class).newInstance();
    if (selector.getSObjectType() != sObjectType) {
      throw new ApplicationException(
        'The selector bound to ' +
          sObjectType +
          ' queries ' +
          selector.getSObjectType() +
          '. Fix its DI_Binding__mdt row.'
      );
    }
    return selector;
  }

  /**
   * @description Selects records by Id through the selector bound to their type.
   * Limits: 1 SOQL, none for an empty set.
   * @param ids Record Ids, all of one SObject type.
   * @return The records the running user can see.
   * @throws ApplicationException If the Ids span more than one SObject type.
   */
  public List<SObject> selectById(Set<Id> ids) {
    if (ids == null || ids.isEmpty()) {
      return new List<SObject>();
    }
    SObjectType sObjectType = null;
    for (Id recordId : ids) {
      if (sObjectType != null && recordId.getSObjectType() != sObjectType) {
        throw new ApplicationException('selectById needs Ids of one SObject type; split them by type first.');
      }
      sObjectType = recordId.getSObjectType();
    }
    return newInstance(sObjectType).selectSObjectsById(ids);
  }

  /**
   * @description Registers a test double for an SObject type, for the rest of the transaction.
   * @param sObjectType The type the mock selector stands in for.
   * @param mock The mock selector.
   * @throws ApplicationException If either argument is null.
   */
  public void setMock(SObjectType sObjectType, ISelector mock) {
    if (sObjectType == null || mock == null) {
      throw new ApplicationException('setMock requires a non-null SObject type and selector.');
    }
    mocksByType.put(sObjectType, mock);
  }
}
