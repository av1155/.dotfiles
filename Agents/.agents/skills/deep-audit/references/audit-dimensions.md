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

If `playwright-cli` is available and the project has a dev server, consider actually loading the page and testing the feature. This is optional and should not block the audit.

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

---

## Dimension 13: Delivery-Context Assumptions

**What to look for:** configuration attached to one request being relied on by code that runs in a different delivery context.

The common shape is a per-route response header. A middleware, proxy or edge function keys a policy on `request.pathname`, and a page depends on the relaxation that policy grants. That holds only when the page is fetched as its own document. In a single-page app, or an App Router app, a route reached by a link, a `router.push` or a server-action `redirect()` renders inside the PREVIOUS document and keeps the previous document's headers. The route-scoped exception silently does not apply, and only a reload makes it work.

The same reasoning covers anything else keyed to how a response was requested: cookies with `SameSite` or `Path` scopes, `Vary` and cache keys, per-route `Permissions-Policy`, `COOP`/`COEP`, frame ancestors, and nonce propagation into dynamically injected scripts.

### Detection strategies

1. Grep the middleware, proxy or server config for anything keyed on a path or route: an allowlist set, a `startsWith`, a switch on `pathname`. Each entry is a claim that the page is always loaded as its own document.
2. For each such route, list the ways a user actually reaches it: a link, a redirect from a server action, a form post, a client router call, a prefetch. Any of those that is not a document load inherits the source document's headers.
3. Verify by loading the route the way a user reaches it, not by typing its URL. Opening the URL directly always produces the permissive response and hides the defect.
4. In the browser, confirm the delivered header on the document that is actually live: `document` response headers, not the route's headers, then check the console for the corresponding violation.
5. For dynamically injected scripts under a nonce-based policy, check that the injection either carries the nonce or is covered by `strict-dynamic`, and that the loader has an error path. A blocked script that is awaited with no `onerror` and no timeout hangs the feature rather than failing it.

### Canonical example (measured 2026-09-17)

A proxy granted `img-src 'self' data:` to exactly two paths, the TOTP enrolment screens, so the QR code could render as a `data:` URI. Sign-up and login reached that screen through a server-action redirect, which is a client-side navigation, so the screen painted inside the `/login` document under `img-src 'self'` and the QR was blocked. Reloading fixed it, which is why three earlier investigations closed as "cannot reproduce": each one opened the URL directly.

### Severity

- FAIL if a feature depends on a route-scoped header and any real entry point into that route is a client-side navigation
- FAIL if a dynamically injected third-party script is awaited with no error path, so a blocked load hangs a user-facing action instead of failing it
- WARN if a route-scoped relaxation exists and the audit cannot enumerate every entry point
- WARN if a cached promise for a failed load is memoized process-wide, so a single failure poisons every later attempt
- PASS if the header is delivered on every document that can render the surface, or the surface does not depend on it

---

## Dimension 14: Reconstruction Fidelity

**What to look for:** code that takes an artifact produced somewhere else and rebuilds it, rather than passing it through.

A vendor's SVG re-drawn as native elements, a wire format re-serialized, a document re-rendered from a parse, a barcode or QR redrawn from its modules, a diff re-applied from a patch. Every one of these has two failure modes and only one of them is visible. Refusing is loud: the surface says it could not do it and offers the fallback. Producing a plausible but wrong artifact is silent, and the user acts on it. A QR that scans to the wrong secret is worse in every way than a QR that does not render.

The generating rule: reproduce what the producer meant, or refuse. Anything a reconstruction does not understand must end the attempt, never be skipped, defaulted or guessed.

### Detection strategies

1. Find the reconstruction boundary: where does data stop being handled as an opaque value and start being interpreted? That is the code under audit.
2. Ask what the code does with input it does not fully understand. Walk the actual grammar of the source format and list what the implementation ignores: an unknown attribute, an unrecognised colour or unit notation, a coordinate that parses as empty, a transform, a nested or escaped context (CDATA, comments, processing instructions, entities). Each one is a candidate.
3. For each, determine whether the output is refused or drawn. Drawn is a FAIL, independent of how unlikely the input is, because the failure is silent and the refusal path already exists.
4. Check the scanning strategy. A regex that picks known shapes out of unknown text cannot tell "inside the document" from "inside a comment" and will accept things no renderer would draw. A closed grammar that rejects anything it has not been taught is the correct shape.
5. Check precedence rules against the real specification, not intuition. Where two mechanisms can set the same property (an attribute and a style declaration, an inline rule and a sheet), reading the wrong one produces a coherent, inverted result.
6. Check the invariants the reconstruction relies on rather than the values. "No two cells overlap", "every row has the same cell size", "the extent on both axes agrees with the declared size" catch classes of corruption that value assertions miss.
7. Obtain the real artifact from the real producer, at the version in production, and run the code against it. A fixture written from the documentation encodes what the format allows, not what the producer emits, and the two differ.

### Canonical example (measured 2026-09-17)

