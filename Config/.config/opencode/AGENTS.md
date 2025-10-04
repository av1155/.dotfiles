# Agent Cheat Sheet

## Overview & Operating Principles

This global guide defines how agents and developers work in this repo: shared Git/GitHub conventions (commits, branches, PRs, reviews), repository hygiene, and how to use our MCP servers (`git`, `fetch`, `context7`, `time`). The goals are correctness, minimal diffs, reproducible builds, strong automation, and a linear, auditable history. Agents should prefer the smallest safe change, open draft PRs early, and rely on CI to validate changes.

---

## Subagents: What You Can Call & When

**Delegation policy (Build/Plan):**

- Prefer **read-only** first (review/security/research).
- For code changes → **@refactorer** → **@linter** (≤2 passes) → **@test-runner** → **@code-reviewer**.
- If tests fail → **@debugger** (diagnose) → **@refactorer** (minimal fix).
- Docs/CHANGELOG → **@docs-writer**. Deps → **@dependency-updater**.
- Unsure? **@router** (max 3 loops), then halt and ask.

**Cheat sheet (trigger → agent → tools & notes → artifact/path):**

- Review a diff/PR → **@code-reviewer** → `read, grep, glob, bash (mkdir/ls only); edit: deny` → `.opencode/reports/review.md`
- Security/secrets/CVEs → **@security-auditor** → `read, grep, glob, bash (mkdir/ls only); edit: deny` → `.opencode/reports/security.md`
- Find specs/compare libs → **@research** → `webfetch: allow; read, write; bash (mkdir/ls only)` → `.opencode/research/{notes.md,citations.json}` (stop at ≥3 vetted or 2 dead ends)
- Implement/refactor (small/medium) → **@refactorer** → `edit/write/patch: allow; bash: ask; webfetch: deny` → `.opencode/refactor/changes.md` (batch ≤3 edit sets)
- Format/lint → **@linter** → `bash: ask (eslint/prettier/ruff/etc allowed); edit: allow` → `.opencode/lint/report.json` (≤2 autofix passes)
- Run tests → **@test-runner** → `bash: ask (common test cmds allowed)` → `.opencode/test/summary.json`
- Debug failing test/trace → **@debugger** → `read, grep, glob, webfetch: allow; bash (mkdir/ls only); edit: ask` → `.opencode/debug/hypothesis.md`
- Write docs/ADR/changelog → **@docs-writer** → `read/write/edit: allow; webfetch: ask; bash (mkdir/ls only)` → `.opencode/docs/*` or patches
- Update dependencies safely → **@dependency-updater** → `bash: ask (install/upgrade cmds allowed); edit: allow` → `.opencode/deps/upgrade_report.md`
- Pick next agent → **@router** → `read, grep, glob; webfetch: ask; bash (mkdir/ls only); edit: deny` → emits `STATUS::router` (≤3 loops)

**Routing hints:**

- Reviewer → Refactorer if **≤100 LOC** and tests exist; else escalate to Plan.
- Tests → Refactorer if **single-file fix ≤50 LOC**; otherwise Tests → Debugger.
- Security → Dependency-updater for vulnerable deps, then back to Security to validate.

---

Note: When per-agent `model` is commented, agents inherit the top-level `model` from `opencode.jsonc`.

## Available MCP Servers

| Server       | Primary Purpose       | Key Capabilities                           |
| ------------ | --------------------- | ------------------------------------------ |
| **git**      | Version control       | Status, diff, commit, branch management    |
| **fetch**    | Simple web content    | Single URL fetching, markdown conversion   |
| **context7** | Library documentation | Resolve library IDs, fetch up-to-date docs |
| **time**     | Temporal operations   | Current time, timezone conversion          |

---

### 🧭 Git & GitHub Conventions and Standards (for agents & developers)

These conventions keep history consistent, enable automation, and make reviews fast. Unless a repository explicitly states otherwise, **use trunk-based development with short‑lived branches, Conventional Commits, and squash‑merge into `main`.**

#### 1) Commit Messages — Conventional Commits + SemVer

**Format**

```
<type>(<optional-scope>)!: <short description>

[optional body]

[optional footer(s)]
```

**Allowed `type` values:** `feat`, `fix`, `docs`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.

**Rules**

- **50/72 Rule**: Subject line max 50 chars (hard limit 72); body text wrapped at 72 chars per line.
- Use present tense, no trailing period.
- Use `!` after the scope or include a `BREAKING CHANGE:` footer for breaking changes.
- Reference issues in footers, e.g. `Fixes #123`, `Refs #456`.
- Prefer one logical change per commit; commit early and often on your branch.

**Versioning impact (SemVer):**

