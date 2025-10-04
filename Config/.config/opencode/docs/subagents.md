# Section A — Agent Catalog

| name                   | purpose                                                                                   | inputs                                           | outputs / artifacts                      | tools enabled                                    | default temp | model suggestion                   | typical triggers                                              | stop criteria                                                                         | handoff targets                                               |
| ---------------------- | ----------------------------------------------------------------------------------------- | ------------------------------------------------ | ---------------------------------------- | ------------------------------------------------ | -----------: | ---------------------------------- | ------------------------------------------------------------- | ------------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| **router**             | Supervisor-style router that selects/loops through subagents and enforces stop conditions | task summary, repo context, last STATUS lines    | routing decision, next agent + rationale | `read`, `grep`, `glob`, `webfetch`               |          0.1 | anthropic/claude-haiku-4-20250514  | “route”, “what next?”, Build/Plan kickoff, ambiguous requests | emits STATUS and either selects next agent or `ok:true` with `next:null`; max 3 loops | all subagents                                                 |
| **research**           | Fetches external info/specs, extracts facts and citations                                 | query, URLs                                      | notes.md, citations.json                 | `webfetch`, `write`, `read`, `grep`, `glob`      |          0.2 | openai/gpt-5-mini                  | “research”, “compare libs”, RFC/issue link present            | STATUS `ok:true` with >=3 vetted sources or `fail` after 2 dead ends                  | router → reviewer/docs; reviewer → refactorer if spec impacts |
| **code-reviewer**      | Static review for quality, correctness, maintainability                                   | diffs, files, PR description                     | review.md with findings                  | `read`, `grep`, `glob`                           |          0.1 | anthropic/claude-sonnet-4-20250514 | “review”, PR/commit opened                                    | STATUS `ok:true` when findings emitted and severity tagged                            | refactorer, security-auditor, linter, docs-writer             |
| **security-auditor**   | Security audit (authZ/N, secrets, deps, config)                                           | files, lockfiles, Dockerfiles                    | security.md with issues                  | `read`, `grep`, `glob`                           |          0.0 | anthropic/claude-sonnet-4-20250514 | “security”, secret/permission changes, new endpoints          | STATUS `ok:true` with issues list or `warn` if incomplete scope                       | refactorer, dependency-updater                                |
| **linter**             | Runs/auto-fixes format & lint rules                                                       | language/tooling (eslint, prettier, ruff, gofmt) | formatted diffs, lint report             | `bash`, `read`, `write`, `patch`, `glob`, `grep` |          0.1 | openai/gpt-5-mini                  | “lint”, formatting noise, CI lint failures                    | STATUS `ok:true` when clean or `fail` with counts; limit 2 fix passes                 | refactorer, test-runner                                       |
| **refactorer**         | Applies safe code changes per review/spec                                                 | change plan, constraints                         | edited files, patches                    | `edit`, `write`, `patch`, `read`, `grep`, `glob` |         0.15 | openai/gpt-5                       | “apply”, “implement”, small/medium change sets                | STATUS `ok:true` when patch applies & tests compile; cap 3 edit batches               | linter → test-runner → reviewer                               |
| **test-runner**        | Executes tests and summarizes failures                                                    | test command, env info                           | test logs, junit summary                 | `bash`, `read`, `grep`                           |          0.1 | openai/gpt-5-mini                  | “run tests”, CI red, failing unit added                       | STATUS `ok:true` when all pass; else `fail` with suite stats                          | debugger, refactorer                                          |
| **debugger**           | Deduces root cause from stack traces/logs; proposes minimal fix                           | failing logs, stack traces                       | hypothesis.md, minimal patch suggestion  | `read`, `grep`, `glob`, `webfetch`               |          0.1 | anthropic/claude-haiku-4-20250514  | “why failing?”, exceptions present                            | STATUS with ranked hypotheses; stop when confidence ≥0.8 or after 2 cycles            | refactorer, test-runner                                       |
| **docs-writer**        | Generates/updates docs, changelogs, ADRs                                                  | code/comments, review notes                      | README/ADR/CHANGELOG patches             | `read`, `write`, `edit`, `grep`, `glob`          |          0.4 | openai/gpt-5                       | “document”, new feature flags, public APIs changed            | STATUS `ok:true` when doc sections updated; stop after 1 pass                         | reviewer                                                      |
| **dependency-updater** | Updates library versions safely; runs security & compat checks                            | lockfiles, manifest, advisories                  | updated manifests, upgrade report        | `bash`, `read`, `write`, `patch`, `grep`, `glob` |         0.15 | openai/gpt-5-mini                  | “bump deps”, CVE alerts                                       | STATUS `ok:true` when build+tests green; `warn` if pinned conflicts                   | test-runner → reviewer → security-auditor                     |

