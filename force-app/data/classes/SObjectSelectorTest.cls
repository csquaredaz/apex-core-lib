@IsTest
private class SObjectSelectorTest {
  @IsTest
  static void buildSoql_dropsDuplicateIdAndAppliesWhereAndOrder() {
    String soql = new DataTestFixtures.AccountsSelector().buildSoql('Name IN :names');

    Assert.areEqual('SELECT Id, Name, Phone FROM Account WHERE Name IN :names ORDER BY Name', soql, 'Query shape');
  }

  @IsTest
  static void buildSoql_blankWhere_omitsWhereAndUsesDefaultOrder() {
    String soql = new DataTestFixtures.OrdersSelector().buildSoql(null);

    Assert.areEqual('SELECT Id, AccountId, Status FROM Order ORDER BY Id', soql, 'No WHERE; ORDER BY Id by default');
  }

  @IsTest
  static void selectSObjectsById_200Records_usesOneQuery() {
    List<Account> accounts = DataTestFixtures.accounts(200);
    insert accounts;
    Set<Id> ids = new Map<Id, Account>(accounts).keySet();

    Test.startTest();
    List<SObject> selected = new DataTestFixtures.AccountsSelector().selectSObjectsById(ids);
    Integer queries = Limits.getQueries();
    Test.stopTest();

    Assert.areEqual(200, selected.size(), 'Every record is returned');
    Assert.areEqual(1, queries, 'Bulk-safe: one SOQL for 200 Ids');
  }

  @IsTest
  static void selectSObjectsById_nullOrEmpty_returnsEmptyWithoutQuerying() {
    DataTestFixtures.AccountsSelector selector = new DataTestFixtures.AccountsSelector();

    Test.startTest();
    Integer nullCount = selector.selectSObjectsById(null).size();
    Integer emptyCount = selector.selectSObjectsById(new Set<Id>()).size();
    Integer queries = Limits.getQueries();
    Test.stopTest();

    Assert.areEqual(0, nullCount + emptyCount, 'Nothing selected');
    Assert.areEqual(0, queries, 'No SOQL spent on empty input');
  }

  @IsTest
  static void query_subclassMethodWithBinds_returnsMatches() {
    insert DataTestFixtures.accounts(3);

    List<Account> selected = new DataTestFixtures.AccountsSelector().selectByName(new Set<String>{ 'Customer 001' });

    Assert.areEqual(1, selected.size(), 'Bind variables filter the query');
    Assert.areEqual('Customer 001', selected[0].Name, 'The matching record');
  }

  @IsTest
  static void query_userWithoutObjectAccess_throwsQueryException() {
    Account account = DataTestFixtures.accounts(1)[0];
    insert account;
    User restricted = DataTestFixtures.restrictedUser(false);

    System.runAs(restricted) {
      try {
        new DataTestFixtures.AccountsSelector().selectSObjectsById(new Set<Id>{ account.Id });
        Assert.fail('Expected QueryException: user mode enforces object permissions');
      } catch (QueryException e) {
        Assert.isNotNull(e.getMessage(), 'The platform rejects the query');
      }
    }
  }

  @IsTest
  static void query_userWithoutFieldAccess_throwsQueryException() {
    User restricted = DataTestFixtures.restrictedUser(true);

    System.runAs(restricted) {
      Account account = new Account(Name = 'Visible');
      insert account;
      try {
        new DataTestFixtures.AccountsSelector().selectSObjectsById(new Set<Id>{ account.Id });
        Assert.fail('Expected QueryException: user mode enforces field-level security on Phone');
      } catch (QueryException e) {
        Assert.isNotNull(e.getMessage(), 'The platform rejects the inaccessible field');
      }
    }
  }
}