- `feat` → **minor** bump (`vX.(Y+1).0`)
- `fix` → **patch** bump (`vX.Y.(Z+1)`)
- `BREAKING CHANGE` or `!` → **major** bump (`v(X+1).0.0`)
- `docs`/`chore`/`test`/`ci` → no version bump

**Examples**

```
feat(auth)!: require MFA during signup
fix(api): handle null user_id on session refresh
docs(readme): add quickstart for docker
revert: feat(search): add embedding cache (reverts commit abc123)
```

#### 2) Branching Strategy

**Default: Trunk‑based**

- Work from `main`.

- Create **short‑lived** topic branches; prefer lifetimes measured in hours/days, not weeks.

- Branch names: `type/area-kebab-summary`.
  - Examples: `feat/auth-mfa`, `fix/payments-retry`, `chore/ci-caching`.

- Keep branches up‑to‑date by rebasing or merging from `main`; resolve conflicts locally.

**When to opt into GitFlow (rare):**

- Multi‑release support or regulated release trains. If used, create `develop`, `release/x.y.z`, and `hotfix/x.y.z` per repo guidelines. Otherwise, avoid long‑lived branches.

#### 3) Pull Requests (PR) & Code Review

**Opening a PR**

- Open as **Draft** early; convert to Ready when tests pass and description is complete.
- Scope: one change per PR; prefer < ~300 lines net change when possible.
- Title uses Conventional Commits style; the PR body includes:
  - **Context** (why), **Changes** (what), **Testing** (how verified), **Risk/rollback**, and **Screenshots** for UI.
  - Linked issues (`Fixes #123`).

**Review standards**

- Require ≥1 approval (≥2 for high‑risk areas) and all status checks green.
- The author resolves every comment or starts a follow‑up issue before merge.
- Prefer **squash‑merge** to maintain a linear history. Rebase‑merge is allowed when preserving individual commits is required and still keeps history linear.
- No force‑push to protected branches; never merge with failing checks.

**PR checklist (copy into template)**

- [ ] Title follows Conventional Commits
- [ ] Tests added/updated & pass locally
- [ ] Docs/CHANGELOG updated if user‑visible
- [ ] Linked issues and labels set
- [ ] PR is small and focused (or justified)

#### 4) GitHub Repository Structure & Usage

**Top‑level files**

- `README.md` (info, how to run, develop, release)
- `LICENSE` (project license)
- `CONTRIBUTING.md` (how to propose changes)
- `.gitignore`, `.editorconfig`
- `CHANGELOG.md` (generated)

**`.github/` directory**

- `ISSUE_TEMPLATE/` — `bug_report.yml`, `feature_request.yml`, `config.yml`
- `PULL_REQUEST_TEMPLATE.md` — includes the PR checklist above
- `workflows/` — CI (lint, test, build), release, and reusable workflows

**Issues vs Discussions**

- Use **Discussions** for Q&A, design proposals, and announcements.
- Convert to **Issues** when work is actionable, scoped, and testable.

**Releases & tags**

- Tag releases as `vMAJOR.MINOR.PATCH`.
- Generate release notes from merged PRs/commits; attach artifacts as needed.

**Branch protection (recommended defaults)**

- Protect `main` (and any `release/*`):
  - Require PR reviews (≥1; ≥2 for critical code paths)
  - Require status checks to pass (CI, linters, tests)
  - Require linear history (squash or rebase merges)
  - Restrict who can push; disallow force‑push & branch deletion

**Actions & automation**

- CI runs on PRs and `main`.
- Use **reusable workflows** for shared CI (build, test, security scans).
- Enable Dependabot or equivalent for dependency updates.
- Make required checks blocking via branch protection.

#### 5) Agent Playbook (quick steps)

1. **Create branch**: `git_create_branch("feat/<area>-<summary>")`
2. **Edit files**; run local tests.
3. **Stage**: `git_add` selected files.
4. **Commit**: `git_commit` with Conventional Commit message.
5. **Sync**: rebase on `main` if behind; resolve conflicts.
6. **Open Draft PR** with template; link issues; request owners.
7. **Checks**: ensure CI green; address review comments; update docs.
8. **Merge**: squash‑merge; delete branch.
9. **Release**: tag `vX.Y.Z` per SemVer and repository release workflow.

---

### 🔧 Git MCP Server

**Workflow Standards:**

1. **Before any changes:** `git_status` to understand current state
2. **Review changes:** `git_diff_unstaged` before staging
3. **Stage selectively:** `git_add` with specific files
4. **Meaningful commits:** Clear, conventional commit messages
5. **Branch strategy:** `feat/`, `fix/`, `chore/` prefixes

- Prefer `git MCP` for all VCS; restrict `bash` to read-only diagnostics.

---

## Decision Trees

