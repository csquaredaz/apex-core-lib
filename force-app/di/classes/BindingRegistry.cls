/**
 * @description Resolves a binding key to an implementation type for one kind of factory
 * (Registry pattern). Services key on an interface name; selectors and domains key on an SObject
 * API name.
 *
 * Resolution order:
 * 1. An active `DI_Binding__mdt` row of this registry's `Kind__c` whose `Interface__c` matches the
 *    key (case-insensitive). Consumers such as `apex-platform-logging` override library defaults
 *    this way, with no code change in this package.
 * 2. The code default passed to the constructor.
 *
 * It fails fast with `ApplicationException` on a missing binding, two active rows for one key, an
 * implementation name that doesn't resolve, or an implementation that isn't assignable to the
 * required type. Validation is lazy and per key, so one bad row never breaks an unrelated key.
 *
 * Limits: no SOQL (`getAll()` reads the metadata cache), metadata is read once per registry.
 * @group Public API
 */
public with sharing class BindingRegistry {
  /**
   * @description The factory a registry serves; matches the `DI_Binding__mdt.Kind__c` values.
   */
  public enum Kind {
    SERVICE,
    SELECTOR,
    DOMAIN
  }

  private final Kind kind;
  private final Map<String, Type> defaultsByKey = new Map<String, Type>();
  private final List<DI_Binding__mdt> metadataRows;
  private Map<String, List<DI_Binding__mdt>> activeRowsByKey;

  /**
   * @description Creates a registry over the org's `DI_Binding__mdt` rows and the given code defaults.
   * @param kind The factory this registry serves; only rows of this kind apply.
   * @param defaults Key to implementation type, used when no active metadata row applies.
   */
  public BindingRegistry(Kind kind, Map<String, Type> defaults) {
    this(kind, defaults, null);
  }

  /**
   * @description Test seam: custom metadata can't be inserted in a test, so rows are injected.
   * @param kind The factory this registry serves.
   * @param defaults Key to implementation type.
   * @param metadataRows Rows to use instead of `DI_Binding__mdt.getAll()`; null means read the org.
   */
  @TestVisible
  private BindingRegistry(Kind kind, Map<String, Type> defaults, List<DI_Binding__mdt> metadataRows) {
    this.kind = kind;
    if (defaults != null) {
      for (String key : defaults.keySet()) {
        defaultsByKey.put(normalise(key), defaults.get(key));
      }
    }
    this.metadataRows = metadataRows;
  }

  /**
   * @description Returns the implementation type bound to a key.
   * @param key The interface name (services) or SObject API name (selectors, domains).
   * @param requiredType The type the implementation must be assignable to.
   * @return The bound implementation type, guaranteed assignable to `requiredType`.
   * @throws ApplicationException If no binding exists or the binding is invalid.
   */
  public Type resolve(String key, Type requiredType) {
    if (String.isBlank(key) || requiredType == null) {
      throw new ApplicationException('A binding lookup needs a key and a required type.');
    }
    Type implementationType = fromMetadata(key);
    if (implementationType == null) {
      implementationType = defaultsByKey.get(normalise(key));
    }
    if (implementationType == null) {
      throw new ApplicationException(
        'No ' + label() + ' binding for ' + key + '. Add a code default or an active DI_Binding__mdt row.'
      );
    }
    if (!requiredType.isAssignableFrom(implementationType)) {
      throw new ApplicationException(
        implementationType.getName() + ' is bound to ' + key + ' but is not a ' + requiredType.getName() + '.'
      );
    }
    return implementationType;
  }

  private Type fromMetadata(String key) {
    List<DI_Binding__mdt> rows = activeRows().get(normalise(key));
    if (rows == null) {
      return null;
    }
    if (rows.size() > 1) {
      List<String> names = new List<String>();
      for (DI_Binding__mdt row : rows) {
        names.add(row.DeveloperName);
      }
      throw new ApplicationException(
        'Ambiguous ' + label() + ' binding for ' + key + ': active DI_Binding__mdt rows ' + String.join(names, ', ')
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
    if (activeRowsByKey != null) {
      return activeRowsByKey;
    }
    activeRowsByKey = new Map<String, List<DI_Binding__mdt>>();
    List<DI_Binding__mdt> rows = metadataRows != null ? metadataRows : DI_Binding__mdt.getAll().values();
    for (DI_Binding__mdt row : rows) {
      if (!row.Is_Active__c || String.isBlank(row.Interface__c) || !isThisKind(row.Kind__c)) {
        continue;
      }
      String key = normalise(row.Interface__c);
      if (!activeRowsByKey.containsKey(key)) {
        activeRowsByKey.put(key, new List<DI_Binding__mdt>());
      }
      activeRowsByKey.get(key).add(row);
    }
    return activeRowsByKey;
  }

  private Boolean isThisKind(String rowKind) {
    // A blank Kind__c means Service, so rows written before Kind__c existed keep working.
    return String.isBlank(rowKind) ? kind == BindingRegistry.Kind.SERVICE : rowKind.equalsIgnoreCase(kind.name());
  }

  private String label() {
    return kind.name().toLowerCase();
  }

  private static String normalise(String key) {
    return key.trim().toLowerCase();
  }
}
