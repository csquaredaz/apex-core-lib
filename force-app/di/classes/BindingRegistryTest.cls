@IsTest
private class BindingRegistryTest {
  private static final Map<String, Type> DEFAULTS = new Map<String, Type>{
    DiTestFixtures.GREETER => DiTestFixtures.EnglishGreeter.class
  };

  private static BindingRegistry services(List<DI_Binding__mdt> rows) {
    return new BindingRegistry(BindingRegistry.Kind.SERVICE, DEFAULTS, rows);
  }

  private static Type resolveGreeter(BindingRegistry registry) {
    return registry.resolve(DiTestFixtures.GREETER, DiTestFixtures.IGreeter.class);
  }

  private static String resolveExpectingError(BindingRegistry registry, String key, Type requiredType) {
    try {
      registry.resolve(key, requiredType);
      Assert.fail('Expected ApplicationException');
    } catch (ApplicationException e) {
      return e.getMessage();
    }
    return null;
  }

  @IsTest
  static void resolve_noMetadataRows_returnsCodeDefault() {
    Test.startTest();
    Type resolved = resolveGreeter(services(new List<DI_Binding__mdt>()));
    Test.stopTest();

    Assert.areEqual(DiTestFixtures.EnglishGreeter.class, resolved, 'Falls back to the code default');
  }

  @IsTest
  static void resolve_publicConstructor_readsOrgMetadataAndFallsBack() {
    // The package ships no DI_Binding__mdt records, so the org read finds no override.
    Type resolved = resolveGreeter(new BindingRegistry(BindingRegistry.Kind.SERVICE, DEFAULTS));

    Assert.areEqual(DiTestFixtures.EnglishGreeter.class, resolved, 'No org rows bind the test interface');
  }

  @IsTest
  static void resolve_activeMetadataRow_overridesCodeDefault() {
    BindingRegistry registry = services(
      new List<DI_Binding__mdt>{
        DiTestFixtures.binding('Spanish', DiTestFixtures.GREETER, 'DiTestFixtures.SpanishGreeter', true)
      }
    );

    Assert.areEqual(
      DiTestFixtures.SpanishGreeter.class,
      resolveGreeter(registry),
      'An active row beats the code default'
    );
  }

  @IsTest
  static void resolve_blankKind_isTreatedAsService() {
    BindingRegistry registry = services(
      new List<DI_Binding__mdt>{
        DiTestFixtures.binding(null, 'Spanish', DiTestFixtures.GREETER, 'DiTestFixtures.SpanishGreeter')
      }
    );

    Assert.areEqual(DiTestFixtures.SpanishGreeter.class, resolveGreeter(registry), 'Blank Kind__c binds services');
  }

  @IsTest
  static void resolve_rowOfAnotherKind_isIgnored() {
    BindingRegistry registry = services(
      new List<DI_Binding__mdt>{
        DiTestFixtures.binding('Selector', 'Spanish', DiTestFixtures.GREETER, 'DiTestFixtures.SpanishGreeter')
      }
    );

    Assert.areEqual(
      DiTestFixtures.EnglishGreeter.class,
      resolveGreeter(registry),
      'A Selector row never binds a service, even with the same key'
    );
  }

  @IsTest
  static void resolve_keyInDifferentCaseAndWhitespace_matches() {
    BindingRegistry registry = services(
      new List<DI_Binding__mdt>{
        DiTestFixtures.binding('Spanish', '  ditestfixtures.IGREETER ', 'DiTestFixtures.SpanishGreeter', true)
      }
    );

    Assert.areEqual(
      DiTestFixtures.SpanishGreeter.class,
      resolveGreeter(registry),
      'Apex type names are case-insensitive, and surrounding whitespace is trimmed'
    );
  }

  @IsTest
  static void resolve_inactiveMetadataRow_isIgnored() {
    BindingRegistry registry = services(
      new List<DI_Binding__mdt>{
        DiTestFixtures.binding('Spanish', DiTestFixtures.GREETER, 'DiTestFixtures.SpanishGreeter', false)
      }
    );

    Assert.areEqual(DiTestFixtures.EnglishGreeter.class, resolveGreeter(registry), 'Deactivating restores the default');
  }

  @IsTest
  static void resolve_noBindingAnywhere_throwsNamingKindAndKey() {
    BindingRegistry registry = new BindingRegistry(BindingRegistry.Kind.SELECTOR, null, new List<DI_Binding__mdt>());

    String message = resolveExpectingError(registry, 'Shipment__c', ISelector.class);

    Assert.isTrue(message.startsWith('No selector binding for Shipment__c'), message);
  }

  @IsTest
  static void resolve_blankKeyOrNullType_throws() {
    BindingRegistry registry = services(new List<DI_Binding__mdt>());

    Assert.isTrue(resolveExpectingError(registry, ' ', ILogger.class).contains('needs a key'), 'Blank key');
    Assert.isTrue(resolveExpectingError(registry, 'ILogger', null).contains('needs a key'), 'Null required type');
  }

  @IsTest
  static void resolve_implementationNameDoesNotExist_throwsNamingTheRow() {
    BindingRegistry registry = services(
      new List<DI_Binding__mdt>{
        DiTestFixtures.binding('Typo', DiTestFixtures.GREETER, 'DiTestFixtures.FrenchGreeter', true)
      }
    );

    String message = resolveExpectingError(registry, DiTestFixtures.GREETER, DiTestFixtures.IGreeter.class);

    Assert.isTrue(message.contains('DI_Binding__mdt Typo'), 'Names the bad row: ' + message);
    Assert.isTrue(message.contains('DiTestFixtures.FrenchGreeter'), 'Names the bad type: ' + message);
  }

  @IsTest
  static void resolve_implementationNotAssignable_throws() {
    BindingRegistry registry = services(
      new List<DI_Binding__mdt>{
        DiTestFixtures.binding('Wrong', DiTestFixtures.GREETER, 'DiTestFixtures.NotAGreeter', true)
      }
    );

    String message = resolveExpectingError(registry, DiTestFixtures.GREETER, DiTestFixtures.IGreeter.class);

    Assert.isTrue(message.contains('is not a DiTestFixtures.IGreeter'), message);
  }

  @IsTest
  static void resolve_twoActiveRowsForOneKey_throwsAmbiguous() {
    BindingRegistry registry = services(
      new List<DI_Binding__mdt>{
        DiTestFixtures.binding('Spanish', DiTestFixtures.GREETER, 'DiTestFixtures.SpanishGreeter', true),
        DiTestFixtures.binding('English', DiTestFixtures.GREETER, 'DiTestFixtures.EnglishGreeter', true)
      }
    );

    String message = resolveExpectingError(registry, DiTestFixtures.GREETER, DiTestFixtures.IGreeter.class);

    Assert.isTrue(message.startsWith('Ambiguous service binding'), message);
    Assert.isTrue(message.contains('Spanish') && message.contains('English'), 'Names both rows: ' + message);
  }

  @IsTest
  static void resolve_badRowForOtherKey_doesNotBreakThisOne() {
    BindingRegistry registry = services(
      new List<DI_Binding__mdt>{
        DiTestFixtures.binding('Broken', 'ILogger', 'DoesNotExist', true),
        DiTestFixtures.binding('Blank', null, 'DiTestFixtures.SpanishGreeter', true)
      }
    );

    Assert.areEqual(
      DiTestFixtures.EnglishGreeter.class,
      resolveGreeter(registry),
      'Validation is per key, and rows without a key are ignored'
    );
  }
}
