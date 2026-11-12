/**
 * @description Interface and implementation pairs that the DI tests bind and resolve.
 * Public so `Type.forName` and `Type.newInstance` can reach the inner types.
 */
@IsTest
public class DiTestFixtures {
  /** @description `Interface__c` value for `IGreeter`. */
  public static final String GREETER = DiTestFixtures.IGreeter.class.getName();

  /** @description A port to bind. */
  public interface IGreeter {
    /** @description @return A greeting. */
    String greet();
  }

  /** @description The code-default implementation. */
  public class EnglishGreeter implements IGreeter {
    /** @description @return A greeting. */
    public String greet() {
      return 'Hello';
    }
  }

  /** @description The metadata override implementation. */
  public class SpanishGreeter implements IGreeter {
    /** @description @return A greeting. */
    public String greet() {
      return 'Hola';
    }
  }

  /** @description A class that does not implement `IGreeter`. */
  public class NotAGreeter {
  }

  /**
   * @description Builds an in-memory binding row; custom metadata can't be inserted in tests.
   * @param developerName Row name.
   * @param interfaceName `Interface__c`.
   * @param implementationName `Implementation__c`.
   * @param isActive `Is_Active__c`.
   * @return The row.
   */
  public static DI_Binding__mdt binding(
    String developerName,
    String interfaceName,
    String implementationName,
    Boolean isActive
  ) {
    return new DI_Binding__mdt(
      DeveloperName = developerName,
      Kind__c = 'Service',
      Interface__c = interfaceName,
      Implementation__c = implementationName,
      Is_Active__c = isActive
    );
  }

  /**
   * @description Builds an in-memory binding row of a given kind.
   * @param kind `Kind__c`: Service, Selector or Domain, or null for blank.
   * @param developerName Row name.
   * @param key `Interface__c`.
   * @param implementationName `Implementation__c`.
   * @return The active row.
   */
  public static DI_Binding__mdt binding(String kind, String developerName, String key, String implementationName) {
    DI_Binding__mdt row = binding(developerName, key, implementationName, true);
    row.Kind__c = kind;
    return row;
  }
}
