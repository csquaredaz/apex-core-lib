/**
 * @description Creates service (and port adapter) instances by interface type (Abstract Factory).
 * Callers depend on the interface and ask the factory for it, so a test can swap in a Stub API
 * mock with `setMock` and production can swap an implementation with a `DI_Binding__mdt` row.
 *
 * Usage: `IOrdersService orders = (IOrdersService) Application.Service.newInstance(IOrdersService.class);`
 *
 * Every call to `newInstance` returns a new instance, because services are stateless. A mock is
 * returned as the same object every time so a test can verify calls on it.
 * @group Public API
 */
public with sharing class ServiceFactory {
  private final BindingRegistry registry;
  private final Map<Type, Object> mocksByInterface = new Map<Type, Object>();

  /**
   * @description Creates a factory that resolves implementations through the given registry.
   * @param registry A `SERVICE` binding registry.
   */
  public ServiceFactory(BindingRegistry registry) {
    this.registry = registry;
  }

  /**
   * @description Returns an implementation of the requested interface.
   * @param interfaceType The interface to instantiate.
   * @return The mock registered for the interface, or a new instance of its bound implementation.
   * @throws ApplicationException If the interface is null or has no valid binding.
   */
  public Object newInstance(Type interfaceType) {
    if (interfaceType == null) {
      throw new ApplicationException('Cannot create a service for a null interface type.');
    }
    if (mocksByInterface.containsKey(interfaceType)) {
      return mocksByInterface.get(interfaceType);
    }
    return registry.resolve(interfaceType.getName(), interfaceType).newInstance();
  }

  /**
   * @description Registers a test double for an interface, for the rest of the transaction.
   * Intended for tests only; it's public so consumer packages' tests can inject mocks.
   * @param interfaceType The interface the mock stands in for.
   * @param mock The mock, for example from `Mocks.stub(interfaceType)` or a `RecordingLogger`.
   * @throws ApplicationException If either argument is null.
   */
  public void setMock(Type interfaceType, Object mock) {
    if (interfaceType == null || mock == null) {
      throw new ApplicationException('setMock requires a non-null interface type and mock.');
    }
    mocksByInterface.put(interfaceType, mock);
  }
}
