# Handoff: apex-core-lib

Last updated: 2026-11-12 · Phase: roadmap step 1, session 2 (PRs 4–8)

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

## Resume here (PR 8 draft, blocked on the scratch-org budget)

PR 7 merged (`041f99e`). Its `main` scratch-org job **failed only because the Dev Hub hit its daily scratch-org signup limit** (`LIMIT_EXCEEDED`, 0/6 left on 2026-11-12 after seven PR runs). The code is identical to the PR 7 head, which passed. The badge job was skipped, so the badge stays at 100%.

PR 8 `ci(release)` is on branch `ci/release`, as a **draft** (static checks only, no org):

- `.github/workflows/release.yml`:
  - **build** (on tag `v*`): checks that the tag equals `versionNumber` major.minor.patch, runs `sf package version create --code-coverage --installation-key-bypass`, gates on `HasPassedCodeCoverageCheck`, and publishes a GitHub pre-release with the `04t` install command.
  - **promote** (`workflow_dispatch`): takes `version_id`, `tag` and `confirm=PROMOTE`, runs `sf package version promote`, then marks the release as latest. It is manual because promotion is irreversible.
- `sfdx-project.json`: `1.0.0.NEXT` / `ver 1.0`, plus `definitionFile` so the build org has Orders enabled (core tests use `Order`).
- Verified locally: CLI flags and report JSON fields (read from the `@salesforce/packaging` source), the tag-match and `04t` checks, and that the YAML parses. Not verified: an actual version build (no version created yet; 6/6 package creates left).

**CI budget fix (ADR 0008, Chad chose option b):** `ci.yml` has a new `reuse` job. On a push to `main` it reuses the PR's scratch-org result when the merge commit's tree equals the PR head's tree and that head has a green scratch-org run. Otherwise it creates a fresh org, as before. A dry run against the real merges `041f99e` and `26592ca` found the matching green runs and their 100% coverage, so both merges would have cost 0 orgs. The job conditions now use `!cancelled()`. Back-port the job to E's `sf-repo-scaffold` CI template.

**When the budget frees up (rolling 24 h; check with `sf org list limits --target-org devhub`), about 2 orgs are needed:**

1. Mark PR 8 ready (1 org). Chad merges. The `main` run should take the **reuse** path (0 orgs) and also proves the PR 7 tree, so re-running the failed job 43262725125 isn't needed.
2. **Ask Chad before tagging** `v1.0.0`: it creates a package version and a public-facing GitHub release. The release workflow's package build uses a build org, not a scratch-org signup (to confirm on the first run).
3. R1 probe (1 org): a fresh scratch org, install the beta `04t`, deploy a probe test class that uses `Mocks`, `FakeId` and `RecordingLogger`, and run it. If it fails, fall back to plain `public` classes (see R1).
4. Add the install line to the README quick start. Chad promotes through the workflow when ready.

## Next (after v1.0.0)

Repo A's definition of done: CI green, README complete, ADRs written, Code Analyzer clean, no `TODO`s, case study written. Update the workspace `CLAUDE.md` status table and `roadmap.md` (Chad's call), and ask Chad before making the repo public.

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
| Domain construction        | A per-domain `IDomainConstructor` class; records are `final`                                                           | No-argument constructor plus `initialise(records)`              | ADR 0006 |
| Trigger kill switch        | `Trigger_Setting__mdt`; no row means active; any inactive row wins                                                     | Hierarchy custom setting                                        | ADR 0006 |
| Re-entry guard             | Depth 2 per type by default, `setMaxDepth` in code, a skip logs a warning                                              | `Max_Depth__c` on the setting; run-once flag                    | ADR 0006 |
| Retry boundary             | Up to 2 immediate retries in the client; async backoff belongs to the caller (C)                                       | Async re-enqueue in the client; no retry                        | ADR 0007 |
| Retries run out            | Throw `CalloutClientException` with attempts and last response                                                         | Return the last response                                        | ADR 0007 |
| 429 handling               | Not retried synchronously; `getRetryAfterSeconds()` for the caller                                                     | Retry like a 5xx (original plan)                                | ADR 0007 |
| Example booking flow       | After-insert → service enqueues `CarrierBookingJob` (Queueable) → gateway → UoW                                        | Synchronous invocable (a trigger can't call out anyway)         | handoff  |
| Example credentials        | External Credential (Custom protocol, no secret) + Named Credential (SecuredEndpoint)                                  | Legacy Named Credential (deprecated model)                      | handoff  |
| Docs vs example            | Separate PRs: example app (PR 6), README + case study (PR 7), release (PR 8)                                           | One PR as planned                                               | handoff  |
| `main` CI scratch org      | Reuse the PR's green result when the merge tree is identical; otherwise a fresh org                                    | Pace PRs to the budget; scheduled `main` runs                   | ADR 0008 |

## Open risks

- **R1:** can consumer repos reference `@IsTest` classes (`Mocks`, `RecordingLogger`, `FakeId`) from a no-namespace unlocked package? Only testable with a real package version installed in a consumer org, so verify at the first package version (PR 7) or B's first session. Fallback: make them normal `public` classes with their own tests.

## Plan deviations

- The plan had 7 PRs. It now has 8, because docs were split from the example app (Chad).
- 429 is no longer retried synchronously, and the exception is `CalloutClientException` rather than `CalloutException` (ADR 0007).
- The base domain class is `SObjectDomain`, not `Domain` as planned, to avoid shadowing `System.Domain`.
- Each factory lands with its layer (`SelectorFactory` and `UnitOfWorkFactory` in PR 3, `DomainFactory` in PR 4) rather than all of them in PR 2, because each needs the interface it returns.
- `SecureDml` with two modes became `UserModeDml` plus the `StripInaccessibleDml` decorator, so the decorator wraps one thing.

## Notes for the next session

- More Apex traps found in PR 4: `bulk` is a reserved word (a constant named `BULK` fails to parse), Apex allows only one level of inner classes, and inner classes can't declare static members. PR 5 added more: `number` is reserved, `HttpRequest` has no `getTimeout()`, `JSON.deserialize` rejects `Map<String, Object>`, and macOS `sed` has no `\b` (use `perl -pi`).
- PR 6 findings: in a scratch org the admin profile gets no field permissions on newly deployed fields, so user-mode queries run as the default test user fail with "No such column". A plain static SOQL query in a test failed the same way until `WITH SYSTEM_MODE` was added (observed; cause not confirmed). Integration tests therefore query their assertions `WITH SYSTEM_MODE` and do the real work as `runAs` users. Static mocks set before `Test.stopTest` are still in place when queued jobs run.
- After deleting metadata, a plain `sf project deploy start` against `acl-dev` tries to delete it again from source tracking and fails. Deploy with `--source-dir force-app --source-dir example`.
- Code Analyzer on PR 6: 0 High. `QueueableWithoutFinalizer` (Low) is deliberate, and the reason is in `CarrierBookingJob`'s ApexDoc (Finalizer recovery is C's showcase).
- Code Analyzer on PR 5: 0 High. Two accepted Moderate findings: class-total complexity on `CalloutRequest` (one guard per builder input, as with `UnitOfWork`) and the four-parameter `CalloutClientException.failed`.
- Candidate for README section 7 ("Built with Claude Code"): Code Analyzer's `TypeShadowsBuiltInNamespace` caught `Domain` vs `System.Domain` in PR 4, and design review caught `CalloutException` vs `System.CalloutException` before it compiled. Both were renamed, and ADRs 0006/0007 record why.

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
