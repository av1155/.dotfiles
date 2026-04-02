---
name: deep-audit
description: Exhaustive post-work audit for any codebase. Run after finishing a feature, sprint, bug fix, or refactoring pass to find overlooked edge cases, discarded response data, missing cross-field validations, misleading success signals, untested failure paths, and implicit assumptions. Invoke with /deep-audit or /deep-audit followed by context. Use this skill whenever the user says audit, review my changes, check my work, what did I miss, post-mortem, sanity check, edge cases, or asks to verify completeness of recent code changes.
argument-hint: "[description or --range HEAD~N..HEAD or --files path1 path2]"
disable-model-invocation: true
effort: high
allowed-tools: Read Grep Glob Bash(git *) Bash(find *) Bash(wc *) Bash(head *) Bash(tail *) Bash(cat *) Bash(jq *) Agent
---

# Deep Audit — Exhaustive Post-Work Review

You are performing an exhaustive, multi-dimensional audit of recent code changes. Your goal is to find every overlooked edge case, every piece of discarded data, every missing validation, every misleading success signal, and every implicit assumption in the changed code. You are not a linter. You are not a generic code reviewer. You are hunting for the kinds of bugs that only surface when a real user does something the developer never anticipated.

## Why this exists

A real incident: a `ping()` function called `GET /api/v3/system/status` and received a JSON response containing an `appName` field identifying the remote application. The code checked whether the HTTP request returned 200 but discarded the response body entirely. A user configured a Sonarr URL under a "Radarr" type selector. The connection test passed (Sonarr responds 200 to the same endpoint). The system then sent Radarr-format commands to Sonarr, which returned HTTP 500. Debugging consumed hours across two people. The fix was a single field comparison using data already present in the response that was being thrown away. This skill ensures that class of oversight never recurs.

## Invocation

- `/deep-audit` — audit all changes vs. the default branch (auto-detects main/master/develop)
- `/deep-audit description of what I just built` — same, but focuses the audit on the described area
- `/deep-audit --range HEAD~5..HEAD` — audit a specific commit range
- `/deep-audit --files src/foo.py src/bar.py` — audit specific files only

---

## Execution Flow

### Step 0: Parse arguments, determine scope, set up tracking

```
ARGS = "$ARGUMENTS"
```

If ARGS is empty, diff against the default branch. If ARGS starts with `--range`, extract the range. If ARGS starts with `--files`, use those paths. Otherwise, treat the entire argument string as context that focuses the audit without changing the scope.

Determine the default branch:
```bash
git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main"
```

Get the list of changed files:
```bash
git diff --name-only --diff-filter=ACMR <base>
```

If no files are changed, report that and stop.

**Progress tracking:** If the diff touches more than 15 files, use ToolSearch to load `TaskCreate` and `TaskUpdate`. Create a tracked task named "Deep Audit" so progress is visible during the run. Update it at each major phase transition (Reconnaissance → Build Verification → Plan → Execute → Report). For smaller diffs, skip task tracking and work inline.

---

### Step 1: Reconnaissance (use subagents heavily)

Before building any audit plan, gather full context. Do NOT skip this phase.

#### 1a. Classify the project

Read config files to auto-detect the project's stack. Check for (non-exhaustive — look for whatever exists):
- **Language/runtime**: package.json, pyproject.toml, Cargo.toml, go.mod, build.gradle, pom.xml, Gemfile, mix.exs, composer.json
- **Framework**: next.config.*, nuxt.config.*, vite.config.*, angular.json, svelte.config.*, manage.py, config/routes.rb
- **Package manager**: detect from lockfile — pnpm-lock.yaml, yarn.lock, package-lock.json, Pipfile.lock, poetry.lock, Cargo.lock, go.sum
- **Test framework**: vitest.config.*, jest.config.*, pytest.ini, .rspec, *_test.go files
- **Linter/formatter**: .eslintrc.*, biome.json, .prettierrc, ruff.toml, .rubocop.yml, rustfmt.toml
- **CI**: .github/workflows/, .gitlab-ci.yml, Jenkinsfile, .circleci/
- **Database**: migrations/ directories, prisma/schema.prisma, supabase/ directory, alembic/, knex migrations
- **Project conventions**: CLAUDE.md, README.md, CONTRIBUTING.md

Store this classification — it determines which audit dimensions are relevant and which tools to invoke.

#### 1b. Discover project-specific resources

Scan for resources the audit can leverage. This skill is global and must adapt to whatever project it lands in.

**Project slash commands and skills:**
```bash
ls .claude/commands/ .claude/skills/ 2>/dev/null
```
Read any that look relevant to quality checking (names containing "review", "test", "lint", "check", "verify", "validate", "ci", "qa"). If the project has a quality-gate command (like a `/review` that runs lint+typecheck+test), note it — you will invoke it in Step 2.

**Build and test scripts:** Check the package manager config for available scripts:
- package.json `scripts` field (look for test, lint, typecheck, build, check, validate)
- Makefile targets
- pyproject.toml `[tool.pytest]`, `[tool.ruff]`, scripts
- Cargo.toml — `cargo test`, `cargo clippy`, `cargo build` are always available for Rust

