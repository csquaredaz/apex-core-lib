# Case study: apex-core-lib

<!--
Reused verbatim on the portfolio site, so keep it self-contained: no relative links, no employer
or client names, and no production metrics. "Informed by production experience at scale" is the
most specific claim allowed.
-->

**Problem.** Salesforce codebases that grow one trigger at a time end up with logic in trigger bodies, queries and DML scattered through services, hand-rolled security checks and ad hoc callout retries. The result breaks at bulk volumes, can't be unit-tested without the database, and fails security review.

**Approach.** A small Apex foundation, distributed as an unlocked package with no namespace, rebuilds the Apex Enterprise Patterns from first principles:

- a Service Locator (`Application`) whose bindings live in Custom Metadata, so consumer packages can rebind ports such as `ILogger` without code changes;
- FFLIB-style Selector, Domain (Table Module with Template Method hooks) and Unit of Work layers, with queries and DML in user mode by default and a Decorator for the strip-inaccessible case;
- a trigger Dispatcher with a metadata kill switch, a per-type bypass and a re-entry depth guard;
- a callout client (Builder, Strategy) that only targets Named Credentials and retries transient failures at most twice, and only for idempotent requests.

An unpackaged shipments example drives every layer end to end, from the trigger through an async carrier booking.

**Trade-offs.**

- **Resolution:** a Service Locator hides dependencies inside method bodies, but it was chosen over compile-time-checked, per-consumer registries because the package must let consumers override its own ports.
- **Retry:** stays synchronous and bounded, because Apex can't sleep and real backoff belongs to an async caller.
- **Rate limits:** a 429 is returned to the caller rather than retried immediately.
- **Construction:** domains use a constructor class per domain rather than an initialise method, so their records stay immutable.

Each decision is recorded as an ADR with the rejected alternatives. The design is informed by production experience at scale.

**Result.**

- 195 Apex tests with 100% coverage, asserting behaviour rather than lines: 200-record bulk cases, negative paths, Stub API mocks for isolation, and real-DML integration tests as least-privilege users that assert governor-limit use (0 SOQL and at most 2 DML statements to save 200 records).
- CI on GitHub Actions: Prettier, Code Analyzer with zero High findings, gitleaks, and a fresh scratch org per ready PR through JWT auth. It deploys, runs every test and gates on coverage, with a free, self-hosted coverage badge. Merges reuse a green PR result when the merged tree is identical, which halves the scratch-org cost on a free Dev Hub.
- Eight ADRs, and every free-only omission documented where a reader would look for it.

**Stack.** Apex · Salesforce DX · GitHub Actions · Claude Code (`apex-standards`)
