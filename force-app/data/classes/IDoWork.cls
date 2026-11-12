/**
 * @description Custom work a Unit of Work runs inside its commit, after all DML, for example
 * publishing Platform Events with `EventBus.publish`. If it throws, the whole commit rolls back.
 * @group Public API
 */
public interface IDoWork {
  /**
   * @description Performs the work.
   */
  void doWork();
}
