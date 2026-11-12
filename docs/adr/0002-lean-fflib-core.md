# ADR 0002: Write a lean, FFLIB-compatible core instead of vendoring fflib

- **Status:** Accepted
- **Date:** 2026-11-11

## Context

`apex-core-lib` provides the Apex Enterprise Patterns layers (application factory, Selector, Domain, Unit of Work) that B, C and F build on. The forces:

1. A reviewer should understand the repo in about 15 minutes, and the code is the evidence, not a dependency list.
2. Package version promotion needs at least 75% coverage of everything in the package, and the repo targets 90%.
3. The `apex-standards` plugin describes the patterns by concept (`Application.Selector.newInstance`, `IUnitOfWork`, `registerWork(IDoWork)`), not by one library's class names.
4. Consumers need a Stub API mocking approach they can reuse in their own tests.

## Options

1. **Lean in-repo core with FFLIB-compatible names** (chosen). For: about 1.5–2.5k lines a reader can follow end to end; it shows the mechanics (commit ordering, factory resolution, user-mode selectors) instead of importing them; package coverage measures only our code; names line up with the plugin's skills, so code written to the skills works here. Against: not drop-in compatible with `fflib-apex-mocks` or upstream `fflib_*` types; we own every bug; no parity with fflib's Query Factory.
2. **Vendor upstream `fflib-apex-common` and `fflib-apex-mocks`** (BSD-3-Clause). For: battle-tested and instantly recognisable, and the mocks ecosystem works unchanged. Against: more than 10k vendored lines swamp the repo and the package coverage; it proves "can install FFLIB", not "can design it"; licence attribution and manual re-vendoring become ongoing chores.
3. **Lean core plus upstream `fflib-apex-mocks` as an unpackaged test dependency.** For: rich mocking (matchers, answer callbacks) without writing a mock framework. Against: B, C and F would each need to vendor the mocks as well; it's still a large blob, and it mixes two idioms in one codebase.

## Decision

Option 1. The repo exists to show the design, and a core a reviewer can read beats a dependency they have to take on trust.

## Consequences

- Mocking uses a small `System.StubProvider` helper (`Mocks`) plus `FakeId`, not `fflib-apex-mocks`. It covers stubbed returns, call recording and `verify(method, times)`, and nothing more until a consumer needs it.
- **Domain objects:** the package ships no custom objects. Core tests use the standard `Account` and `Order` objects (the scratch definition enables Orders). The Orders / Shipments demo, including `Shipment__c`, lives in an unpackaged `example/` directory that deploys to scratch orgs for integration tests and never into the package.
- **Open risk:** it's unverified whether consumers can reference `@isTest` classes such as `Mocks` from a no-namespace unlocked package. If they can't, `Mocks` becomes a normal `public` class with its own tests.
- Revisit if consumers keep re-implementing fflib features (selector field sets, query factory, matchers). At that point vendoring upstream becomes cheaper than growing this core.
