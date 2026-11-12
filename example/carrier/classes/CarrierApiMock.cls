/**
 * @description A fake carrier API: answers every request with one status code and, on 2xx, books
 * every parcel in the request with a reference `CR-<n>`. Counts the requests it receives.
 */
@IsTest
public class CarrierApiMock implements HttpCalloutMock {
  private final Integer statusCode;
  /** @description Requests received, in order. */
  public final List<HttpRequest> requests = new List<HttpRequest>();

  /** @description @param statusCode The status every response carries. */
  public CarrierApiMock(Integer statusCode) {
    this.statusCode = statusCode;
  }

  /**
   * @description Registers a mock with `Test.setMock`.
   * @param statusCode The status every response carries.
   * @return The mock.
   */
  public static CarrierApiMock install(Integer statusCode) {
    CarrierApiMock mock = new CarrierApiMock(statusCode);
    Test.setMock(HttpCalloutMock.class, mock);
    return mock;
  }

  /**
   * @description Records the request and books its parcels.
   * @param request The request.
   * @return The response.
   */
  public HttpResponse respond(HttpRequest request) {
    requests.add(request);
    HttpResponse response = new HttpResponse();
    response.setStatusCode(statusCode);
    if (statusCode < 200 || statusCode >= 300) {
      response.setBody('{"error":"unavailable"}');
      return response;
    }
    CarrierGateway.BookingRequest booking = (CarrierGateway.BookingRequest) JSON.deserialize(
      request.getBody(),
      CarrierGateway.BookingRequest.class
    );
    CarrierGateway.BookingResponse body = new CarrierGateway.BookingResponse();
    for (Integer i = 0; i < booking.parcels.size(); i++) {
      CarrierGateway.Booking booked = new CarrierGateway.Booking();
      booked.shipmentId = booking.parcels[i].shipmentId;
      booked.reference = 'CR-' + (i + 1);
      body.bookings.add(booked);
    }
    response.setBody(JSON.serialize(body));
    return response;
  }
}
