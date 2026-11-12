@IsTest
private class UnitOfWorkFactoryTest {
  private static final List<SObjectType> COMMIT_ORDER = new List<SObjectType>{ Account.SObjectType };

  @IsTest
  static void newInstance_noMock_returnsNewUnitOfWork() {
    UnitOfWorkFactory factory = new UnitOfWorkFactory();

    IUnitOfWork first = factory.newInstance(COMMIT_ORDER);
    IUnitOfWork second = factory.newInstance(COMMIT_ORDER, new SystemDml());

    Assert.isInstanceOfType(first, UnitOfWork.class, 'Default implementation');
    Assert.isFalse(first === second, 'A new unit per business operation');
  }

  @IsTest
  static void setMock_mockWinsForBothOverloads() {
    UnitOfWorkFactory factory = new UnitOfWorkFactory();
    Mocks uowMock = new Mocks();
    IUnitOfWork mock = (IUnitOfWork) uowMock.stub(IUnitOfWork.class);
    factory.setMock(mock);

    factory.newInstance(COMMIT_ORDER).commitWork();

    Assert.isTrue(factory.newInstance(COMMIT_ORDER, new SystemDml()) === mock, 'The mock is returned');
    uowMock.verify('commitWork', 1);
  }

  @IsTest
  static void setMock_null_throws() {
    try {
      new UnitOfWorkFactory().setMock(null);
      Assert.fail('Expected ApplicationException');
    } catch (ApplicationException e) {
      Assert.isTrue(e.getMessage().contains('non-null'), e.getMessage());
    }
  }
}
