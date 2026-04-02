# Common Oversight Anti-Patterns

A catalog of recurring patterns where developers overlook simple things that cause disproportionate debugging pain. Each pattern describes the shape of the oversight, how to detect it in code, and what the fix looks like.

When running a deep audit, actively hunt for each of these patterns in the changed code.

> **This is a living document.** When a deep audit discovers a novel FAIL that doesn't match any existing pattern, add it here. Use the next available AP number, follow the existing format (Shape, Detection, Example, Fix), and describe the pattern generally enough that it applies across projects and tech stacks. The more patterns in this catalog, the more effective every future audit becomes.

---

## AP-01: The Discarded Identity

**Shape:** An external system tells you what it is in every response, but you only check whether it responded.

**Detection:** Find connection-test, health-check, or ping functions that call an endpoint returning rich JSON but only check the HTTP status code.

**Example:** `ping()` calls `GET /system/status`, gets back `{"appName": "Sonarr", "version": "4.0.17"}`, checks for HTTP 200, returns `True`. Never reads `appName`. User configures a Sonarr URL as "Radarr." Connection test passes. Wrong commands are sent at runtime.

**Fix:** Read the identity/type field from the response and compare it to what the user configured.

---

## AP-02: The Boolean Bottleneck

**Shape:** A function that could return rich information returns only `True`/`False`, discarding context that callers need.

**Detection:** Find functions that return `bool` but internally have access to more information (error details, response data, partial results). Check if callers would benefit from the richer data.

**Example:** `validate(data) -> bool` returns `False` on failure but doesn't say which field failed or why. The caller shows "Validation failed" with no guidance.

**Fix:** Return a result object or raise a descriptive exception. At minimum, return a tuple of `(success, reason)`.

---

## AP-03: The Distant Failure

**Shape:** A misconfiguration at setup time causes an opaque error at runtime, with multiple layers of abstraction between cause and symptom.

**Detection:** Trace each configuration value from where it's entered to where it's first used at runtime. Count the layers between them. If > 2, check whether there's a closer validation point.

**Example:** User enters a wrong URL in settings. Settings are saved to the database. Hours later, a background job reads the URL from the database, makes an HTTP call, gets a 500, logs a generic error. User sees "Search failed" with no connection to the misconfigured URL.

**Fix:** Validate as close to the input as possible. The connection test should verify not just reachability but correctness.

---

## AP-04: The Green Lie

**Shape:** A success indicator (green checkmark, "success" toast, 201 Created) is displayed when the operation didn't actually achieve what the user intended.

**Detection:** For every success signal in the UI, ask: "Under what conditions would this signal be shown even though the underlying operation didn't do what the user expected?"

**Example:** "Connection successful" appears after pinging a URL, but the URL hosts a different application type than what the user selected. The connection succeeded at the HTTP level but the configuration is wrong.

**Fix:** Make success signals verify the semantic correctness of the operation, not just its technical completion.

---

## AP-05: The Swallowed Exception

**Shape:** An error is caught and silently discarded, hiding a bug that would otherwise be immediately visible.

**Detection:** Find `except: pass`, `except Exception: pass`, `catch(e) {}`, `catch(_) => ()`, or any error handler that doesn't log, propagate, or act on the error.

**Example:** A database migration fails silently because the error is caught with a bare `except: pass`. The table is never created. Queries fail later with "table not found."

**Fix:** At minimum, log the error. Ideally, propagate it or handle it explicitly.

---

## AP-06: The Isolated Validator

**Shape:** Each input field is validated individually, but the combination of valid-looking fields creates an invalid state.

**Detection:** Find validation logic for multi-field forms or configuration objects. Check whether any validation crosses field boundaries.

**Example:** A form has "protocol" (HTTP/HTTPS) and "port" (1-65535) fields. Each is individually validated. But HTTPS on port 80 is almost certainly wrong, and HTTP on port 443 is suspicious. No cross-field check exists.

**Fix:** Add relationship validation that checks field combinations, not just individual field values.

---

## AP-07: The Assumed Homogeneity