_Conforms to OpenCode’s Primary vs Subagents model, per-agent tools, and permission semantics with `allow/ask/deny`. Tools list and permission behavior are defined in the OpenCode docs. ([GitHub][1])_

---

# Section B — Handoff Matrix

**Legend:** ✓ allowed (rule), — not routed.

| from \ to      |                          router |                        research |                                     reviewer |                          security |                linter |                                      refactorer |                       tests |             debugger |                        docs |                         deps |
| -------------- | ------------------------------: | ------------------------------: | -------------------------------------------: | --------------------------------: | --------------------: | ----------------------------------------------: | --------------------------: | -------------------: | --------------------------: | ---------------------------: |
| **router**     |                               — |   ✓ (when external info needed) |                             ✓ (on code/diff) |   ✓ (auth/secrets/config touched) |     ✓ (format errors) |                            ✓ (explicit “apply”) |         ✓ (pre-merge tests) | ✓ (on failing tests) | ✓ (docs request/API change) | ✓ (lockfile/manifest change) |
| **research**   | ✓ (no sources found → re-route) |                               — |                 ✓ (send findings for impact) |           ✓ (security advisories) |                     — |                                               — |                           — |                    — |         ✓ (docs references) |               ✓ (advisories) |
| **reviewer**   |               ✓ (needs routing) |                ✓ (missing spec) |                                            — |    ✓ (if security issues present) | ✓ (style issues only) | ✓ (if review suggests concrete change ≤100 LOC) |       ✓ (if tests required) |                    — |            ✓ (if docs gaps) |                            — |
| **security**   |                               ✓ |             ✓ (advisory lookup) | ✓ (back to reviewer for non-security issues) |                                 — |                     — |          ✓ (if fixes are mechanical & low risk) | ✓ (to validate mitigations) |                    — |          ✓ (security notes) |        ✓ (if vulnerable dep) |
| **linter**     |                               ✓ |                               — |                ✓ (if semantic issues remain) |                                 — |                     — |               ✓ (if only rename/format touches) |        ✓ (run sanity tests) |                    — |                           — |                            — |
| **refactorer** |                               ✓ |                               — |           ✓ (request re-review after change) | ✓ (if change affects auth/crypto) |       ✓ (post-change) |                                               — |                ✓ (validate) |       ✓ (if failing) |             ✓ (update docs) |                            — |
| **tests**      |                               ✓ |                               — |                       ✓ (if flaky but green) |                                 — |                     — |                    ✓ (apply tiny fixes <50 LOC) |                           — |       ✓ (if failing) |                           — |                            — |
| **debugger**   |                               ✓ | ✓ (read external issue threads) |                      ✓ (confirm minimal fix) |                                 — |                     — |                           ✓ (apply minimal fix) |                  ✓ (re-run) |                    — |                           — |                            — |
| **docs**       |                               ✓ |                               — |                         ✓ (final doc review) |                                 — |                     — |                                               — |                           — |                    — |                           — |                            — |
| **deps**       |                               ✓ |                 ✓ (CVE details) |                     ✓ (review compatibility) |                 ✓ (validate risk) |                     — |             ✓ (patch code for breaking changes) |          ✓ (validate build) |                    — |               ✓ (changelog) |                            — |

**Routing rules, examples:**

- _Reviewer → Refactorer_ if **change size ≤ 100 LOC** and tests exist; else _Reviewer → Plan (primary)_ for larger tasks.
- _Tests → Refactorer_ if a **single-file fix ≤ 50 LOC** with clear failure; else _Tests → Debugger_.
- _Security → Dependency-updater_ when issue is **vulnerable dependency**; return to _Security_ after update for validation.
- _Refactorer → Linter → Tests → Reviewer_ is the default “apply” loop, max **3 cycles** enforced by _router_.
  (Primary/subagent invocation and routing are supported; subagents can be @mentioned.) ([GitHub][1])

---

