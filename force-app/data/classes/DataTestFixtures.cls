/**
 * @description Selectors and users shared by the data-layer tests. Public so `Type.forName` can
 * reach the selector classes through `DI_Binding__mdt` rows.
 */
@IsTest
public class DataTestFixtures {
  /** @description Selects `Account` with `Name` and `Phone`, ordered by `Name`. */
  public class AccountsSelector extends SObjectSelector {
    /** @description @return `Account`. */
    public override SObjectType getSObjectType() {
      return Account.SObjectType;
    }

    /** @description @return `Name`, `Phone`, and a duplicate `Id` that must be dropped. */
    public override List<SObjectField> getSObjectFieldList() {
      return new List<SObjectField>{ Account.Id, Account.Name, Account.Phone };
    }

    /** @description @return `Name`. */
    public override String getOrderBy() {
      return 'Name';
    }

    /**
     * @description A subclass query method, the way consumers write them.
     * @param names Account names.
     * @return Matching accounts.
     */
    public List<Account> selectByName(Set<String> names) {
      return (List<Account>) query('Name IN :names', new Map<String, Object>{ 'names' => names });
    }
  }

  /** @description Selects `Order`, used to prove the factory checks the selector's type. */
  public class OrdersSelector extends SObjectSelector {
    /** @description @return `Order`. */
    public override SObjectType getSObjectType() {
      return Order.SObjectType;
    }

    /** @description @return `AccountId` and `Status`. */
    public override List<SObjectField> getSObjectFieldList() {
      return new List<SObjectField>{ Order.AccountId, Order.Status };
    }
  }

  /**
   * @description Unsaved accounts with valid defaults.
   * @param count How many.
   * @return The accounts.
   */
  public static List<Account> accounts(Integer count) {
    List<Account> records = new List<Account>();
    for (Integer i = 0; i < count; i++) {
      records.add(new Account(Name = 'Customer ' + String.valueOf(i).leftPad(3, '0')));
    }
    return records;
  }

  /**
   * @description An unsaved draft order for an account.
   * @return The order, without `AccountId`.
   */
  public static Order draftOrder() {
    return new Order(Status = 'Draft', EffectiveDate = Date.today());
  }

  /**
   * @description Inserts a Minimum Access user. With `grantAccountAccess`, a permission set grants
   * full CRUD on `Account` but no field permissions, so the user can't read or edit `Phone`.
   * Setup DML runs as the current user to avoid mixed-DML errors.
   * @param grantAccountAccess Whether to grant `Account` object permissions.
   * @return The inserted user, to pass to `System.runAs`.
   */
  public static User restrictedUser(Boolean grantAccountAccess) {
    Profile minimumAccess = [SELECT Id FROM Profile WHERE Name = 'Minimum Access - Salesforce' LIMIT 1];
    String unique = String.valueOf(Crypto.getRandomInteger()).replace('-', '');
    User user = new User(
      Alias = 'acltest',
      Email = 'acl-test@example.com',
      EmailEncodingKey = 'UTF-8',
      LastName = 'Restricted',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      TimeZoneSidKey = 'America/Phoenix',
      ProfileId = minimumAccess.Id,
      Username = 'acl-test-' + unique + '@example.com'
    );
    System.runAs(new User(Id = UserInfo.getUserId())) {
      insert user;
      if (grantAccountAccess) {
        PermissionSet accountAccess = new PermissionSet(Name = 'Acl_Test_' + unique, Label = 'ACL Test ' + unique);
        insert accountAccess;
        insert new ObjectPermissions(
          ParentId = accountAccess.Id,
          SobjectType = 'Account',
          PermissionsRead = true,
          PermissionsCreate = true,
          PermissionsEdit = true,
          PermissionsDelete = true
        );
        insert new PermissionSetAssignment(PermissionSetId = accountAccess.Id, AssigneeId = user.Id);
      }
    }
    return user;
  }
}
