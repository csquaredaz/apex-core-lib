# Handoff: apex-core-lib

Last updated: 2026-11-11 · Phase: roadmap step 1, session 1

## Done

- GitHub repo `csquaredaz/apex-core-lib` created (private) and `main` pushed. CI secrets set by Chad, and JWT auth proven in CI.
- Unlocked package `apex-core-lib` created on the Dev Hub (`0Ho` alias in `sfdx-project.json`).
- Repository scaffolded from `apex-standards:sf-repo-scaffold`. API 68.0 confirmed against the Dev Hub.
- ADR 0001 (unlocked package, no namespace) moved here from the workspace.
- Plan approved: file tree, class list, test plan and a 7-PR delivery sequence.

## Next

1. Land PR 1 `chore`: ADRs 0002 (lean FFLIB core) and 0003 (coverage badge), the `badges`-branch CI job, and `orderSettings.enableOrders` in the scratch definition.
2. PR 2 `feat(di)`: factories, `BindingRegistry`, `DI_Binding__mdt`, ports with default adapters, and `Mocks` / `FakeId`. Verify risk R1 here.

## Decisions made

| Decision                   | Choice                                                                                                                 | Rejected                                                        | Record   |
| -------------------------- | ---------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------- | -------- |
| FFLIB core                 | Lean in-repo core with FFLIB-compatible names, plus a small Stub API helper (`Mocks`)                                  | Vendored `fflib-apex-common` / `fflib-apex-mocks`, and a hybrid | ADR 0002 |
| Coverage badge             | shields.io endpoint badge from `coverage.json` on an orphan `badges` branch (main only)                                | Codecov (SaaS, breaks free-only), job summary only              | ADR 0003 |
| CI sharing                 | Per-repo copy from the scaffold                                                                                        | Reusable workflow in a central repo                             | roadmap  |
| Domain objects             | The package ships none. Core tests use `Account` / `Order`. `Shipment__c` lives in the unpackaged `example/` directory | Custom objects in the package                                   | ADR 0002 |
| Inbound-adapter port for C | Deferred to C. Adding an interface later is a minor version bump                                                       | Designing it now, before C exists                               | handoff  |

## Open risks

- **R1:** can consumer repos reference `@isTest` classes (`Mocks`) from a no-namespace unlocked package? Fallback: make `Mocks` a normal `public` class with its own tests.
- **R3:** `Order` in a scratch org needs `orderSettings.enableOrders`. Confirm on the first org.

## Notes for the next session

- The old name `csquaredaz/apex-core-lib` redirected to the renamed `legacy-apex-core-lib`. Creating the new repo ended that redirect. Always check a repo name with `gh repo view` before pushing.
- An empty `force-app/` deploys cleanly (no `--source-dir`, so the CLI returns empty). Still unverified: whether `RunLocalTests` with zero tests passes. PR 1 is the first run that tests it.
- Package promotion stays a manual `workflow_dispatch` because promotion is irreversible.
- Iterate as draft PRs (static checks only) and mark each one ready once, so it costs about one scratch org per PR.
- Back-port the `badges`-branch job to E's scaffold template once it's proven here.
