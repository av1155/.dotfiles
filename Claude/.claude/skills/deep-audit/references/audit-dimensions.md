# Audit Dimensions — Detailed Reference

This document expands each audit dimension with detection strategies, examples, and guidance on when a check should produce PASS, FAIL, or WARN.

---

## Dimension 1: Discarded Data

**What to look for:** Any place where an external call is made and the response body (or part of it) is ignored.

### Detection strategies

1. Find every `await` or synchronous call to an HTTP client, database driver, or external service where the return value is not assigned to a variable.
   - Pattern: `await self._get(path)` on its own line with no `result = ` prefix
   - Pattern: `requests.post(url, data=payload)` without capturing the response
   - Pattern: `.execute(query)` without reading the result set

2. Find every response that IS captured but only partially used.
   - Pattern: `response = await client.get(url)` followed by only `response.status_code` checks — the `.json()` body is never read
   - Pattern: `data = response.json()` followed by reading only one or two fields when the response contains ten

3. Find every function with a return value where callers ignore it.
   - Pattern: `validate_input(data)` called without checking the return
   - Pattern: `result = process(item)` where `result` is never referenced after assignment

### Severity

- FAIL if the discarded data contains identity, type, version, or status information that could prevent misconfiguration
- FAIL if the discarded data contains error details that would make debugging easier
- WARN if the discarded data contains supplementary information that could enhance the feature
- PASS if the discarded data is genuinely irrelevant to the current feature's purpose

### The canonical example

```python
# BEFORE (the Houndarr bug)
async def ping(self) -> bool:
    try:
        await self._get(self._SYSTEM_STATUS_PATH)  # response discarded
        return True
    except (httpx.HTTPError, httpx.InvalidURL):
        return False

# AFTER (the fix)
async def ping(self) -> dict[str, Any] | None:
    try:
        return await self._get(self._SYSTEM_STATUS_PATH)
    except (httpx.HTTPError, httpx.InvalidURL):
        return None
```

The response contained `appName` which identifies the application type. Discarding it meant the system could not detect a type mismatch between user configuration and reality.

---

## Dimension 2: Cross-Field Validation

**What to look for:** User inputs or configuration fields that have a logical relationship but are validated independently.

### Detection strategies

1. Find forms, settings pages, or configuration objects with multiple fields.
2. For each pair of fields, ask: "Can a user set Field A to a value that contradicts Field B?"
3. Check whether any validation logic compares fields against each other (not just against their own constraints).

### Common patterns that indicate missing cross-field validation

- A "type" dropdown and a URL/endpoint field (type says X, URL actually hosts Y)
- A "start date" and "end date" (start > end)
- A "min" and "max" value pair (min > max)
- A "protocol" selector and a "port" field (HTTPS with port 80)
- A "region" selector and an "endpoint URL" (region says us-east but URL points to eu-west)
- An "enabled" toggle and required sub-fields (feature enabled but required config missing)

### Severity

- FAIL if the mismatch would cause silent incorrect behavior (wrong commands sent, wrong data processed)
- FAIL if the mismatch would cause a runtime error that's hard to trace back to configuration
- WARN if the mismatch would cause degraded but not incorrect behavior
- PASS if cross-field relationships are properly validated

---

## Dimension 3: Failure Mode Distance

**What to look for:** How many layers of abstraction separate a misconfiguration or error from the symptom the user actually sees.

### Detection strategies

1. For every piece of user configuration, trace the path from when it's saved to when it's actually used at runtime.
2. Count the number of function calls, async boundaries, and system components between the configuration step and the first runtime use.
3. If the distance is > 2 layers, check whether there's a validation step closer to the configuration point.

### Key question

"If this value is wrong, how long will it take the user to find out, and will the error message point them back to the real cause?"

### Severity

- FAIL if a misconfiguration at setup time causes an opaque error hours/days later at runtime with no indication of the root cause
- WARN if the error eventually surfaces but the message doesn't point to the configuration as the cause
- PASS if misconfiguration is caught at configuration time or the error message clearly identifies the root cause

---

## Dimension 4: Happy Path Bias

**What to look for:** Code paths that only work correctly when all inputs are valid, all external services are available, and all operations succeed.

### Detection strategies

