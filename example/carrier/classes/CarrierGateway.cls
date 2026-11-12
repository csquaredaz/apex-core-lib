/**
 * @description Calls the carrier's booking API through the `Carrier` Named Credential and
 * `ICalloutClient`, and maps its JSON. Bound by the `DI_Binding.Carrier_Gateway` row.
 *
 * The POST carries an `Idempotency-Key` derived from the shipment Ids, so `CalloutClient` may retry
 * it and the carrier books each batch once, however many attempts reach it.
 */
public with sharing class CarrierGateway implements ICarrierGateway {
  /** @description The Named Credential the gateway calls. */
  public static final String NAMED_CREDENTIAL = 'Carrier';
  /** @description The booking endpoint path. */
  public static final String BOOKINGS_PATH = '/v1/bookings';

  /**
   * @description Books shipments in one callout. Limits: 1 to 3 callouts.
   * @param shipments The shipments.
   * @return Booking reference by shipment Id.
   * @throws CalloutClientException If retries run out, or the carrier rejects the request (non-2xx).
   */
  public Map<Id, String> book(List<Shipment__c> shipments) {
    Map<Id, String> referencesById = new Map<Id, String>();
    if (shipments == null || shipments.isEmpty()) {
      return referencesById;
    }
    BookingRequest payload = new BookingRequest();
    for (Shipment__c shipment : shipments) {
      payload.parcels.add(new Parcel(shipment));
    }
    CalloutRequest request = CalloutRequest.post(NAMED_CREDENTIAL, BOOKINGS_PATH)
      .withJsonBody(payload)
      .withIdempotencyKey(idempotencyKey(shipments));
    CalloutResponse response = ((ICalloutClient) Application.Service.newInstance(ICalloutClient.class)).send(request);
    if (!response.isSuccess()) {
      throw CalloutClientException.failed(request, response.getAttempts(), response, null);
    }
    for (Booking booking : ((BookingResponse) response.readJson(BookingResponse.class)).bookings) {
      referencesById.put(Id.valueOf(booking.shipmentId), booking.reference);
    }
    return referencesById;
  }

  /**
   * @description The same shipments always produce the same key, in any order.
   * @param shipments The shipments.
   * @return A SHA-256 hex digest of the sorted shipment Ids.
   */
  @TestVisible
  private static String idempotencyKey(List<Shipment__c> shipments) {
    List<String> ids = new List<String>();
    for (Shipment__c shipment : shipments) {
      ids.add(shipment.Id);
    }
    ids.sort();
    return EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(String.join(ids, ','))));
  }

  /** @description Request body: the parcels to book. */
  public class BookingRequest {
    /** @description One entry per shipment. */
    public List<Parcel> parcels = new List<Parcel>();
  }

  /** @description One parcel in the request. */
  public class Parcel {
    /** @description The Salesforce shipment Id, echoed back in the booking. */
    public String shipmentId;
    /** @description Weight in kilograms. */
    public Decimal weightKg;

    /** @description @param shipment The shipment. */
    public Parcel(Shipment__c shipment) {
      this.shipmentId = shipment.Id;
      this.weightKg = shipment.Weight_Kg__c;
    }
  }

  /** @description Response body: the bookings made. */
  public class BookingResponse {
    /** @description One entry per booked parcel. */
    public List<Booking> bookings = new List<Booking>();
  }

  /** @description One booking in the response. */
  public class Booking {
    /** @description The shipment Id from the request. */
    public String shipmentId;
    /** @description The carrier's booking reference. */
    public String reference;
  }
}
