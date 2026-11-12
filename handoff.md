# Handoff: apex-core-lib

Last updated: 2026-11-12 · Phase: roadmap step 1, session 1

## Done

- GitHub repo `csquaredaz/apex-core-lib` created (private) and `main` pushed. CI secrets set by Chad, and JWT auth proven in CI.
- Unlocked package `apex-core-lib` created on the Dev Hub (`0Ho` alias in `sfdx-project.json`).
- Repository scaffolded from `apex-standards:sf-repo-scaffold`. API 68.0 confirmed against the Dev Hub.
- ADR 0001 (unlocked package, no namespace) moved here from the workspace.
- Plan approved: file tree, class list, test plan and a 7-PR delivery sequence.
- PR 1 merged: ADRs 0002 and 0003, the coverage-badge job, Orders enabled, and CI that skips Apex tests until a test class exists.
- PR 2 `feat(di)` merged: `Application.Service`, `ServiceFactory`, `BindingRegistry`, `DI_Binding__mdt`, the `ILogger` and `IAlertSink` ports with `DebugLogger` / `NoOpAlertSink`, the `Alert` value type, and the test kit `Mocks`, `FakeId`, `RecordingLogger`. ADR 0004. The CI test step reads the real result file and gates on all tests passing and at least 90% coverage. 36 tests, 100% coverage in the dev org.
- PR 3 `feat(data)` (open): `DI_Binding__mdt.Kind__c`, `BindingRegistry` keyed by kind + string, `SelectorFactory` and `SObjectSelector` (user mode), `IDml` with `UserModeDml` (default), `StripInaccessibleDml` (decorator) and `SystemDml` (opt-in), `UnitOfWork` + `UnitOfWorkFactory`. ADR 0005. 94 tests, 100% coverage in the dev org, including restricted-user tests.

## Next

1. Land PR 3.
2. PR 4 `feat(triggers)`: `DomainFactory`, `Domain`, `TriggerDispatcher`, `TriggerContext`, `Trigger_Setting__mdt`.

## Decisions made

| Decision                   | Choice                                                                                                                 | Rejected                                                        | Record   |
| -------------------------- | ---------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------- | -------- |
| FFLIB core                 | Lean in-repo core with FFLIB-compatible names, plus a small Stub API helper (`Mocks`)                                  | Vendored `fflib-apex-common` / `fflib-apex-mocks`, and a hybrid | ADR 0002 |
| Coverage badge             | shields.io endpoint badge from `coverage.json` on an orphan `badges` branch (main only)                                | Codecov (SaaS, breaks free-only), job summary only              | ADR 0003 |
| CI sharing                 | Per-repo copy from the scaffold                                                                                        | Reusable workflow in a central repo                             | roadmap  |
| Domain objects             | The package ships none. Core tests use `Account` / `Order`. `Shipment__c` lives in the unpackaged `example/` directory | Custom objects in the package                                   | ADR 0002 |
| Inbound-adapter port for C | Deferred to C. Adding an interface later is a minor version bump                                                       | Designing it now, before C exists                               | handoff  |
| DI resolution              | Service Locator over a registry with `DI_Binding__mdt` overrides                                                       | Code-only registry per consumer, constructor injection only     | ADR 0004 |
| `ILogger.error` signature  | Keep `error(String, Exception)` and ship `RecordingLogger` as the test double                                          | `Object cause`, an `ErrorDetail` value type                     | ADR 0002 |
| Selector and domain lookup | By SObject type via `DI_Binding__mdt.Kind__c` (FFLIB-style `Application.Selector`)                                     | Selectors via the service factory; one metadata type per kind   | ADR 0004 |
| ENFORCE vs STRIP           | `UserModeDml` (default, throws) and a separate `StripInaccessibleDml` decorator, instead of one class with a mode flag | `SecureDml` with an ENFORCE/STRIP mode                          | ADR 0005 |

## Open risks

- **R1:** can consumer repos reference `@IsTest` classes (`Mocks`, `RecordingLogger`, `FakeId`) from a no-namespace unlocked package? Only testable with a real package version installed in a consumer org, so verify at the first package version (PR 7) or B's first session. Fallback: make them normal `public` classes with their own tests.

## Plan deviations

- Each factory lands with its layer (`SelectorFactory` and `UnitOfWorkFactory` in PR 3, `DomainFactory` in PR 4) rather than all of them in PR 2, because each needs the interface it returns.
- `SecureDml` with two modes became `UserModeDml` plus the `StripInaccessibleDml` decorator, so the decorator wraps one thing.

## Notes for the next session

- Apex reserves `inner`, and constants clash with SObject names case-insensitively (`ORDER` vs `Order`). Apex has no `IllegalStateException`. Minimum Access test users plus a test-created permission set work in a Developer Edition scratch org (no license limit hit).
- Code Analyzer on PR 3: 0 High. `UnitOfWork` has a class-total complexity warning (Moderate) from guarding every registration mistake; the method-level findings were refactored away.
- **Stub API limits (verified in a scratch org):** no inner types, no method that takes the base `Exception` type, and `@IsTest` classes can't be `virtual`. Mock top-level interfaces only.
- Apex is case-insensitive, so a local variable named like a class (`Alert alert`) breaks static references. Prettier formats Apex at 2-space indentation; match it in any scripted edit.
- `sf apex run test --output-dir` writes `test-result-<runId>.json` (run Id in `test-run-id.txt`), not `test-result.json`. The scaffold template's summary step has this bug: back-port the fix to E.
- Code Analyzer: 0 High. 36 Moderate `MethodNamingConventions` findings come from PMD rejecting the skill's `method_condition_result` test names. Fix with a custom PMD ruleset in E's scaffold template, then here.
- CI test logs print the throwaway scratch org's Id and username (human result format). Low risk because the org is deleted, but worth dropping before the repo goes public.
- Local dev scratch org: alias `acl-dev`, 7 days. Local signup needs `SF_SCRATCH_SIGNUP_CONNECTED_APP=PlatformCLI` and `SF_SCRATCH_SIGNUP_CALLBACK_URL=http://localhost:1717/OauthRedirect`, the same as CI.
- The old name `csquaredaz/apex-core-lib` redirected to the renamed `legacy-apex-core-lib`. Creating the new repo ended that redirect. Always check a repo name with `gh repo view` before pushing.
- `RunLocalTests` with zero tests fails (`INVALID_INPUT`), so CI skips the test step until a test class exists. Back-port that and the `badges` job to E's scaffold template.
- Package promotion stays a manual `workflow_dispatch` because promotion is irreversible.
- Iterate as draft PRs (static checks only) and mark each one ready once, so it costs about one scratch org per PR.
