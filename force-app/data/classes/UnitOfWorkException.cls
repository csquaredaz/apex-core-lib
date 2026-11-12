/**
 * @description Thrown when a Unit of Work is used incorrectly: a record registered in a way that
 * would corrupt the commit, a type missing from the commit order, a relationship whose parent has
 * no Id at commit, or a second `commitWork()`. It signals a coding defect, so don't catch it.
 * @group Public API
 */
public with sharing class UnitOfWorkException extends Exception {
}
