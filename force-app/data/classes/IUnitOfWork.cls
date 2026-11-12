/**
 * @description Collects the DML for one business operation and commits it in one transaction
 * (Unit of Work, PoEAA). Services register changes, then call `commitWork()` once.
 * @group Public API
 */
public interface IUnitOfWork {
  /** @description Registers a record to insert. @param record A record without an Id. */
  void registerNew(SObject record);

  /** @description Registers records to insert. @param records Records without Ids. */
  void registerNew(List<SObject> records);

  /**
   * @description Registers a record to insert, with a lookup to a parent that may itself be new.
   * @param record A record without an Id.
   * @param relatedToField The lookup field on `record`.
   * @param relatedTo The parent record.
   */
  void registerNew(SObject record, SObjectField relatedToField, SObject relatedTo);

  /** @description Registers a record to update with all its set fields. @param record A record with an Id. */
  void registerDirty(SObject record);

  /** @description Registers records to update. @param records Records with Ids. */
  void registerDirty(List<SObject> records);

  /**
   * @description Registers only the given fields of a record to update, merging with any earlier
   * registration of the same record. Use it when two code paths change different fields.
   * @param record A record with an Id.
   * @param dirtyFields The fields to write.
   */
  void registerDirty(SObject record, List<SObjectField> dirtyFields);

  /** @description Registers a record to delete. @param record A record with an Id. */
  void registerDeleted(SObject record);

  /** @description Registers records to delete. @param records Records with Ids. */
  void registerDeleted(List<SObject> records);

  /**
   * @description Sets a lookup at commit time, once the parent has an Id.
   * @param record The child record, registered new or dirty.
   * @param relatedToField The lookup field on `record`.
   * @param relatedTo The parent record.
   */
  void registerRelationship(SObject record, SObjectField relatedToField, SObject relatedTo);

  /** @description Registers custom work to run after all DML. @param work The work. */
  void registerWork(IDoWork work);

  /**
   * @description Commits everything in one savepoint: inserts and updates in commit order, deletes
   * in reverse order, then registered work. Any failure rolls back all of it and rethrows.
   */
  void commitWork();
}
