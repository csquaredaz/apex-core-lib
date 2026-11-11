# ADR 0001: Distribute apex-core-lib as an unlocked package with no namespace

- **Status:** Accepted (2026-11-11)
- **Date:** 2026-11-11
- **Deciders:** Chad Countryman

## Context

`apex-core-lib` (A) provides the DI container, FFLIB-style layers, trigger framework, security decorator, callout client and port interfaces. B (`apex-platform-logging`), C (`apex-event-ingestion`) and F (`agentforce-action-pack`) consume it. Each consumer must:

1. deploy to a fresh scratch org in about 3 commands
2. pin a specific version of A, so a change in A can't silently break B, C or F
3. keep its own code clearly separate from library code, so a reviewer reading C isn't reading A by accident
4. run CI inside a Developer Edition Dev Hub's limits (6 scratch orgs and 6 package versions per rolling 24h)

## Options

### 1. Unlocked package, no namespace (recommended)

A builds package versions in CI on release tags. Consumers declare `"dependencies": [{ "package": "apex-core-lib@1.0.0-1" }]` and install the `04t` version ID before deploying.

- **For:** real semantic versioning and pinning. The library/consumer boundary is enforced by the platform, and it's the model Salesforce recommends for modular orgs. Consumers stay small and readable. Upgrades are explicit and auditable in the PR diff.
- **Against:** needs packaging enabled on the Dev Hub. Each version build takes about 5–15 min and counts toward the 6/day package version cap. Promotion needs ≥75% coverage (A targets 90%). Without a namespace every `public` member is reachable, so A's API surface is governed by documentation and an ApexDoc `@group Public API` convention, not by the compiler. Quick start gains an install step, hidden behind `npm run org:setup`.

### 2. Source copy via a pinned script

`scripts/vendor-core-lib.sh <tag>` copies A's `force-app` into `vendor/apex-core-lib/` as a second `packageDirectory`.

- **For:** no packaging infrastructure, the fastest CI, and everything a reviewer needs in one clone.
- **Against:** about 3k lines of A duplicated into B, C and F. Versioning is by convention only and drift is invisible. Reviewers can't easily tell what is library and what is consumer. It looks like the copy-paste reuse these repos argue against.

### 3. Unlocked package with a namespace

- **For:** compiler-enforced encapsulation via `public` vs `global`.
- **Against:** a library built to be extended (Domain and Selector base classes, DI bindings by type name) would need `global` everywhere. Cross-namespace `Type.forName` and Custom Metadata class-name bindings need namespace prefixes, which hurts readability. It also means a namespace to register and link. The encapsulation gain doesn't justify that cost for an open-source library.

**Also rejected:** an org-dependent unlocked package (it exists to skip dependency validation against a target org, which isn't our problem) and git submodules (poor tooling ergonomics, and no Salesforce-level versioning).

## Decision

Option 1: unlocked package, no namespace.

## Consequences

- A's CI adds a release job: on tag `v*`, run `sf package version create --code-coverage`, promote, then publish the `04t` ID in the GitHub release notes and README.
- Consumers' `sfdx-project.json` pins A's version with `packageAliases`. Upgrading A means opening a PR in the consumer.
- A's README documents its public API surface and semantic-versioning policy. Breaking changes bump the major version.
- Rollback: consumers pin the previous `04t`. Package versions are immutable, so rollback is a one-line revert.
- Revisit if the Dev Hub moves to a higher allocation (where cost stops mattering) or if build times make consumer CI unusable (where option 2 for local dev becomes worth it).
