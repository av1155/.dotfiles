# Agentic Coding Harnesses Reference

Comprehensive reference for the four agentic coding harnesses used across global and project scopes:

- **Claude Code** (Anthropic, CLI + IDE integrations)
- **Codex CLI** (OpenAI, terminal coding agent)
- **OpenCode** (sst, open-source TUI agent)
- **Pi** (earendil-works/pi v0.73.0, minimalist extensible terminal harness)

This document captures verified behavior per harness, the canonical file layout in `~/.dotfiles/`, procedures for common operations, and the decision log for the alignment migration. It is the source of truth for how the cross-harness environment is wired.

> **Status**: scaffolded during Stage 1. Content is filled in incrementally as alignment stages execute (see Stage 10 for finalization).

---

## 1. Harness Reference

> TODO (Stage 2): per-harness install paths, versions, what each one reads from disk at session start.

## 2. Skills

> TODO (Stages 2, 5): per-harness skill loading paths, SKILL.md frontmatter compatibility matrix, argument substitution support, `paths:` field semantics, description-based discovery.

## 3. Rules

> TODO (Stage 2): Claude path-conditional `.claude/rules/*.md` mechanics, Codex Starlark `.rules` (command-prefix gates), OpenCode AGENTS.md-as-rules pattern.

## 4. AGENTS.md / CLAUDE.md

> TODO (Stage 4): loading order per harness, size caps (Codex 32 KiB hard cap, Claude < 200 lines recommended), single-canonical-with-symlinks strategy, section-header convention for tool-specific content.

## 5. Plugins

> TODO (Stage 2): Claude marketplaces, Codex plugins (`developers.openai.com/codex/plugins`), OpenCode TypeScript plugins, Pi packages and extensions.

## 6. MCP Servers

> TODO (Stage 8): Claude `.mcp.json` / `~/.claude.json` scopes, Codex `[mcp_servers.<name>]` in config.toml, OpenCode `mcp:` key in opencode.jsonc. Pi does NOT support MCP natively (uses extension-registered tools).

## 7. Hooks

> TODO (Stage 2): Claude `settings.json` hooks (25+ events), Codex `hooks.json`, OpenCode plugin hooks (`tool.execute.before`, `command.executed`, etc.), Pi extension events via `pi.on(event, handler)`.

## 8. Sub-agents

> TODO (Stage 2): Claude built-ins (Explore, Plan, general-purpose), Codex sub-agents, OpenCode primary agents (build, plan) and sub-agents (general, explore), Pi pi-subagents package.

## 9. Settings

> TODO (Stage 2): `~/.claude/settings.json`, `~/.codex/config.toml`, `~/.config/opencode/opencode.jsonc`, `~/.pi/agent/settings.json`. Permissions, env vars, statusline, enabled plugins.

## 10. Permissions Models

> TODO (Stage 2): per-harness allow/ask/deny patterns. Claude `permissions` in settings.json, Codex Starlark `prefix_rule()`, OpenCode `permission` key with pattern matching, Pi extension-controlled.

## 11. Auto-memory

> TODO (Stage 2): Claude `MEMORY.md` mechanics (200 lines / 25 KB loaded at session start, project-scoped at `~/.claude/projects/<project>/memory/`). No equivalent in Codex / OpenCode / Pi.

## 12. Pi Extensions Inventory

> TODO (Stage 7): per-extension summary covering `pi-subagents`, `pi-web-access`, `pi-lens`, `pi-powerline-footer`, `@juicesharp/rpiv-args` (adds `$ARGUMENTS`/`$1` substitution to skill bodies), `@juicesharp/rpiv-todo`, `@juicesharp/rpiv-ask-user-question`. What each registers (tools, hooks, providers).

## 13. Cross-Harness Compatibility Matrix

> TODO (Stage 2): table of feature support per harness — frontmatter fields, argument substitution, MCP, hooks, sub-agents, plugin systems, etc. What's portable vs. what's tool-specific.

## 14. Provenance / Origin

