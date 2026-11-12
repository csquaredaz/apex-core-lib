@IsTest
private class DomainFactoryTest {
  private static final String ACCOUNTS_CONSTRUCTOR = 'DomainTestFixtures.AccountsDomainConstructor';

  private static DomainFactory accountsBound() {
    return DomainTestFixtures.factory(new Map<String, String>{ 'Account' => ACCOUNTS_CONSTRUCTOR });
  }

  private static String expectError(DomainFactory factory, List<SObject> records, SObjectType sObjectType) {
    try {
      factory.newInstance(records, sObjectType);
      Assert.fail('Expected ApplicationException');
    } catch (ApplicationException e) {
      return e.getMessage();
    }
    return null;
  }

  @IsTest
  static void newInstance_typedList_buildsBoundDomainOverTheRecords() {
    List<Account> accounts = DomainTestFixtures.accountsWithIds(2);

    IDomain domain = accountsBound().newInstance(accounts);

    Assert.isInstanceOfType(domain, DomainTestFixtures.AccountsDomain.class, 'Built by the bound constructor');
    Assert.isTrue(domain.getRecords() === accounts, 'Over the same list');
  }

  @IsTest
  static void newInstance_untypedNonEmptyList_infersTypeFromFirstRecord() {
    List<SObject> records = new List<SObject>{ new Account(Name = 'Customer') };

    Assert.areEqual(Account.SObjectType, accountsBound().newInstance(records).getSObjectType(), 'Inferred');
  }

  @IsTest
  static void newInstance_emptyUntypedList_throws() {
    try {
      accountsBound().newInstance(new List<SObject>());
      Assert.fail('Expected ApplicationException');
    } catch (ApplicationException e) {
      Assert.isTrue(e.getMessage().contains('Cannot infer'), e.getMessage());
    }
  }

  @IsTest
  static void newInstance_nullList_throws() {
    try {
      accountsBound().newInstance((List<SObject>) null);
      Assert.fail('Expected ApplicationException');
    } catch (ApplicationException e) {
      Assert.isTrue(e.getMessage().contains('null record list'), e.getMessage());
    }
  }

  @IsTest
  static void newInstance_sObjectType_buildsDomainOverEmptyTypedList() {
    IDomain domain = accountsBound().newInstance(Account.SObjectType);

    Assert.areEqual(0, domain.getRecords().size(), 'No records');
    Assert.areEqual(Account.SObjectType, domain.getRecords().getSObjectType(), 'The empty list is typed');
  }

  @IsTest
  static void newInstance_nullSObjectType_throws() {
    try {
      accountsBound().newInstance((SObjectType) null);
      Assert.fail('Expected ApplicationException');
    } catch (ApplicationException e) {
      Assert.isTrue(e.getMessage().contains('null SObject type'), e.getMessage());
    }
  }

  @IsTest
  static void newInstance_nullArgumentsToExplicitOverload_throw() {
    Assert.isTrue(expectError(accountsBound(), null, Account.SObjectType).contains('null'), 'Null records');
    Assert.isTrue(expectError(accountsBound(), new List<Account>(), null).contains('null'), 'Null type');
  }

  @IsTest
  static void newInstance_unboundType_throws() {
    String message = expectError(accountsBound(), new List<Order>(), Order.SObjectType);

    Assert.isTrue(message.startsWith('No domain binding for Order'), message);
  }

  @IsTest
  static void newInstance_domainForAnotherType_throws() {
    DomainFactory factory = DomainTestFixtures.factory(
      new Map<String, String>{ 'Account' => 'DomainTestFixtures.MinimalOrdersDomainConstructor' }
    );

    String message = expectError(factory, new List<Account>(), Account.SObjectType);

    Assert.isTrue(message.contains('owns Order'), message);
  }

  @IsTest
  static void newInstance_constructorReturnsNull_throws() {
    DomainFactory factory = DomainTestFixtures.factory(
      new Map<String, String>{ 'Account' => 'DomainTestFixtures.NullDomainConstructor' }
    );

    String message = expectError(factory, new List<Account>(), Account.SObjectType);

    Assert.isTrue(message.contains('owns null'), message);
  }

  @IsTest
  static void newInstance_bindingNamesTheDomainNotItsConstructor_throws() {
    DomainFactory factory = DomainTestFixtures.factory(
      new Map<String, String>{ 'Account' => 'DomainTestFixtures.AccountsDomain' }
    );

    String message = expectError(factory, new List<Account>(), Account.SObjectType);

    Assert.isTrue(message.contains('is not a IDomainConstructor'), message);
  }

  @IsTest
  static void setMock_registeredMock_winsOverBindingAndIgnoresRecords() {
    DomainFactory factory = accountsBound();
    IDomain mock = (IDomain) new Mocks().stub(IDomain.class);
    factory.setMock(Account.SObjectType, mock);

    Assert.isTrue(factory.newInstance(DomainTestFixtures.accountsWithIds(1)) === mock, 'The mock is returned');
  }

  @IsTest
  static void setMock_nullArguments_throw() {
    try {
      accountsBound().setMock(null, (IDomain) new Mocks().stub(IDomain.class));
      Assert.fail('Expected ApplicationException');
    } catch (ApplicationException e) {
      Assert.isTrue(e.getMessage().contains('non-null'), e.getMessage());
    }
  }
}
