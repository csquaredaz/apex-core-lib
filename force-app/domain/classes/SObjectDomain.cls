/**
 * @description Base class for domains: the behaviour of one SObject type across a list of records
 * (Table Module, FFLIB Domain layer). The `handle*` methods are Template Methods that fix the
 * order of the hooks; subclasses override only the hooks they need.
 *
 * Hook order per trigger event:
 * - before insert: `onApplyDefaults`, then `onBeforeInsert`
 * - after insert: `onValidate()`, then `onAfterInsert`
 * - before update: `onBeforeUpdate`
 * - after update: `onValidate(existingRecords)`, then `onAfterUpdate`
 * - before delete, after delete, after undelete: the matching `on*` hook
 *
 * Validation runs in the after phase, as in FFLIB, so it sees field values set by every before
 * trigger, flow and workflow. `onValidate(existingRecords)` calls `onValidate()` by default, so
 * one override validates both inserts and updates.
 *
 * Domains hold no state beyond their records and do no SOQL or DML of their own: they ask a
 * selector for data and register changes with a Unit of Work.
 * @group Public API
 */
public abstract with sharing class SObjectDomain implements IDomain {
  /** @description The records this domain owns; `Trigger.new`, or `Trigger.old` on delete. */
  protected final List<SObject> records;

  /**
   * @description Creates a domain over the given records.
   * @param records The records; must not be null.
   * @throws ApplicationException If `records` is null.
   */
  protected SObjectDomain(List<SObject> records) {
    if (records == null) {
      throw new ApplicationException('A domain needs a record list; pass an empty list for none.');
    }
    this.records = records;
  }

  /**
   * @description The SObject type this domain owns; `DomainFactory` checks it against the binding.
   * @return The SObject type.
   */
  public abstract SObjectType getSObjectType();

  /**
   * @description The records this domain owns.
   * @return The records.
   */
  public List<SObject> getRecords() {
    return records;
  }

  /** @description Template Method: `onApplyDefaults`, then `onBeforeInsert`. */
  public void handleBeforeInsert() {
    onApplyDefaults();
    onBeforeInsert();
  }

  /**
   * @description Template Method: `onBeforeUpdate`.
   * @param existingRecords The records before the update, by Id.
   */
  public void handleBeforeUpdate(Map<Id, SObject> existingRecords) {
    onBeforeUpdate(existingRecords);
  }

  /** @description Template Method: `onBeforeDelete`. */
  public void handleBeforeDelete() {
    onBeforeDelete();
  }

  /** @description Template Method: `onValidate()`, then `onAfterInsert`. */
  public void handleAfterInsert() {
    onValidate();
    onAfterInsert();
  }

  /**
   * @description Template Method: `onValidate(existingRecords)`, then `onAfterUpdate`.
   * @param existingRecords The records before the update, by Id.
   */
  public void handleAfterUpdate(Map<Id, SObject> existingRecords) {
    onValidate(existingRecords);
    onAfterUpdate(existingRecords);
  }

  /** @description Template Method: `onAfterDelete`. */
  public void handleAfterDelete() {
    onAfterDelete();
  }

  /** @description Template Method: `onAfterUndelete`. */
  public void handleAfterUndelete() {
    onAfterUndelete();
  }

  /** @description Hook: set default field values on new records. Does nothing by default. */
  public virtual void onApplyDefaults() {
    return;
  }

  /** @description Hook: validate new records; report failures with `addError`. Does nothing by default. */
  public virtual void onValidate() {
    return;
  }

  /**
   * @description Hook: validate updated records. Calls `onValidate()` by default.
   * @param existingRecords The records before the update, by Id.
   */
  public virtual void onValidate(Map<Id, SObject> existingRecords) {
    onValidate();
  }

  /** @description Hook: before insert, after `onApplyDefaults`. Does nothing by default. */
  public virtual void onBeforeInsert() {
    return;
  }

  /**
   * @description Hook: before update. Does nothing by default.
   * @param existingRecords The records before the update, by Id.
   */
  public virtual void onBeforeUpdate(Map<Id, SObject> existingRecords) {
    return;
  }

  /** @description Hook: before delete. Does nothing by default. */
  public virtual void onBeforeDelete() {
    return;
  }

  /** @description Hook: after insert, after `onValidate()`. Does nothing by default. */
  public virtual void onAfterInsert() {
    return;
  }

  /**
   * @description Hook: after update, after `onValidate(existingRecords)`. Does nothing by default.
   * @param existingRecords The records before the update, by Id.
   */
  public virtual void onAfterUpdate(Map<Id, SObject> existingRecords) {
    return;
  }

  /** @description Hook: after delete. Does nothing by default. */
  public virtual void onAfterDelete() {
    return;
  }

  /** @description Hook: after undelete. Does nothing by default. */
  public virtual void onAfterUndelete() {
    return;
  }
}