Per-item mapping with origin classification and bucket assignment, documented during Stage 2 audit (read-only; no file moves yet). Buckets follow Q3:
- **A** — always-on context, migrates to AGENTS.md, original deleted
- **B** — path-conditional, lives as canonical SKILL.md with `paths:` frontmatter, single skill-symlink in `.claude/skills/`
- **C** — task/procedure, description-triggered, lives as canonical SKILL.md, single skill-symlink in `.claude/skills/`

### 14.1 Global scope

#### Skills currently in `.dotfiles/Agents/.agents/skills/`

| File | Origin | Bucket | Migration |
|---|---|---|---|
| python/SKILL.md | user-authored portable | B | Stay; path-conditional `**/*.py` `**/*.pyi`. Re-wire `Claude/.claude/rules/python.md` symlink → `Claude/.claude/skills/python` directory symlink |
| typescript/SKILL.md | user-authored portable | B | Stay; path-conditional `**/*.ts` `**/*.tsx`. Re-wire as skill-symlink |
| scalability/SKILL.md | user-authored portable | B | Stay; path-conditional 20 backend file patterns. Re-wire as skill-symlink |
| security/SKILL.md | user-authored portable | C (re-class) | Currently no `paths:`; description-triggered. **Note**: audit suggested A, but skill loading behavior without `paths:` is C. Stay as skill, add skill-symlink in `Claude/.claude/skills/` |
| commenting/SKILL.md | user-authored portable | C (re-class) | Same reasoning as security; stay as skill, add skill-symlink |
| caveman/SKILL.md | Matt Pocock | C | Stay as-is |
| diagnose/SKILL.md | Matt Pocock | C | Stay as-is |
| grill-me/SKILL.md | Matt Pocock | C | Stay as-is |
| grill-with-docs/SKILL.md | Matt Pocock | C | Stay as-is |
| improve-codebase-architecture/SKILL.md | Matt Pocock | C | Stay as-is |
| setup-matt-pocock-skills/SKILL.md | Matt Pocock | C (`disable-model-invocation: true`) | Stay as-is |
| tdd/SKILL.md | Matt Pocock | C | Stay as-is |
| to-issues/SKILL.md | Matt Pocock | C | Stay as-is |
| to-prd/SKILL.md | Matt Pocock | C | Stay as-is |
| triage/SKILL.md | Matt Pocock | C | Stay as-is |
| write-a-skill/SKILL.md | Matt Pocock | C | Stay as-is |
| zoom-out/SKILL.md | Matt Pocock | C (`disable-model-invocation: true`) | Stay as-is |
| playwright-cli/SKILL.md | Matt Pocock-flavored / infrastructure | C | Stay; `allowed-tools` inert outside Claude. No path constraints — description-triggered |
| agentic-coding-harnesses/SKILL.md (Stage 1) | user-authored discovery | C | Stay; description-triggered when env modifications discussed |

#### Skills currently in `.dotfiles/Claude/.claude/skills/` (16 personal-workflow)

All bucket **C** (description-triggered, most use `$ARGUMENTS`). All migrate to `.agents/skills/<name>/` in Stage 5; replace original with directory skill-symlink.

| Skill | Uses args? | Notable frontmatter |
|---|---|---|
| catchup | no | `allowed-tools` |
| coordinator | no | `disable-model-invocation: true` |
| deep-audit | yes (`$ARGUMENTS`) | `argument-hint`, `disable-model-invocation: true` |
| fix-issue | yes (`$ARGUMENTS`) | `argument-hint`, `disable-model-invocation: true` |
| merge | yes (`$ARGUMENTS`) | `disable-model-invocation: true` |
| open-pr | no | — |
| rebase | yes (`$ARGUMENTS`) | `disable-model-invocation: true` |
| review | no | — |
| ship | yes (`$ARGUMENTS`) | `argument-hint`, `disable-model-invocation: true` |
| workmux | no | — |
| worktree | yes (`$ARGUMENTS`) | `disable-model-invocation: true` |