# Section C — Guardrails & Permissions

- **Global defaults (mergeable per agent):**
  - `edit`: **ask**; `bash`: **ask**; `webfetch`: **ask**. This aligns with Plan’s restrictive defaults and OpenCode’s permission model. ([GitHub][1])
  - Granular bash rules override defaults; patterns allowed (e.g., `"git push": "ask"`, `"terraform *": "deny"`). ([GitHub][1])
  - **Deny hides tools** (e.g., `edit: deny` hides `write`/`patch`); **ask** prompts; **allow** runs. ([GitHub][1])

- **router:** tools `read`, `grep`, `glob`, `webfetch`; permissions: `edit: deny`, `bash: deny`, `webfetch: allow`.
- **research:** tools `webfetch`, `write`, `read`, `grep`, `glob`; permissions: `webfetch: allow`, `edit: ask` (for notes), `bash: deny`.
- **code-reviewer & security-auditor:** read-only — tools `read`, `grep`, `glob`; permissions: `edit: deny`, `bash: deny`, `webfetch: allow`.
- **linter:** tools `bash`, `read`, `write`, `patch`; permissions: `bash: { "*": "allow" }`, `edit: allow`, risky ops → `git push: ask`, `terraform *: deny`.
- **refactorer:** tools `edit`, `write`, `patch`, `read`; permissions: `edit: allow`, `bash: ask` (only local tooling), `webfetch: deny`.
- **test-runner:** tools `bash`, `read`; permissions: `bash: { "*": "allow", "git push": "ask", "terraform *": "deny" }`.
- **debugger:** tools `read`, `grep`, `glob`, `webfetch`; permissions: `webfetch: allow`, `edit: ask` (for minimal patch suggestion only), `bash: deny`.
- **docs-writer:** tools `read`, `write`, `edit`; permissions: `edit: allow`, `bash: deny`, `webfetch: ask` (for references).
- **dependency-updater:** tools `bash`, `read`, `write`, `patch`, `grep`, `glob`; permissions: `bash: { "*": "allow", "git push": "ask", "terraform *": "deny" }`, `edit: allow`.
- **Human-approval boundaries:**
  - Any **VCS push**, **infrastructure/terraform**, **package publish**, **secret rotation**, or **file deletions > 10 files** ⇒ **ask** and require human approval.
  - Router halts and asks for human confirmation when **>3 loops** or when **cross-cutting changes** touch **5+ modules**.

---

# Section D — `opencode.json` snippet

