/**
 * @description Domains, domain constructors and records shared by the domain and trigger tests.
 * Public so `Type.forName` can reach the constructor classes through `DI_Binding__mdt` rows.
 * Apex allows one level of inner classes, so each constructor is a sibling of its domain.
 */
@IsTest
public class DomainTestFixtures {
  /** @description Hooks called, in order, as `hook:recordCount`. Inner classes can't hold statics. */
  public static List<String> hookLog = new List<String>();

  /** @description Logs every hook it overrides, with the size of its record list. */
  public class AccountsDomain extends SObjectDomain {
    /** @description @param records The accounts. */
    public AccountsDomain(List<SObject> records) {
      super(records);
    }

    /** @description @return `Account`. */
    public override SObjectType getSObjectType() {
      return Account.SObjectType;
    }

    /** @description Logs the hook. */
    public override void onApplyDefaults() {
      log('onApplyDefaults');
    }

    /** @description Logs the hook; `onValidate(existingRecords)` is left to the base class. */
    public override void onValidate() {
      log('onValidate');
    }

    /** @description Logs the hook. */
    public override void onBeforeInsert() {
      log('onBeforeInsert');
    }

    /** @description Logs the hook and the old-record count. @param existingRecords Old records. */
    public override void onBeforeUpdate(Map<Id, SObject> existingRecords) {
      log('onBeforeUpdate', existingRecords);
    }

    /** @description Logs the hook. */
    public override void onBeforeDelete() {
      log('onBeforeDelete');
    }

    /** @description Logs the hook. */
    public override void onAfterInsert() {
      log('onAfterInsert');
    }

    /** @description Logs the hook and the old-record count. @param existingRecords Old records. */
    public override void onAfterUpdate(Map<Id, SObject> existingRecords) {
      log('onAfterUpdate', existingRecords);
    }

    /** @description Logs the hook. */
    public override void onAfterDelete() {
      log('onAfterDelete');
    }

    /** @description Logs the hook. */
    public override void onAfterUndelete() {
      log('onAfterUndelete');
    }

    private void log(String hook) {
      hookLog.add(hook + ':' + records.size());
    }

    private void log(String hook, Map<Id, SObject> existingRecords) {
      hookLog.add(hook + ':' + records.size() + ':' + existingRecords.size());
    }
  }

  /** @description Builds `AccountsDomain`. */
  public class AccountsDomainConstructor implements IDomainConstructor {
    /** @description @param records The accounts. @return The domain. */
    public IDomain construct(List<SObject> records) {
      return new AccountsDomain(records);
    }
  }

  /** @description Re-dispatches its own records from `onBeforeInsert`, as a domain's DML would. */
  public class ReentrantAccountsDomain extends SObjectDomain {
    /** @description @param records The accounts. */
    public ReentrantAccountsDomain(List<SObject> records) {
      super(records);
    }

    /** @description @return `Account`. */
    public override SObjectType getSObjectType() {
      return Account.SObjectType;
    }

    /** @description Logs the hook, then runs the dispatcher again for the same type. */
    public override void onBeforeInsert() {
      hookLog.add('onBeforeInsert:' + records.size());
      TriggerDispatcher.run(new TriggerContext(TriggerOperation.BEFORE_INSERT, records, null));
    }
  }

  /** @description Builds `ReentrantAccountsDomain`. */
  public class ReentrantAccountsDomainConstructor implements IDomainConstructor {
    /** @description @param records The accounts. @return The domain. */
    public IDomain construct(List<SObject> records) {
      return new ReentrantAccountsDomain(records);
    }
  }

  /** @description Overrides no hooks, so every base-class default runs. */
  public class MinimalOrdersDomain extends SObjectDomain {
    /** @description @param records The orders. */
    public MinimalOrdersDomain(List<SObject> records) {
      super(records);
    }

    /** @description @return `Order`. */
    public override SObjectType getSObjectType() {
      return Order.SObjectType;
    }
  }

  /** @description Builds `MinimalOrdersDomain`; bound to `Account` it proves the type check. */
  public class MinimalOrdersDomainConstructor implements IDomainConstructor {
    /** @description @param records The records. @return The domain. */
    public IDomain construct(List<SObject> records) {
      return new MinimalOrdersDomain(records);
    }
  }

  /** @description A broken constructor that returns no domain. */
  public class NullDomainConstructor implements IDomainConstructor {
    /** @description @param records Ignored. @return Null. */
    public IDomain construct(List<SObject> records) {
      return null;
    }
  }

  /**
   * @description A domain factory over in-memory `Domain` bindings.
   * @param keyToConstructor SObject API name to constructor class name.
   * @return The factory.
   */
  public static DomainFactory factory(Map<String, String> keyToConstructor) {
    List<DI_Binding__mdt> rows = new List<DI_Binding__mdt>();
    for (String key : keyToConstructor.keySet()) {
      rows.add(DiTestFixtures.binding('Domain', key + 'Domain', key, keyToConstructor.get(key)));
    }
    return new DomainFactory(new BindingRegistry(BindingRegistry.Kind.DOMAIN, null, rows));
  }

  /**
   * @description Unsaved accounts with fake Ids, so they can stand in for `Trigger.old`.
   * @param count How many.
   * @return The accounts.
   */
  public static List<Account> accountsWithIds(Integer count) {
    List<Account> records = new List<Account>();
    for (Integer i = 0; i < count; i++) {
      records.add(new Account(Id = FakeId.generate(Account.SObjectType), Name = 'Customer ' + i));
    }
    return records;
  }
}
