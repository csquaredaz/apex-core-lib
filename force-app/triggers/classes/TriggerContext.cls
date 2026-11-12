/**
 * @description An immutable snapshot of one trigger invocation (Adapter over the static `Trigger`
 * context variables). The dispatcher reads only this, so its logic is unit-testable with a fake
 * context and no DML; production code calls `TriggerContext.current()` inside a trigger.
 *
 * ```apex
 * TriggerDispatcher.run(new TriggerContext(TriggerOperation.BEFORE_INSERT, accounts, null));
 * ```
 * @group Public API
 */
public with sharing class TriggerContext {
  /** @description The trigger event. */
  public final TriggerOperation operation;
  /** @description `Trigger.new`; null on delete. */
  public final List<SObject> newRecords;
  /** @description `Trigger.old`; null on insert and undelete. */
  public final List<SObject> oldRecords;
  /** @description `Trigger.oldMap`, built from `oldRecords`; null when they are. */
  public final Map<Id, SObject> oldMap;
  /** @description The SObject type the trigger fired on. */
  public final SObjectType sObjectType;

  /**
   * @description Creates a context, usually a fake one in a test.
   * @param operation The trigger event.
   * @param newRecords `Trigger.new`; required except on delete.
   * @param oldRecords `Trigger.old`; required on update and delete. Records need Ids (see `FakeId`).
   * @throws ApplicationException If the operation is null, a list the event needs is missing, or the
   * SObject type can't be inferred.
   */
  public TriggerContext(TriggerOperation operation, List<SObject> newRecords, List<SObject> oldRecords) {
    requireRecords(operation, newRecords, oldRecords);
    this.operation = operation;
    this.newRecords = newRecords;
    this.oldRecords = oldRecords;
    this.oldMap = oldRecords == null ? null : new Map<Id, SObject>(oldRecords);
    this.sObjectType = typeOf(records());
  }

  /**
   * @description The context of the trigger now running.
   * @return A snapshot of `Trigger.operationType`, `Trigger.new` and `Trigger.old`.
   * @throws ApplicationException If called outside a trigger.
   */
  public static TriggerContext current() {
    if (!Trigger.isExecuting) {
      throw new ApplicationException('TriggerContext.current() must be called from a trigger.');
    }
    return new TriggerContext(Trigger.operationType, Trigger.new, Trigger.old);
  }

  /**
   * @description The records a domain owns for this event.
   * @return `oldRecords` on delete, otherwise `newRecords`.
   */
  public List<SObject> records() {
    return newRecords == null ? oldRecords : newRecords;
  }

  private static void requireRecords(TriggerOperation operation, List<SObject> newRecords, List<SObject> oldRecords) {
    if (operation == null) {
      throw new ApplicationException('A trigger context needs an operation.');
    }
    Boolean needsNew = operation != TriggerOperation.BEFORE_DELETE && operation != TriggerOperation.AFTER_DELETE;
    Boolean needsOld =
      !needsNew ||
      operation == TriggerOperation.BEFORE_UPDATE ||
      operation == TriggerOperation.AFTER_UPDATE;
    if (needsNew && newRecords == null) {
      throw new ApplicationException(operation + ' needs new records.');
    }
    if (needsOld && oldRecords == null) {
      throw new ApplicationException(operation + ' needs old records.');
    }
  }

  private static SObjectType typeOf(List<SObject> records) {
    SObjectType sObjectType = records.getSObjectType();
    if (sObjectType == null && !records.isEmpty()) {
      sObjectType = records[0].getSObjectType();
    }
    if (sObjectType == null) {
      throw new ApplicationException('Cannot infer the SObject type of an empty, untyped record list.');
    }
    return sObjectType;
  }
}