```json
{
    "$schema": "https://opencode.ai/config.json",
    "agent": {
        "router": {
            "description": "Supervisor router; selects subagents and enforces stop conditions",
            "mode": "subagent",
            "model": "anthropic/claude-haiku-4-20250514",
            "temperature": 0.1,
            "tools": { "read": true, "grep": true, "glob": true, "webfetch": true },
            "permission": { "edit": "deny", "bash": "deny", "webfetch": "allow" }
        },
        "research": {
            "description": "Fetches external info/specs and extracts facts with citations",
            "mode": "subagent",
            "model": "openai/gpt-5-mini",
            "temperature": 0.2,
            "tools": { "webfetch": true, "write": true, "read": true, "grep": true, "glob": true },
            "permission": { "webfetch": "allow", "edit": "ask", "bash": "deny" }
        },
        "code-reviewer": {
            "description": "Static code review: correctness, quality, maintainability",
            "mode": "subagent",
            "model": "anthropic/claude-sonnet-4-20250514",
            "temperature": 0.1,
            "tools": { "read": true, "grep": true, "glob": true, "edit": false, "bash": false },
            "permission": { "edit": "deny", "bash": "deny", "webfetch": "allow" }
        },
        "security-auditor": {
            "description": "Security audit for authZ/N, secrets, dependencies, config",
            "mode": "subagent",
            "model": "anthropic/claude-sonnet-4-20250514",
            "temperature": 0.0,
            "tools": { "read": true, "grep": true, "glob": true },
            "permission": { "edit": "deny", "bash": "deny", "webfetch": "allow" }
        },
        "linter": {
            "description": "Runs formatters/linters; auto-fixes safe issues",
            "mode": "subagent",
            "model": "openai/gpt-5-mini",
            "temperature": 0.1,
            "tools": {
                "bash": true,
                "read": true,
                "write": true,
                "patch": true,
                "glob": true,
                "grep": true
            },
            "permission": {
                "bash": { "*": "allow", "git push": "ask", "terraform *": "deny" },
                "edit": "allow"
            }
        },
        "refactorer": {
            "description": "Applies safe code changes per plan/review; small/medium edits",
            "mode": "subagent",
            "model": "openai/gpt-5",
            "temperature": 0.15,
            "tools": {
                "edit": true,
                "write": true,
                "patch": true,
                "read": true,
                "grep": true,
                "glob": true
            },
            "permission": { "edit": "allow", "bash": "ask", "webfetch": "deny" }
        },
        "test-runner": {
            "description": "Executes tests, summarizes failures, recommends fixes",
            "mode": "subagent",
            "model": "openai/gpt-5-mini",
            "temperature": 0.1,
            "tools": { "bash": true, "read": true, "grep": true },
            "permission": { "bash": { "*": "allow", "git push": "ask", "terraform *": "deny" } }
        },
        "debugger": {
            "description": "Diagnoses failures from logs/traces; proposes minimal fix",
            "mode": "subagent",
            "model": "anthropic/claude-haiku-4-20250514",
            "temperature": 0.1,
            "tools": { "read": true, "grep": true, "glob": true, "webfetch": true },
            "permission": { "bash": "deny", "edit": "ask", "webfetch": "allow" }
        },
        "docs-writer": {
            "description": "Writes/updates docs, ADRs, changelogs",
            "mode": "subagent",
            "model": "openai/gpt-5",
            "temperature": 0.4,
            "tools": { "read": true, "write": true, "edit": true, "grep": true, "glob": true },
            "permission": { "edit": "allow", "bash": "deny", "webfetch": "ask" }
        },
        "dependency-updater": {
            "description": "Upgrades dependencies safely with security/compat checks",
            "mode": "subagent",
            "model": "openai/gpt-5-mini",
            "temperature": 0.15,
            "tools": {
                "bash": true,
                "read": true,
                "write": true,
                "patch": true,
                "grep": true,
                "glob": true
            },
            "permission": {
                "bash": { "*": "allow", "git push": "ask", "terraform *": "deny" },
                "edit": "allow"
            }
        }
    }
}
```

_(Agent JSON/Markdown placement & options follow OpenCode’s config format.)_ ([GitHub][1])

---

# Section E — Markdown stubs

> Place each in `~/.config/opencode/agent/<name>.md` (file name sets the agent name). ([GitHub][1])

### `router.md`

```markdown
---
description: Supervisor router; selects subagents and enforces stop conditions
mode: subagent
model: anthropic/claude-haiku-4-20250514
temperature: 0.1
tools:
    read: true
    grep: true
    glob: true
    webfetch: true
permission:
    edit: deny
    bash: deny
    webfetch: allow
---

You are a routing supervisor. Given the user intent, repo signals, and recent STATUS lines, select the next subagent and rationale.
Loop at most 3 times. Prefer smallest, read-only agents first. Always emit:

STATUS::router::{"ok":true|false,"summary":"next=<agent>|halt","metrics":{"loops":0,"rationale_tokens":0}}
```

### `research.md`

```markdown
---
description: Fetches external info/specs and extracts facts with citations
mode: subagent
model: openai/gpt-5-mini
temperature: 0.2
tools:
    webfetch: true
    write: true
    read: true
    grep: true
    glob: true
permission:
    webfetch: allow
    edit: ask
    bash: deny
---

Research the topic; fetch up to 6 high-quality sources; extract facts with inline citations.
Produce notes.md and citations.json if enabled.
STATUS::research::{"ok":true|false,"summary":"sources=<n>,unique_domains=<m>","metrics":{"sources":0,"dead_ends":0}}
```

### `code-reviewer.md`

```markdown
---
description: Static code review for correctness, quality, maintainability
mode: subagent
model: anthropic/claude-sonnet-4-20250514
temperature: 0.1
tools:
    read: true
    grep: true
    glob: true
permission:
    edit: deny
    bash: deny
    webfetch: allow
---

Review diffs and files for correctness, maintainability, performance, and tests.
Output review.md with findings: [{"file":"","line":0,"issue":"","severity":"info|warn|error"}]
STATUS::code-reviewer::{"ok":true,"summary":"issues=<n>,errors=<e>","metrics":{"issues":0,"errors":0}}
```

