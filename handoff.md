# Handoff: apex-core-lib

Last updated: 2026-11-12 · Phase: roadmap step 1 **complete**; 1.1.0 released for repo B (4 sessions, 15 PRs)

## Status

Repo A is **done and public**. `main` is green, coverage is 100%, and every definition-of-done item passes: CI green, 0 High Code Analyzer findings, no `TODO`s, ApexDoc on every public class, README in 7 sections, ADRs 0001–0009, `docs/case-study.md`, and a full-history gitleaks scan with no leaks.

**Released:**

| Version   | Id                   | Tag      | Adds                                                               | Coverage |
| --------- | -------------------- | -------- | ------------------------------------------------------------------ | -------- |
| `1.1.0-1` | `04tak000000u3MbAAI` | `v1.1.0` | `IDml.dmlUpsert`, `IUnitOfWork.registerUpsert` (ADR 0009) — latest | 99%      |
| `1.0.0-1` | `04tak000000u0zpAAA` | `v1.0.0` | First release                                                      | 99%      |

## For consumers (repos B, C and F)

- Install: `sf package install --package 04tak000000u3MbAAI --target-org <alias> --wait 20 --no-prompt` (1.1.0-1).
- Declare the dependency: `"dependencies": [{ "package": "apex-core-lib@1.1.0-1" }]` in `sfdx-project.json`, with `packageAliases` mapping `apex-core-lib@1.1.0-1` to the `04t` Id. CI installs it before the deploy. The scaffold's `org-setup.sh` already installs dependencies.
- B implements A's ports: `ILogger` (`debug`, `info`, `warn`, `error(String, Exception)`, `flush`) and `IAlertSink` (`send(List<Alert>)`). B binds its adapters with `DI_Binding__mdt` rows (Kind `Service`, ADR 0004), so A doesn't change.
- **R1 is resolved:** consumer tests can use the test kit (`Mocks`, `FakeId`, `RecordingLogger`) and `Application.Service.setMock` straight from the installed no-namespace package.
- A change to A's public API means a new A version: a minor version for additions, a major version for breaking changes. Tag `vX.Y.Z` after bumping `versionNumber`. `release.yml` builds a beta, and Chad promotes it through `workflow_dispatch` with `confirm=PROMOTE`.

## Session 4 (2026-11-12): 1.1.0, upsert for repo B

- Probe in `acl-dev`: generic `List<SObject>` upsert keyed on the standard `idLookup` field `Order.OrderReferenceNumber` works in user mode, so tests need no external-Id metadata in the package. `stripInaccessible(UPSERTABLE)` keeps Ids. The platform rejects a non-`idLookup` key (`SObjectException`) and a key from another type (`TypeException`). `Account.Id` is a valid key.
- PR 14 `feat/dml-upsert`: `IDml.dmlUpsert` in all three strategies and `IUnitOfWork.registerUpsert`. Per type, inserts then upserts, so a child can look up an upserted parent; one key per type per Unit of Work; rollback clears only the Ids the commit assigned. ADR 0009, an ADR 0005 amendment, `CHANGELOG.md`, and `release.yml` adding the version's changelog section to the release notes (a tag without one fails before the build). 195 tests, 100% coverage. The `main` run took the reuse path.
- Tagged `v1.1.0` (Chad approved); beta `1.1.0-1` = `04tak000000u3MbAAI`, 99% coverage. Chad promoted it; the release is latest with the changelog notes.
- Code Analyzer caught `EagerlyLoadedDescribeSObjectResult` (High) on the new key check; fixed with `SObjectDescribeOptions.DEFERRED`.
- Not proven: that a hand-written `IDml` / `IUnitOfWork` breaks the upgrade install until it adds the method (no consumer has one). The CHANGELOG says to add the method before upgrading.
- The beta wasn't installed into `apl-dev`, because an org with a beta can't upgrade to the promoted version. B installs `1.1.0-1` in its own thread.

## Session 3 (2026-11-12)

- PR 8 merged; the `main` run took the ADR 0008 reuse path and spent no org.
- Tagged `v1.0.0` (Chad approved). The build passed, and **a package build uses no daily scratch-org signup**; it only consumes one of the 6 daily package version creates.
- R1 probe: a fresh scratch org, the beta installed, and a throwaway consumer test class (kept outside the repo) that passed.
- PR 9: the README install section and the `1.0.0-1` alias. Chad promoted the version.
- PR 10: the promote job now rewrites the release notes, dropping the beta wording. The `v1.0.0` notes were fixed by hand.
- PR 11: CI logs and artifacts no longer name any org. `scripts/redact-org-details.sh` masks the Dev Hub login, scratch-org setup, delete and promote output. The test step sends its JSON stdout to `/dev/null`, strips `hostname`, `orgId`, `userId` and `username` from the summary, and deletes the JUnit file.
- With Chad's approval, every workflow run older than `main` run 43298802736 was deleted, because the older logs showed the Dev Hub org Id. The repo was then made public. Both badges render.
- All merged branches were deleted, leaving only `main` and `badges`. The probe org was deleted. Workspace `CLAUDE.md` and `roadmap.md` mark A done and B next.

## Next

