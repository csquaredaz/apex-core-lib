/**
 * @description The one line every trigger calls: it builds the domain bound to the trigger's
 * SObject type and calls the `IDomain.handle*` method for the event (Dispatcher). A trigger holds
 * no logic of its own:
 *
 * ```apex
 * trigger ShipmentTrigger on Shipment__c(before insert, before update, before delete,
 *     after insert, after update, after delete, after undelete) {
 *   TriggerDispatcher.run();
 * }
 * ```
 *
 * Before resolving the domain, `run` skips the event when any of these holds, in this order:
 * 1. **Kill switch.** An inactive `Trigger_Setting__mdt` row for the type turns its trigger logic
 *    off without a deploy. No row means active; any inactive row for the type wins.
 * 2. **Bypass.** Code called `bypass(type)` earlier in the transaction, for example a data fix
 *    that must not re-run automation. It lasts until `clearBypass(type)`.
 * 3. **Depth guard.** A domain's own DML re-fires the same type's trigger. Runs nest at most
 *    `DEFAULT_MAX_DEPTH` (2) deep per type, or the depth set with `setMaxDepth`; a deeper run is
 *    skipped and logged as a warning through `ILogger`, so a skip is never silent.
 *
 * The kill switch and depth checks run before the domain is resolved, so switching a type off
 * also stops a broken domain binding from failing its DML.
 *
 * Limits: no SOQL (`getAll()` reads the metadata cache); the settings are read once per transaction.
 * @group Public API
 */