(Plus the 13 symlinks to `Agents/.agents/skills/` already covered above.)

#### Rules in `.dotfiles/Claude/.claude/rules/`

| File | Type | Bucket | Migration |
|---|---|---|---|
| context7.md | user-authored CLI wrapper (real file) | A | Always-on; consider moving content into canonical AGENTS.md (Stage 4) |
| python.md | symlink → `Agents/.agents/skills/python/SKILL.md` | B | Replace with skill-symlink in Stage 5 |
| typescript.md | symlink → `Agents/.agents/skills/typescript/SKILL.md` | B | Replace with skill-symlink in Stage 5 |
| scalability.md | symlink → `Agents/.agents/skills/scalability/SKILL.md` | B | Replace with skill-symlink in Stage 5 |

#### Rules in `.dotfiles/Codex/.codex/rules/`

| File | Type | Bucket | Migration |
|---|---|---|---|
| default.rules | Starlark prefix-rules (allowlist) | n/a | Different system; stays as-is |

#### Skills in `.dotfiles/Codex/.codex/skills/` (11 duplicates)

All going away in Stage 6. Note: drift detected vs Claude/.claude/skills versions:
- fix-issue: Codex 211 lines vs Claude 271 lines (60-line drift, Claude is newer)
- review: Codex 238 lines vs Claude 286 lines (48-line drift, Claude is newer)
- Others: minor formatting drift only

Before Stage 6 deletion, verify the canonical Claude versions don't lose features that exist in Codex versions.

### 14.2 Houndarr (`Developer/Houndarr/`)

#### Skills `.agents/skills/`

| Skill | `paths:` | Bucket | Migration (Stage 8) |
|---|---|---|---|
| houndarr-architecture | `src/houndarr/**` | B | Re-wire `.claude/rules/houndarr-architecture.md` symlink → `.claude/skills/houndarr-architecture` directory symlink |
| houndarr-changelog | `CHANGELOG.md`, `VERSION` | B | Re-wire as skill-symlink |
| houndarr-ci | `.github/workflows/**` | B | Re-wire as skill-symlink |
| houndarr-database | `src/houndarr/database.py` | B | Re-wire as skill-symlink |
| houndarr-python | `**/*.py` | B | Re-wire as skill-symlink |
| houndarr-testing | `tests/**` | B | Re-wire as skill-symlink |
| verify-algorithms | `src/houndarr/engine/**` | B | Re-wire as skill-symlink |
| bump | no | C | Add skill-symlink in `.claude/skills/bump` |
| check | no | C | Add skill-symlink |
| test | no | C | Add skill-symlink |

#### Rules `.claude/rules/`

| File | Type | Bucket | Migration |
|---|---|---|---|
| hook-compliance.md | real file (77 lines) | A | Move content into Houndarr AGENTS.md, delete file |
| (7 rule-symlinks to .agents/skills/) | symlink | B | Delete each rule-symlink; create directory skill-symlink at `.claude/skills/<name>` (Stage 8) |

#### Commands `.claude/commands/` and `.opencode/commands/`

3 commands (bump, check, test) duplicated across `.claude/commands/`, `.opencode/commands/`, AND `.agents/skills/`. Per Claude Code docs, `.claude/commands/foo.md` and `.claude/skills/foo/SKILL.md` are equivalent.

| Command | Canonical | Action |
|---|---|---|
| bump | `.agents/skills/bump/SKILL.md` | Delete `.claude/commands/bump.md` and `.opencode/commands/bump.md`. Skill-symlink in `.claude/skills/`. |
| check | `.agents/skills/check/SKILL.md` | Same |
| test | `.agents/skills/test/SKILL.md` | Same |

#### Top-level files

| File | Lines | Size | Status |
|---|---|---|---|
| AGENTS.md | 507 | 20 KiB | Comfortable under Codex 32 KiB cap. No trim needed. |
| CONTEXT.md | 88 | 3.4 KiB | Domain glossary. Keep as-is. |
| CLAUDE.md | 1 | — | `@AGENTS.md` stub. Correct. |

