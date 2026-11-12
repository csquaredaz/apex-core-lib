/**
 * @description An `IDml` that runs in system mode: no object, field or sharing checks. Use it only
 * for writes the running user must not be able to block, such as persisting audit or log records,
 * and say why in the caller's ApexDoc (ADR 0005). It is never a default.
 * @group Public API
 */
public without sharing class SystemDml implements IDml {
  // without sharing is the point of this class: callers opt in explicitly and document the reason.

  /** @description Inserts in system mode, all or none. @param records Records of one type. */
  public void dmlInsert(List<SObject> records) {
    Database.insert(records, true, AccessLevel.SYSTEM_MODE);
  }

  /** @description Updates in system mode, all or none. @param records Records of one type. */
  public void dmlUpdate(List<SObject> records) {
    Database.update(records, true, AccessLevel.SYSTEM_MODE);
  }

  /** @description Deletes in system mode, all or none. @param records Records of one type. */
  public void dmlDelete(List<SObject> records) {
    Database.delete(records, true, AccessLevel.SYSTEM_MODE);
  }
}
