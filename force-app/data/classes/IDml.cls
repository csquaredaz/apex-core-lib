/**
 * @description DML strategy the Unit of Work commits through (Strategy pattern), so the security
 * mode is a choice made once, at construction, not at every DML statement. Implementations:
 * `UserModeDml` (default), `StripInaccessibleDml` (decorator) and `SystemDml` (explicit opt-in).
 * @group Public API
 */
public interface IDml {
  /**
   * @description Inserts the records, all or none. Inserted Ids are set on the given instances.
   * @param records Records of one SObject type.
   */
  void dmlInsert(List<SObject> records);

  /**
   * @description Updates the records, all or none.
   * @param records Records of one SObject type, each with an Id.
   */
  void dmlUpdate(List<SObject> records);

  /**
   * @description Upserts the records, all or none, matching on `externalIdField`. Created and
   * matched records both get their Ids set on the given instances. Added in 1.1.0.
   * @param records Records of one SObject type.
   * @param externalIdField The match key: an External Id or other `idLookup` field of that type,
   * or its `Id` field.
   */
  void dmlUpsert(List<SObject> records, SObjectField externalIdField);

  /**
   * @description Deletes the records, all or none.
   * @param records Records of one SObject type, each with an Id.
   */
  void dmlDelete(List<SObject> records);
}
