/**
 * @description The default `IDml`: every statement runs with `AccessLevel.USER_MODE`, so object
 * permissions, field-level security and sharing are enforced by the platform. A record that sets a
 * field the user can't edit fails the whole statement with a `DmlException` (ADR 0005).
 * @group Public API
 */
public with sharing class UserModeDml implements IDml {
  /** @description Inserts in user mode, all or none. @param records Records of one type. */
  public void dmlInsert(List<SObject> records) {
    Database.insert(records, true, AccessLevel.USER_MODE);
  }

  /** @description Updates in user mode, all or none. @param records Records of one type. */
  public void dmlUpdate(List<SObject> records) {
    Database.update(records, true, AccessLevel.USER_MODE);
  }

  /**
   * @description Upserts in user mode, all or none. The user needs create and edit access.
   * @param records Records of one type.
   * @param externalIdField The match key.
   */
  public void dmlUpsert(List<SObject> records, SObjectField externalIdField) {
    Database.upsert(records, externalIdField, true, AccessLevel.USER_MODE);
  }

  /** @description Deletes in user mode, all or none. @param records Records of one type. */
  public void dmlDelete(List<SObject> records) {
    Database.delete(records, true, AccessLevel.USER_MODE);
  }
}
