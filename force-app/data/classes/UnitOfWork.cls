/**
 * @description The default `IUnitOfWork`. Commit order is the SObject type list given to the
 * constructor, parents before children. Deletes run in reverse order, so children go first.
 *
 * Guarantees:
 * - One savepoint around all DML and registered work. On failure it rolls back, clears the Ids it
 *   assigned to new records (so a retry can't update ghosts), and rethrows the original exception.
 * - One DML statement per SObject type per operation (insert, update, delete), plus the savepoint.
 *   Nothing is registered, nothing is spent.
 * - DML goes through the `IDml` strategy, `UserModeDml` by default (ADR 0005).
 *
 * Registration mistakes fail fast with `UnitOfWorkException`: a new record with an Id, a dirty or
 * deleted record without one, a type outside the commit order, the same Id registered dirty as
 * two different instances without a field list, or the same Id both dirty and deleted.
 * @group Public API
 */
public with sharing class UnitOfWork implements IUnitOfWork {
  private final List<SObjectType> commitOrder = new List<SObjectType>();
  private final IDml dml;
  private final Map<SObjectType, List<SObject>> newByType = new Map<SObjectType, List<SObject>>();
  private final Map<SObjectType, Map<Id, SObject>> dirtyByType = new Map<SObjectType, Map<Id, SObject>>();
  private final Map<SObjectType, Map<Id, SObject>> deletedByType = new Map<SObjectType, Map<Id, SObject>>();
  private final Map<SObjectType, List<Relationship>> relationshipsByType = new Map<SObjectType, List<Relationship>>();
  private final List<IDoWork> work = new List<IDoWork>();
  private Boolean committed = false;
  private Integer registrations = 0;

  /**
   * @description Creates a Unit of Work that commits in user mode.
   * @param commitOrder SObject types, parents before children.
   */
  public UnitOfWork(List<SObjectType> commitOrder) {
    this(commitOrder, new UserModeDml());
  }

  /**
   * @description Creates a Unit of Work with an explicit DML strategy.
   * @param commitOrder SObject types, parents before children.
   * @param dml The DML strategy.
   * @throws UnitOfWorkException If the commit order is empty or the strategy is null.
   */
  public UnitOfWork(List<SObjectType> commitOrder, IDml dml) {
    if (commitOrder == null || commitOrder.isEmpty() || dml == null) {
      throw new UnitOfWorkException('A Unit of Work needs a non-empty commit order and an IDml.');
    }
    this.dml = dml;
    for (SObjectType sObjectType : commitOrder) {
      this.commitOrder.add(sObjectType);
      newByType.put(sObjectType, new List<SObject>());
      dirtyByType.put(sObjectType, new Map<Id, SObject>());
      deletedByType.put(sObjectType, new Map<Id, SObject>());
      relationshipsByType.put(sObjectType, new List<Relationship>());
    }
  }

  /** @description See `IUnitOfWork.registerNew`. @param record A record without an Id. */
  public void registerNew(SObject record) {
    SObjectType sObjectType = typeInCommitOrder(record);
    if (record.Id != null) {
      throw new UnitOfWorkException('registerNew needs a record without an Id; got ' + record.Id + '.');
    }
    newByType.get(sObjectType).add(record);
    registrations++;
  }

  /** @description See `IUnitOfWork.registerNew`. @param records Records without Ids. */
  public void registerNew(List<SObject> records) {
    for (SObject record : records) {
      registerNew(record);
    }
  }

  /**
   * @description See `IUnitOfWork.registerNew`.
   * @param record A record without an Id.
   * @param relatedToField The lookup field on `record`.
   * @param relatedTo The parent record.
   */
  public void registerNew(SObject record, SObjectField relatedToField, SObject relatedTo) {
    registerNew(record);
    registerRelationship(record, relatedToField, relatedTo);
  }

  /** @description See `IUnitOfWork.registerDirty`. @param record A record with an Id. */
  public void registerDirty(SObject record) {
    Map<Id, SObject> dirty = dirtyByType.get(typeWithId(record, 'registerDirty'));
    SObject existing = dirty.get(record.Id);
    if (existing != null && existing !== record) {
      throw new UnitOfWorkException(
        record.Id +
        ' is already registered dirty as another instance. Pass the changed fields to registerDirty(record, dirtyFields).'
      );
    }
    dirty.put(record.Id, record);
    registrations++;
  }

  /** @description See `IUnitOfWork.registerDirty`. @param records Records with Ids. */
  public void registerDirty(List<SObject> records) {
    for (SObject record : records) {
      registerDirty(record);
    }
  }

  /**
   * @description See `IUnitOfWork.registerDirty`.
   * @param record A record with an Id.
   * @param dirtyFields The fields to write.
   */
  public void registerDirty(SObject record, List<SObjectField> dirtyFields) {
    SObjectType sObjectType = typeWithId(record, 'registerDirty');
    Map<Id, SObject> dirty = dirtyByType.get(sObjectType);
    SObject sparse = dirty.get(record.Id);
    if (sparse == null) {
      sparse = sObjectType.newSObject(record.Id);
      dirty.put(record.Id, sparse);
      registrations++;
    }
    for (SObjectField field : dirtyFields) {
      sparse.put(field, record.get(field));
    }
  }

  /** @description See `IUnitOfWork.registerDeleted`. @param record A record with an Id. */
  public void registerDeleted(SObject record) {
    SObjectType sObjectType = typeWithId(record, 'registerDeleted');
    if (dirtyByType.get(sObjectType).containsKey(record.Id)) {
      throw new UnitOfWorkException(record.Id + ' is registered both dirty and deleted; pick one.');
    }
    deletedByType.get(sObjectType).put(record.Id, record);
    registrations++;
  }

  /** @description See `IUnitOfWork.registerDeleted`. @param records Records with Ids. */
  public void registerDeleted(List<SObject> records) {
    for (SObject record : records) {
      registerDeleted(record);
    }
  }

  /**
   * @description See `IUnitOfWork.registerRelationship`.
   * @param record The child record.
   * @param relatedToField The lookup field on `record`.
   * @param relatedTo The parent record.
   */
  public void registerRelationship(SObject record, SObjectField relatedToField, SObject relatedTo) {
    SObjectType sObjectType = typeInCommitOrder(record);
    if (relatedToField == null || relatedTo == null) {
      throw new UnitOfWorkException('registerRelationship needs a lookup field and a parent record.');
    }
    DescribeFieldResult field = relatedToField.getDescribe();
    if (field.getType() != DisplayType.REFERENCE || !field.getReferenceTo().contains(relatedTo.getSObjectType())) {
      throw new UnitOfWorkException(
        relatedToField + ' is not a lookup to ' + relatedTo.getSObjectType() + ', so it cannot hold that parent.'
      );
    }
    relationshipsByType.get(sObjectType).add(new Relationship(record, relatedToField, relatedTo));
  }

  /** @description See `IUnitOfWork.registerWork`. @param work The work. */
  public void registerWork(IDoWork work) {
    if (work == null) {
      throw new UnitOfWorkException('registerWork needs non-null work.');
    }
    this.work.add(work);
    registrations++;
  }

  /**
   * @description See `IUnitOfWork.commitWork`.
   * Limits: 1 DML for the savepoint plus 1 per non-empty (type, operation); none if nothing is registered.
   * @throws UnitOfWorkException If called twice, or a parent has no Id when its child is written.
   */
  public void commitWork() {
    if (committed) {
      throw new UnitOfWorkException('commitWork was already called. Use one Unit of Work per business operation.');
    }
    committed = true;
    if (isEmpty()) {
      return;
    }
    Savepoint savepoint = Database.setSavepoint();
    try {
      insertInCommitOrder();
      updateInCommitOrder();
      deleteInReverseOrder();
      for (IDoWork unit : work) {
        unit.doWork();
      }
    } catch (Exception e) {
      Database.rollback(savepoint);
      clearAssignedIds();
      throw e;
    }
  }

  private void insertInCommitOrder() {
    for (SObjectType sObjectType : commitOrder) {
      resolveRelationships(sObjectType);
      List<SObject> inserts = newByType.get(sObjectType);
      if (!inserts.isEmpty()) {
        dml.dmlInsert(inserts);
      }
    }
  }

  private void updateInCommitOrder() {
    for (SObjectType sObjectType : commitOrder) {
      Map<Id, SObject> updates = dirtyByType.get(sObjectType);
      if (!updates.isEmpty()) {
        dml.dmlUpdate(updates.values());
      }
    }
  }

  private void deleteInReverseOrder() {
    for (Integer i = commitOrder.size() - 1; i >= 0; i--) {
      Map<Id, SObject> deletes = deletedByType.get(commitOrder[i]);
      if (!deletes.isEmpty()) {
        dml.dmlDelete(deletes.values());
      }
    }
  }

  private void resolveRelationships(SObjectType sObjectType) {
    for (Relationship relationship : relationshipsByType.get(sObjectType)) {
      relationship.resolve();
    }
  }

  private void clearAssignedIds() {
    for (List<SObject> inserts : newByType.values()) {
      for (SObject record : inserts) {
        record.Id = null;
      }
    }
  }

  private Boolean isEmpty() {
    return registrations == 0;
  }

  private SObjectType typeInCommitOrder(SObject record) {
    if (record == null) {
      throw new UnitOfWorkException('Cannot register a null record.');
    }
    SObjectType sObjectType = record.getSObjectType();
    if (!newByType.containsKey(sObjectType)) {
      throw new UnitOfWorkException(sObjectType + ' is not in this Unit of Work\'s commit order.');
    }
    return sObjectType;
  }

  private SObjectType typeWithId(SObject record, String operation) {
    SObjectType sObjectType = typeInCommitOrder(record);
    if (record.Id == null) {
      throw new UnitOfWorkException(operation + ' needs a record with an Id.');
    }
    return sObjectType;
  }

  private class Relationship {
    private final SObject record;
    private final SObjectField field;
    private final SObject relatedTo;

    private Relationship(SObject record, SObjectField field, SObject relatedTo) {
      this.record = record;
      this.field = field;
      this.relatedTo = relatedTo;
    }

    private void resolve() {
      if (relatedTo.Id == null) {
        throw new UnitOfWorkException(
          'The parent for ' +
            field +
            ' has no Id at commit. Put ' +
            relatedTo.getSObjectType() +
            ' earlier in the commit order.'
        );
      }
      record.put(field, relatedTo.Id);
    }
  }
}