### 14.3 invest-platform (`Developer/invest-platform/`)

#### Skills

| Skill | Location | Bucket | Migration (Stage 8) |
|---|---|---|---|
| opengrep | `.claude/skills/opengrep/` | B (or C; verify) | Move to `.agents/skills/opengrep/`. Add skill-symlink. |
| sprint-plan | `.claude/skills/sprint-plan/` | C (`argument-hint`, `$ARGUMENTS`) | Move to `.agents/skills/sprint-plan/`. Add skill-symlink. |
| sprint-pr | `.claude/skills/sprint-pr/` | C (same) | Move to `.agents/skills/sprint-pr/`. Add skill-symlink. |
| check | `.agents/skills/check/` | C | Add skill-symlink. |
| linear-sync | `.agents/skills/linear-sync/` | C | Add skill-symlink. **DRIFT** — `.claude/commands/linear-sync.md` and `.opencode/commands/linear-sync.md` are stale (270-line drift). Delete both; canonical is `.agents/skills/`. |
| new-component | `.agents/skills/new-component/` | C | Add skill-symlink. Delete duplicates in `.claude/commands/`, `.opencode/commands/`. |
| new-adapter | same | C | Same |
| new-migration | same | C | Same |
| progress-update | same | C | Same |

#### Rules `.claude/rules/`

| File | `paths:`/`globs:`/`trigger:` | Bucket | Migration |
|---|---|---|---|
| commenting.md | none | A | Move to AGENTS.md, delete file (Stage 8) |
| dev-credentials.md | none | A | Move to AGENTS.md, delete file |
| frontend-ui.md | `trigger: *.tsx,*.css,*.scss` | B | Stay scoped; standardize frontmatter to `paths:` |
| git-workflow.md | none | A | Move to AGENTS.md, delete file |
| linear-conventions.md | none | A | Move to AGENTS.md, delete file |
| plan-mode.md | none | A (or delete entirely) | 17 lines about PreToolUse hook; either inline as comment in settings.json or move 1-line note to AGENTS.md |
| security-compliance.md | none | A | Move to AGENTS.md, delete file |
| testing-patterns.md | `globs: tests/**` | B | Stay scoped; convert to skill with `paths:` (Stage 8) |
| typescript-conventions.md | `globs: **/*.ts,*.tsx` | B | Stay scoped; convert to skill with `paths:` |
| writing-style.md | `globs: **/*.md,*.mdx,.github/**` | B | Stay scoped; convert to skill with `paths:` |

#### Top-level files

| File | Lines | Size | Status |
|---|---|---|---|
| AGENTS.md | 694 | **32,079 bytes (AT Codex 32 KiB cap)** | **Critical**: at the boundary. Trim plan in section 17 / Stage 8. Target ~210 lines / 11 KiB. |
| CONTEXT.md | 41 | 2 KiB | Domain glossary. Keep. |
| CLAUDE.md | 1 | — | `@AGENTS.md` stub. Correct. |

### 14.4 wedding-site (`Developer/wedding-site/`)

#### Skills `.agents/skills/`

| Skill | Bucket | Migration |
|---|---|---|
| stripe-best-practices | B (toolkit, infrastructure) | Already skill-wired in `.claude/skills/`. No change. |
| stripe-projects | C (or A; verify) | Already skill-wired. **Description weak** (49 chars; Stage 3 fix). |
| upgrade-stripe | C | Already skill-wired. **Description weak** (49 chars; Stage 3 fix). |

#### Rules `.claude/rules/`

| File | `paths:`/`globs:` | Bucket | Migration |
|---|---|---|---|
| frontend-ui.md | `paths: **` (all files) | A (effectively, with `**`) or B | Already broad-scoped. Either keep as path-scoped rule or move content to AGENTS.md. |
| git-workflow.md | none | A | Move to AGENTS.md (Stage 8) |
| paulinas-branch.md | none (branch-conditional, not file-conditional) | A or C | Branch-conditional behavior isn't a Claude rule mechanism. Stay as bucket A in AGENTS.md, OR convert to description-triggered skill ("Use when working on paulinas-branch") |

