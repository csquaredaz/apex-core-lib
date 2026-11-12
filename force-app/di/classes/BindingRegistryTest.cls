@IsTest
private class BindingRegistryTest {
  private static final Map<Type, Type> DEFAULTS = new Map<Type, Type>{
    DiTestFixtures.IGreeter.class => DiTestFixtures.EnglishGreeter.class
  };

  private static BindingRegistry registryWith(List<DI_Binding__mdt> rows) {
    return new BindingRegistry(DEFAULTS, rows);
  }

  private static String resolveExpectingError(BindingRegistry registry, Type interfaceType) {
    try {
      registry.resolve(interfaceType);
      Assert.fail('Expected ApplicationException');
    } catch (ApplicationException e) {
      return e.getMessage();
    }
    return null;
  }

  @IsTest
  static void resolve_noMetadataRows_returnsCodeDefault() {
    Test.startTest();
    Type resolved = registryWith(new List<DI_Binding__mdt>()).resolve(DiTestFixtures.IGreeter.class);
    Test.stopTest();

    Assert.areEqual(DiTestFixtures.EnglishGreeter.class, resolved, 'Falls back to the code default');
  }

  @IsTest
  static void resolve_publicConstructor_readsOrgMetadataAndFallsBack() {
    // The package ships no DI_Binding__mdt records, so the org read finds no override.
    Type resolved = new BindingRegistry(DEFAULTS).resolve(DiTestFixtures.IGreeter.class);

    Assert.areEqual(DiTestFixtures.EnglishGreeter.class, resolved, 'No org rows bind the test interface');
  }

  @IsTest
  static void resolve_activeMetadataRow_overridesCodeDefault() {
    BindingRegistry registry = registryWith(
      new List<DI_Binding__mdt>{
        DiTestFixtures.binding('Spanish', 'DiTestFixtures.IGreeter', 'DiTestFixtures.SpanishGreeter', true)
      }
    );

    Type resolved = registry.resolve(DiTestFixtures.IGreeter.class);

    Assert.areEqual(DiTestFixtures.SpanishGreeter.class, resolved, 'An active row beats the code default');
  }

  @IsTest
  static void resolve_interfaceNameInDifferentCase_matches() {
    BindingRegistry registry = registryWith(
      new List<DI_Binding__mdt>{
        DiTestFixtures.binding('Spanish', '  ditestfixtures.IGREETER ', 'DiTestFixtures.SpanishGreeter', true)
      }
    );

    Assert.areEqual(
      DiTestFixtures.SpanishGreeter.class,
      registry.resolve(DiTestFixtures.IGreeter.class),
      'Apex type names are case-insensitive, and surrounding whitespace is trimmed'
    );
  }

  @IsTest
  static void resolve_inactiveMetadataRow_isIgnored() {
    BindingRegistry registry = registryWith(
      new List<DI_Binding__mdt>{
        DiTestFixtures.binding('Spanish', 'DiTestFixtures.IGreeter', 'DiTestFixtures.SpanishGreeter', false)
      }
    );

    Assert.areEqual(
      DiTestFixtures.EnglishGreeter.class,
      registry.resolve(DiTestFixtures.IGreeter.class),
      'Deactivating a row restores the code default'
    );
  }

  @IsTest
  static void resolve_noBindingAnywhere_throws() {
    BindingRegistry registry = new BindingRegistry(new Map<Type, Type>(), new List<DI_Binding__mdt>());

    String message = resolveExpectingError(registry, DiTestFixtures.IGreeter.class);

    Assert.isTrue(message.startsWith('No binding for DiTestFixtures.IGreeter'), message);
  }

  @IsTest
  static void resolve_nullInterface_throws() {
    String message = resolveExpectingError(registryWith(new List<DI_Binding__mdt>()), null);

    Assert.isTrue(message.contains('null interface'), message);
  }

  @IsTest
  static void resolve_implementationNameDoesNotExist_throwsNamingTheRow() {
    BindingRegistry registry = registryWith(
      new List<DI_Binding__mdt>{
        DiTestFixtures.binding('Typo', 'DiTestFixtures.IGreeter', 'DiTestFixtures.FrenchGreeter', true)
      }
    );

    String message = resolveExpectingError(registry, DiTestFixtures.IGreeter.class);

    Assert.isTrue(message.contains('DI_Binding__mdt Typo'), 'Names the bad row: ' + message);
    Assert.isTrue(message.contains('DiTestFixtures.FrenchGreeter'), 'Names the bad type: ' + message);
  }

  @IsTest
  static void resolve_implementationDoesNotImplementInterface_throws() {
    BindingRegistry registry = registryWith(
      new List<DI_Binding__mdt>{
        DiTestFixtures.binding('Wrong', 'DiTestFixtures.IGreeter', 'DiTestFixtures.NotAGreeter', true)
      }
    );

    String message = resolveExpectingError(registry, DiTestFixtures.IGreeter.class);

    Assert.isTrue(message.contains('does not implement'), message);
  }

  @IsTest
  static void resolve_twoActiveRowsForOneInterface_throwsAmbiguous() {
    BindingRegistry registry = registryWith(
      new List<DI_Binding__mdt>{
        DiTestFixtures.binding('Spanish', 'DiTestFixtures.IGreeter', 'DiTestFixtures.SpanishGreeter', true),
        DiTestFixtures.binding('English', 'DiTestFixtures.IGreeter', 'DiTestFixtures.EnglishGreeter', true)
      }
    );

    String message = resolveExpectingError(registry, DiTestFixtures.IGreeter.class);

    Assert.isTrue(message.startsWith('Ambiguous binding'), message);
    Assert.isTrue(message.contains('Spanish') && message.contains('English'), 'Names both rows: ' + message);
  }

  @IsTest
  static void resolve_badRowForOtherInterface_doesNotBreakThisOne() {
    BindingRegistry registry = registryWith(
      new List<DI_Binding__mdt>{
        DiTestFixtures.binding('Broken', 'ILogger', 'DoesNotExist', true),
        DiTestFixtures.binding('Blank', null, 'DiTestFixtures.SpanishGreeter', true)
      }
    );

    Assert.areEqual(
      DiTestFixtures.EnglishGreeter.class,
      registry.resolve(DiTestFixtures.IGreeter.class),
      'Validation is per interface, and rows without an interface are ignored'
    );
  }
}
