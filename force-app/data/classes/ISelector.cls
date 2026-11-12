/**
 * @description Contract every selector meets, so generic code (the selector factory, domains,
 * the Unit of Work) can query any SObject type by Id without knowing its selector class.
 * @group Public API
 */
public interface ISelector {
  /**
   * @description The SObject type this selector queries.
   * @return The SObject type.
   */
  SObjectType getSObjectType();

  /**
   * @description Selects records by Id with the selector's standard field list, in user mode.
   * @param ids The record Ids; null or empty returns an empty list without querying.
   * @return The records the running user can see.
   */
  List<SObject> selectSObjectsById(Set<Id> ids);
}
