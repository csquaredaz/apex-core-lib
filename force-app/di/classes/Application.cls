/**
 * @description Static entry point to the application factories (FFLIB-compatible naming).
 *
 * This is a Service Locator over `BindingRegistry` (ADR 0004 names the trade-off): Apex has no
 * constructor-injection container, and the Stub API needs a seam to substitute mocks.
 * Collaborators are always requested by interface or SObject type, at the edge of a class.
 *
 * Code defaults bind the library's ports to safe built-in adapters. A consumer rebinds a port, or
 * binds its own services and selectors, with active `DI_Binding__mdt` rows.
 * @group Public API
 */
public with sharing class Application {
  /**
   * @description Services and port adapters, resolved by interface type.
   */
  public static final ServiceFactory Service = new ServiceFactory(
    new BindingRegistry(
      BindingRegistry.Kind.SERVICE,
      new Map<String, Type>{
        ILogger.class.getName() => DebugLogger.class,
        IAlertSink.class.getName() => NoOpAlertSink.class
      }
    )
  );

  /**
   * @description Selectors, resolved by SObject type. The library ships no selector bindings.
   */
  public static final SelectorFactory Selector = new SelectorFactory(
    new BindingRegistry(BindingRegistry.Kind.SELECTOR, null)
  );

  /**
   * @description Domains, resolved by SObject type. The library ships no domain bindings.
   */
  public static final DomainFactory Domain = new DomainFactory(new BindingRegistry(BindingRegistry.Kind.DOMAIN, null));

  /**
   * @description Units of Work; each caller supplies its commit order.
   */
  public static final UnitOfWorkFactory UnitOfWork = new UnitOfWorkFactory();
}