### Git Operations Decision Tree

```
Working with git?
├── Check current state?
│   ├── Working tree → git_status
│   ├── Unstaged changes → git_diff_unstaged
│   └── Staged changes → git_diff_staged
├── Make changes?
│   ├── Stage files → git_add
│   ├── Commit → git_commit
│   └── Unstage → git_reset
└── Navigate history?
    ├── View commits → git_log
    ├── Switch branch → git_checkout
    └── Create branch → git_create_branch
```

---

### 🌍 Global Engineering Conventions (repo‑agnostic)

These apply to **all** projects and agents. They’re intentionally general and safe to adopt everywhere.

**A. Tests & CI (fast, deterministic, hermetic)**

- Tests are **isolated** and pass when run alone or in any order; avoid shared global state.
- Default to **hermetic** tests: no live network, no external services; use fakes/stubs/fixtures.
- Prefer **table‑driven** specs for combinatorial cases; keep cases small and readable.
- Mark slow/integration tests and run them separately; keep PR checks fast.
- Quarantine and deflake flaky tests quickly; add regression cases when fixed.

**B. Docs & Generated Artifacts**

- Generate docs from source annotations when possible; **do not edit generated files**.
- Provide a script (e.g., `./scripts/docs`) and a CI check to verify generated output is current.
- Keep `README` as the newcomer path (how to build, test, run, release); link deeper docs.

**C. Feature Flags & Config**

- Respect global and per‑scope toggles; default to **safe off** for risky changes.
- Classify toggles (release/ops/experiment/permission); add owners and an expiry plan.
- Remove stale flags promptly; capture behavior in tests with the flag on/off.

**D. Scripts & Tooling**

- Common tasks live in `./scripts`; scripts are **idempotent**, verbose on failure, and return non‑zero on error.
- Provide `--help` and environment toggles for offline/headless CI.
- Pin tool versions; ensure scripts run on Linux/macOS by default.

**E. Logging & Telemetry**

- Use **structured logs** with consistent levels; include request/trace IDs when available.
- Never log secrets, tokens, or PII; sanitize inputs and truncate large payloads.
- Keep test logs quiet by default; surface summaries and actionable errors in CI.

**F. Reproducible Builds**

- Pin dependencies with lockfiles; avoid floating `latest`.
- Make builds **deterministic**; record or containerize the build environment.
- Artifact/version metadata comes from the VCS (tag/commit); avoid embedding local machine state.

---

### 📚 Context7 MCP Server

**When to Use:**

- Generating code with modern frameworks/APIs
- Need current, version-specific library documentation
- Avoiding outdated training data and hallucinated APIs
- Getting working code examples from official sources

**Two-Step Workflow:**

1. **resolve-library-id** → Convert package name to Context7 ID
2. **get-library-docs** → Fetch documentation with optional topic focus

**Key Insights:**

- Always resolve library ID first unless user provides `/org/project` format
- Use `topic` parameter to focus docs (e.g., "routing", "authentication")
- Default token limit is 5000 (min 1000)
- Add "use context7" to prompts or create a rule for automatic invocation
- If you know the exact library, use `/org/project` syntax directly

**Example Usage:**

```
User: "Create Next.js middleware for JWT validation. use context7"

1. resolve-library-id("next.js") → /vercel/next.js
2. get-library-docs("/vercel/next.js", topic="middleware")
3. Generate code with current API
```

**Pro Tips:**

- Create a rule: "Always use context7 for code generation"
- Use library IDs directly: "use library /supabase/supabase"
- Prefer Context7 over generic knowledge for framework-specific code

### 🌐 Fetch MCP Server

**When to Use:**

- Single page content
- APIs returning JSON/XML
- Quick content checks
- When you don't need JavaScript rendering

**Limitations:**

- 5000 character default limit (use `start_index` for pagination)
- No JavaScript execution
- No authentication support

### ⏰ Time MCP Server

**Usage:**

- Current time: `get_current_time` with IANA timezone
- Conversions: `convert_time` between timezones
- Always use IANA format: 'America/New_York', not 'EST'

---

## Quick Reference Card

```
Git ops        → git
Simple URL     → fetch
Library docs   → context7
Time/timezone  → time

ALWAYS:
- git_status before commits
- prefer smallest safe changes
```

---

## Troubleshooting

| Problem             | Solution                                   |
| ------------------- | ------------------------------------------ |
| Token overflow      | Use limits, pagination, selective reading  |
| Tool unavailable    | Check env vars, use fallback tool          |
| Git conflicts       | Show diff, explain options, await decision |
| Web content missing | Try different extraction method/tool       |

---

_This document is the authoritative guide for MCP server operations. When in doubt, refer to the decision trees and best practices above._
