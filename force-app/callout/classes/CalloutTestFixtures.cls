/**
 * @description An `HttpCalloutMock` that plays a scripted sequence of responses and transport
 * errors and records every request it receives, for the callout tests.
 */
@IsTest
public class CalloutTestFixtures {
  /** @description Plays one step per callout; the last step repeats once the script runs out. */
  public class SequenceMock implements HttpCalloutMock {
    private final List<HttpResponse> steps;
    /** @description Requests received, in order. */
    public final List<HttpRequest> requests = new List<HttpRequest>();

    /** @description @param steps Responses in order; a null step throws a transport error. */
    public SequenceMock(List<HttpResponse> steps) {
      this.steps = steps;
    }

    /**
     * @description Records the request and plays the next step.
     * @param request The request.
     * @return The scripted response.
     */
    public HttpResponse respond(HttpRequest request) {
      requests.add(request);
      HttpResponse step = steps[Math.min(requests.size(), steps.size()) - 1];
      if (step == null) {
        throw new System.CalloutException('Read timed out');
      }
      return step;
    }
  }

  /** @description The body shape `status()` writes, for typed JSON reads. */
  public class StatusBody {
    /** @description The status code echoed in the body. */
    public Integer code;
  }

  /**
   * @description Registers a scripted mock with `Test.setMock`.
   * @param steps Responses in order; null means a transport error.
   * @return The mock, for asserting on the requests it received.
   */
  public static SequenceMock script(List<HttpResponse> steps) {
    SequenceMock mock = new SequenceMock(steps);
    Test.setMock(HttpCalloutMock.class, mock);
    return mock;
  }

  /**
   * @description A response with a status and a body.
   * @param statusCode The status code.
   * @return The response.
   */
  public static HttpResponse status(Integer statusCode) {
    HttpResponse response = new HttpResponse();
    response.setStatusCode(statusCode);
    response.setStatus(statusCode == 200 ? 'OK' : 'Status ' + statusCode);
    response.setBody('{"code":' + statusCode + '}');
    return response;
  }
}
