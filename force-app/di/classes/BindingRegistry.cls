/**
 * @description Resolves an interface type to its implementation type (Registry pattern).
 *
 * Resolution order:
 * 1. An active `DI_Binding__mdt` row whose `Interface__c` names the interface (case-insensitive).
 *    Consumers such as `apex-platform-logging` override library defaults this way, with no code
 *    change in this package.
 * 2. The code default passed to the constructor.
 *
 * It fails fast with `ApplicationException` on a missing binding, two active rows for one
 * interface, an implementation name that doesn't resolve, or an implementation that isn't
 * assignable to the interface. Validation is lazy and per interface, so one bad row never breaks
 * resolution of an unrelated interface.
 *
 * Limits: no SOQL (`getAll()` reads the metadata cache), metadata is read once per transaction.
 * @group Public API
 */
public with sharing class BindingRegistry {
  private final Map<Type, Type> defaults;
  private final List<DI_Binding__mdt> metadataRows;
  private Map<String, List<DI_Binding__mdt>> activeRowsByInterface;

  /**
   * @description Creates a registry over the org's `DI_Binding__mdt` rows and the given code defaults.
   * @param defaults Interface type to implementation type, used when no active metadata row applies.
   */
  public BindingRegistry(Map<Type, Type> defaults) {
    this(defaults, null);
  }

  /**
   * @description Test seam: custom metadata can't be inserted in a test, so rows are injected.
   * @param defaults Interface type to implementation type.
   * @param metadataRows Rows to use instead of `DI_Binding__mdt.getAll()`; null means read the org.
   */
  @TestVisible
  private BindingRegistry(Map<Type, Type> defaults, List<DI_Binding__mdt> metadataRows) {
    this.defaults = defaults == null ? new Map<Type, Type>() : defaults;
    this.metadataRows = metadataRows;
  }

  /**
   * @description Returns the implementation type bound to an interface.
   * @param interfaceType The interface (or abstract type) being requested.
   * @return The bound implementation type, guaranteed assignable to `interfaceType`.
   * @throws ApplicationException If no binding exists or the binding is invalid.
   */
  public Type resolve(Type interfaceType) {
    if (interfaceType == null) {
      throw new ApplicationException('Cannot resolve a binding for a null interface type.');
    }
    Type implementationType = fromMetadata(interfaceType);
    if (implementationType == null) {
      implementationType = defaults.get(interfaceType);
    }
    if (implementationType == null) {
      throw new ApplicationException(
        'No binding for ' + interfaceType.getName() + '. Add a code default or an active DI_Binding__mdt row.'
      );
    }
    if (!interfaceType.isAssignableFrom(implementationType)) {
      throw new ApplicationException(
        implementationType.getName() + ' is bound to ' + interfaceType.getName() + ' but does not implement it.'
      );
    }
    return implementationType;
  }

  private Type fromMetadata(Type interfaceType) {
    List<DI_Binding__mdt> rows = activeRows().get(interfaceType.getName().toLowerCase());
    if (rows == null) {
      return null;
    }
    if (rows.size() > 1) {
      List<String> names = new List<String>();
      for (DI_Binding__mdt row : rows) {
        names.add(row.DeveloperName);
      }
      throw new ApplicationException(
        'Ambiguous binding for ' + interfaceType.getName() + ': active DI_Binding__mdt rows ' + String.join(names, ', ')
      );
    }
    DI_Binding__mdt row = rows[0];
    Type implementationType = Type.forName(row.Implementation__c);
    if (implementationType == null) {
      throw new ApplicationException(
        'DI_Binding__mdt ' +
          row.DeveloperName +
          ' names implementation ' +
          row.Implementation__c +
          ', which does not exist.'
      );
    }
    return implementationType;
  }

  private Map<String, List<DI_Binding__mdt>> activeRows() {
    if (activeRowsByInterface != null) {
      return activeRowsByInterface;
    }
    activeRowsByInterface = new Map<String, List<DI_Binding__mdt>>();
    List<DI_Binding__mdt> rows = metadataRows != null ? metadataRows : DI_Binding__mdt.getAll().values();
    for (DI_Binding__mdt row : rows) {
      if (!row.Is_Active__c || String.isBlank(row.Interface__c)) {
        continue;
      }
      String key = row.Interface__c.trim().toLowerCase();
      if (!activeRowsByInterface.containsKey(key)) {
        activeRowsByInterface.put(key, new List<DI_Binding__mdt>());
      }
      activeRowsByInterface.get(key).add(row);
    }
    return activeRowsByInterface;
  }
}
