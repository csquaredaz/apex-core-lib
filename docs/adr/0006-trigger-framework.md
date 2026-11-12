# ADR 0006: Dispatch triggers to domains built by constructor classes, with a kill switch and a depth guard

- **Status:** Accepted
- **Date:** 2026-11-12

## Context

Every consumer trigger is one line, `TriggerDispatcher.run()`. The dispatcher builds the domain bound to the trigger's SObject type and calls the right `IDomain.handle*` method. Three questions shaped the design:

1. **Construction.** `DomainFactory` instantiates domains from `DI_Binding__mdt` class names, and `Type.newInstance()` only calls public no-argument constructors. A domain can't receive its records through its constructor directly.
2. **Operations.** Support teams need to switch one object's trigger logic off in production without a deploy. Data fixes need to switch it off from code, for one transaction.
3. **Re-entry.** A domain's own DML re-fires the trigger of its own type. Unbounded, that recursion only ends at a governor limit. A "run once" static flag, the usual fix, silently drops validation on records the domain inserts itself.

## Options

### Construction

1. **A constructor class per domain** (chosen). Each domain ships a small `IDomainConstructor` class (FFLIB's `IConstructable` pattern), and the binding names it, for example `ShipmentsDomain.Constructor`. The domain takes its records in a real constructor and keeps them `final`. For: records are immutable and a domain can't exist without them. Against: four lines of boilerplate per domain, and a binding that names the domain class instead of its constructor fails at runtime (`BindingRegistry` reports it as "is not a IDomainConstructor").
2. **A no-argument constructor plus an `initialise(records)` method.** For: one class per domain, no boilerplate. Against: records are set after construction, so they can't be `final`, and every domain needs a guard against a second `initialise` call.

### Kill switch

1. **`Trigger_Setting__mdt` with `SObject_Type__c` and `Is_Active__c`** (chosen). No row means active, and any inactive row for a type turns it off. `Is_Active__c` is subscriber-controlled, so an admin can flip it in production. For: no deploy, no data, and it's readable from the metadata cache with no SOQL. Against: a deploy can still overwrite the row, so the switch belongs in the runbook.
2. **A hierarchy custom setting.** For: per-user or per-profile bypass. Against: it's data, not metadata, so it isn't source-tracked and has to be set up again in every sandbox.

### Re-entry

1. **A per-type depth guard: depth 2 by default, overridable in code** (chosen). The outer run plus one nested run execute. A deeper run is skipped and logged as a warning through `ILogger`. `TriggerDispatcher.setMaxDepth(type, n)` changes the limit for one transaction. For: bounded recursion, nested inserts still validated, and a skip is visible in the logs. Against: a domain that needs deeper nesting must say so in code.
2. **A `Max_Depth__c` field on `Trigger_Setting__mdt`.** For: admins can tune depth without a deploy. Against: depth is a property of the domain's code, not an operational setting, so tuning it without a code change hides a design problem.
3. **Run once per type per transaction.** For: the simplest option. Against: silently skips validation on nested DML.

## Decision

Constructor classes, the `Trigger_Setting__mdt` kill switch, and a depth guard of 2 that can be overridden in code.

## Consequences

- **Order of checks in `run`:** kill switch, then bypass, then depth, and only then domain resolution. Switching a type off also stops a broken domain binding from failing its DML.
- **`bypass(type)` lasts until `clearBypass(type)`**, so callers pair them in a `finally` block. Bypass is per type, not per user. A per-user bypass belongs in a consumer's domain.
- **Depth is released in a `finally` block,** so a domain exception doesn't leave the type stuck at its old depth for the rest of the transaction.
- **Validation runs in the after phase** (`onValidate`), as in FFLIB, so it sees values set by every before trigger and flow. `onValidate(existingRecords)` calls `onValidate()` by default, so one override covers inserts and updates.
- **Testability:** `TriggerContext` is an Adapter over `Trigger.*`, so every dispatcher path is unit-tested with fake contexts and no DML. The package ships no triggers. `TriggerContext.current()`'s return line runs only inside a real trigger, so the `example/` trigger and its integration tests in PR 6 cover it.
- **Naming:** the base class is `SObjectDomain`, not `Domain`, because `Domain` collides with `System.Domain` (Code Analyzer: `TypeShadowsBuiltInNamespace`, High). It pairs with `SObjectSelector`. The factory field stays `Application.Domain`, in line with FFLIB call sites.
- **Rollback:** deactivate the `Trigger_Setting__mdt` row, or remove the type's `Domain` binding.
