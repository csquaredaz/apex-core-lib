/**
 * @description A small `System.StubProvider` test double: stub return values or exceptions per
 * method, record every call with its arguments, and verify call counts. Deliberately smaller
 * than `fflib-apex-mocks` (ADR 0002): no argument matchers and no answer callbacks.
 *
 * Methods are keyed by name, case-insensitively, so overloads of one method share a stub and a
 * call log.
 *
 * Stub API limits: it can't stub inner types, or any method that takes the base `Exception`
 * type. Use `RecordingLogger` for `ILogger`.
 *
 * ```apex
 * Mocks sinkMock = new Mocks();
 * Application.Service.setMock(IAlertSink.class, sinkMock.stub(IAlertSink.class));
 * // ... act ...
 * sinkMock.verify('send', 1);
 * List<Alert> sent = (List<Alert>) sinkMock.argumentsOf('send', 0)[0];
 * ```
 * @group Testing
 */
@IsTest
public class Mocks implements System.StubProvider {
  private final Map<String, Object> returnValuesByMethod = new Map<String, Object>();
  private final Map<String, Exception> exceptionsByMethod = new Map<String, Exception>();
  private final Map<String, List<List<Object>>> callsByMethod = new Map<String, List<List<Object>>>();

  /**
   * @description Creates a stub of the given type that routes every call to this mock.
   * @param typeToMock An interface or a virtual or abstract class.
   * @return The stub; cast it to `typeToMock`.
   */
  public Object stub(Type typeToMock) {
    return Test.createStub(typeToMock, this);
  }

  /**
   * @description Makes calls to the method return a value.
   * @param methodName The method name.
   * @param value The value to return.
   * @return This mock, for chaining.
   */
  public Mocks stubReturn(String methodName, Object value) {
    returnValuesByMethod.put(methodName.toLowerCase(), value);
    return this;
  }

  /**
   * @description Makes calls to the method throw an exception.
   * @param methodName The method name.
   * @param error The exception to throw.
   * @return This mock, for chaining.
   */
  public Mocks stubThrow(String methodName, Exception error) {
    exceptionsByMethod.put(methodName.toLowerCase(), error);
    return this;
  }

  /**
   * @description Number of times the method was called.
   * @param methodName The method name.
   * @return The call count; zero if never called.
   */
  public Integer callCount(String methodName) {
    List<List<Object>> calls = callsByMethod.get(methodName.toLowerCase());
    return calls == null ? 0 : calls.size();
  }

  /**
   * @description Arguments of one recorded call.
   * @param methodName The method name.
   * @param callIndex Zero-based call index.
   * @return The arguments passed on that call.
   */
  public List<Object> argumentsOf(String methodName, Integer callIndex) {
    Assert.isTrue(callIndex < callCount(methodName), methodName + ' was not called ' + (callIndex + 1) + ' time(s)');
    return callsByMethod.get(methodName.toLowerCase())[callIndex];
  }

  /**
   * @description Asserts the method was called exactly `times` times.
   * @param methodName The method name.
   * @param times The expected call count.
   */
  public void verify(String methodName, Integer times) {
    Assert.areEqual(times, callCount(methodName), 'Expected ' + methodName + ' to be called ' + times + ' time(s)');
  }

  /**
   * @description `System.StubProvider` callback: records the call, then throws or returns as stubbed.
   * @param stubbedObject The stub.
   * @param stubbedMethodName The called method.
   * @param returnType The method's return type.
   * @param listOfParamTypes Parameter types.
   * @param listOfParamNames Parameter names.
   * @param listOfArgs Argument values.
   * @return The stubbed value, or null.
   */
  public Object handleMethodCall(
    Object stubbedObject,
    String stubbedMethodName,
    Type returnType,
    List<Type> listOfParamTypes,
    List<String> listOfParamNames,
    List<Object> listOfArgs
  ) {
    String key = stubbedMethodName.toLowerCase();
    if (!callsByMethod.containsKey(key)) {
      callsByMethod.put(key, new List<List<Object>>());
    }
    callsByMethod.get(key).add(listOfArgs == null ? new List<Object>() : new List<Object>(listOfArgs));
    if (exceptionsByMethod.containsKey(key)) {
      throw exceptionsByMethod.get(key);
    }
    return returnValuesByMethod.get(key);
  }
}
