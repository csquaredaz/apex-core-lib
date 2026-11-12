/**
 * @description Decorator over an `IDml` that removes fields the running user can't create or
 * edit before delegating, instead of failing the statement. Each removal is logged as a warning
 * through `ILogger`, so silent data loss is visible (ADR 0005).
 *
 * Use it where a partial write is the right business outcome, for example a self-service form
 * that may carry fields some profiles can't set. Wrap `UserModeDml` so sharing and object
 * permissions are still enforced: `new StripInaccessibleDml(new UserModeDml())`.
 *
 * `Security.stripInaccessible` returns copies, so inserted Ids are copied back onto the caller's
 * records. The Unit of Work relies on that to resolve relationships.
 *
 * Limits: no SOQL; one describe-backed access check per statement.
 * @group Public API
 */
public with sharing class StripInaccessibleDml implements IDml {
  private final IDml wrapped;
  private final ILogger logger;

  /**
   * @description Decorates an `IDml`, logging through the bound `ILogger`.
   * @param wrapped The `IDml` that performs the DML.
   */
  public StripInaccessibleDml(IDml wrapped) {
    this(wrapped, (ILogger) Application.Service.newInstance(ILogger.class));
  }

  /**
   * @description Decorates an `IDml` with an explicit logger.
   * @param wrapped The `IDml` that performs the DML.
   * @param logger Where stripped fields are reported.
   */
  public StripInaccessibleDml(IDml wrapped, ILogger logger) {
    if (wrapped == null || logger == null) {
      throw new IllegalArgumentException('StripInaccessibleDml needs a wrapped IDml and a logger.');
    }
    this.wrapped = wrapped;
    this.logger = logger;
  }

  /**
   * @description Strips fields the user can't create, inserts, then copies Ids back.
   * @param records Records of one SObject type.
   */
  public void dmlInsert(List<SObject> records) {
    List<SObject> stripped = strip(AccessType.CREATABLE, records, 'insert');
    wrapped.dmlInsert(stripped);
    copyIdsBack(stripped, records);
  }

  /**
   * @description Strips fields the user can't both create and edit, upserts, then copies the Ids
   * of created and matched records back. If the match key itself is stripped, the upsert fails.
   * @param records Records of one SObject type.
   * @param externalIdField The match key.
   */
  public void dmlUpsert(List<SObject> records, SObjectField externalIdField) {
    List<SObject> stripped = strip(AccessType.UPSERTABLE, records, 'upsert');
    wrapped.dmlUpsert(stripped, externalIdField);
    copyIdsBack(stripped, records);
  }

  /**
   * @description Strips fields the user can't edit, then updates.
   * @param records Records of one SObject type, each with an Id.
   */
  public void dmlUpdate(List<SObject> records) {
    wrapped.dmlUpdate(strip(AccessType.UPDATABLE, records, 'update'));
  }

  /**
   * @description Deletes are not field-level, so they pass straight through to the wrapped `IDml`.
   * @param records Records of one SObject type, each with an Id.
   */
  public void dmlDelete(List<SObject> records) {
    wrapped.dmlDelete(records);
  }

  private static void copyIdsBack(List<SObject> written, List<SObject> callers) {
    for (Integer i = 0; i < callers.size(); i++) {
      callers[i].Id = written[i].Id;
    }
  }

  private List<SObject> strip(AccessType accessType, List<SObject> records, String operation) {
    SObjectAccessDecision decision = Security.stripInaccessible(accessType, records);
    Map<String, Set<String>> removed = decision.getRemovedFields();
    for (String sObjectName : removed.keySet()) {
      List<String> fields = new List<String>(removed.get(sObjectName));
      fields.sort();
      logger.warn(
        'StripInaccessibleDml removed fields on ' + operation + ' of ' + sObjectName + ': ' + String.join(fields, ', ')
      );
    }
    return decision.getRecords();
  }
}