1. For every conditional branch (if/else, match/switch, try/catch), check whether the non-happy paths are tested.
2. Identify "implicit success assumptions" — places where the absence of an error is treated as proof that the operation succeeded correctly.
3. Look for missing else clauses, empty catch blocks, and default switch cases that do nothing.

### Common patterns

- `if response.ok:` with no `else:` — what happens when the response is NOT ok?
- `try: ... except SomeError: pass` — error is swallowed
- Testing only with correct inputs — no tests for malformed, empty, null, or boundary values
- "Test Connection" that only checks reachability but not correctness

### Severity

- FAIL if the untested path would cause data loss, corruption, or security issues
- FAIL if the untested path would cause a user-visible error with no recovery option
- WARN if the untested path would cause degraded functionality
- PASS if non-happy paths are tested or gracefully handled

---

## Dimension 5: Boundary Validation Completeness

**What to look for:** Every trust boundary where data crosses from one domain of control to another.

### Trust boundaries to check

- User input entering the backend (forms, API parameters, file uploads)
- Backend sending data to external APIs
- External API responses entering the backend
- Configuration files being loaded at runtime
- Environment variables being read
- Database values being used in logic (they could have been modified externally)
- Inter-service communication in microservices

### For each boundary, verify

1. **Type validation**: Is the data the expected type?
2. **Range validation**: Is the data within acceptable bounds?
3. **Format validation**: Does the data match the expected format/pattern?
4. **Semantic validation**: Does the data make sense in context? (This is the cross-field dimension applied at a boundary)
5. **Relationship validation**: Does this data agree with related data from other sources?

### Severity

- FAIL if a trust boundary accepts data without any validation and the data reaches a sensitive operation
- WARN if validation exists but is incomplete (checks type but not range, checks format but not semantics)
- PASS if validation is comprehensive at the boundary

---

## Dimension 6: Error Handling and Propagation

**What to look for:** How errors are caught, reported, and propagated through the system.

### Detection strategies

1. Find every try/catch, error handler, and error callback.
2. For each: is the error logged? Is it propagated? Is it swallowed?
3. For every external call: what happens on timeout?
4. For every error message the user could see: is it actionable?

### Common anti-patterns

- `except Exception: pass` or `catch(e) {}` — error swallowed entirely
- `logger.error(str(e))` without the stack trace
- Returning a generic "Something went wrong" to the user
- No timeout configured on HTTP clients (will hang indefinitely)
- Catching too broadly (catching `Exception` when only `ValueError` is expected)

### Severity

- FAIL if errors are swallowed and cause silent incorrect behavior
- FAIL if error messages expose sensitive internal details (stack traces, database queries)
- WARN if error messages are not actionable for the user
- PASS if errors are properly caught, logged with context, and reported clearly

---

## Dimension 7: Security Surface

**What to look for:** New attack surface introduced by the changes.

### Checks (scoped to changed code only)

1. **Injection**: SQL, command, template, LDAP — any user input reaching a query or command without parameterization
2. **Authentication/Authorization**: New endpoints without auth checks, privilege escalation through new parameters
3. **SSRF**: User-controlled URLs being fetched server-side without allowlist validation
4. **Secrets**: API keys, tokens, passwords in code, logs, or error messages
5. **IDOR**: Object references (IDs) that aren't scoped to the authenticated user
6. **CORS**: Overly permissive cross-origin policies
7. **Deserialization**: Untrusted data being deserialized without validation

If the `security-guidance` plugin produced findings in Step 2c, incorporate them here. Verify each plugin finding against the actual code. Add any findings the plugin missed.

### Severity

- FAIL for any exploitable vulnerability
- WARN for defense-in-depth gaps that aren't directly exploitable but weaken security posture
- PASS if the security surface is properly defended

---

## Dimension 8: Concurrency and State

**What to look for:** Race conditions, shared mutable state, and async safety issues.

### Detection strategies

1. Find shared mutable state (global variables, class-level state, module-level caches)
2. Check if access to shared state is synchronized (locks, atomics, thread-safe collections)
3. In async code: find `await` points that could interleave with other operations on the same state
4. Check for TOCTOU (time-of-check-time-of-use) patterns

### Severity