**Issue tracker and PR context:** Determine what's available and use the best source of intent:

1. **Linear:** Check if the Linear MCP is connected AND the project references Linear (search CLAUDE.md, README, or .claude/ configs for "linear" mentions). If so, use Linear MCP to look up the issue linked to the current branch. Linear issues often carry the ground-truth acceptance criteria.

2. **GitHub (PR, issues, reviews):** If the remote is a GitHub repo, pull PR and issue context using whichever method is available, in this preference order:
   - **`gh` CLI** (check `which gh`): fastest and most flexible. Use `gh pr view --json title,body,comments,reviews,url`, `gh pr diff`, `gh issue view <number> --json title,body,comments`, etc. The `gh api` subcommand can hit any GitHub REST or GraphQL endpoint if you need more.
   - **GitHub MCP**: if connected, use its tools for PR/issue lookup, code search, and review comments.
   - **Raw git**: `git log --oneline <base>..HEAD` for commit messages if neither `gh` nor the MCP is available.
   Use whichever is available. If multiple are available, prefer `gh` CLI for speed and flexibility but fall back gracefully. Do not require any specific one.

3. **Neither:** Fall back to `git log` messages for intent context.

The issue/PR context tells you what the code is *supposed* to do, making it far easier to spot where implementation diverges from requirement.

#### 1c. Explore changed files with subagents

For each changed file (or tightly-coupled group), spawn an **Explore** subagent to research:
- What calls this file (callers/importers)
- What this file calls (dependencies/imports)
- What data flows through it (function signatures, return types, response handling)
- Every external interaction: HTTP calls, DB queries, file I/O, message queues, IPC
- For each external interaction: what data is sent, what data is received, what is done with the response, and critically — what is NOT done with the response
- The corresponding test file(s) — do they exist? What do they test?

One subagent per major file or tightly-coupled group. Collect all reports before proceeding.

#### 1d. Read the actual diffs

Don't just know which files changed — read what changed within them:
```bash
git diff <base> -- <file>
```

#### 1e. Library and API verification (when available)

For external libraries, APIs, or frameworks used in the changed code, verify correct usage:

1. **context7 (first choice):** If the context7 MCP is connected, use `resolve-library-id` then `get-library-docs` to fetch current docs for any library or framework the changed code interacts with. Check whether the code uses the API correctly, handles all documented error cases, and isn't ignoring return values or response fields that the docs say are important.

2. **WebSearch + WebFetch (general research):** Use ToolSearch to load WebSearch and WebFetch. Search for known issues, CVEs, deprecation notices, or migration guides related to the specific dependency versions in use. Check whether any external API the code calls has documented constraints the code doesn't enforce.

3. **Firecrawl (JS-heavy fallback):** If WebFetch fails to properly render a page (returns empty content, incomplete HTML, or garbled output from a JavaScript-heavy documentation site), and the Firecrawl plugin is available, use it as a fallback to get properly rendered content. Do not use Firecrawl as a first choice — it's specifically for sites that standard fetching cannot handle.

Skip this entire substep if no web tools are available. The audit continues without it.

---

### Step 2: Build verification

Before spending time on semantic analysis, confirm the code compiles and passes existing quality gates.

#### 2a. Build check

Using the detected package manager and build system from Step 1a, run the build command:
- Node/pnpm/yarn/npm: the `build` script if it exists
- Python: `python -m py_compile` on changed .py files, or the project's build command
- Rust: `cargo check`
- Go: `go build ./...`
- Other: whatever the project's standard build command is

If the build fails, report the failure immediately. Do not proceed with the full audit — the developer needs to fix compilation first. List the errors and stop.

#### 2b. Run existing quality gates

If Step 1b found project-specific quality commands (a `/review` slash command, or individual lint/typecheck/test scripts), invoke them now. Specifically:
- Run the linter on changed files if a linter exists
- Run the type checker if one exists
- Run tests related to changed files if a test runner exists

Capture all output. Failures become automatic FAIL findings in the audit report — you don't need to rediscover what the toolchain already caught. Passing quality gates doesn't mean the code is correct; it means the audit can focus on the things machines don't catch.

If no quality gates are found, note it as a WARN ("No automated quality gates detected in this project") and continue.

#### 2c. Security guidance check

If the `security-guidance` plugin is available (check via ToolSearch), invoke it against the changed files. Capture its output. Any findings become inputs to Dimension 7 (Security Surface) of the audit — you don't need to duplicate its work, but you should verify its findings and add any it missed.

If the plugin is unavailable, Dimension 7 runs entirely from the hand-written checks in the audit dimensions reference.

---

### Step 3: Build the audit plan

Using reconnaissance data and build verification results, construct a detailed plan organized by the ten audit dimensions. Each item must be a concrete, specific check against actual code — never generic advice.

Enter plan mode if not already in it. Present the full plan to the user for review before executing.

**Read `references/audit-dimensions.md`** for the detailed specification of all ten dimensions with examples and detection strategies.

**Read `references/anti-patterns.md`** for the catalog of common oversight patterns to hunt for.

