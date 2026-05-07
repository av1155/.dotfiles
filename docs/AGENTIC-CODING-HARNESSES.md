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

> TODO (Stage 2): per-skill mapping to origin — user-authored portable conventions, user-authored personal workflow, Matt Pocock skills (via `setup-matt-pocock-skills`), imported via plugin, imported via Claude.ai chat app, project-specific user-authored.

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

> Running log of modifications made to imported / external skills, and of plugin re-install conflicts resolved. Each entry captures: date, skill name, what changed, why, how to re-apply if overwritten. Populated during execution and ongoing thereafter.

> _No entries yet._

## 19. Open Questions / Deferred Work

> TODO (Stage 10): items explicitly deferred to consolidation phase or future iterations. Includes: whether plugin-installed global skills should move to project-only scope, tooling for plugin-reinstall diff resolution, generalizing wedding-site `skills-lock.json`, and any items discovered during execution.

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
