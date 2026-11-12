/**
 * @description Thrown when the application factories can't satisfy a request: a missing or
 * ambiguous binding, an implementation type that doesn't exist, or one that doesn't implement
 * the interface it's bound to. It always signals a configuration defect, never bad user input,
 * so callers shouldn't catch it.
 * @group Public API
 */
public with sharing class ApplicationException extends Exception {
}
