# ADR 0005: Run queries and DML in user mode by default

- **Status:** Accepted
- **Date:** 2026-11-12

## Context

Every selector query and Unit of Work commit in B, C and F goes through this library, so its default security posture becomes theirs. The forces:

1. `with sharing` enforces record access only. Object permissions and field-level security need either manual checks or the platform's user mode.
2. API 68.0 supports `AccessLevel.USER_MODE` on `Database.queryWithBinds` and on `Database.insert/update/delete`, which enforce sharing, object permissions and FLS in one place.
3. Some writes must not be blockable by the running user (audit and log records in `apex-platform-logging`).
4. Some business flows prefer a partial write to a failure, for example a self-service form that may carry fields some profiles can't set.

## Options

1. **User mode by default, with two explicit opt-outs** (chosen). `SObjectSelector` queries and `UserModeDml` (the Unit of Work default) run in `USER_MODE` and fail loudly. `StripInaccessibleDml` is a Decorator that strips inaccessible fields, logs each removal, then delegates. `SystemDml` runs in system mode and is never a default. For: secure unless someone types a different class name, which shows up in review; the platform does the checks, so there's no hand-written describe logic. Against: a missing permission fails the whole statement, which can surprise teams used to system-mode Apex.
2. **System mode plus manual `Schema` describe checks.** For: full control over the error message. Against: easy to forget a field, slow to read, and it duplicates what the platform already does correctly.
3. **`stripInaccessible` everywhere by default.** For: never throws on FLS. Against: silent data loss by default. A field the user meant to set just disappears.

## Decision

Option 1. Secure and loud by default; quiet or privileged only by an explicit, reviewable choice.

## Consequences

- **Selectors:** a query that touches a field or object the user can't read throws `QueryException`. Tests prove it with a Minimum Access user (`SObjectSelectorTest`).
- **DML strategy:** chosen once per Unit of Work: `Application.UnitOfWork.newInstance(order)` for user mode, or `newInstance(order, new StripInaccessibleDml(new UserModeDml()))` for a partial write. `StripInaccessibleDml` copies inserted Ids back onto the caller's records, because `Security.stripInaccessible` returns copies and the Unit of Work needs the Ids to resolve relationships.
- **`SystemDml`** is `without sharing` and must be justified in the caller's ApexDoc. Code review is the control.
- **Deletes** aren't field-level, so `StripInaccessibleDml` passes them straight through. User mode still enforces delete permission.
- **Rollback posture:** behaviour changes only through which `IDml` a caller passes, so reverting a caller to the default is a one-line change.

## Amendment (2026-11-12, 1.1.0): upsert

Upsert follows the same rules ([ADR 0009](0009-upsert-in-a-minor-version.md)). `UserModeDml.dmlUpsert` runs in `USER_MODE`, so the user needs create and edit access. `SystemDml.dmlUpsert` runs in `SYSTEM_MODE`. `StripInaccessibleDml.dmlUpsert` strips with `AccessType.UPSERTABLE`, logs each removal and copies the Ids of created and matched records back. If the match key itself is stripped, the upsert fails rather than silently inserting duplicates.
