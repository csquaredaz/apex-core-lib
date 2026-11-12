/**
 * @description Base class for selectors (Template Method, Query Object). A subclass names its
 * SObject type and field list once, then adds query methods that call `query`.
 *
 * Security: every query runs through `Database.queryWithBinds(..., AccessLevel.USER_MODE)`, so
 * object permissions, field-level security and sharing are enforced by the platform (ADR 0005).
 * A field the running user can't read throws `QueryException` rather than returning silently.
 *
 * Injection: `whereClause` must be a literal written in the subclass, with every value passed as
 * a bind variable in `binds`. Never concatenate input into it.
 *
 * ```apex
 * public with sharing class ShipmentsSelector extends SObjectSelector {
 *   public override SObjectType getSObjectType() { return Shipment__c.SObjectType; }
 *   public override List<SObjectField> getSObjectFieldList() {
 *     return new List<SObjectField>{ Shipment__c.Status__c, Shipment__c.Order__c };
 *   }
 *   public List<Shipment__c> selectPendingByOrderId(Set<Id> orderIds) {
 *     return query('Order__c IN :orderIds AND Status__c = \'Pending\'', new Map<String, Object>{ 'orderIds' => orderIds });
 *   }
 * }
 * ```
 * @group Public API
 */
public abstract with sharing class SObjectSelector implements ISelector {
  /**
   * @description The SObject type this selector queries.
   * @return The SObject type.
   */
  public abstract SObjectType getSObjectType();

  /**
   * @description The fields every query returns. `Id` is always added.
   * @return The field list.
   */
  public abstract List<SObjectField> getSObjectFieldList();

  /**
   * @description The ORDER BY clause every query uses. Override for a business ordering.
   * @return The ordering, without the `ORDER BY` keywords.
   */
  public virtual String getOrderBy() {
    return 'Id';
  }

  /**
   * @description Selects records by Id with the standard field list, in user mode.
   * Limits: 1 SOQL, none for an empty set.
   * @param ids The record Ids; null or empty returns an empty list without querying.
   * @return The records the running user can see.
   */
  public List<SObject> selectSObjectsById(Set<Id> ids) {
    if (ids == null || ids.isEmpty()) {
      return new List<SObject>();
    }
    return query('Id IN :ids', new Map<String, Object>{ 'ids' => ids });
  }

  /**
   * @description Runs a query with the standard field list and ordering, in user mode.
   * @param whereClause A literal condition without the `WHERE` keyword; blank selects everything.
   * @param binds Bind variable values referenced in `whereClause`.
   * @return The matching records.
   */
  protected List<SObject> query(String whereClause, Map<String, Object> binds) {
    return Database.queryWithBinds(
      buildSoql(whereClause),
      binds == null ? new Map<String, Object>() : binds,
      AccessLevel.USER_MODE
    );
  }

  /**
   * @description Builds the SOQL text. Visible to tests so the query shape can be asserted.
   * @param whereClause A literal condition without the `WHERE` keyword.
   * @return The SOQL statement.
   */
  @TestVisible
  protected String buildSoql(String whereClause) {
    // A list keeps the field order stable; the set drops duplicates (Id is always first).
    List<String> fieldNames = new List<String>{ 'Id' };
    Set<String> seen = new Set<String>{ 'id' };
    for (SObjectField field : getSObjectFieldList()) {
      String fieldName = String.valueOf(field);
      if (seen.add(fieldName.toLowerCase())) {
        fieldNames.add(fieldName);
      }
    }
    String soql = 'SELECT ' + String.join(fieldNames, ', ') + ' FROM ' + getSObjectType();
    if (String.isNotBlank(whereClause)) {
      soql += ' WHERE ' + whereClause;
    }
    return soql + ' ORDER BY ' + getOrderBy();
  }
}