#### Top-level files

| File | Status | Notes |
|---|---|---|
| AGENTS.md | **PROBLEM**: file is just `@AGENTS.md` (1 line) — same content as CLAUDE.md. Audit calls this "broken". Investigate Stage 8: was this meant to be the canonical content with CLAUDE.md as stub, but got swapped? |
| CLAUDE.md | 219 lines, 20 KiB | Has all the actual content |
| CONTEXT.md | 78 lines, 3 KiB | Domain glossary. Keep. |

#### skills-lock.json

All 3 SHA-256 hashes are STALE (skills modified May 3, lock not updated). Decision needed:
- Recompute hashes (preserve the integrity-checking pattern)
- Remove the lock file (simpler, accept that we don't pin Stripe skills)

### 14.5 Imported skills NOT version-tracked

Per Q4. Live as real directories at `~/.agents/skills/` and `~/.claude/skills/`, outside dotfiles.

| Skill | Source |
|---|---|
| deploy-to-vercel | Vercel plugin or setup-script |
| doc-coauthoring | Claude.ai desktop chat app |
| find-docs | utility (origin unattributed) |
| find-skills | utility (origin unattributed) |
| frontend-design | Claude Code plugin (claude-plugins-official) |
| supabase | Supabase plugin |
| supabase-postgres-best-practices | Supabase plugin |
| vercel-cli-with-tokens | Vercel plugin |
| vercel-composition-patterns | Vercel plugin |
| vercel-react-best-practices | Vercel plugin |
| vercel-react-native-skills | Vercel plugin (description blocker — Stage 3) |
| vercel-react-view-transitions | Vercel plugin |
| web-design-guidelines | Claude Code plugin |
| webapp-testing | playwright/testing plugin |

These are not modified by alignment work. Stage 3 fixes the 2 description blockers in-place but does not bring them under version control.

## 15. File Layout

> TODO (Stage 5): canonical tree of `.dotfiles/` after migration. Where each kind of artifact lives, which paths are real files vs. committed symlinks vs. stow-target symlinks.

## 16. Procedures

> TODO (Stages 5-9): step-by-step procedures for:
> - Add a new skill (canonical location + skill-symlink wiring)
> - Modify a Matt Pocock or other imported skill
> - Trim an AGENTS.md that's exceeding the Codex 32 KiB cap
> - Handle a plugin or setup-script re-install that overwrites tracked content
> - Re-stow after adding new packages or top-level paths
> - Debug "skill not loading" per harness (Pi description blocker, Codex skill path, OpenCode regex validation)
> - Verify each harness loads correctly after migration

## 17. Cap & Adherence Cheatsheet

> TODO (Stage 4): one-page reference of the size caps and adherence guidance:
> - Codex `project_doc_max_bytes` = 32 KiB default (silent truncation from start)
> - Claude < 200 lines per CLAUDE.md (Anthropic recommendation; longer reduces adherence)
> - OpenCode no documented hard cap; community recommends < 300 lines
> - Pi no documented hard cap; SKILL.md description hard-required
> - "Lost in the middle" research summary
> - Skill discovery via description quality

## 18. Modification Ledger

Running log of modifications made to imported / external skills, and of plugin re-install conflicts resolved. Each entry captures: date, skill name, what changed, why, how to re-apply if overwritten. Populated during execution and ongoing thereafter.

### 2026-05-07 — Stage 3 false-alarm verification

The Stage 2 audit's "Tier 1 description blocker" classification for three files was **incorrect**. Verification with frontmatter parsing confirmed:

- `~/.agents/skills/vercel-react-native-skills/SKILL.md` — name `vercel-react-native-skills`, description 295 chars (valid YAML implicit multi-line plain scalar)
- `~/.agents/skills/vercel-composition-patterns/SKILL.md` — name `vercel-composition-patterns`, description 310 chars (valid)
- `.dotfiles/Codex/.codex/skills/deep-audit/SKILL.md` — name `deep-audit` (NOT `caveman` as previous audit claimed), description 466 chars (valid)

Likely cause: the audit used a parser that didn't handle YAML's indented continuation form (`description:` on one line followed by indented continuation lines on subsequent lines). All three files are correctly formed per YAML 1.2.

**No file modifications made.** If Pi (or any harness) is in fact failing to load these skills, the cause is downstream of frontmatter validity — possibly the harness's `skills:` configuration or its YAML parser strictness. Investigate during Stage 9 verification.

### Pending entries

(none)

## 19. Open Questions / Deferred Work

### Raised during Stage 2 audit (need user judgement before Stages 5/8)

1. **`security` and `commenting` skills bucket assignment**: currently no `paths:` frontmatter, so they load only via description-discovery (bucket C). Audit suggested they're conceptually always-on (bucket A), which would mean moving content to AGENTS.md. Decision needed: keep as description-triggered skills (C) OR migrate content to AGENTS.md (A)?

2. **`agentic-coding-harnesses` (the new discovery skill)**: classified as C in section 14 (description-triggered). Confirm.

3. **Houndarr `hook-compliance.md`** (77-line standalone rule): bucket A (move content to AGENTS.md, delete file)? Or keep as standalone always-on rule? Content overlap risk with AGENTS.md to monitor.

4. **invest-platform unscoped rules** (commenting, dev-credentials, git-workflow, linear-conventions, security-compliance — all 5 ~17 KiB combined): if all promoted to bucket A and merged into AGENTS.md, AGENTS.md grows. Combined with current 32-KiB cap pressure, this requires aggressive trim of OTHER AGENTS.md content. Confirm trim plan (target ~210 lines / 11 KiB) before Stage 8.

5. **invest-platform `plan-mode.md`** (17 lines): potential deletion (inline as comment elsewhere) vs. keep as A?

6. **wedding-site AGENTS.md "broken" symlink**: file contains `@AGENTS.md` literal — same content as CLAUDE.md. Investigate: was this meant to be canonical with CLAUDE.md as stub, but got swapped? Will resolve in Stage 8.

7. **wedding-site `skills-lock.json`**: all 3 hashes stale. Recompute (preserve the integrity-checking pattern, generalize to other projects later) OR remove (simplify, accept no pinning)?

8. **Codex/.codex/skills/ drift before deletion**: fix-issue 60-line drift, review 48-line drift between Codex and Claude versions. Before Stage 6 deletion, verify the canonical Claude versions don't lose features. May need to merge Codex content into Claude version first.

9. **Houndarr / invest-platform `.opencode/commands/` files**: drifted from canonical `.agents/skills/`. Resolution: delete `.opencode/commands/` directories entirely. They were a previous OpenCode pattern that never got cleaned up. Confirm before deletion in Stage 8.

### Deferred to consolidation phase (post-alignment)

- Whether plugin-installed global skills (vercel-*, supabase-*, etc., 14 total) should move to project-only scope
- Tooling for automated plugin-reinstall diff resolution
- Generalizing wedding-site `skills-lock.json` pattern across projects (or removing entirely)
- Worktree branching strategy for large refactors

## 20. Decision Log

> Architectural decisions from the planning phase (Q1-Q8) and any subsequent decisions made during execution.

### Q1 — Harness scope
All four harnesses (Claude Code, Codex, OpenCode, Pi) actively maintained.

### Q2 — Canonical skill location
`.dotfiles/Agents/.agents/skills/<name>/SKILL.md` is the single source of truth for skills. Codex, OpenCode, Pi read it natively at `~/.agents/skills/`. Claude reaches it via committed in-repo symlinks at `.dotfiles/Claude/.claude/skills/<name>` → relative path to canonical. `.dotfiles/Codex/.codex/skills/` is deleted in Stage 6.

### Q3 — Bucket strategy
- **Bucket A** (always-on context): goes only into AGENTS.md
- **Bucket B** (path-conditional): canonical SKILL.md with `paths:` frontmatter
- **Bucket C** (task/procedure): canonical SKILL.md with description-trigger

Single wiring per skill — never both rule-symlink and skill-symlink for the same content (would double-load in Claude).

### Q4 — Imported skills
The 14 plugin-installed / Claude.ai-app-installed / setup-script-installed skills (vercel-*, supabase-*, deploy-to-vercel, doc-coauthoring, find-docs, find-skills, frontend-design, web-design-guidelines, webapp-testing) are NOT version-tracked. They stay outside dotfiles. Documented as external in section 14.

### Q5 — Bucket A migration disposition
For each rule classified as bucket A: content moves into AGENTS.md. The corresponding `.claude/rules/<name>.md` AND `.agents/skills/<name>/` directory are both deleted. Aggressive trimming required to fit caps.

### Q6 — Global AGENTS.md
Single canonical at `.dotfiles/Agents/.agents/AGENTS.md`. Each harness's expected location is a committed in-repo symlink:
- `.dotfiles/Claude/.claude/CLAUDE.md` → `../../Agents/.agents/AGENTS.md`
- `.dotfiles/Codex/.codex/AGENTS.md` → `../../Agents/.agents/AGENTS.md`
- `.dotfiles/Config/.config/opencode/AGENTS.md` → `../../../Agents/.agents/AGENTS.md`
- `.dotfiles/Pi/.pi/agent/AGENTS.md` → `../../../Agents/.agents/AGENTS.md` (new package)

Tool-specific content via clearly-marked section headers within the canonical file.

### Q7 — Runbook location and format
Single document at `.dotfiles/docs/AGENTIC-CODING-HARNESSES.md` (this file). New `docs/` package with `.stow-local-ignore: .+` (tracked but not stowed). Paired `agentic-coding-harnesses` skill at `.dotfiles/Agents/.agents/skills/agentic-coding-harnesses/SKILL.md` for AI discoverability — the skill points LLMs to read this file before modifying the environment.

### Q8 — Execution sequence
Ten stages with explicit approval gates:
1. Scaffold runbook (this commit)
2. Audit skills and rules
3. Fix description blockers
4. Consolidate global AGENTS.md (HIGH RISK)
5. Migrate skill canonical location
6. Delete `.dotfiles/Codex/.codex/skills/`
7. Create Pi stow package
8. Project-level migrations (Houndarr → wedding-site → invest-platform)
9. End-to-end verification
10. Finalize runbook

### Stage 2 audit-resolution decisions (2026-05-07)

The 9 open questions raised in section 19 during the Stage 2 audit were resolved per the recommendations:

1. `security` and `commenting` skills → **C** (description-triggered; no AGENTS.md migration)
2. `agentic-coding-harnesses` → **C** (confirmed)
3. Houndarr `hook-compliance.md` → **A** (move to AGENTS.md, delete file in Stage 8)
4. invest-platform 5 unscoped rules → all **A** (move to AGENTS.md, delete files in Stage 8). Combined with aggressive trim of OTHER AGENTS.md content (target 11 KiB / 210 lines)
5. invest-platform `plan-mode.md` → **delete entirely**; inline as comment elsewhere
6. wedding-site AGENTS.md "broken" symlink → **investigate during Stage 8**, restore stub-pattern correctly
7. wedding-site `skills-lock.json` → **recompute** during Stage 8 (preserve integrity-checking pattern)
8. Codex/.codex/skills/ drift → **merge missing content** from Codex versions into Claude (canonical) versions before Stage 6 deletion
9. `.opencode/commands/` directories in Houndarr and invest-platform → **delete entirely** (stale duplicates)

### Stage 3 outcome (2026-05-07)
All 3 alleged description-blockers verified to have valid YAML frontmatter with non-empty descriptions. Earlier audit was incorrect. No modifications made. See section 18.