public with sharing class TriggerDispatcher {
  /** @description How deep runs for one SObject type may nest: the outer run plus one re-entry. */
  public static final Integer DEFAULT_MAX_DEPTH = 2;

  private static final Set<SObjectType> BYPASSED_TYPES = new Set<SObjectType>();
  private static final Map<SObjectType, Integer> DEPTH_BY_TYPE = new Map<SObjectType, Integer>();
  private static final Map<SObjectType, Integer> MAX_DEPTH_BY_TYPE = new Map<SObjectType, Integer>();

  /** Test seam: custom metadata can't be inserted in a test, so rows are injected. */
  @TestVisible
  private static List<Trigger_Setting__mdt> settingRows;

  /** Test seam: a factory over injected bindings instead of the org's. */
  @TestVisible
  private static DomainFactory domains = Application.Domain;

  private static Set<String> disabledTypeNames;

  /**
   * @description Dispatches the trigger now running.
   * @throws ApplicationException If called outside a trigger, or the domain binding is invalid.
   */
  public static void run() {
    run(TriggerContext.current());
  }

  /**
   * @description Dispatches the given context; tests call this with a fake `TriggerContext`.
   * @param context The trigger event and records.
   * @throws ApplicationException If the context is null, or the domain binding is missing or invalid.
   */
  public static void run(TriggerContext context) {
    if (context == null) {
      throw new ApplicationException('TriggerDispatcher.run needs a trigger context.');
    }
    SObjectType sObjectType = context.sObjectType;
    if (!isEnabled(sObjectType) || isBypassed(sObjectType)) {
      return;
    }
    Integer depth = depthOf(sObjectType) + 1;
    if (depth > maxDepthOf(sObjectType)) {
      logger()
        .warn(
          'TriggerDispatcher skipped ' +
            context.operation +
            ' on ' +
            sObjectType +
            ': re-entry depth ' +
            depth +
            ' exceeds ' +
            maxDepthOf(sObjectType) +
            '.'
        );
      return;
    }
    IDomain domain = domains.newInstance(context.records(), sObjectType);
    DEPTH_BY_TYPE.put(sObjectType, depth);
    try {
      dispatch(domain, context);
    } finally {
      DEPTH_BY_TYPE.put(sObjectType, depth - 1);
    }
  }

  /**
   * @description Skips trigger logic for a type for the rest of the transaction, or until
   * `clearBypass`. Pair every call with `clearBypass` in a `finally` block.
   * @param sObjectType The type to bypass.
   * @throws ApplicationException If the type is null.
   */
  public static void bypass(SObjectType sObjectType) {
    BYPASSED_TYPES.add(requireType(sObjectType));
  }

  /**
   * @description Ends a bypass. Clearing a type that isn't bypassed does nothing.
   * @param sObjectType The type to run trigger logic for again.
   * @throws ApplicationException If the type is null.
   */
  public static void clearBypass(SObjectType sObjectType) {
    BYPASSED_TYPES.remove(requireType(sObjectType));
  }

  /**
   * @description Whether code has bypassed a type in this transaction.
   * @param sObjectType The type.
   * @return True between `bypass` and `clearBypass`.
   */
  public static Boolean isBypassed(SObjectType sObjectType) {
    return BYPASSED_TYPES.contains(sObjectType);
  }

  /**
   * @description Whether the `Trigger_Setting__mdt` kill switch lets a type's trigger logic run.
   * @param sObjectType The type.
   * @return False if any inactive row names the type; true otherwise, including when no row exists.
   */
  public static Boolean isEnabled(SObjectType sObjectType) {
    return !disabledTypeNames().contains(String.valueOf(sObjectType).toLowerCase());
  }

  /**
   * @description Changes how deep runs for one type may nest, for the rest of the transaction.
   * @param sObjectType The type.
   * @param maxDepth At least 1; 1 means a domain's DML never re-runs its own type's logic.
   * @throws ApplicationException If the type is null or `maxDepth` is below 1.
   */
  public static void setMaxDepth(SObjectType sObjectType, Integer maxDepth) {
    if (maxDepth == null || maxDepth < 1) {
      throw new ApplicationException('Max trigger depth must be at least 1, not ' + maxDepth + '.');
    }
    MAX_DEPTH_BY_TYPE.put(requireType(sObjectType), maxDepth);
  }

  private static void dispatch(IDomain domain, TriggerContext context) {
    switch on context.operation {
      when BEFORE_INSERT {
        domain.handleBeforeInsert();
      }
      when BEFORE_UPDATE {
        domain.handleBeforeUpdate(context.oldMap);
      }
      when BEFORE_DELETE {
        domain.handleBeforeDelete();
      }
      when AFTER_INSERT {
        domain.handleAfterInsert();
      }
      when AFTER_UPDATE {
        domain.handleAfterUpdate(context.oldMap);
      }
      when AFTER_DELETE {
        domain.handleAfterDelete();
      }
      when AFTER_UNDELETE {
        domain.handleAfterUndelete();
      }
    }
  }

  private static Integer depthOf(SObjectType sObjectType) {
    Integer depth = DEPTH_BY_TYPE.get(sObjectType);
    return depth == null ? 0 : depth;
  }

  private static Integer maxDepthOf(SObjectType sObjectType) {
    Integer maxDepth = MAX_DEPTH_BY_TYPE.get(sObjectType);
    return maxDepth == null ? DEFAULT_MAX_DEPTH : maxDepth;
  }

  private static Set<String> disabledTypeNames() {
    if (disabledTypeNames != null) {
      return disabledTypeNames;
    }
    disabledTypeNames = new Set<String>();
    List<Trigger_Setting__mdt> rows = settingRows != null ? settingRows : Trigger_Setting__mdt.getAll().values();
    for (Trigger_Setting__mdt row : rows) {
      if (!row.Is_Active__c && String.isNotBlank(row.SObject_Type__c)) {
        disabledTypeNames.add(row.SObject_Type__c.trim().toLowerCase());
      }
    }
    return disabledTypeNames;
  }

  private static SObjectType requireType(SObjectType sObjectType) {
    if (sObjectType == null) {
      throw new ApplicationException('A trigger bypass or depth setting needs an SObject type.');
    }
    return sObjectType;
  }

  private static ILogger logger() {
    return (ILogger) Application.Service.newInstance(ILogger.class);
  }
}
