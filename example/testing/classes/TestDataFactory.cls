/**
 * @description Test data for the shipments example: customers, orders, shipments and
 * least-privilege users. Setup DML runs as the current user to avoid mixed-DML errors.
 */
@IsTest
public class TestDataFactory {
  /** @description Weight that passes `ShipmentsDomain` validation. */
  public static final Decimal VALID_WEIGHT_KG = 1.5;

  /**
   * @description Inserts a customer account with one draft order.
   * @return The order.
   */
  public static Order insertOrder() {
    Account customer = new Account(Name = 'Example Customer');
    insert customer;
    Order customerOrder = new Order(AccountId = customer.Id, Status = 'Draft', EffectiveDate = Date.today());
    insert customerOrder;
    return customerOrder;
  }

  /**
   * @description Unsaved shipments for an order.
   * @param count How many.
   * @param orderId The order, or null.
   * @param weightKg The weight of each.
   * @return The shipments.
   */
  public static List<Shipment__c> shipments(Integer count, Id orderId, Decimal weightKg) {
    List<Shipment__c> records = new List<Shipment__c>();
    for (Integer i = 0; i < count; i++) {
      records.add(new Shipment__c(Order__c = orderId, Weight_Kg__c = weightKg));
    }
    return records;
  }

  /**
   * @description In-memory shipments with fake Ids, for unit tests that never touch the database.
   * @param count How many.
   * @return The shipments, `Pending` with a valid weight.
   */
  public static List<Shipment__c> fakeShipments(Integer count) {
    List<Shipment__c> records = shipments(count, null, VALID_WEIGHT_KG);
    for (Shipment__c shipment : records) {
      shipment.Id = FakeId.generate(Shipment__c.SObjectType);
      shipment.Status__c = ShipmentsDomain.STATUS_PENDING;
    }
    return records;
  }

  /**
   * @description A Minimum Access user with the `Shipment_Manager` permission set.
   * @return The user, to pass to `System.runAs`.
   */
  public static User shipmentManager() {
    User user = minimumAccessUser('Manager');
    PermissionSet managerAccess = [SELECT Id FROM PermissionSet WHERE Name = 'Shipment_Manager' LIMIT 1];
    System.runAs(new User(Id = UserInfo.getUserId())) {
      insert new PermissionSetAssignment(PermissionSetId = managerAccess.Id, AssigneeId = user.Id);
    }
    return user;
  }

  /**
   * @description A Minimum Access user with no permission sets: no access to `Shipment__c`.
   * @return The user.
   */
  public static User userWithoutAccess() {
    return minimumAccessUser('NoAccess');
  }

  private static User minimumAccessUser(String lastName) {
    Profile minimumAccess = [SELECT Id FROM Profile WHERE Name = 'Minimum Access - Salesforce' LIMIT 1];
    String unique = String.valueOf(Crypto.getRandomInteger()).replace('-', '');
    User user = new User(
      Alias = 'shiptest',
      Email = 'shipments-test@example.com',
      EmailEncodingKey = 'UTF-8',
      LastName = lastName,
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      TimeZoneSidKey = 'America/Phoenix',
      ProfileId = minimumAccess.Id,
      Username = 'shipments-test-' + unique + '@example.com'
    );
    System.runAs(new User(Id = UserInfo.getUserId())) {
      insert user;
    }
    return user;
  }
}
