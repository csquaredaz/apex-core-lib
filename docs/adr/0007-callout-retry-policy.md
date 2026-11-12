# ADR 0007: Retry callouts synchronously, at most twice, and only when it's safe and useful

- **Status:** Accepted
- **Date:** 2026-11-12

## Context

`CalloutClient` is the one way B, C and F reach external systems. Retry is where callout code usually goes wrong:

1. **Apex can't sleep.** A synchronous retry fires immediately, so it can only absorb a blip: a dropped connection, a pod restart behind a load balancer. Real backoff needs an async hop (a Queueable re-enqueue or a scheduled job).
2. **Budgets are per transaction:** 100 callouts and 120 seconds of total callout time. Each retry spends both.
3. **Retrying a non-idempotent request can duplicate a side effect,** for example two shipments booked with the carrier.
4. **Callers must be able to tell "the server answered no" from "we gave up".**

## Options

### Where retry lives

1. **Bounded synchronous retry in the client; async backoff left to the caller** (chosen). The client makes up to 2 immediate retries. When they run out it throws `CalloutClientException` with the attempt count and last response, so an async caller (C's Queueable) can catch it and re-enqueue with a delay. For: the client stays simple and testable, and the async boundary is explicit. Against: a caller that wants backoff has to write it.
2. **Async backoff in the client** (re-enqueue itself). For: one place for all retry logic. Against: the client would need to know the caller's job, its state and its chaining limits, so it would stop being a library.
3. **No retry.** For: the simplest option. Against: every caller hand-rolls the same loop, and some get the idempotency rule wrong.

### What happens when retries run out

1. **Throw `CalloutClientException`** (chosen, Chad's call). A transient failure that persists can't be mistaken for an answer.
2. **Return the last response.** For: a single return path. Against: every caller must check whether the client gave up.

### Whether to retry 429 Too Many Requests

1. **Don't retry 429 synchronously** (chosen, Chad's call; the approved plan said retry). An immediate retry almost always hits the same rate limit and adds load. The 429 comes back as a response, and `getRetryAfterSeconds()` gives an async caller the server's delay.
2. **Retry 429 like a 5xx.** For: it matches the original plan. Against: it usually spends two of the transaction's callouts for nothing.

## Decision

Bounded synchronous retry: up to 2 retries (3 attempts) on a transport error, 408, 500, 502, 503 or 504. Only idempotent requests are retried: GET, HEAD, OPTIONS, PUT, DELETE, or a POST or PATCH with an `Idempotency-Key` header. A 429 isn't retried. When retries run out, the client throws.

## Consequences

- **Outcomes of `send`:** a response the policy won't retry (2xx, 4xx, 429, 501, or a 5xx on a non-idempotent request) is returned. A persistent transient failure throws after the retries. A transport error on a non-idempotent request throws after one attempt, because the request may have reached the server.
- **501 and 505 aren't retried:** "not implemented" and "version not supported" won't change on a retry.
- **The retry cap is enforced:** `RetryPolicy` accepts 0 to 2 retries, and the client also stops when the transaction has no callouts left. The timeout is per attempt (default 10 s, maximum 120 s), so a caller with tight time limits lowers the timeout or uses `new RetryPolicy(0)`.
- **Endpoints are Named Credentials only:** `CalloutRequest` takes the credential's API name and a path that must start with `/` or `?`. A raw URL or a `callout:` string is rejected, so a path can't redirect to another host.
- **Correlation:** every request carries `X-Correlation-Id`, generated with `UUID.randomUUID()` unless the caller passes one on. Retries reuse it, and it appears in every retry warning and in the exception message.
- **Naming:** the exception is `CalloutClientException`, because `CalloutException` would shadow `System.CalloutException`, the platform exception the client catches. It also covers invalid requests, where `getAttempts()` is 0.
- **Deliberately omitted:**
  - **A circuit breaker.** It needs state shared across transactions (DML or Platform Cache) and belongs to the consumer that owns the integration.
  - **Retry jitter.** Without a sleep there is no delay to randomise.
- **Strategy seam:** subclass `RetryPolicy` and pass it to `new CalloutClient(policy)` to change the retryable statuses for one integration. The idempotency rule and the cap live in the base class.
