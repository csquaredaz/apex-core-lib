/**
 * @description Port to the fictional carrier API (Gateway). Services depend on this interface, so
 * their tests mock the carrier without HTTP.
 */
public interface ICarrierGateway {
  /**
   * @description Books shipments with the carrier in one call.
   * @param shipments The shipments, with `Weight_Kg__c` set.
   * @return Carrier booking reference by shipment Id; shipments the carrier didn't book are absent.
   */
  Map<Id, String> book(List<Shipment__c> shipments);
}
