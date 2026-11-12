/**
 * @description Generates syntactically valid, unique record Ids for in-memory test records, so
 * unit tests can build related SObjects without DML.
 * @group Testing
 */
@IsTest
public class FakeId {
  private static Integer sequence = 0;

  /**
   * @description Returns a new fake Id for the SObject type.
   * @param sObjectType The type the Id should belong to.
   * @return A 15-character Id with the type's key prefix, unique within the transaction.
   */
  public static Id generate(SObjectType sObjectType) {
    sequence++;
    String keyPrefix = sObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).getKeyPrefix();
    return Id.valueOf(keyPrefix + String.valueOf(sequence).leftPad(12, '0'));
  }
}
