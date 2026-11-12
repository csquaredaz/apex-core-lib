/**
 * @description Contract between the trigger dispatcher and a domain (Table Module). The dispatcher
 * calls exactly one `handle*` method per trigger invocation; `SObjectDomain` implements them as Template
 * Methods over overridable hooks. Being an interface, it can be replaced with a Stub API mock
 * through `Application.Domain.setMock`.
 * @group Public API
 */
public interface IDomain {
  /**
   * @description The SObject type this domain owns.
   * @return The SObject type.
   */
  SObjectType getSObjectType();

  /**
   * @description The records this domain was built with.
   * @return The records; `Trigger.new`, or `Trigger.old` on delete.
   */
  List<SObject> getRecords();

  /** @description Runs the before-insert logic. */
  void handleBeforeInsert();

  /**
   * @description Runs the before-update logic.
   * @param existingRecords The records before the update, by Id (`Trigger.oldMap`).
   */
  void handleBeforeUpdate(Map<Id, SObject> existingRecords);

  /** @description Runs the before-delete logic. */
  void handleBeforeDelete();

  /** @description Runs the after-insert logic. */
  void handleAfterInsert();

  /**
   * @description Runs the after-update logic.
   * @param existingRecords The records before the update, by Id (`Trigger.oldMap`).
   */
  void handleAfterUpdate(Map<Id, SObject> existingRecords);

  /** @description Runs the after-delete logic. */
  void handleAfterDelete();

  /** @description Runs the after-undelete logic. */
  void handleAfterUndelete();
}
