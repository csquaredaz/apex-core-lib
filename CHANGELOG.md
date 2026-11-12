# Changelog

Each `## X.Y.Z` section is added to the GitHub release notes for tag `vX.Y.Z` by `release.yml`. Versions follow [ADR 0009](docs/adr/0009-upsert-in-a-minor-version.md): additions are minor versions, even when they add a method to an interface.

## 1.1.0

### Added

- `IDml.dmlUpsert(List<SObject> records, SObjectField externalIdField)`, implemented by `UserModeDml` (user mode), `SystemDml` (system mode) and `StripInaccessibleDml` (strips with `AccessType.UPSERTABLE`, then copies Ids back). All or none, like the other methods.
- `IUnitOfWork.registerUpsert(List<SObject> records, SObjectField externalIdField)`. For each type in commit order, inserts run, then upserts, so a child can look up an upserted parent. Updates and deletes follow. Use one key field per type per Unit of Work.

### Upgrading from 1.0.0

- **Hand-written implementers of `IDml` or `IUnitOfWork` must add the new method.** Add it to your class before you upgrade; an extra public method compiles against 1.0.0, so the upgrade then installs cleanly.
- Stub API mocks (`Mocks`, `Test.createStub`) are unaffected.
- Nothing else changes: existing calls behave as in 1.0.0.

## 1.0.0

First release: DI container, FFLIB-style layers, trigger framework, user-mode DML strategies and the callout client.
