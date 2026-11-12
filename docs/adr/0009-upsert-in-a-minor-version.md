# ADR 0009: Add upsert to IDml and IUnitOfWork in a minor version

- **Status:** Accepted
- **Date:** 2026-11-12

## Context

`apex-platform-logging` persists Platform Event log entries to a custom object. Event subscribers can be redelivered, so the write must be idempotent: an upsert on an external Id (`Request_Id + Sequence`), not an insert. Before 1.1.0, `IDml` and `IUnitOfWork` had no upsert, so every write had to bypass the Unit of Work and its DML strategy (ADR 0005).

The forces:

1. Apex has no default interface methods. Adding a method to a public interface breaks every class that implements it by hand, so the upgrade install fails until the class has the method.
2. The documented way to replace `IDml` or `IUnitOfWork` in tests is a Stub API mock (`Mocks`), and Stub API mocks implement every method automatically. A hand-written implementer is possible but unusual.
3. Only B needs upsert today, and the library has one released version (`1.0.0-1`) with no known outside consumers.
4. A probe in a scratch org (2026-11-12) showed that `Database.upsert` on a generic `List<SObject>` with an external-Id field works in default, user and system mode. `Security.stripInaccessible(AccessType.UPSERTABLE, …)` keeps Ids on the copies it returns. The platform rejects a key field that isn't `idLookup` (`SObjectException`) and a key field from another type (`TypeException`).

## Options

1. **Add the methods to the existing interfaces and release 1.1.0** (chosen). `IDml.dmlUpsert(List<SObject>, SObjectField)` and `IUnitOfWork.registerUpsert(List<SObject>, SObjectField)`. For: one Unit of Work type and one DML strategy type, as before; callers don't cast; upsert gets the same user-mode-by-default posture as every other write. Against: a minor version breaks hand-written implementers, which strict semantic versioning would call a major change.
2. **Extension interfaces (`IUpsertDml`, `IUpsertUnitOfWork`) in 1.1.0.** For: strictly additive, so nothing breaks. Against: every caller must cast or hold two references; `UnitOfWork` must check at run time whether its `IDml` supports upsert; two interfaces for one concept stay forever.
3. **Release 2.0.0.** For: honest semantic versioning. Against: a major version for one method signals a rewrite that didn't happen, and consumers on `1.x` aliases must change their dependency on every repo for no other change.
4. **No change to A; B owns an `ILogStore` that calls `Database.upsert` directly.** For: A stays untouched. Against: B's write bypasses the Unit of Work and the DML strategy, so the security mode is chosen per statement again, which is what ADR 0005 exists to prevent.

## Decision

Option 1. The interfaces are the library's contract, and the expected way to fake them (Stub API) is unaffected. The cost lands only on hand-written implementers, so the release notes and README name it and give the migration step.

## Consequences

- **Migration for hand-written implementers:** add `dmlUpsert` (for `IDml`) or `registerUpsert` (for `IUnitOfWork`) to the class **before** upgrading. An extra public method compiles against 1.0.0, so the upgrade install then succeeds. That the upgrade fails without the method is expected from Apex's rules but was not tested, because no consumer repo has a hand-written implementer.
- **Commit order:** for each type in commit order, its inserts, then its upserts. Then updates in commit order, deletes in reverse, then registered work. Upserts run after inserts and before updates, as planned. Running them per type also lets `registerRelationship` resolve a child's lookup to an **upserted** parent.
- **One key per type per Unit of Work.** A second, different key for the same type throws `UnitOfWorkException`. This keeps the "one statement per type per operation" guarantee. If a real case needs two keys, one statement per (type, key) pair would be an additive change.
- **Fail fast:** `registerUpsert` rejects a key that isn't `idLookup` or doesn't belong to the record's type, with one field describe the first time a type gets its key. `Id` is a valid key.
- **Rollback:** on failure, Ids the commit assigned are cleared from new records and from upserted records that had no Id before the commit. Records that already had an Id keep it.
- **Security:** each strategy upserts in its own mode. `StripInaccessibleDml` strips with `UPSERTABLE` (fields the user can both create and edit) and copies the Ids back. If the key itself is stripped, the upsert fails, which is the right outcome (ADR 0005, amended).
- **Revisit** if A gains outside consumers: from then on, any interface addition is a major version or an extension interface.
