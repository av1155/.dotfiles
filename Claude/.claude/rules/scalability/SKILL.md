---
name: scalability
description: Production scalability rules for backend code. Apply when writing or editing database queries, API endpoints, background jobs, caching layers, or server-side code that will run under load. Prevents the scaling cliff (works for 10 users, breaks at 1000) by enforcing N+1 avoidance, cursor pagination, request coalescing, async queues, connection pooling, timeouts, rate limits, and observability standards. Triggers on database, query, API, endpoint, route, handler, controller, service, cache, queue, background job, worker, migration, schema, ORM, performance, scale, or production hardening tasks.
paths:
  - "**/*.sql"
  - "**/*.prisma"
  - "**/api/**"
  - "**/routes/**"
  - "**/handlers/**"
  - "**/controllers/**"
  - "**/services/**"
  - "**/db/**"
  - "**/database/**"
  - "**/migrations/**"
  - "**/repositories/**"
  - "**/models/**"
  - "**/queries/**"
  - "**/cache/**"
  - "**/queue/**"
  - "**/jobs/**"
  - "**/workers/**"
  - "**/middleware/**"
  - "**/prisma/**"
  - "**/drizzle/**"
  - "**/server.{ts,tsx,js,jsx,mjs,py,go,rb,rs}"
---

# Production scalability

Before writing backend code, ask: how does this perform with 100k rows? 1M rows? 1000 concurrent users? AI-generated code optimizes for "works", not "works at scale". This rule catches the scaling cliff.

## Database queries

- No queries inside `for`, `while`, `map`, or `forEach`. Batch with `WHERE id IN (...)` or eager-load relationships. The N+1 query is the most common scaling killer.
- Always specify columns in `SELECT`. Never `SELECT *` in production code.
- Always paginate list endpoints. Prefer cursor pagination (`WHERE id > ?`) over offset; offset scans skipped rows and degrades past ~10k.
- Add an index for every `WHERE` / `ORDER BY` / `JOIN` column. Run `EXPLAIN ANALYZE` against realistic data volumes (1M+ rows) before merging non-trivial queries.
- Set explicit `LIMIT` on every query. Unbounded result sets cause OOM at scale.
- Use the framework's connection pool. Never open a connection per request. Pool size roughly 2x expected concurrent requests.
- Batch writes: one `INSERT INTO ... VALUES (...), (...)` over many single-row inserts.

## Caching

- Cache only data that is expensive AND infrequently mutated (aggregations, feature flags, computed projections).
- Define the invalidation strategy when adding a cache. A cache without explicit invalidation is a bug.
- TTL with jitter: `ttl = base + random(0, base * 0.2)`. Fixed TTLs cause thundering herd at expiry.
- Single-flight / request coalescing for hot keys. Only one request rebuilds; others wait on the result.
- No in-process caches (Map, dict, instance var) for state shared across requests. Use Redis or the database. In-process caches lose data on every deploy and break horizontal scaling.

## Async work

These operations must go to a queue (BullMQ, SQS, Sidekiq, Cloud Tasks, or equivalent), never blocking an HTTP response:

- Email sends
- Image / video / PDF processing
- Reports and exports
- Webhook delivery and third-party API calls (Stripe, SendGrid, S3 uploads larger than a few MB)
- Bulk imports and data migrations
- Anything that can take more than 1 second

Jobs must be idempotent (same job ID run twice produces the same outcome; use unique constraints or `IF NOT EXISTS` checks). Retries use exponential backoff with jitter (1s, 2s, 4s, ..., cap at 1h). Set a per-job timeout.

## API endpoints

- Per-user rate limit (e.g., 100 req/min) and per-IP rate limit (e.g., 1000 req/min) on every public endpoint.
- Read timeout no more than 30s, write timeout no more than 60s. No hung requests.
- Request body size limit (default 10MB; uploads larger than that stream to storage, never buffer in memory).
- Stream large responses (chunked JSON, NDJSON, or pagination). Never load 100k rows into memory before responding.
- Pagination defaults: 50 items per page, hard cap 1000 with explicit opt-in.
- Set timeouts on every outbound HTTP / gRPC / DB call. Default 5-10s for internal, 30s for external.

## State and concurrency

- Services must be stateless. All per-request context comes from the request (JWT claims, session ID, headers).
- Session and user state in Redis or the database. Never in process memory or local disk.
- No background timers or in-memory schedulers for cross-request work. Use a distributed scheduler (cron service, queue with delayed jobs, durable workflow).
- Wrap external calls in circuit breakers when downstream is critical-path; fail fast rather than queue requests behind a dead service.

## Observability (non-negotiable)

Every endpoint and external call must emit:

- Latency p50 / p95 / p99. Mean alone hides the p99 cliff.
- Error rate.
- Throughput (req/s).

Logs must be structured JSON with `request_id`, `trace_id`, `user_id`. Use OpenTelemetry for distributed tracing across services. Add a span around every external call so latency is measurable.

## Pre-launch load test

Before shipping a new endpoint or background job, run a load test (k6 or Locust) against realistic data volumes. Three scenarios catch most cliffs:

1. N+1 detection: drive concurrency from 10 to 100; if p99 latency more than doubles, find the missing batch or index.
2. Cache stampede: warm the cache, then force expiry under sustained load. p99 should not spike more than 50%.
3. Pool saturation: drive twice the connection-pool size in concurrent requests; verify queueing behavior degrades gracefully.

## Self-audit checklist before shipping backend code

- [ ] No query inside a loop. All N-relations batched.
- [ ] Every `SELECT` names its columns.
- [ ] Every list endpoint paginates with cursor.
- [ ] Every new `WHERE` / `ORDER BY` / `JOIN` column has an index.
- [ ] Every external call has a timeout.
- [ ] Every blocking operation (email, image, export, webhook) is queued.
- [ ] Every cache has an invalidation strategy and TTL with jitter.
- [ ] No in-process state shared across requests.
- [ ] Per-user and per-IP rate limits in place.
- [ ] Request body size limit set.
- [ ] Latency p50 / p95 / p99 metrics emitted.
- [ ] Structured logs with `request_id` / `trace_id`.
- [ ] Load tested at realistic data volume.

If any item is unchecked, the code is not production-ready.