1. **Repo B, PR #4 `feat/persistence`** (its own thread): bump B's dependency to `apex-core-lib@1.1.0-1` (`04tak000000u3MbAAI`), upgrade A in `apl-dev`, and commit through `registerUpsert(rows, Log__c.Log_Key__c)` with `SystemDml`.
2. **Back-port to E** (final pass, step 6): `scripts/changelog-section.sh`, `CHANGELOG.md` and the changelog step in `release.yml`, for repos that publish a package. The earlier 7-item CI back-port is done (E PR #8).
3. A changes again only with a new version: additions are minor versions (ADR 0009) until A has outside consumers.

## Decisions made

| Decision                   | Choice                                                                                                                        | Rejected                                                                         | Record   |
| -------------------------- | ----------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- | -------- |
| FFLIB core                 | Lean in-repo core with FFLIB-compatible names, plus a small Stub API helper (`Mocks`)                                         | Vendored `fflib-apex-common` / `fflib-apex-mocks`, and a hybrid                  | ADR 0002 |
| Coverage badge             | shields.io endpoint badge from `coverage.json` on an orphan `badges` branch (main only)                                       | Codecov (SaaS, breaks free-only), job summary only                               | ADR 0003 |
| CI sharing                 | Per-repo copy from the scaffold                                                                                               | Reusable workflow in a central repo                                              | roadmap  |
| Domain objects             | The package ships none. Core tests use `Account` / `Order`. `Shipment__c` lives in the unpackaged `example/` directory        | Custom objects in the package                                                    | ADR 0002 |
| Inbound-adapter port for C | Deferred to C. Adding an interface later is a minor version bump                                                              | Designing it now, before C exists                                                | handoff  |
| DI resolution              | Service Locator over a registry with `DI_Binding__mdt` overrides                                                              | Code-only registry per consumer, constructor injection only                      | ADR 0004 |
| `ILogger.error` signature  | Keep `error(String, Exception)` and ship `RecordingLogger` as the test double                                                 | `Object cause`, an `ErrorDetail` value type                                      | ADR 0002 |
| Selector and domain lookup | By SObject type via `DI_Binding__mdt.Kind__c` (FFLIB-style `Application.Selector`)                                            | Selectors via the service factory; one metadata type per kind                    | ADR 0004 |
| ENFORCE vs STRIP           | `UserModeDml` (default, throws) and a separate `StripInaccessibleDml` decorator, instead of one class with a mode flag        | `SecureDml` with an ENFORCE/STRIP mode                                           | ADR 0005 |
| Domain construction        | A per-domain `IDomainConstructor` class; records are `final`                                                                  | No-argument constructor plus `initialise(records)`                               | ADR 0006 |
| Trigger kill switch        | `Trigger_Setting__mdt`; no row means active; any inactive row wins                                                            | Hierarchy custom setting                                                         | ADR 0006 |
| Re-entry guard             | Depth 2 per type by default, `setMaxDepth` in code, a skip logs a warning                                                     | `Max_Depth__c` on the setting; run-once flag                                     | ADR 0006 |
| Retry boundary             | Up to 2 immediate retries in the client; async backoff belongs to the caller (C)                                              | Async re-enqueue in the client; no retry                                         | ADR 0007 |
| Retries run out            | Throw `CalloutClientException` with attempts and last response                                                                | Return the last response                                                         | ADR 0007 |
| 429 handling               | Not retried synchronously; `getRetryAfterSeconds()` for the caller                                                            | Retry like a 5xx (original plan)                                                 | ADR 0007 |
| Example booking flow       | After-insert → service enqueues `CarrierBookingJob` (Queueable) → gateway → UoW                                               | Synchronous invocable (a trigger can't call out anyway)                          | handoff  |
| Example credentials        | External Credential (Custom protocol, no secret) + Named Credential (SecuredEndpoint)                                         | Legacy Named Credential (deprecated model)                                       | handoff  |
| Docs vs example            | Separate PRs: example app (PR 6), README + case study (PR 7), release (PR 8)                                                  | One PR as planned                                                                | handoff  |
| Upsert API                 | `dmlUpsert` / `registerUpsert` on the existing interfaces, released as 1.1.0; per type inserts then upserts; one key per type | Extension interfaces; 2.0.0; a B-owned `ILogStore`; all inserts then all upserts | ADR 0009 |
| Release notes              | `CHANGELOG.md` section added to the notes by `release.yml` in both jobs                                                       | Editing the notes by hand after promote (the promote job overwrites them)        | PR 14    |
| `main` CI scratch org      | Reuse the PR's green result when the merge tree is identical; otherwise a fresh org                                           | Pace PRs to the budget; scheduled `main` runs                                    | ADR 0008 |
| CI log hygiene             | Mask org details with a redact filter, scrub the result JSON, drop JUnit                                                      | `--json > /dev/null` everywhere (loses failure diagnostics)                      | PR 11    |
| Old CI runs before public  | Delete every run older than the first clean `main` run                                                                        | Leave them (Dev Hub org Id stays visible)                                        | handoff  |

## Open risks

- **R1 (resolved 2026-11-12):** consumer tests can use the `@IsTest` test kit from the installed no-namespace package. Proven with `1.0.0-1`.

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
