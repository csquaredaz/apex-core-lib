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
- PR 3 `feat(data)` merged (`a24afcf`): `DI_Binding__mdt.Kind__c`, `BindingRegistry` keyed by kind + string, `SelectorFactory` and `SObjectSelector` (user mode), `IDml` with `UserModeDml` (default), `StripInaccessibleDml` (decorator) and `SystemDml` (opt-in), `UnitOfWork` + `UnitOfWorkFactory`. ADR 0005. 94 tests, 100% coverage. `main` CI green, and the badge job has published `coverage.json` to `badges`.
- Merged branches deleted: `chore/foundation-adrs`, `feat/di-container`. `feat/data-layer` is merged but not deleted yet (Chad deletes or asks).

## Resume here (PR 4)

Work on branch `feat/domain-triggers` (already created off `main` at `a24afcf`, holding only this handoff update). Same routine as PRs 2–3: iterate in the `acl-dev` scratch org, open a draft PR (static checks only), then mark it ready once so it uses one CI scratch org.

**PR 4 `feat(triggers)`, from the approved plan:**

| Class                                  | Responsibility                                                                                                                                                 | Pattern                                      |
| -------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------- |
| `IDomain`, `Domain`                    | Holds `Records`; hooks `onApplyDefaults`, `onValidate`, `onBefore*` / `onAfter*`; no SOQL or DML                                                               | Table Module (FFLIB Domain), Template Method |
| `DomainFactory` + `Application.Domain` | `newInstance(List<SObject>)` or `newInstance(SObjectType)`; `Kind__c = Domain` rows key on the SObject API name; `setMock`                                     | Abstract Factory                             |
| `TriggerDispatcher`                    | `run()`: resolve the domain via `DomainFactory`, honour the `Trigger_Setting__mdt` kill switch and `bypass(SObjectType)` / `clearBypass`, re-entry depth guard | Dispatcher                                   |
| `TriggerContext`                       | Wraps `Trigger.*` so dispatcher logic is unit-testable without DML                                                                                             | Adapter                                      |
| `Trigger_Setting__mdt`                 | `SObject_Type__c`, `Is_Active__c` (kill switch; no row means active)                                                                                           |                                              |

Design points to settle while building:

- `Type.newInstance()` needs a public no-argument constructor, so a domain can't take records in its constructor. Use a no-argument constructor plus an initialisation method (for example `withRecords(List<SObject>)`), or a domain constructor interface that `DomainFactory` calls. Present the options to Chad if the trade-off isn't obvious.
- Mirror `SelectorFactory`: check that the bound domain handles the requested SObject type.
- `Trigger_Setting__mdt` can't be inserted in tests; inject rows through a `@TestVisible` constructor, as `BindingRegistry` does.
- No triggers ship in the package. Core tests drive the dispatcher through a fake `TriggerContext`; a real trigger goes in `example/` (PR 6).

**Test plan:** a 200-record fake context calls each hook once; the kill switch off means no hooks; `bypass` is honoured and cleared; re-entry beyond the depth guard is skipped; a missing domain binding throws `ApplicationException`; a domain for the wrong type throws.

## Next (after PR 4)

1. PR 5 `feat(callout)`: `ICalloutClient`, `CalloutClient` (Named Credential only, timeout, correlation-id header, at most 2 synchronous retries on 408/429/5xx/`CalloutException` for idempotent verbs or when `Idempotency-Key` is set), `CalloutRequest` (Builder), `CalloutResponse`, `RetryPolicy`, `CalloutException`. ADR 0006 (sync retry only; real backoff is async and belongs to C).
2. PR 6 `feat(example)` + docs: unpackaged `example/` directory (`Shipment__c`, `ShipmentTrigger`, selector, domain, service, `CarrierGateway`, `TestDataFactory`, `Shipment_Manager` permission set, binding records, `Carrier` Named Credential with no secrets), real-DML integration tests, README in the seven-section order, `docs/case-study.md`.
3. PR 7 `ci(release)`: on tag `v*`, run `sf package version create --code-coverage`. Promotion stays a manual `workflow_dispatch`. Cut v1.0.0 and verify R1 there.

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