The ten dimensions are:
1. **Discarded Data** — response bodies, return values, and fields that are fetched but unused
2. **Cross-Field Validation** — logical relationships between user inputs that go unchecked
3. **Failure Mode Distance** — how far errors travel from their root cause before surfacing
4. **Happy Path Bias** — code paths that only work when everything goes right
5. **Boundary Validation** — completeness of checks at every trust boundary
6. **Error Handling** — swallowed errors, unactionable messages, missing timeout handling
7. **Security Surface** — injection, auth bypass, SSRF, secrets exposure scoped to changes (incorporate security-guidance plugin output if available)
8. **Concurrency and State** — race conditions, shared mutable state, async safety
9. **Idempotency and Retry Safety** — double-execution risk, missing rollback paths
10. **Observable Behavior Gaps** — what the user sees (or doesn't) during partial failures

**Additional cross-cutting checks:**

11. **Test Coverage Gaps** — for each changed source file:
    - Does a corresponding test file exist? If not, FAIL.
    - Do the tests cover the new/changed code paths? Specifically, do they test non-happy paths, error conditions, and edge cases introduced by the changes?
    - If new conditional branches were added, are there tests for both sides?

12. **Schema and Contract Consistency** — if any of the following changed, verify downstream consumers are updated:
    - TypeScript interfaces/types that other files import
    - Database schemas, migrations, or ORM models
    - API request/response shapes (OpenAPI specs, GraphQL schemas, tRPC routers)
    - Environment variable requirements
    - Configuration file formats
    - If a schema changed but its consumers didn't, FAIL.

For each dimension, generate specific checklist items derived from the actual code. Each item has:
- An ID (e.g., D1-03 for Dimension 1, item 3; T-02 for Test Coverage, item 2; S-01 for Schema Consistency, item 1)
- A concrete description of what to check
- The file(s) and line(s) involved

---

### Step 4: Execute the audit

For each checklist item, determine:

- **PASS**: The code handles this correctly. State the evidence.
- **FAIL**: The code has a concrete deficiency. State exactly what is wrong and provide a fix.
- **WARN**: The code might be fine but deserves human review. State the concern.

Do NOT be lazy. Do NOT skip items. Do NOT produce generic observations. Every finding must cite specific files, line numbers, and code. If a dimension has zero items (e.g., no concurrency in a pure synchronous script), state that explicitly and move on.

**Observable behavior verification (when possible):** If the changes affect a web UI and browser automation is available (Playwright MCP or Claude-in-Chrome), consider spawning a subagent to actually load the affected page, trigger the new feature, and verify what the user sees — instead of only inferring behavior from source code. This is optional and should only be attempted if the project has a working dev server configuration. Do not block the audit on browser verification.

---

### Step 5: Summary report

After all checks complete, produce:

```
## Deep Audit Report

### Scope
- Base: <branch or range>
- Files audited: <count>
- Dimensions evaluated: <count>/12
- Issue/PR context: <Linear issue, GitHub PR, or "none found">
- Build verification: <passed/failed/skipped>
- Quality gates run: <list what ran, or "none detected">

### Results
| Status | Count |
|--------|-------|
| PASS   | N     |
| FAIL   | N     |
| WARN   | N     |
| SKIP   | N     |

### Critical Findings (FAIL)
<each finding with full context, code reference, and recommended fix>

### Warnings (WARN)
<each warning with context and what to look for>

### Passed Checks
<abbreviated list — ID and one-line description only>

### Meta-Observations
<patterns across findings, if any — e.g., "3 of 4 FAILs involve discarded response data"
or "all changed files lack corresponding test files">
```

**After reporting:** If any FAIL was novel (doesn't match an existing anti-pattern in `references/anti-patterns.md`), tell the user: "This finding doesn't match any cataloged anti-pattern. Consider adding it to `~/.claude/skills/deep-audit/references/anti-patterns.md` so future audits hunt for it specifically." Describe the pattern shape so the user can append it.

---

## Rules

1. **Never abbreviate.** Run every dimension against every changed file where it applies.
2. **Never produce generic advice.** "Consider adding error handling" is not a finding. "Line 47 of src/client.py catches `httpx.HTTPError` but swallows the exception with `pass`, losing the error message and status code that the caller needs for retry logic" is a finding.
3. **Always cite code.** Every PASS, FAIL, and WARN must reference a specific file and line range.
4. **Use subagents for heavy research.** Don't try to hold the entire codebase in context. Farm out exploration to Explore subagents and synthesize their reports.
5. **Prioritize findings by user impact.** A FAIL that causes silent data loss ranks higher than a WARN about a missing log message.
6. **Don't audit generated files, lockfiles, or vendored dependencies** unless explicitly requested.
7. **If the diff is very large (100+ files),** focus on non-test source files first, then audit test files for coverage gaps.
8. **Adapt to the project.** Use whatever quality gates, slash commands, test runners, linters, and issue trackers exist in the current project. Never hardcode tool names — discover them dynamically from config files and available resources.
9. **Degrade gracefully.** Every optional tool (context7, WebSearch, Firecrawl, Linear, GitHub, Playwright, security-guidance) enhances the audit when present but must not block it when absent. If a tool is unavailable, note what was skipped and continue.