A TOTP enrolment QR was redrawn from the vendor's SVG into native elements. Six separate passes each found another way the parser drew a plausible, wrong code rather than refusing: the `fill` attribute read in place of the `style` declaration that overrides it (a photographic negative of the real code), an unrecognised colour notation (a solid black square), an empty coordinate (every module in one column), a module displaced by a `transform`, a rect read out of a CDATA section, an `<svg>`-shaped string inside a processing instruction taken for the root, and a module painted over by a later rect that the reconstruction drew underneath. Every one of them passed the gates and the reading passes.

### Severity

- FAIL if any unhandled input produces output instead of a refusal
- FAIL if the scan is a regex over the raw text rather than a grammar that closes
- FAIL if the fixtures were authored from the specification and the real producer's output was never captured
- WARN if the reconstruction refuses correctly but the refusal is not observable (no log, no metric, no user-visible fallback)
- PASS if every path that cannot reproduce faithfully refuses, and the refusal is visible to both the user and operations

---

## Dimension 15: Assertions That Cannot Fail

**What to look for:** tests that pass regardless of the code under test.

A green suite is evidence only in proportion to what would turn it red. An assertion nothing can falsify costs the same to run as a real one, reads identically in review, and counts toward coverage, which is what makes it worse than no test.

### Detection strategies

1. For every assertion the diff adds, name the change to the source that would make it fail. If you cannot name one, the assertion is vacuous. Prefer making the change and watching it go red.
2. Treat negative assertions as suspect by default. "The secret never appears in the payload" stops being able to fail the moment the payload carries nothing secret-shaped, and it keeps passing after the code that put it there is deleted. Pin the positive case alongside it: construct a payload that WOULD leak, and assert the code refuses it.
3. Check whether the fixture was captured or invented. A fixture the diff also authored can encode a shape the real producer never emits, and then the code and its test agree on a fiction that production refutes.
4. Check mocks for assertions satisfied by construction. Asserting that a mocked function returns what the mock was configured to return tests the mock.
5. Watch for assertions that hold for the wrong reason: a guard earlier in the function refuses the fixture before the code under test runs, so the test passes while the intended path is never reached. Mutation testing finds these, and a surviving mutant whose fixture is refused by a different guard is the signature.
6. Re-run each new test against the pre-change source where that is cheap. A test that passes on both sides of the diff is documenting, not verifying.

### Severity

- FAIL if an assertion cannot be made to fail by any change to the code it claims to cover
- FAIL if a fixture that stands in for a third party's output was written rather than captured, and the real output was available
- WARN if an assertion passes for a reason other than the one stated, even when the outcome is correct
- PASS if every new assertion has a named, demonstrated failure mode

---

## Dimension 16: Claims the Diff Ships

**What to look for:** factual assertions in text, which no gate reads.

Comments, docblocks, commit messages, PR bodies, issue descriptions and progress files all carry claims about browsers, vendors, protocols, specifications, performance and cause. Lint does not check them, tests do not exercise them, and review tends to read them as context rather than as findings. They then outlive the code they describe and steer whoever touches it next.

### Detection strategies

1. Enumerate the claims. Every sentence in the diff's prose that asserts how something outside the repository behaves is an item.
2. For each, name the observation that would refute it, and check whether anyone made that observation. A claim derived from reasoning, from training data, or from the vendor's documentation alone is a hypothesis and must say so in the text.
3. Prefer a measurement to a citation when the behaviour is drivable. Browser engines, CLI tools and local servers can be driven directly; documentation describes intent and lags implementation in both directions.
4. Check claims about a second implementation especially hard. "Engine A does X and engine B does not" is two claims, and the second one is usually the unmeasured half.
5. Check that the claim's scope matches the evidence. Telemetry attributed to one browser does not establish behaviour in another; a preview environment is not production; one console capture is one sample.

### The causal claim attached to a working fix

This is the case that survives every gate, because the thing it is attached to works.

A fix that resolves the symptom is evidence that something in the change mattered. It is not evidence for which part, and it is not evidence for the mechanism the author had in mind. Once the symptom is gone, the explanation stops being tested by anything: the tests pass, the user confirms the fix, and the story in the comment hardens into a fact that the next change reasons from.

To claim X is what fixed it: reproduce the failure with X absent, or demonstrate the mechanism directly under controlled conditions. If neither is possible, the comment names the correlation and says the mechanism is unestablished.

Measured 2026-09-18: a change fixed Safari sign-in and its comments credited a nonce added to a third-party script tag. Driving the real engine under the production policy showed the engine honours `strict-dynamic` and runs that script with no nonce at all, so the credited half was inert. The same change had also given the script loader an error path, which is what mattered. Two earlier explanations for the same fix had already been falsified, and each had been written into the code as settled.

### Severity

- FAIL if the diff asserts a causal mechanism for a fix and neither the failure-with-the-fix-absent nor the mechanism itself was reproduced
- FAIL if a claim about external behaviour is stated as measured when it was reasoned
- WARN if a claim is correctly hedged but the discriminating experiment is cheap and was not run
- WARN if evidence from one environment, browser or sample is generalized without saying so
- PASS if every external claim carries its measurement, or is marked as a hypothesis in the text itself
