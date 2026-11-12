/**
 * @description Creates Units of Work, so a service's DML can be replaced by a mock in unit tests.
 * Each service passes its own commit order, because the library can't know the consumer's types.
 *
 * Usage: `IUnitOfWork uow = Application.UnitOfWork.newInstance(new List<SObjectType>{ Account.SObjectType, Order.SObjectType });`
 * @group Public API
 */
public with sharing class UnitOfWorkFactory {
  private IUnitOfWork mock;

  /**
   * @description Returns a Unit of Work that commits in user mode.
   * @param commitOrder SObject types, parents before children.
   * @return The mock if one is registered, otherwise a new `UnitOfWork`.
   */
  public IUnitOfWork newInstance(List<SObjectType> commitOrder) {
    return mock != null ? mock : new UnitOfWork(commitOrder);
  }

  /**
   * @description Returns a Unit of Work with an explicit DML strategy.
   * @param commitOrder SObject types, parents before children.
   * @param dml The DML strategy, for example `new StripInaccessibleDml(new UserModeDml())`.
   * @return The mock if one is registered, otherwise a new `UnitOfWork`.
   */
  public IUnitOfWork newInstance(List<SObjectType> commitOrder, IDml dml) {
    return mock != null ? mock : new UnitOfWork(commitOrder, dml);
  }

  /**
   * @description Registers a test double returned by every `newInstance` call, for the rest of the transaction.
   * @param mock The mock Unit of Work.
   * @throws ApplicationException If the mock is null.
   */
  public void setMock(IUnitOfWork mock) {
    if (mock == null) {
      throw new ApplicationException('setMock requires a non-null Unit of Work.');
    }
    this.mock = mock;
  }
}
