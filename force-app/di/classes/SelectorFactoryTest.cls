@IsTest
private class SelectorFactoryTest {
  private static SelectorFactory factoryWith(List<DI_Binding__mdt> rows) {
    return new SelectorFactory(new BindingRegistry(BindingRegistry.Kind.SELECTOR, null, rows));
  }

  private static SelectorFactory accountsBound() {
    return factoryWith(
      new List<DI_Binding__mdt>{
        DiTestFixtures.binding('Selector', 'Accounts', 'Account', 'DataTestFixtures.AccountsSelector')
      }
    );
  }

  private static String expectError(SelectorFactory factory, SObjectType sObjectType) {
    try {
      factory.newInstance(sObjectType);
      Assert.fail('Expected ApplicationException');
    } catch (ApplicationException e) {
      return e.getMessage();
    }
    return null;
  }

  @IsTest
  static void newInstance_boundSObjectType_returnsItsSelector() {
    ISelector selector = accountsBound().newInstance(Account.SObjectType);

    Assert.isInstanceOfType(selector, DataTestFixtures.AccountsSelector.class, 'Resolved from the Selector row');
  }

  @IsTest
  static void newInstance_selectorQueriesAnotherType_throws() {
    SelectorFactory factory = factoryWith(
      new List<DI_Binding__mdt>{
        DiTestFixtures.binding('Selector', 'Wrong', 'Account', 'DataTestFixtures.OrdersSelector')
      }
    );

    String message = expectError(factory, Account.SObjectType);

    Assert.isTrue(message.contains('queries Order'), message);
  }

  @IsTest
  static void newInstance_serviceRowForSameKey_doesNotBind() {
    SelectorFactory factory = factoryWith(
      new List<DI_Binding__mdt>{
        DiTestFixtures.binding('Service', 'Accounts', 'Account', 'DataTestFixtures.AccountsSelector')
      }
    );

    Assert.isTrue(expectError(factory, Account.SObjectType).startsWith('No selector binding'), 'Kind matters');
  }

  @IsTest
  static void newInstance_nullType_throws() {
    Assert.isTrue(expectError(accountsBound(), null).contains('null SObject type'), 'Null type');
  }

  @IsTest
  static void setMock_registeredMock_winsOverBinding() {
    SelectorFactory factory = accountsBound();
    ISelector mock = (ISelector) new Mocks().stub(ISelector.class);
    factory.setMock(Account.SObjectType, mock);

    Assert.isTrue(factory.newInstance(Account.SObjectType) === mock, 'The mock is returned');
  }

  @IsTest
  static void setMock_nullArguments_throw() {
    try {
      accountsBound().setMock(Account.SObjectType, null);
      Assert.fail('Expected ApplicationException');
    } catch (ApplicationException e) {
      Assert.isTrue(e.getMessage().contains('non-null'), e.getMessage());
    }
  }

  @IsTest
  static void selectById_idsOfOneType_queriesThroughBoundSelector() {
    List<Account> accounts = DataTestFixtures.accounts(2);
    insert accounts;

    List<SObject> selected = accountsBound().selectById(new Map<Id, Account>(accounts).keySet());

    Assert.areEqual(2, selected.size(), 'Both records');
    Assert.isTrue(selected[0].isSet('Phone'), 'Selected with the bound selector field list');
  }

  @IsTest
  static void selectById_mixedTypes_throws() {
    Set<Id> ids = new Set<Id>{ FakeId.generate(Account.SObjectType), FakeId.generate(Order.SObjectType) };

    try {
      accountsBound().selectById(ids);
      Assert.fail('Expected ApplicationException');
    } catch (ApplicationException e) {
      Assert.isTrue(e.getMessage().contains('one SObject type'), e.getMessage());
    }
  }

  @IsTest
  static void selectById_empty_returnsEmptyWithoutQuerying() {
    Test.startTest();
    Integer size = accountsBound().selectById(new Set<Id>()).size();
    Integer queries = Limits.getQueries();
    Test.stopTest();

    Assert.areEqual(0, size + queries, 'Nothing selected and no SOQL');
  }
}
