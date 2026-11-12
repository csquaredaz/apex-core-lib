# ADR 0003: Publish Apex coverage as a shields.io endpoint badge from a `badges` branch

- **Status:** Accepted
- **Date:** 2026-11-11

## Context

The README should show live Apex coverage next to the CI badge. The constraints:

1. **Free only.** No SaaS accounts, no upload tokens beyond `GITHUB_TOKEN`, and no paid actions.
2. Coverage comes from `sf apex run test --code-coverage` in the scratch-org job, as `orgWideCoverage`.
3. PR runs must stay read-only (`permissions: contents: read`).

## Options

1. **shields.io endpoint badge** (chosen). On a push to `main`, after the scratch-org tests pass, a separate job writes `coverage.json` (the shields.io endpoint schema) to an orphan `badges` branch. The README points shields.io at the raw file. For: no account and no extra secret; the badge reflects the last green `main` run. Against: that one job needs `contents: write`; the raw URL only resolves once the repo is public; there's an extra branch to explain.
2. **Codecov free OSS tier.** For: polished UI and PR comments. Against: a third-party SaaS account and upload token, which breaks the free-only rule.
3. **Job summary and artifact only.** For: no moving parts (this is the scaffold's default). Against: no README badge, so a reader has to open an Actions run to see coverage.

## Decision

Option 1. It's the only option that puts coverage in the README without a third-party account.

## Consequences

- The `coverage-badge` job runs only on `push` to `main`, needs `scratch-org`, and is the only job with `contents: write`. PR runs never get write access.
- The job appends one commit per green `main` run to `badges`. It never force-pushes, so the branch history doubles as a coverage log.
- Colours: 90% or more is green, 75–89% is yellow (the promote floor still passes), and below 75% is red.
- Before a repo has any Apex test class, the scratch-org job skips `RunLocalTests` (which otherwise fails with `INVALID_INPUT: No tests found`) and reports no coverage, so the badge job is skipped instead of publishing 0%. Once tests exist the skip is inert.
- Until the repo is public, the coverage badge shows as an error. That's expected.
- Back-port to the `sf-repo-scaffold` template in `claude-code-salesforce-skills` once this has run green here.
- Rollback: delete the job and the badge line. The `badges` branch can stay or be deleted, since nothing else reads it.
