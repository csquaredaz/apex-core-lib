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
   * @description Deletes the records, all or none.
   * @param records Records of one SObject type, each with an Id.
   */
  void dmlDelete(List<SObject> records);
}