### `security-auditor.md`

```markdown
---
description: Security audit for authZ/N, secrets, dependencies, config
mode: subagent
model: anthropic/claude-sonnet-4-20250514
temperature: 0.0
tools:
    read: true
    grep: true
    glob: true
permission:
    edit: deny
    bash: deny
    webfetch: allow
---

Audit input validation, authZ/authN, secret handling, dependency CVEs, and config hardening.
Emit: {"status":"ok|warn|fail","findings":[{"file":"","line":0,"issue":"","severity":""}]}
STATUS::security-auditor::{"ok":true|false,"summary":"findings=<n>","metrics":{"critical":0,"high":0,"medium":0,"low":0}}
```

### `linter.md`

```markdown
---
description: Runs formatters/linters; auto-fixes safe issues
mode: subagent
model: openai/gpt-5-mini
temperature: 0.1
tools:
    bash: true
    read: true
    write: true
    patch: true
    glob: true
    grep: true
permission:
    bash:
        "*": allow
        "git push": ask
        "terraform *": deny
    edit: allow
---

Run configured linters/formatters; attempt max 2 autofix passes.
STATUS::linter::{"ok":true|false,"summary":"fixed=<n>,remaining=<m>","metrics":{"fixed":0,"remaining":0}}
```

### `refactorer.md`

```markdown
---
description: Applies safe code changes per plan/review; small/medium edits
mode: subagent
model: openai/gpt-5
temperature: 0.15
tools:
    edit: true
    write: true
    patch: true
    read: true
    grep: true
    glob: true
permission:
    edit: allow
    bash: ask
    webfetch: deny
---

Implement the smallest correct change. Batch up to 3 edit sets; request re-review after.
STATUS::refactorer::{"ok":true|false,"summary":"files=<n>,loc=<m>","metrics":{"files_changed":0,"loc_changed":0}}
```

### `test-runner.md`

```markdown
---
description: Executes tests, summarizes failures, recommends fixes
mode: subagent
model: openai/gpt-5-mini
temperature: 0.1
tools:
    bash: true
    read: true
    grep: true
permission:
    bash:
        "*": allow
        "git push": ask
        "terraform *": deny
---

Run the project's test command; parse results; emit junit-style stats.
STATUS::test-runner::{"ok":true|false,"summary":"pass=<p>/fail=<f>","metrics":{"tests_passed":0,"tests_failed":0,"duration_sec":0}}
```

### `debugger.md`

```markdown
---
description: Diagnoses failures from logs/traces; proposes minimal fix
mode: subagent
model: anthropic/claude-haiku-4-20250514
temperature: 0.1
tools:
    read: true
    grep: true
    glob: true
    webfetch: true
permission:
    bash: deny
    edit: ask
    webfetch: allow
---

Infer root cause from stacks/logs; produce ranked hypotheses and a minimal patch suggestion.
STATUS::debugger::{"ok":true|false,"summary":"top_cause=<id>","metrics":{"hypotheses":0,"confidence":0.0}}
```

### `docs-writer.md`

```markdown
---
description: Writes/updates docs, ADRs, changelogs
mode: subagent
model: openai/gpt-5
temperature: 0.4
tools:
    read: true
    write: true
    edit: true
    grep: true
    glob: true
permission:
    edit: allow
    bash: deny
    webfetch: ask
---

Draft/update docs with clear structure and examples. Keep diffs minimal.
STATUS::docs-writer::{"ok":true|false,"summary":"docs_updated=<n>","metrics":{"files_changed":0,"sections_touched":0}}
```

### `dependency-updater.md`

```markdown
---
description: Upgrades dependencies safely with security/compat checks
mode: subagent
model: openai/gpt-5-mini
temperature: 0.15
tools:
    bash: true
    read: true
    write: true
    patch: true
    grep: true
    glob: true
permission:
    bash:
        "*": allow
        "git push": ask
        "terraform *": deny
    edit: allow
---

Perform conservative upgrades; run build/tests; generate upgrade_report.md.
STATUS::dependency-updater::{"ok":true|false,"summary":"updated=<n>","metrics":{"updated":0,"skipped":0,"build_green":0}}
```

---

# Section F — Eval & Observability

**Checks (6–10):**

