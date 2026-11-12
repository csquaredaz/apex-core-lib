# ADR 0008: Reuse a PR's scratch-org result on main when the merged tree is identical

- **Status:** Accepted
- **Date:** 2026-11-12

## Context

The free Developer Edition Dev Hub allows 6 scratch-org signups per rolling 24 hours. CI creates one org when a PR is marked ready and another when the merge lands on `main`. On 2026-11-12 four PRs used the whole budget, and the fifth `main` run failed at signup (`LIMIT_EXCEEDED`) with no code problem. With "Create a merge commit" and an up-to-date PR branch, the `main` run tests exactly the tree the PR run already tested.

## Options

1. **Reuse the PR result when the tree is identical** (chosen). A `reuse` job runs first on a push to `main`, and reuses only when all three hold:
   - `HEAD` is a merge commit;
   - `HEAD^{tree}` equals the PR-head parent's tree;
   - that PR head has a `ci` run whose scratch-org job passed.

   It then downloads the run's `apex-test-results` artifact and gives its coverage to the badge job, and no org is created. Anything else falls through to a fresh scratch-org run. For: halves the cost of a PR, with no loss of evidence, because the bits are identical. Against: one more job to read; it depends on the artifact still being retained (90 days by default).

2. **Pace PRs to the budget.** For: no CI change. Against: about 3 PRs a day, and a failed `main` run looks like a broken build.
3. **Run the `main` scratch-org job on a schedule.** For: a fixed cost. Against: `main` can be red for hours before anyone knows, and the badge lags.

## Decision

Option 1 (Chad's call).

## Consequences

- **Safe by construction.** A `pull_request` run tests the PR head merged into its base. If the final merge tree equals the PR head's tree, the base added nothing, so the tested tree, the PR head and `main` are byte-identical.
- **Fall-throughs:** a squash merge (one parent), a branch behind `main` (trees differ), a draft-only history (the scratch-org job was skipped), or an expired artifact all run a fresh org, as before.
- **Permissions:** only the `reuse` job gets `actions: read`, to list runs and download the artifact. The badge job keeps the only `contents: write`.
- **Job conditions use `!cancelled()`,** not `always()`, so a cancelled run never creates an org.
- **Back-port** this job to the `sf-repo-scaffold` CI template in `claude-code-salesforce-skills`, so B, C and F start with it.
