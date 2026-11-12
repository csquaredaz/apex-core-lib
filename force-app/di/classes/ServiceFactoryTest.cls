@IsTest
private class ServiceFactoryTest {
  private static ServiceFactory factory() {
    return new ServiceFactory(
      new BindingRegistry(
        new Map<Type, Type>{ DiTestFixtures.IGreeter.class => DiTestFixtures.EnglishGreeter.class },
        new List<DI_Binding__mdt>()
      )
    );
  }

  @IsTest
  static void newInstance_boundInterface_returnsWorkingImplementation() {
    DiTestFixtures.IGreeter greeter = (DiTestFixtures.IGreeter) factory().newInstance(DiTestFixtures.IGreeter.class);

    Assert.areEqual('Hello', greeter.greet(), 'Returns the bound implementation');
  }

  @IsTest
  static void newInstance_calledTwice_returnsDistinctInstances() {
    ServiceFactory services = factory();

    Object first = services.newInstance(DiTestFixtures.IGreeter.class);
    Object second = services.newInstance(DiTestFixtures.IGreeter.class);

    Assert.isFalse(first === second, 'Services are stateless, so each call gets a new instance');
  }

  @IsTest
  static void newInstance_mockRegistered_returnsSameMockEveryCall() {
    // The Stub API can't stub inner types, so this mocks a top-level port instead of IGreeter.
    ServiceFactory services = new ServiceFactory(
      new BindingRegistry(new Map<Type, Type>{ IAlertSink.class => NoOpAlertSink.class }, new List<DI_Binding__mdt>())
    );
    Mocks sinkMock = new Mocks();
    services.setMock(IAlertSink.class, sinkMock.stub(IAlertSink.class));

    IAlertSink first = (IAlertSink) services.newInstance(IAlertSink.class);
    IAlertSink second = (IAlertSink) services.newInstance(IAlertSink.class);
    first.send(new List<Alert>());

    Assert.isFalse(first instanceof NoOpAlertSink, 'The mock wins over the binding');
    Assert.isTrue(first === second, 'One mock per interface, so calls can be verified');
    sinkMock.verify('send', 1);
  }

  @IsTest
  static void newInstance_unboundInterface_throws() {
    try {
      factory().newInstance(ILogger.class);
      Assert.fail('Expected ApplicationException');
    } catch (ApplicationException e) {
      Assert.isTrue(e.getMessage().startsWith('No binding for ILogger'), e.getMessage());
    }
  }

  @IsTest
  static void setMock_nullMock_throws() {
    try {
      factory().setMock(DiTestFixtures.IGreeter.class, null);
      Assert.fail('Expected ApplicationException');
    } catch (ApplicationException e) {
      Assert.isTrue(e.getMessage().contains('non-null'), e.getMessage());
    }
  }
}