1. **Unit test status** (pass/fail counts; durations).
2. **Static analysis** (lint error count, autofix applied).
3. **Security diff** (critical/high/medium/low counts; new secrets detected).
4. **Change size** (files changed, LOC changed, churn ratio).
5. **Doc coverage** (API changes documented? sections updated).
6. **Dependency health** (updated/skipped; CVEs resolved).
7. **Routing loops** (router loop count ≤ 3).
8. **Handoff latency** (number of agent hops per task).
9. **Build sanity** (compiles/builds without warnings).
10. **External sources quality** (unique domains, dead ends).

**Machine-readable status line (all agents must emit):**
`STATUS::<agent>::{"ok":true|false,"summary":"...", "metrics":{...}}`

**Schema (shared):**

```json
{
    "ok": true,
    "summary": "short human-readable summary",
    "metrics": {
        "tests_passed": 0,
        "tests_failed": 0,
        "lint_fixed": 0,
        "lint_remaining": 0,
        "critical": 0,
        "files_changed": 0,
        "loc_changed": 0,
        "loops": 0,
        "duration_sec": 0
    }
}
```

---

# Section G — Build/Plan trigger rules

- **General invocation rules:** Build/Plan can **switch or @mention subagents**, and subagents can be configured in JSON/Markdown. Tools and permissions are controlled per agent; permissions can be global or overridden per agent. ([GitHub][1])
- **router**: default entry when intent is ambiguous or when prior STATUS lines conflict; cap 3 loops; prefer read-only agents first.
- **research**: trigger phrases “research”, “compare”, “find examples”, presence of links; also when missing spec/requirements.
- **code-reviewer**: when a diff/PR exists or phrase includes “review”, “feedback”, “smell”; auto after refactorer & tests green.
- **security-auditor**: when changes touch auth, secrets, network rules, Docker/K8s/config; on CVE mentions.
- **linter**: when Build sees formatting/lint errors or file patterns `*.ts, *.tsx, *.py, *.go, *.md` changed; also before tests.
- **refactorer**: when reviewer suggests concrete fix ≤100 LOC or router selects “apply”; avoid on cross-module refactors.
- **test-runner**: when code is edited or before merge; on CI failure.
- **debugger**: upon failing tests or runtime exceptions; if stack trace present in context.
- **docs-writer**: when public APIs, CLI flags, schema or migrations change; file patterns `README.md`, `docs/**`, `CHANGELOG.md`.
- **dependency-updater**: when `package.json`, `poetry.lock`, `go.mod`, `Cargo.toml` change or CVE advisories appear.

---

## Section B (expanded rules examples)

- **Reviewer → Refactorer** if change size ≤100 LOC and tests exist; else back to **Plan** for larger design.
- **Tests → Refactorer** if single-file fix ≤50 LOC and failing assertion pinpointed; otherwise **Tests → Debugger**.
- **Security → Dependency-updater** on vulnerable deps; **Dependency-updater → Tests → Reviewer → Security** to validate.
- **Refactorer → Linter → Tests → Reviewer** default apply loop; router enforces ≤3 cycles with diminishing scope.

---

### Justifications

- **Small, specialized subagents** keep tools minimal and permissions tight, aligning with OpenCode’s subagent design and per-agent tool control. ([GitHub][1])
- **Router-centric (supervisor) coordination** provides deterministic loops and explicit stop criteria, preventing runaway edits and enforcing approval boundaries.
- **Read-only first** (review/security/research) reduces risk; risky operations default to **ask**, and infrastructure actions like `terraform *` are **deny** by policy. ([GitHub][1])
- **Function-call style roles** (clear names, concise outputs, explicit success criteria and STATUS lines) enable robust orchestration and observability across agents.
- **Temperature discipline** (low for analysis/test; moderate for docs) yields deterministic outputs and consistent diffs per the temperature guidance. ([GitHub][1])
- **Handoff Matrix** encodes common engineering flows (review → refactor → lint → test) with conditions (LOC/test state), optimizing for safety and speed.

---

**Notes:**

- The tables, JSON, and Markdown stubs conform to OpenCode’s agent formats: primary vs subagent modes, tools/permissions, JSON and markdown locations/options, available tools list, and permission semantics (allow/ask/deny with bash patterns). ([GitHub][1])

[1]: https://raw.githubusercontent.com/sst/opencode/refs/heads/dev/packages/web/src/content/docs/agents.mdx "raw.githubusercontent.com"