- FAIL if a race condition could cause data corruption or security issues
- WARN if a race condition could cause incorrect behavior under load
- PASS if concurrency is handled correctly, or if the code is single-threaded with no shared state
- SKIP if no concurrent or async code is involved in the changes

---

## Dimension 9: Idempotency and Retry Safety

**What to look for:** Operations that would cause problems if executed more than once.

### Detection strategies

1. For every write operation (database INSERT, API POST, file write, message publish): what happens if it runs twice?
2. For every external call that might fail: is it retried? If so, is the retry safe?
3. For every state mutation: can it be rolled back if a subsequent step fails?

### Severity

- FAIL if double execution causes duplicate records, double charges, or data corruption
- WARN if double execution causes wasted resources but no incorrect behavior
- PASS if operations are idempotent or properly guarded against double execution
- SKIP if no write operations are involved in the changes

---

## Dimension 10: Observable Behavior Gaps

**What to look for:** What the user experiences during edge cases, failures, and partial successes.

### Detection strategies

1. For the feature being audited: walk through the user journey step by step
2. At each step, ask: "What does the user see if this step fails?"
3. Check for loading states, progress indicators, error messages, success confirmations
4. Check for partial failure scenarios: step 1 succeeds, step 2 fails — what's the user's state?

If browser automation tools are available (Playwright MCP, Claude-in-Chrome) and the project has a dev server, consider actually loading the page and testing the feature. This is optional and should not block the audit.

### Severity

- FAIL if a failure leaves the user in an inconsistent state with no indication of what happened
- FAIL if a success signal is shown when the operation actually failed (the misleading green checkmark)
- WARN if the user experience during failure is confusing but not incorrect
- PASS if the user is informed of both success and failure with actionable next steps

---

## Dimension 11: Test Coverage Gaps

**What to look for:** Changed source files without corresponding tests, and new code paths without test cases.

### Detection strategies

1. For each changed source file, locate its test file. Common patterns:
   - `src/foo.ts` → `src/foo.test.ts`, `src/__tests__/foo.test.ts`, `tests/foo.test.ts`
   - `src/foo.py` → `tests/test_foo.py`, `src/foo_test.py`, `tests/foo/test_foo.py`
   - `src/foo.go` → `src/foo_test.go`
   - `src/Foo.java` → `src/FooTest.java`, `test/FooTest.java`
   If the project has a non-standard test layout, infer it from existing test files.

2. If no test file exists for a changed source file, FAIL.

3. If a test file exists, read it and check:
   - Does it test the new/changed code? (not just old paths)
   - For every new conditional branch in the source diff, is there a test for both sides?
   - For every new error handling path, is there a test that triggers it?
   - For every new function, is there at least one test?

4. If tests exist but only cover the happy path of the new code, WARN.

### Severity

- FAIL if a changed source file has no corresponding test file at all
- FAIL if a new public function or method has zero tests
- WARN if tests exist but only cover the happy path of the new code
- WARN if a new conditional branch has tests for only one side
- PASS if new code paths are tested including error conditions and edge cases

---

## Dimension 12: Schema and Contract Consistency

**What to look for:** Changes to data shapes, interfaces, schemas, or contracts that aren't reflected in all consumers.

### Detection strategies

1. Identify every changed type definition, interface, schema, or contract:
   - TypeScript: `interface`, `type`, `zod` schema, `tRPC` router input/output
   - Python: dataclass, Pydantic model, TypedDict, SQLAlchemy model
   - Database: migration files, Prisma schema, Supabase types
   - API: OpenAPI spec, GraphQL schema, protobuf definitions
   - Config: environment variable additions, new config keys

2. For each changed definition, find all importers/consumers using Grep.

3. Check whether every consumer has been updated to handle the change:
   - New required fields: are all callers providing them?
   - Removed fields: are all callers no longer referencing them?
   - Type changes: are all callers handling the new type?
   - New enum values: are all switch/match statements updated?

4. If a migration was added, check:
   - Does the migration match the model/schema change?
   - Is there a rollback/down migration?
   - Does the migration handle existing data?

### Severity

- FAIL if a type/schema changed but a consumer still references the old shape (will crash or silently use wrong data)
- FAIL if a migration was needed but not created (schema change without migration)
- WARN if a new required environment variable was added but not documented
- WARN if a migration exists but has no rollback path
- PASS if all consumers are updated consistently