**Shape:** Code treats all instances of a category identically when they have meaningful differences.

**Detection:** Find places where multiple similar-but-different systems are handled by the same code path. Check whether the differences between them can cause incorrect behavior.

**Example:** All five *arr applications share the same API version prefix (`/api/v3/`), so a generic HTTP client works for connection testing. But they accept different command names (`MoviesSearch` vs `EpisodeSearch`). The shared connection code masks the difference that matters at command-dispatch time.

**Fix:** Explicitly model the differences. Even if the connection code is shared, type-specific behavior should be dispatched correctly.

---

## AP-08: The Test-Time Tunnel Vision

**Shape:** Tests only exercise the scenario the developer had in mind, never the scenarios a confused or careless user would create.

**Detection:** For each test, ask: "Does this test only pass because the test data is perfectly formed?" Look for tests that use only valid inputs, correct configurations, and cooperative external systems.

**Example:** Connection test is tested with matching type/URL pairs. Nobody tests mismatched pairs because "why would someone do that?" A real user does it immediately.

**Fix:** Add negative test cases and misconfiguration test cases. For every configuration form, test at least one case where fields contradict each other.

---

## AP-09: The Ecosystem Blindspot

**Shape:** Similar tools in the same ecosystem share enough surface area that the wrong one can pass for the right one at the protocol level.

**Detection:** When the system integrates with a family of similar tools (microservices with shared APIs, plugins with shared interfaces, applications with shared protocols), check whether the system can distinguish between members of the family.

**Example:** Sonarr and Radarr both respond to `/api/v3/system/status` with 200 OK and valid JSON. A generic health check passes for either. Only the `appName` field in the response body distinguishes them.

**Fix:** When integrating with ecosystems of similar tools, always verify identity, not just reachability.

---

## AP-10: The Optimistic Serialization

**Shape:** Data from an external source is deserialized and used without validating its structure or values.

**Detection:** Find every place where JSON, XML, YAML, or other structured data is parsed from an external source. Check whether the parsed data is validated before use.

**Example:** `data = response.json()` followed by `name = data["name"]` with no check that `data` contains a "name" key, that it's a string, or that it's non-empty. If the API changes or returns an error in JSON format, this crashes or produces wrong results.

**Fix:** Validate the structure and types of deserialized data before using it. Use schema validation, type checking, or at minimum defensive `.get()` with defaults.

---

## AP-11: The Phantom Default

**Shape:** A missing or null value silently falls back to a default that changes the behavior in non-obvious ways.

**Detection:** Find every `.get(key, default)`, `?? fallback`, `|| default`, or `getOrDefault()` call. For each, ask: "If the default is used, does the system behave correctly, or does it silently do the wrong thing?"

**Example:** `timeout = config.get("timeout", 0)` — if timeout is missing from config, it's set to 0, which means "no timeout," which means the HTTP client will hang indefinitely on a non-responsive server.

**Fix:** Make defaults explicit and safe. If a missing value could cause problems, fail loudly instead of defaulting silently.

---

## AP-12: The One-Way Door

**Shape:** An operation that's easy to do but hard or impossible to undo, with no confirmation or guardrail.

**Detection:** Find delete operations, migrations, external API calls with side effects, or state changes that can't be reversed. Check whether there's a confirmation step or undo mechanism.

**Example:** A "Reset All Settings" button that clears the database without confirmation and without backup. One click destroys hours of configuration.

**Fix:** Add confirmation dialogs for destructive operations. Create backups before irreversible changes. Implement soft-delete where possible.

---

## Adding new patterns

When a deep audit discovers a FAIL that doesn't fit any of the above, add it here using this template:

```markdown
## AP-NN: <Memorable Name>

**Shape:** <One sentence describing the abstract pattern>

**Detection:** <How to find this in code — what to grep for, what structure to look for>

**Example:** <A concrete instance of this pattern causing a real problem>

**Fix:** <What the correct approach looks like>
```

Good pattern names are metaphorical and memorable. They should evoke the shape of the problem so a developer who's seen the name once can recall what it means months later.
