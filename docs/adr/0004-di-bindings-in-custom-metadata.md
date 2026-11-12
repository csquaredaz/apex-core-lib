# ADR 0004: Resolve dependencies through a Service Locator with Custom Metadata bindings

- **Status:** Accepted
- **Date:** 2026-11-11

## Context

Layers depend on interfaces (`ILogger`, `IOrdersService`), not implementations. Something has to pick the implementation, and:

1. Apex has no constructor-injection container, and `Type.newInstance()` needs a public no-argument constructor.
2. Unit tests must swap in Stub API mocks without touching production wiring.
3. `apex-core-lib` is a package. Consumers can't edit its classes, so they can't add bindings to an `Application` class the way an FFLIB app normally does.
4. `apex-platform-logging` must replace the default `ILogger` adapter without the core depending on it (Dependency Inversion).

## Options

1. **Service Locator over a registry, with `DI_Binding__mdt` overrides** (chosen). `Application.Service.newInstance(ILogger.class)` asks a `BindingRegistry`. An active `DI_Binding__mdt` row wins over the library's code default, and `setMock` wins over both. For: consumers rebind ports with one metadata record and no code change; tests inject mocks through one seam; FFLIB-compatible call sites. Against: it's a Service Locator, so dependencies are hidden inside method bodies rather than shown in constructors; a bad binding fails at runtime, not at compile time.
2. **Code-only registry, where each consumer builds its own `Application` class.** For: compile-time checked bindings, exactly like upstream FFLIB. Against: the package's own code (for example `SecureDml` logging through `ILogger`) can't see a consumer's `Application`, so the library couldn't use the logging port at all.
3. **Manual constructor injection only.** For: explicit dependencies, nothing hidden. Against: every caller wires the whole graph, triggers and Queueables can't pass constructor arguments, and tests need overloaded constructors everywhere.

## Decision

Option 1. Rebinding a port across package boundaries is the requirement that rules out the others, and the hidden-dependency cost is contained by always resolving by interface at the edge of a class.

## Consequences

- **Fail fast, per interface.** `BindingRegistry` rejects a missing binding, two active rows for one interface, an implementation name that doesn't resolve, and an implementation that isn't assignable to the interface (`Type.isAssignableFrom`). One bad row never breaks resolution of an unrelated interface.
- **No SOQL.** Rows come from `DI_Binding__mdt.getAll()`, read once per transaction.
- **Naming.** `Application.Service` breaks PMD's constant-naming rule on purpose, to keep FFLIB-compatible call sites (`Application.Selector`, `Application.UnitOfWork` follow in later PRs). Code Analyzer reports it as Moderate, below the CI threshold.
- `setMock` is public so consumers' tests can use it. Nothing stops production code from calling it, and code review is the control. A `Test.isRunningTest()` guard would be a test branch in production code, which the testing standard forbids.
- Rollback: deactivate the `DI_Binding__mdt` row and the code default applies again.
