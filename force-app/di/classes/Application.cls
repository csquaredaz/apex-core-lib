/**
 * @description Static entry point to the application factories (FFLIB-compatible naming).
 *
 * This is a Service Locator over the `BindingRegistry` (ADR 0004 names the trade-off): Apex has
 * no constructor injection container, and the Stub API needs a seam to substitute mocks.
 * Collaborators are always requested by interface, so the locator stays at the edges of each class.
 *
 * Code defaults bind the library's ports to safe built-in adapters. A consumer rebinds a port by
 * shipping one active `DI_Binding__mdt` row, for example `ILogger` → `PlatformEventLogger`.
 *
 * Later factories (`Selector`, `UnitOfWork`, `Domain`) join this class with their layers.
 * @group Public API
 */
public with sharing class Application {
  /**
   * @description Services and port adapters, resolved by interface type.
   */
  public static final ServiceFactory Service = new ServiceFactory(
    new BindingRegistry(
      new Map<Type, Type>{ ILogger.class => DebugLogger.class, IAlertSink.class => NoOpAlertSink.class }
    )
  );
}
