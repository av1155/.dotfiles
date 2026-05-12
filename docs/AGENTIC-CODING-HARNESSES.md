# Agentic Coding Harnesses Reference

Comprehensive reference for the four agentic coding harnesses used across global and project scopes:

- **Claude Code** (Anthropic, CLI + IDE integrations)
- **Codex CLI** (OpenAI, terminal coding agent)
- **OpenCode** (sst, open-source TUI agent)
- **Pi** (earendil-works/pi v0.74.0, minimalist extensible terminal harness)

This document captures verified behavior per harness, the canonical file layout in `~/.dotfiles/`, procedures for common operations, and the decision log for the alignment migration. It is the source of truth for how the cross-harness environment is wired.

> **Status**: scaffolded during Stage 1. Content is filled in incrementally as alignment stages execute (see Stage 10 for finalization).

---

## 1. Harness Reference

| Harness                     | Version     | Install path                                                                | Session-start input                                                                                                                                                                    |
| --------------------------- | ----------- | --------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Claude Code** (Anthropic) | per release | `claude` CLI (Homebrew + IDE integrations)                                  | `~/.claude/CLAUDE.md`, `~/.claude/rules/*.md` (matching `paths:`), auto-memory `MEMORY.md`, project `<repo>/CLAUDE.md` (concatenated root-to-cwd), project `<repo>/.claude/rules/*.md` |
| **Codex CLI** (OpenAI)      | 0.128.0     | `/opt/homebrew/Caskroom/codex/<v>/codex-aarch64-apple-darwin` (Rust binary) | `~/.codex/AGENTS.override.md` then `AGENTS.md`, project `AGENTS.md` walk-up (32 KiB combined cap)                                                                                      |
| **OpenCode** (sst)          | 1.14.41     | npm/Homebrew                                                                | `~/.config/opencode/AGENTS.md` (or `CLAUDE.md` fallback), project `AGENTS.md`. `instructions:` field globs/URLs in `opencode.jsonc`                                                    |
| **Pi** (earendil-works)     | 0.74.0      | npm `@earendil-works/pi-coding-agent`                                       | `~/.pi/agent/AGENTS.md` (or `CLAUDE.md`), project `.pi/AGENTS.md` walk-up. `SYSTEM.md`/`APPEND_SYSTEM.md` for system prompt customization                                              |

Project-scope artifacts are inspected at session start; subdirectory CLAUDE.md / AGENTS.md load on-demand when those subdirs are accessed (Claude). Pi accepts `--no-context-files` / `-nc` to disable session-start loading.

## 2. Skills

### Per-harness skill loading paths (verified)

| Harness     | Reads from                                                                                                                                                                                                                                                             | Native? |
| ----------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- |
| Claude Code | `~/.claude/skills/<name>/`, `<repo>/.claude/skills/<name>/`, plugin caches                                                                                                                                                                                             | yes     |
| Codex CLI   | `$HOME/.agents/skills/`, `$CWD/.agents/skills/`, `$REPO_ROOT/.agents/skills/`, `/etc/codex/skills/`, bundled SYSTEM. Also reads deprecated `$CODEX_HOME/skills/` (i.e. `~/.codex/skills/`) at higher precedence. Source: `codex-rs/core-skills/src/loader.rs:293-320`. | yes     |
| OpenCode    | `.opencode/skills/`, `~/.config/opencode/skills/`, `.claude/skills/`, `~/.claude/skills/`, `.agents/skills/`, `~/.agents/skills/` (in that precedence order)                                                                                                           | yes     |
| Pi          | `~/.pi/agent/skills/`, `.pi/skills/`, `~/.agents/skills/`, `.agents/skills/`, packages, **plus any path in `skills:` settings array**                                                                                                                                  | yes     |

### Frontmatter compatibility (verified)

| Field                                                                                    | Claude  | Codex   | OpenCode                             | Pi                       |
| ---------------------------------------------------------------------------------------- | ------- | ------- | ------------------------------------ | ------------------------ |
| `name` (required)                                                                        | ✓       | ✓       | ✓ (regex `^[a-z0-9]+(-[a-z0-9]+)*$`) | ✓                        |
| `description` (required for Pi)                                                          | ✓       | ✓       | ✓ (1-1024 chars)                     | ✓ (hard-fail without it) |
| `paths:` (path-conditional auto-load)                                                    | ✓       | ignored | ignored                              | ignored                  |
| `argument-hint`, `arguments`                                                             | ✓       | ignored | ignored                              | ignored\*                |
| `allowed-tools`                                                                          | ✓       | ignored | ignored                              | ✓                        |
| `disable-model-invocation`                                                               | ✓       | ignored | ignored                              | ✓                        |
| `when_to_use`, `model`, `effort`, `context`, `agent`, `hooks`, `shell`, `user-invocable` | ✓       | ignored | ignored                              | ignored                  |
| `license`, `metadata`, `compatibility`                                                   | partial | partial | ✓                                    | ✓                        |

\*Pi gains `$ARGUMENTS`, `$1`-`$N`, `$@`, `${@:N}`, `${@:N:L}` substitution via the `@juicesharp/rpiv-args` extension.

Unrecognized fields are silently ignored (no errors). Minimum portable SKILL.md = `name + description + body`.

### Skill body argument substitution

| Surface                                            | Supports `$ARGUMENTS` / `$1`     |
| -------------------------------------------------- | -------------------------------- |
| Claude Code skill body                             | ✓                                |
| Claude Code command body (`.claude/commands/*.md`) | ✓                                |
| OpenCode `commands/*.md`                           | ✓                                |
| OpenCode skill body                                | ✗                                |
| Codex skill body                                   | ✗                                |
| Pi skill body                                      | ✓ (with `@juicesharp/rpiv-args`) |

### Description-based discovery

All four harnesses use the SKILL.md `description:` field at session-prompt time to decide whether to load the skill. Weak descriptions = skill stays invisible. Pattern that works: "Use when X. Triggers on Y. Skip if Z." Reference: `~/.dotfiles/Agents/.agents/skills/find-docs/SKILL.md` and `deep-audit/SKILL.md`.

## 3. Rules

### Claude Code rules (`.claude/rules/*.md`)

- Per [code.claude.com/docs/en/memory#organize-rules-with-claude/rules/](https://code.claude.com/docs/en/memory):
- Rules **without** `paths:` frontmatter load at session start with the same priority as `.claude/CLAUDE.md`.
- Rules **with** `paths:` frontmatter load only when Claude reads files matching the pattern (NOT on every tool use).
- Rules can be symlinks to skills (the existing pattern for python/typescript/scalability).
- User-level rules at `~/.claude/rules/` are loaded before project-level rules; project rules override.

### Codex rules (`.codex/rules/*.rules`)

- Starlark language (Python-like syntax). Source: [developers.openai.com/codex/rules](https://developers.openai.com/codex/rules).
- Define command-prefix gates with `prefix_rule()`: `pattern`, `decision` (allow/prompt/forbidden), `justification`.
- NOT a prose-rules system. Functionally distinct from Claude rules.
- This setup uses a single global `~/.codex/rules/default.rules` (allowlist for pnpm, gh, git, docker, curl, supabase, workmux).

### OpenCode "rules"

- Per [opencode.ai/docs/rules](https://opencode.ai/docs/rules) — NOT a separate subsystem.
- Rules = AGENTS.md content + external instruction files loaded via `instructions:` glob in opencode.jsonc.
- Project guidance per Cursor convention. Created/updated via `/init` command.

### Pi context files

- Pi accepts `AGENTS.md` or `CLAUDE.md` at global (`~/.pi/agent/`) and project locations.
- Pi has no separate "rules" concept; AGENTS.md content is the rule layer.
- `SYSTEM.md` (replace) or `APPEND_SYSTEM.md` (append) at the same locations override the system prompt entirely.

## 4. AGENTS.md / CLAUDE.md

### Per-harness behavior

| Harness     | File loaded                                                                               | Size cap                                                                                           | `@import` syntax                              | Concatenation                                                                           |
| ----------- | ----------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- | --------------------------------------------- | --------------------------------------------------------------------------------------- |
| Claude Code | `CLAUDE.md` only (NOT `AGENTS.md`)                                                        | None hard; Anthropic recommends < 200 lines per file (adherence drops above)                       | Yes — `@path/to/file`, max 5 hops             | All files in directory tree concatenated root-to-cwd; subdirectory files load on-demand |
| Codex CLI   | `AGENTS.override.md` then `AGENTS.md`, plus configurable `project_doc_fallback_filenames` | **32 KiB combined hard cap** (`project_doc_max_bytes`); silent truncation from start when exceeded | No                                            | Concatenated root-to-cwd; later files override earlier                                  |
| OpenCode    | `AGENTS.md`, falls back to `CLAUDE.md` if no AGENTS.md present                            | None documented; community recommends < 300 lines                                                  | No (uses `instructions:` for modular loading) | Project file > global `~/.config/opencode/AGENTS.md` > global `~/.claude/CLAUDE.md`     |
| Pi          | `AGENTS.md` or `CLAUDE.md` (either name)                                                  | None documented                                                                                    | No                                            | Walk-up from cwd to root, plus global `~/.pi/agent/<file>`                              |

### "Lost in the middle" adherence

LLMs allocate ~40-60% less attention to mid-context tokens than to head/tail tokens (Stanford 2023 onward; persists in 2026 frontier models). Practical impact: position critical instructions at top OR end of AGENTS.md; accept that mid-file content gets less reliable enforcement. Files >300 lines show 14-22% increase in reasoning tokens per the agents.md empirical study.

### HTML comments stripped (Claude only)

Block-level `<!-- maintainer note -->` HTML comments in CLAUDE.md are stripped before context injection. Use them for human notes that shouldn't consume tokens. Note: comments inside fenced code blocks are preserved.

### Single-canonical strategy (this setup)

Canonical file at `~/.dotfiles/Agents/.agents/AGENTS.md`. Each harness's expected location is a committed in-repo symlink:

- `Claude/.claude/CLAUDE.md` → `../../Agents/.agents/AGENTS.md`
- `Codex/.codex/AGENTS.md` → `../../Agents/.agents/AGENTS.md`
- `Config/.config/opencode/AGENTS.md` → `../../../Agents/.agents/AGENTS.md`
- `Pi/.pi/agent/AGENTS.md` → `../../../Agents/.agents/AGENTS.md`

Stage 4 verified all four `$HOME` paths resolve to identical SHA-256 content. Tool-specific bits (e.g. Codex sandbox note for ctx7, OpenCode artifacts directory) live in clearly-marked subsections within the canonical file.

## 5. Plugins

| Harness     | System                                                                                                                                                                            | Install path                                                                                                  |
| ----------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| Claude Code | Marketplaces (`claude-plugins-official` is auto-available); plugin = `.claude-plugin/plugin.json` + skills/ + agents/ + hooks/ subdirs. Skills namespace as `/plugin-name:skill`. | `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`                                                   |
| Codex CLI   | Plugins bundle skills + apps + MCP servers. Distinct from skills. Reference: [developers.openai.com/codex/plugins](https://developers.openai.com/codex/plugins).                  | Codex internal cache                                                                                          |
| OpenCode    | TypeScript modules exporting plugin functions. Hooks: `tool.execute.before`, `command.executed`, `file.edited`, etc.                                                              | `.opencode/plugins/` (project) or `~/.config/opencode/plugins/` (global), or npm packages via `plugin:` array |
| Pi          | "Extensions" (TypeScript) and "packages" (npm/git/local). Extensions register tools (`pi.registerTool`), providers (`pi.registerProvider`), event handlers (`pi.on`).             | Packages installed via `pi install npm:<name>`                                                                |

User's currently enabled Claude Code plugins (per `~/.claude/plugins/installed_plugins.json`): code-review, security-guidance, pyright-lsp, typescript-lsp, lua-lsp, frontend-design, semgrep, supabase, ui-ux-pro-max, claude-notifications-go, codex (OpenAI), skill-codex.

## 6. MCP Servers

| Harness     | Configuration location                                                                                                                                                  | MCP support |
| ----------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| Claude Code | `.mcp.json` (project, committed), `~/.claude.json` (user/local)                                                                                                         | ✓           |
| Codex CLI   | `[mcp_servers.<name>]` TOML tables in `~/.codex/config.toml` or `.codex/config.toml`                                                                                    | ✓           |
| OpenCode    | `mcp:` key in `~/.config/opencode/opencode.jsonc` or project `opencode.jsonc`                                                                                           | ✓           |
| Pi          | Via `pi-mcp-adapter`: `~/.pi/agent/mcp.json` (Pi global override), `.pi/mcp.json` (project override), plus shared `.mcp.json` / `~/.config/mcp/mcp.json` import support | via package |

User's global MCP servers: `context-mode` is enabled across Claude Code, Codex, OpenCode, and Pi via each harness's native config method. `magic` (21st.dev) and `stitch` (Google Stitch) are configured for Codex/OpenCode and disabled by default; enable per-need.

Per-project MCP examples:

- invest-platform `.mcp.json`: cloudflare, grafana, next-devtools, shadcn
- wedding-site `.mcp.json`: shadcn, next-devtools, stripe (with shell wrapper for env-var expansion since Claude doesn't expand `${VAR}` in args)

## 7. Hooks

| Harness     | Configuration                                                                                                                                                                                                                                                                                                                       | Events                                                                                                                                                                                                                                                                                                                                                                                              |
| ----------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Claude Code | `hooks` key in `settings.json` or skill/agent frontmatter                                                                                                                                                                                                                                                                           | 25+ events: SessionStart, Setup, InstructionsLoaded, UserPromptSubmit, PreToolUse, PermissionRequest, PostToolUse, PostToolUseFailure, PostToolBatch, PermissionDenied, Notification, SubagentStart/Stop, TaskCreated/Completed, Stop, StopFailure, TeammateIdle, ConfigChange, CwdChanged, FileChanged, WorktreeCreate/Remove, PreCompact, PostCompact, SessionEnd, Elicitation, ElicitationResult |
| Codex CLI   | `~/.codex/hooks.json` or project `.codex/hooks.json`. The `hooks` feature must be enabled in `config.toml`.                                                                                                                                                                                                                         | (subset; reference Codex docs)                                                                                                                                                                                                                                                                                                                                                                      |
| OpenCode    | TS plugin hooks via `pi.on()`-equivalent: `tool.execute.before`, `tool.execute.after`, `command.executed`, `file.edited`, `file.watcher.updated`, `installation.updated`, `lsp.client.diagnostics`                                                                                                                                  | per OpenCode plugin docs                                                                                                                                                                                                                                                                                                                                                                            |
| Pi          | TS extension event handlers via `pi.on(event, handler)`: `session_start`, `session_end`, `turn_start`, `turn_end`, `message_start`, `message_end`, `tool_call`, `tool_result`, `context`, `before_provider_request`, `after_provider_response`, `model_select`, `thinking_level_select`, `input`, `user_bash`, `before_agent_start` | per Pi extensions docs                                                                                                                                                                                                                                                                                                                                                                              |

User's global Claude Code hooks (from `~/.claude/settings.json`): workmux tmux status updates (Notification, PreToolUse, PostToolUse, Stop, UserPromptSubmit) and a SessionStart hook for session tracking.

## 8. Sub-agents

| Harness     | Read-only discovery                     | General execution / planning                                                                          |
| ----------- | --------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| Claude Code | `Explore` (Haiku, fast codebase search) | `Plan` (architect), `general-purpose`                                                                 |
| Codex CLI   | `explorer`                              | `default`, `worker`. Custom subagents at `~/.codex/agents/<name>.toml` or `.codex/agents/<name>.toml` |
| OpenCode    | `@explore`                              | `@general`. Custom agents in `opencode.jsonc` `agent` key or `.opencode/agents/*.md`                  |
| Pi          | via `pi-subagents` package              | via `pi-subagents` package                                                                            |

Pi's subagent support comes from the `pi-subagents` npm package (third-party, not core Pi). It provides 8 built-in agent personas (scout, researcher, planner, worker, reviewer, context-builder, oracle, delegate) and supports `.chain.md` workflow chains, parallel execution, git worktree isolation.

## 9. Settings

| Harness     | File                                                                                      | Format                                                                                                                                                                                                                                                                                                                        |
| ----------- | ----------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Claude Code | `~/.claude/settings.json`, project `.claude/settings.json`, `.claude/settings.local.json` | JSON. Keys: `permissions`, `env`, `hooks`, `statusLine`, `enabledPlugins`, `extraKnownMarketplaces`, `outputStyle`, `effortLevel`, `voice`, `autoMemoryEnabled`, etc.                                                                                                                                                         |
| Codex CLI   | `~/.codex/config.toml`, project `.codex/config.toml`                                      | TOML. Sections: top-level (`model`, `model_reasoning_effort`, `personality`), `[projects]`, `[plugins]`, `[features]`, `[mcp_servers.<name>]`, `[notice]`, `[tui]`                                                                                                                                                            |
| OpenCode    | `~/.config/opencode/opencode.jsonc`, project `opencode.jsonc`                             | JSONC. Keys: `provider`, `model`, `lsp`, `permission`, `formatter`, `mcp`, `agent`, `command`, `plugin`, `instructions`, `theme`, `keybinds`, `server`                                                                                                                                                                        |
| Pi          | `~/.pi/agent/settings.json`, project `.pi/settings.json`                                  | JSON. Keys: `defaultProvider`, `defaultModel`, `defaultThinkingLevel`, `packages`, `extensions`, `skills` (path array), `compaction`, `lastChangelogVersion`, UI preferences. Global `settings.json` is tracked in `.dotfiles/Pi/.pi/agent/settings.json`; `auth.json`, sessions, caches, and local databases stay untracked. |

## 10. Permissions Models

| Harness     | Mechanism                                                                                                                                                                                                                                     |
| ----------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Claude Code | `permissions.allow`, `permissions.ask`, `permissions.deny` arrays in settings.json. Pattern: `Tool(arg-pattern:*)`, e.g. `Bash(git push:*)`. Layered: managed > local > project > user > defaults                                             |
| Codex CLI   | Starlark `prefix_rule()` in `~/.codex/rules/default.rules`. Decisions: allow / prompt / forbidden. Plus per-project trust settings in `config.toml` `[projects]` section                                                                      |
| OpenCode    | `permission` key in opencode.jsonc with per-tool subkeys (bash, edit, read, glob, grep, task, skill, lsp, webfetch, websearch, external_directory, doom_loop). Actions: `allow`, `ask`, `deny`. Pattern matching with `*`, `?`, `~` expansion |
| Pi          | Extension-controlled. `pi.on("tool_call", ...)` handler can return `{block: true}` to deny                                                                                                                                                    |

## 11. Auto-memory

Claude Code only. Per [code.claude.com/docs/en/memory#auto-memory](https://code.claude.com/docs/en/memory):

- Storage: `~/.claude/projects/<project>/memory/` (per git repo; all worktrees and subdirs share one auto-memory directory)
- Loaded at session start: first 200 lines OR 25 KB of `MEMORY.md` (whichever first)
- Topic files (`debugging.md`, `api-conventions.md`, etc.) NOT loaded at startup; read on-demand
- Toggle via `/memory` command or `autoMemoryEnabled` setting; env var `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`
- Subagents can have separate persistent auto-memory

Codex / OpenCode / Pi have no auto-memory equivalent. Cross-session continuity must be handled via AGENTS.md updates or external systems.

## 12. Pi Packages and Extensions Inventory

User's currently installed Pi packages and local extensions are tracked in `.dotfiles/Pi/.pi/agent/settings.json`.

| Package / extension                      | What it does                                                                                                                                                                                                             |
| ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `pi-subagents`                           | Adds 8 built-in subagent personas; supports chains, parallel execution, TUI clarification, git worktree isolation                                                                                                        |
| `pi-web-access`                          | Adds `web_search` (Exa, Perplexity, Gemini), `code_search` (Exa MCP), `fetch_content` (URL+local with GitHub/YouTube/PDF specialization), `get_search_content`                                                           |
| `pi-lens`                                | Real-time pipeline on file writes: secrets detection, 26+ formatters, ESLint/Ruff auto-fix, LSP (37 servers), tree-sitter + ast-grep + Semgrep linting, dependency analysis. 35+ languages, 180+ ast-grep security rules |
| `packages/pi-statusline-footer`          | Local statusline/footer package: editor stash, working vibes, model/tokens/cost segments, bash mode                                                                                                                      |
| `@juicesharp/rpiv-args` v1.2.0           | **Adds `$ARGUMENTS` / `$1`-`$N` / `$@` / `${@:N}` / `${@:N:L}` substitution to Pi skill bodies.** Hooks `input`, `before_agent_start`, `session_start`                                                                   |
| `@juicesharp/rpiv-todo`                  | Persistent task tracking, `/todos` command, TUI overlay, dependency graph, survives `/reload` and compaction                                                                                                             |
| `@juicesharp/rpiv-ask-user-question`     | Tabbed-question dialog tool: 1-4 questions, 2-4 options each, single/multi-select, optional previews, free-text notes, Submit review tab                                                                                 |
| `pi-mcp-adapter`                         | Adds MCP support to Pi through a compact proxy tool, lazy server lifecycle, direct-tool promotion, and config discovery from `~/.pi/agent/mcp.json`, `.pi/mcp.json`, `.mcp.json`, and `~/.config/mcp/mcp.json`           |
| `extensions/all-core-tools.ts`           | Local extension that keeps all official Pi built-in tools active every session: `read`, `bash`, `edit`, `write`, `grep`, `find`, `ls`                                                                                    |
| `extensions/inline-skill-invocations.ts` | Local input-transform extension that lets `/skill:<name>` or `/<skill-name>` appear on its own line anywhere in a prompt, then rewrites the prompt so Pi's normal skill expansion runs.                                  |

`rpiv` = juicesharp's brand for a suite of Pi enhancements (from monorepo `rpiv-mono`).

## 13. Cross-Harness Compatibility Matrix

| Capability                                         | Claude Code                    | Codex CLI                                 | OpenCode                                      | Pi                            |
| -------------------------------------------------- | ------------------------------ | ----------------------------------------- | --------------------------------------------- | ----------------------------- |
| Session-start instructions (AGENTS.md / CLAUDE.md) | CLAUDE.md only                 | AGENTS.md, 32 KiB cap                     | AGENTS.md, fallback CLAUDE.md                 | AGENTS.md or CLAUDE.md        |
| `@import` in instructions                          | ✓                              | ✗                                         | ✗ (use `instructions:` field)                 | ✗                             |
| Path-conditional auto-load (`paths:` frontmatter)  | ✓ skills + rules               | ✗                                         | ✗                                             | ✗                             |
| Slash command invocation                           | ✓ `/skill`                     | partial (built-ins only; no user-defined) | ✓ `/cmd`                                      | configurable via extension    |
| `$ARGUMENTS` / `$1` body substitution              | ✓ skills + commands            | ✗                                         | ✓ commands only (not skills)                  | ✓ with `rpiv-args` extension  |
| Skill description-based discovery                  | ✓                              | ✓                                         | ✓                                             | ✓ (description hard-required) |
| MCP                                                | ✓                              | ✓                                         | ✓                                             | via `pi-mcp-adapter` package  |
| Auto-memory                                        | ✓                              | ✗                                         | ✗                                             | ✗                             |
| Sub-agents (built-in)                              | Explore, Plan, general-purpose | explorer, default, worker                 | @explore, @general (+ build, plan as primary) | via pi-subagents pkg          |
| Plugin system                                      | manifests + marketplaces       | bundled (skills + apps + MCP)             | TS modules + npm                              | TS extensions + npm packages  |
| Hooks                                              | ✓ 25+ events                   | ✓                                         | ✓ TS plugin hooks                             | ✓ via `pi.on()` in extensions |
| Reads `~/.agents/skills/` natively                 | ✗ (this setup uses symlinks)   | ✓                                         | ✓                                             | ✓                             |
| Reads `~/.claude/skills/` natively                 | ✓                              | ✗                                         | ✓ (fallback)                                  | ✓ if added to `skills:` array |
| HTML comment stripping                             | ✓                              | ✗                                         | ✗                                             | ✗                             |
| Project trust / sandboxing                         | permission-mode                | sandbox modes                             | permission patterns                           | extension-controlled          |

## 14. Provenance / Origin

Per-item mapping with origin classification and bucket assignment, documented during Stage 2 audit (read-only; no file moves yet). Buckets follow Q3:

- **A** — always-on context, migrates to AGENTS.md, original deleted
- **B** — path-conditional, lives as canonical SKILL.md with `paths:` frontmatter, single skill-symlink in `.claude/skills/`
- **C** — task/procedure, description-triggered, lives as canonical SKILL.md, single skill-symlink in `.claude/skills/`

### 14.1 Global scope

#### Skills currently in `.dotfiles/Agents/.agents/skills/`

| File                                        | Origin                                | Bucket                               | Migration                                                                                                                                                                                 |
| ------------------------------------------- | ------------------------------------- | ------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| python/SKILL.md                             | user-authored portable                | B                                    | Stay; path-conditional `**/*.py` `**/*.pyi`. Re-wire `Claude/.claude/rules/python.md` symlink → `Claude/.claude/skills/python` directory symlink                                          |
| typescript/SKILL.md                         | user-authored portable                | B                                    | Stay; path-conditional `**/*.ts` `**/*.tsx`. Re-wire as skill-symlink                                                                                                                     |
| scalability/SKILL.md                        | user-authored portable                | B                                    | Stay; path-conditional 20 backend file patterns. Re-wire as skill-symlink                                                                                                                 |
| security/SKILL.md                           | user-authored portable                | C (re-class)                         | Currently no `paths:`; description-triggered. **Note**: audit suggested A, but skill loading behavior without `paths:` is C. Stay as skill, add skill-symlink in `Claude/.claude/skills/` |
| commenting/SKILL.md                         | user-authored portable                | C (re-class)                         | Same reasoning as security; stay as skill, add skill-symlink                                                                                                                              |
| caveman/SKILL.md                            | Matt Pocock                           | C                                    | Stay as-is                                                                                                                                                                                |
| diagnose/SKILL.md                           | Matt Pocock                           | C                                    | Stay as-is                                                                                                                                                                                |
| grill-me/SKILL.md                           | Matt Pocock                           | C                                    | Stay as-is                                                                                                                                                                                |
| grill-with-docs/SKILL.md                    | Matt Pocock                           | C                                    | Stay as-is                                                                                                                                                                                |
| improve-codebase-architecture/SKILL.md      | Matt Pocock                           | C                                    | Stay as-is                                                                                                                                                                                |
| setup-matt-pocock-skills/SKILL.md           | Matt Pocock                           | C (`disable-model-invocation: true`) | Stay as-is                                                                                                                                                                                |
| tdd/SKILL.md                                | Matt Pocock                           | C                                    | Stay as-is                                                                                                                                                                                |
| to-issues/SKILL.md                          | Matt Pocock                           | C                                    | Stay as-is                                                                                                                                                                                |
| to-prd/SKILL.md                             | Matt Pocock                           | C                                    | Stay as-is                                                                                                                                                                                |
| triage/SKILL.md                             | Matt Pocock                           | C                                    | Stay as-is                                                                                                                                                                                |
| write-a-skill/SKILL.md                      | Matt Pocock                           | C                                    | Stay as-is                                                                                                                                                                                |
| zoom-out/SKILL.md                           | Matt Pocock                           | C (`disable-model-invocation: true`) | Stay as-is                                                                                                                                                                                |
| playwright-cli/SKILL.md                     | Matt Pocock-flavored / infrastructure | C                                    | Stay; `allowed-tools` inert outside Claude. No path constraints — description-triggered                                                                                                   |
| agentic-coding-harnesses/SKILL.md (Stage 1) | user-authored discovery               | C                                    | Stay; description-triggered when env modifications discussed                                                                                                                              |
| context7-cli/SKILL.md                       | Upstash Context7                      | C                                    | Added 2026-05-10; verbatim from `upstash/context7` commit `78b98266954d35da8aa93ad40c67df33a3ff4443`; skill-symlinked for Claude                                                          |
| find-docs/SKILL.md                          | Upstash Context7                      | C                                    | Added 2026-05-10; verbatim from `upstash/context7` commit `78b98266954d35da8aa93ad40c67df33a3ff4443`; replaces unmanaged live Claude copy and restores universal availability             |
| firecrawl-cli/SKILL.md                      | Firecrawl CLI                         | C                                    | Added 2026-05-10 from `firecrawl/cli` commit `efeb34d3fbe936d631e17ab55c19f096fb3ef189`; frontmatter name changed to `firecrawl-cli` to match directory; skill-symlinked for Claude       |
| firecrawl-scrape/SKILL.md                   | Firecrawl CLI                         | C                                    | Added 2026-05-10; verbatim from `firecrawl/cli` commit `efeb34d3fbe936d631e17ab55c19f096fb3ef189`; skill-symlinked for Claude                                                             |
| firecrawl-map/SKILL.md                      | Firecrawl CLI                         | C                                    | Added 2026-05-10; verbatim from `firecrawl/cli` commit `efeb34d3fbe936d631e17ab55c19f096fb3ef189`; skill-symlinked for Claude                                                             |

#### Skills currently in `.dotfiles/Claude/.claude/skills/` (16 personal-workflow)

All bucket **C** (description-triggered, most use `$ARGUMENTS`). All migrate to `.agents/skills/<name>/` in Stage 5; replace original with directory skill-symlink.

| Skill       | Uses args?         | Notable frontmatter                               |
| ----------- | ------------------ | ------------------------------------------------- |
| catchup     | no                 | `allowed-tools`                                   |
| coordinator | no                 | `disable-model-invocation: true`                  |
| deep-audit  | yes (`$ARGUMENTS`) | `argument-hint`, `disable-model-invocation: true` |
| fix-issue   | yes (`$ARGUMENTS`) | `argument-hint`, `disable-model-invocation: true` |
| merge       | yes (`$ARGUMENTS`) | `disable-model-invocation: true`                  |
| open-pr     | no                 | —                                                 |
| rebase      | yes (`$ARGUMENTS`) | `disable-model-invocation: true`                  |
| review      | no                 | —                                                 |
| ship        | yes (`$ARGUMENTS`) | `argument-hint`, `disable-model-invocation: true` |
| workmux     | no                 | —                                                 |
| worktree    | yes (`$ARGUMENTS`) | `disable-model-invocation: true`                  |

(Plus the 13 symlinks to `Agents/.agents/skills/` already covered above.)

#### Rules in `.dotfiles/Claude/.claude/rules/`

| File           | Type                                                   | Bucket | Migration                                                             |
| -------------- | ------------------------------------------------------ | ------ | --------------------------------------------------------------------- |
| context7.md    | user-authored CLI wrapper (real file)                  | A      | Always-on; consider moving content into canonical AGENTS.md (Stage 4) |
| python.md      | symlink → `Agents/.agents/skills/python/SKILL.md`      | B      | Replace with skill-symlink in Stage 5                                 |
| typescript.md  | symlink → `Agents/.agents/skills/typescript/SKILL.md`  | B      | Replace with skill-symlink in Stage 5                                 |
| scalability.md | symlink → `Agents/.agents/skills/scalability/SKILL.md` | B      | Replace with skill-symlink in Stage 5                                 |

#### Rules in `.dotfiles/Codex/.codex/rules/`

| File          | Type                              | Bucket | Migration                     |
| ------------- | --------------------------------- | ------ | ----------------------------- |
| default.rules | Starlark prefix-rules (allowlist) | n/a    | Different system; stays as-is |

#### Skills in `.dotfiles/Codex/.codex/skills/` (11 duplicates)

All going away in Stage 6. Note: drift detected vs Claude/.claude/skills versions:

- fix-issue: Codex 211 lines vs Claude 271 lines (60-line drift, Claude is newer)
- review: Codex 238 lines vs Claude 286 lines (48-line drift, Claude is newer)
- Others: minor formatting drift only

Before Stage 6 deletion, verify the canonical Claude versions don't lose features that exist in Codex versions.

### 14.2 Houndarr (`Developer/Houndarr/`)

#### Skills `.agents/skills/`

| Skill                 | `paths:`                   | Bucket | Migration (Stage 8)                                                                                                 |
| --------------------- | -------------------------- | ------ | ------------------------------------------------------------------------------------------------------------------- |
| houndarr-architecture | `src/houndarr/**`          | B      | Re-wire `.claude/rules/houndarr-architecture.md` symlink → `.claude/skills/houndarr-architecture` directory symlink |
| houndarr-changelog    | `CHANGELOG.md`, `VERSION`  | B      | Re-wire as skill-symlink                                                                                            |
| houndarr-ci           | `.github/workflows/**`     | B      | Re-wire as skill-symlink                                                                                            |
| houndarr-database     | `src/houndarr/database.py` | B      | Re-wire as skill-symlink                                                                                            |
| houndarr-python       | `**/*.py`                  | B      | Re-wire as skill-symlink                                                                                            |
| houndarr-testing      | `tests/**`                 | B      | Re-wire as skill-symlink                                                                                            |
| verify-algorithms     | `src/houndarr/engine/**`   | B      | Re-wire as skill-symlink                                                                                            |
| bump                  | no                         | C      | Add skill-symlink in `.claude/skills/bump`                                                                          |
| check                 | no                         | C      | Add skill-symlink                                                                                                   |
| test                  | no                         | C      | Add skill-symlink                                                                                                   |

#### Rules `.claude/rules/`

| File                                 | Type                 | Bucket | Migration                                                                                     |
| ------------------------------------ | -------------------- | ------ | --------------------------------------------------------------------------------------------- |
| hook-compliance.md                   | real file (77 lines) | A      | Move content into Houndarr AGENTS.md, delete file                                             |
| (7 rule-symlinks to .agents/skills/) | symlink              | B      | Delete each rule-symlink; create directory skill-symlink at `.claude/skills/<name>` (Stage 8) |

#### Commands `.claude/commands/` and `.opencode/commands/`

3 commands (bump, check, test) duplicated across `.claude/commands/`, `.opencode/commands/`, AND `.agents/skills/`. Per Claude Code docs, `.claude/commands/foo.md` and `.claude/skills/foo/SKILL.md` are equivalent.

| Command | Canonical                       | Action                                                                                                  |
| ------- | ------------------------------- | ------------------------------------------------------------------------------------------------------- |
| bump    | `.agents/skills/bump/SKILL.md`  | Delete `.claude/commands/bump.md` and `.opencode/commands/bump.md`. Skill-symlink in `.claude/skills/`. |
| check   | `.agents/skills/check/SKILL.md` | Same                                                                                                    |
| test    | `.agents/skills/test/SKILL.md`  | Same                                                                                                    |

#### Top-level files

| File       | Lines | Size    | Status                                              |
| ---------- | ----- | ------- | --------------------------------------------------- |
| AGENTS.md  | 507   | 20 KiB  | Comfortable under Codex 32 KiB cap. No trim needed. |
| CONTEXT.md | 88    | 3.4 KiB | Domain glossary. Keep as-is.                        |
| CLAUDE.md  | 1     | —       | `@AGENTS.md` stub. Correct.                         |

### 14.3 invest-platform (`Developer/invest-platform/`)

#### Skills

| Skill           | Location                        | Bucket                            | Migration (Stage 8)                                                                                                                                                               |
| --------------- | ------------------------------- | --------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| opengrep        | `.claude/skills/opengrep/`      | B (or C; verify)                  | Move to `.agents/skills/opengrep/`. Add skill-symlink.                                                                                                                            |
| sprint-plan     | `.claude/skills/sprint-plan/`   | C (`argument-hint`, `$ARGUMENTS`) | Move to `.agents/skills/sprint-plan/`. Add skill-symlink.                                                                                                                         |
| sprint-pr       | `.claude/skills/sprint-pr/`     | C (same)                          | Move to `.agents/skills/sprint-pr/`. Add skill-symlink.                                                                                                                           |
| check           | `.agents/skills/check/`         | C                                 | Add skill-symlink.                                                                                                                                                                |
| linear-sync     | `.agents/skills/linear-sync/`   | C                                 | Add skill-symlink. **DRIFT** — `.claude/commands/linear-sync.md` and `.opencode/commands/linear-sync.md` are stale (270-line drift). Delete both; canonical is `.agents/skills/`. |
| new-component   | `.agents/skills/new-component/` | C                                 | Add skill-symlink. Delete duplicates in `.claude/commands/`, `.opencode/commands/`.                                                                                               |
| new-adapter     | same                            | C                                 | Same                                                                                                                                                                              |
| new-migration   | same                            | C                                 | Same                                                                                                                                                                              |
| progress-update | same                            | C                                 | Same                                                                                                                                                                              |

#### Rules `.claude/rules/`

| File                      | `paths:`/`globs:`/`trigger:`      | Bucket                 | Migration                                                                                                  |
| ------------------------- | --------------------------------- | ---------------------- | ---------------------------------------------------------------------------------------------------------- |
| commenting.md             | none                              | A                      | Move to AGENTS.md, delete file (Stage 8)                                                                   |
| dev-credentials.md        | none                              | A                      | Move to AGENTS.md, delete file                                                                             |
| frontend-ui.md            | `trigger: *.tsx,*.css,*.scss`     | B                      | Stay scoped; standardize frontmatter to `paths:`                                                           |
| git-workflow.md           | none                              | A                      | Move to AGENTS.md, delete file                                                                             |
| linear-conventions.md     | none                              | A                      | Move to AGENTS.md, delete file                                                                             |
| plan-mode.md              | none                              | A (or delete entirely) | 17 lines about PreToolUse hook; either inline as comment in settings.json or move 1-line note to AGENTS.md |
| security-compliance.md    | none                              | A                      | Move to AGENTS.md, delete file                                                                             |
| testing-patterns.md       | `globs: tests/**`                 | B                      | Stay scoped; convert to skill with `paths:` (Stage 8)                                                      |
| typescript-conventions.md | `globs: **/*.ts,*.tsx`            | B                      | Stay scoped; convert to skill with `paths:`                                                                |
| writing-style.md          | `globs: **/*.md,*.mdx,.github/**` | B                      | Stay scoped; convert to skill with `paths:`                                                                |

#### Top-level files

| File       | Lines | Size                                   | Status                                                                                        |
| ---------- | ----- | -------------------------------------- | --------------------------------------------------------------------------------------------- |
| AGENTS.md  | 694   | **32,079 bytes (AT Codex 32 KiB cap)** | **Critical**: at the boundary. Trim plan in section 17 / Stage 8. Target ~210 lines / 11 KiB. |
| CONTEXT.md | 41    | 2 KiB                                  | Domain glossary. Keep.                                                                        |
| CLAUDE.md  | 1     | —                                      | `@AGENTS.md` stub. Correct.                                                                   |

### 14.4 wedding-site (`Developer/wedding-site/`)

#### Skills `.agents/skills/`

| Skill                 | Bucket                      | Migration                                                          |
| --------------------- | --------------------------- | ------------------------------------------------------------------ |
| stripe-best-practices | B (toolkit, infrastructure) | Already skill-wired in `.claude/skills/`. No change.               |
| stripe-projects       | C (or A; verify)            | Already skill-wired. **Description weak** (49 chars; Stage 3 fix). |
| upgrade-stripe        | C                           | Already skill-wired. **Description weak** (49 chars; Stage 3 fix). |

#### Rules `.claude/rules/`

| File               | `paths:`/`globs:`                               | Bucket                          | Migration                                                                                                                                                                   |
| ------------------ | ----------------------------------------------- | ------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| frontend-ui.md     | `paths: **` (all files)                         | A (effectively, with `**`) or B | Already broad-scoped. Either keep as path-scoped rule or move content to AGENTS.md.                                                                                         |
| git-workflow.md    | none                                            | A                               | Move to AGENTS.md (Stage 8)                                                                                                                                                 |
| paulinas-branch.md | none (branch-conditional, not file-conditional) | A or C                          | Branch-conditional behavior isn't a Claude rule mechanism. Stay as bucket A in AGENTS.md, OR convert to description-triggered skill ("Use when working on paulinas-branch") |

#### Top-level files

| File       | Status                                                                                                                                                                                                           | Notes                      |
| ---------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------- |
| AGENTS.md  | **PROBLEM**: file is just `@AGENTS.md` (1 line) — same content as CLAUDE.md. Audit calls this "broken". Investigate Stage 8: was this meant to be the canonical content with CLAUDE.md as stub, but got swapped? |
| CLAUDE.md  | 219 lines, 20 KiB                                                                                                                                                                                                | Has all the actual content |
| CONTEXT.md | 78 lines, 3 KiB                                                                                                                                                                                                  | Domain glossary. Keep.     |

#### skills-lock.json

All 3 SHA-256 hashes are STALE (skills modified May 3, lock not updated). Decision needed:

- Recompute hashes (preserve the integrity-checking pattern)
- Remove the lock file (simpler, accept that we don't pin Stripe skills)

### 14.5 Imported skills NOT version-tracked

Per Q4. Live as real directories at `~/.agents/skills/` and `~/.claude/skills/`, outside dotfiles.

| Skill                            | Source                                        |
| -------------------------------- | --------------------------------------------- |
| deploy-to-vercel                 | Vercel plugin or setup-script                 |
| doc-coauthoring                  | Claude.ai desktop chat app                    |
| find-skills                      | utility (origin unattributed)                 |
| frontend-design                  | Claude Code plugin (claude-plugins-official)  |
| supabase                         | Supabase plugin                               |
| supabase-postgres-best-practices | Supabase plugin                               |
| vercel-cli-with-tokens           | Vercel plugin                                 |
| vercel-composition-patterns      | Vercel plugin                                 |
| vercel-react-best-practices      | Vercel plugin                                 |
| vercel-react-native-skills       | Vercel plugin (description blocker — Stage 3) |
| vercel-react-view-transitions    | Vercel plugin                                 |
| web-design-guidelines            | Claude Code plugin                            |
| webapp-testing                   | playwright/testing plugin                     |

These are not modified by alignment work. Stage 3 fixes the 2 description blockers in-place but does not bring them under version control.

## 15. File Layout

Canonical tree of `~/.dotfiles/` after the alignment migration. **R** = real file, **S→** = committed symlink with target. Stow installs each top-level dir into `$HOME` matching its inner path structure.

```
~/.dotfiles/
├── Agents/                                 # NEW canonical pool
│   └── .agents/
│       ├── AGENTS.md  (R)                  # canonical for all 4 harnesses
│       └── skills/
│           ├── agentic-coding-harnesses/   (R, Stage 1)
│           │   └── SKILL.md
│           ├── caveman/                    (R, Matt Pocock)
│           ├── catchup/                    (R, Stage 5 migration)
│           ├── deep-audit/                 (R, Stage 5 migration)
│           ├── ship/, merge/, rebase/, ...  (Stage 5 migrations)
│           ├── python/, typescript/, scalability/, security/, commenting/
│           └── ...                         (12 Matt Pocock + 5 conventions + 11 personal workflow + 1 discovery = 29 canonical skills)
├── Claude/
│   └── .claude/
│       ├── CLAUDE.md       S→ ../../Agents/.agents/AGENTS.md
│       ├── settings.json   (R)             # permissions, hooks, plugins, statusline
│       ├── rules/                          # 4 entries
│       │   ├── context7.md       (R)       # ctx7 CLI wrapper (only "real" global rule)
│       │   ├── python.md         S→ ../../../Agents/.agents/skills/python/SKILL.md
│       │   ├── typescript.md     S→ ../../../Agents/.agents/skills/typescript/SKILL.md
│       │   └── scalability.md    S→ ../../../Agents/.agents/skills/scalability/SKILL.md
│       └── skills/                         # 41 entries (all symlinks)
│           ├── catchup           S→ ../../../Agents/.agents/skills/catchup
│           ├── caveman           S→ ../../../Agents/.agents/skills/caveman
│           └── ...                         # all symlinks pointing into Agents pool
├── Codex/
│   └── .codex/
│       ├── AGENTS.md       S→ ../../Agents/.agents/AGENTS.md
│       ├── config.toml     (R)             # model, projects, plugins, MCP, features
│       ├── rules/
│       │   └── default.rules    (R)        # Starlark prefix-rules
│       └── (NO skills dir — deleted Stage 6; Codex reads ~/.agents/skills/ natively)
├── Config/
│   └── .config/
│       └── opencode/
│           ├── AGENTS.md   S→ ../../../Agents/.agents/AGENTS.md
│           ├── opencode.jsonc   (R)        # model, providers, lsp, permission, mcp, agents, formatter
│           ├── package.json     (R)        # plugin deps
│           ├── tui.json         (R)        # TUI customization
│           └── plugins/                    # OpenCode TS plugins
├── Pi/                                     # Pi global config package
│   └── .pi/
│       └── agent/
│           ├── AGENTS.md       S→ ../../../Agents/.agents/AGENTS.md
│           ├── extensions/
│           │   └── all-core-tools.ts (R)  # enables all official Pi built-in tools every session
│           ├── mcp.json        (R)        # Pi MCP adapter global override (no secrets)
│           ├── packages/
│           │   └── pi-statusline-footer/  # local Pi statusline/footer package
│           └── settings.json   (R)        # model defaults, packages, extensions, non-secret UI settings
├── docs/                                   # NEW package (Stage 1); .stow-local-ignore: .+
│   ├── .stow-local-ignore  (R)             # ignore everything (don't stow)
│   ├── AGENTIC-CODING-HARNESSES.md (R)     # this runbook
│   └── cross-tool-standardization/         # prior research (preserved)
├── scripts/                                # .stow-local-ignore: .+
└── (other stow packages: AgentWorktrees/, App-Configs/, Fonts/, Formatting-Files/,
   Git/, Java-Jars/, Local/, macOS-Library/, SSH/, ZSH/)
```

**Per-project layout** (Houndarr / wedding-site / invest-platform):

```
<repo>/
├── AGENTS.md       (R)                     # project canonical (CLAUDE.md is one-line @AGENTS.md stub)
├── CLAUDE.md       (R, just "@AGENTS.md")
├── CONTEXT.md      (R)                     # domain glossary
├── .agents/skills/ (R dirs)                # project-specific skills (canonical)
└── .claude/
    ├── settings.json (R)
    ├── rules/      (R, path-scoped only after migration)
    └── skills/     (S→, symlinks to .agents/skills/<name>)
```

## 16. Procedures

### Add a new skill

1. Decide the bucket: **A** (always-on) → don't make a skill; add content to AGENTS.md. **B** (path-conditional) → SKILL.md with `paths:` frontmatter. **C** (task/procedure) → SKILL.md with description-trigger.
2. Create the canonical SKILL.md at `~/.dotfiles/Agents/.agents/skills/<name>/SKILL.md`. Required frontmatter: `name` (lowercase-hyphens), `description` (write a strong "Use when X. Triggers on Y." description; Pi will hard-skip empty descriptions).
3. For Claude Code visibility, create a directory symlink: `cd ~/.dotfiles && ln -s ../../../Agents/.agents/skills/<name> Claude/.claude/skills/<name>`.
4. Run `cd ~/.dotfiles && stow --restow Agents Claude` to wire `$HOME` symlinks.
5. Verify all 4 harnesses see the skill: `ls ~/.agents/skills/<name>/SKILL.md` and `ls -L ~/.claude/skills/<name>/SKILL.md`.

### Modify an imported skill (Matt Pocock or installer-managed)

1. Edit the file directly under `~/.dotfiles/Agents/.agents/skills/<name>/SKILL.md`.
2. Commit with a clear message describing the modification rationale.
3. **Add an entry to section 18 (Modification Ledger)** with date, skill name, what changed, why, and how to re-apply.
4. Re-running the installer (e.g. `setup-matt-pocock-skills`) writes through the stow symlink → produces a git diff. Review with `git diff Agents/`. Decide whether to keep the upstream version (revert your change) or re-apply your modification per the ledger entry.

### Trim AGENTS.md exceeding the Codex 32 KiB cap

1. Identify the operational sections that don't strictly need always-on context: extended CLI catalogs, full procedural runbooks, library-specific deep dives.
2. Move each to a topical doc file (`docs/runbooks/<topic>.md` or similar). Keep AGENTS.md as a hub with brief 3-10 line summaries and links.
3. Delete temporary debt sections (e.g. "Pre-Launch Password Gate") that are TODO-flavored.
4. Verify size: `wc -c <repo>/AGENTS.md`. Target: < 30 KiB to leave headroom for future additions.
5. Anthropic recommends < 200 lines per CLAUDE.md/AGENTS.md; over 300 lines reliably increases reasoning tokens 14-22% per agents.md research. Prefer subdir AGENTS.md (loads on-demand in Claude) over one massive root file when content is dir-specific.

### Handle a plugin or setup-script re-install that overwrites tracked content

1. After running the installer, check `git status`/`git diff` in dotfiles.
2. For each modified file under `Agents/`, decide:
    - Accept upstream → `git checkout -- <path>` (keep installer version, drop your edits).
    - Keep your version → `git restore --source HEAD~1 <path>` (revert to last commit).
    - Merge → manually reconcile, commit with rationale.
3. **Add ledger entry** documenting the conflict resolution.

### Track Pi settings safely

1. Inspect `~/.pi/agent/settings.json` before tracking. It should contain model defaults, package names, extension paths, skill paths, compaction settings, and UI preferences only.
2. Do **not** track `~/.pi/agent/auth.json`, `sessions/`, `mcp-cache.json`, context-mode SQLite databases, provider credentials, literal bearer tokens, or generated package caches. Tracked local Pi packages under `Pi/.pi/agent/packages/` should be source code, not generated dependency caches.
3. Move safe settings into the Pi stow package: `mv ~/.pi/agent/settings.json ~/.dotfiles/Pi/.pi/agent/settings.json`.
4. Re-stow: `cd ~/.dotfiles && stow --restow Pi`.
5. Verify the live file is a symlink: `ls -l ~/.pi/agent/settings.json`.
6. If adding MCP config later, track `mcp.json` only when it uses command/env-var references rather than literal tokens.

### Customize Pi Plannotator phase prompts

1. Edit the tracked config at `Pi/.pi/agent/plannotator.json`, not the installed package under Homebrew or npm paths.
2. Keep Plannotator template variables such as `${planFilePath}` and `${todoList}` when overriding the executing prompt. The variable name `${todoList}` is internal Plannotator prompt plumbing, not the external `todo` tool.
3. In Plannotator's code, plan checkboxes are parsed into `checklistItems`, rendered to the model as Remaining steps, and marked complete only when the assistant emits `[DONE:n]` for item `n`.
4. Validate after edits with `python3 -m json.tool Pi/.pi/agent/plannotator.json >/dev/null`.
5. Verify the live file is still the stow-managed symlink: `ls -l ~/.pi/agent/plannotator.json`.

### Track Pi extensions safely

1. Store non-secret global Pi extensions under `Pi/.pi/agent/extensions/`.
2. Add relative paths to `.dotfiles/Pi/.pi/agent/settings.json`, e.g. `"extensions": ["extensions/all-core-tools.ts"]`.
3. Keep extension code free of credentials, literal bearer tokens, local database paths, or generated cache content.
4. Re-stow: `cd ~/.dotfiles && stow --restow Pi`.
5. Verify the live extension resolves from the stow package: `ls -l ~/.pi/agent/extensions/<name>.ts`.
6. For global core-tool activation, keep `all-core-tools.ts`: it uses Pi's documented `pi.setActiveTools()` extension API to activate official built-ins, without registering replacement tools.

### Re-stow after adding a top-level package (or after deletions)

1. `cd ~/.dotfiles && stow --restow <PackageName>` (or `*/` for all).
2. **Stow does NOT clean up orphan `$HOME` symlinks** when their target source has been deleted from the package. Manual cleanup: `find ~/<dir> -type l -! -exec test -e {} \; -delete` (POSIX find variant) or for known paths, `rm <path>` for each broken symlink. Stage 6 hit this: deleted `Codex/.codex/skills/` in the package, but `~/.codex/skills/<11 broken symlinks>` remained until manual cleanup in Stage 9.
3. After cleanup, `stow --restow` again to ensure package state is consistent.

### Debug "skill not loading"

Per-harness diagnostic flow:

| Harness     | Symptom                                                     | Check                                                                                                                                                                                                                                                            |
| ----------- | ----------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Pi          | Skill is invisible to model                                 | (1) Does SKILL.md have a non-empty `description:` field? Pi hard-skips skills without one. (2) Is the skill in a Pi-discoverable path? Run `pi list-skills` if available; verify `skills:` array in `~/.pi/agent/settings.json` includes the skill's parent dir. |
| Pi          | `/skill:<name>` only works when it is the whole first token | Core Pi only expands skill commands when the prompt starts with `/skill:`. This setup includes `extensions/inline-skill-invocations.ts`; reload Pi, then put `/skill:<name>` or `/<skill-name>` on its own line anywhere in the message.                         |
| Claude Code | Skill doesn't auto-load on path match                       | Verify `paths:` frontmatter is correct YAML. Use the `InstructionsLoaded` hook to log what loaded.                                                                                                                                                               |
| Codex       | Skill not in slash menu / `$<name>` invocation fails        | Verify SKILL.md is at `~/.agents/skills/<name>/SKILL.md` (canonical) or `~/.codex/skills/<name>/SKILL.md` (deprecated). Ensure name is lowercase-alphanumeric-hyphens.                                                                                           |
| OpenCode    | Skill not surfaced                                          | OpenCode validates name regex `^[a-z0-9]+(-[a-z0-9]+)*$`. Capital letters or underscores cause silent skip.                                                                                                                                                      |
| All         | Description-discovery failing                               | The model picks skills based on description trigger words. If the description is generic ("Helps with X"), the model won't reach for it. Rewrite description as "Use when X. Triggers on Y/Z. Skip if Q."                                                        |

### Verify each harness loads correctly

1. Hash check: `for p in ~/.claude/CLAUDE.md ~/.codex/AGENTS.md ~/.config/opencode/AGENTS.md ~/.pi/agent/AGENTS.md ~/.agents/AGENTS.md; do shasum -a 256 "$p"; done` — all 5 should match.
2. Claude Code: launch any session, run `/memory`, confirm CLAUDE.md content matches canonical.
3. Codex: launch `codex` in any directory, confirm session-start instructions match. For repos near the 32 KiB cap, watch for missing leading content (silent truncation from start).
4. OpenCode: launch `opencode`, check session-start.
5. Pi: launch `pi`, ask about agentic environment to confirm `agentic-coding-harnesses` skill triggers.
6. Slash invocation: in Claude, try `/ship` or `/catchup` — should resolve to canonical skill.
7. Path-conditional: edit a `.py` file in any project — Claude should auto-load `python` rule (it's a `paths:`-frontmatter symlink to the canonical skill).

## 17. Cap & Adherence Cheatsheet

| Harness     | Hard cap                                                   | Soft guideline                                  | Truncation behavior                                          |
| ----------- | ---------------------------------------------------------- | ----------------------------------------------- | ------------------------------------------------------------ |
| Claude Code | None                                                       | < 200 lines per CLAUDE.md/AGENTS.md (Anthropic) | None — full file loaded; adherence drops on long files       |
| Codex CLI   | **32 KiB combined `project_doc_max_bytes`** (configurable) | Same                                            | **Silent truncation from start** when exceeded; no warning   |
| OpenCode    | None documented                                            | < 300 lines (community / agents.md research)    | None documented                                              |
| Pi          | None documented                                            | Same                                            | None; but skills with empty `description:` hard-fail to load |

### Skill description quality

| Indicator                                                                                       | Effect                                                |
| ----------------------------------------------------------------------------------------------- | ----------------------------------------------------- |
| Description contains explicit trigger phrases ("Use when X", "Triggers on Y")                   | Model reaches for skill reliably                      |
| Description is generic ("Helps with X", "A skill for Y")                                        | Model doesn't trigger; skill stays invisible          |
| Description is empty                                                                            | Pi: hard-skipped. Other harnesses: silently invisible |
| Description starts with the action ("Audit code", "Create PR")                                  | Strong signal                                         |
| Description names the user phrases that should invoke ("Use when user says: review my changes") | Strongest signal                                      |

### "Lost in the middle"

| Position             | Attention weight |
| -------------------- | ---------------- |
| Beginning of context | High             |
| End of context       | High             |
| Middle               | 40-60% lower     |

Practical: critical AGENTS.md content goes near the top OR near the end. Mid-file sections experience reliability drops, especially in files >300 lines. (Stanford 2023 research; persists in 2026 frontier models.)

### Per-project current state (post-Stage-9 verification)

| Project         | AGENTS.md            | Cap utilization                        |
| --------------- | -------------------- | -------------------------------------- |
| Houndarr        | 547 lines / 23.7 KiB | 72%                                    |
| wedding-site    | 418 lines / 32.2 KiB | **98% — at the cap, 587 bytes margin** |
| invest-platform | 397 lines / 28.6 KiB | 87% (4 KiB headroom)                   |
| Global          | 226 lines / 11.4 KiB | 35%                                    |

## 18. Modification Ledger

Running log of modifications made to imported / external skills, and of plugin re-install conflicts resolved. Each entry captures: date, skill name, what changed, why, how to re-apply if overwritten. Populated during execution and ongoing thereafter.

### 2026-05-07 — Stage 3 false-alarm verification

The Stage 2 audit's "Tier 1 description blocker" classification for three files was **incorrect**. Verification with frontmatter parsing confirmed:

- `~/.agents/skills/vercel-react-native-skills/SKILL.md` — name `vercel-react-native-skills`, description 295 chars (valid YAML implicit multi-line plain scalar)
- `~/.agents/skills/vercel-composition-patterns/SKILL.md` — name `vercel-composition-patterns`, description 310 chars (valid)
- `.dotfiles/Codex/.codex/skills/deep-audit/SKILL.md` — name `deep-audit` (NOT `caveman` as previous audit claimed), description 466 chars (valid)

Likely cause: the audit used a parser that didn't handle YAML's indented continuation form (`description:` on one line followed by indented continuation lines on subsequent lines). All three files are correctly formed per YAML 1.2.

**No file modifications made.** If Pi (or any harness) is in fact failing to load these skills, the cause is downstream of frontmatter validity — possibly the harness's `skills:` configuration or its YAML parser strictness. Investigate during Stage 9 verification.

### 2026-05-07 — Stage 6 cleanup: orphan Codex symlinks

After deleting `.dotfiles/Codex/.codex/skills/` in Stage 6 and running `stow --restow Codex`, 11 broken symlinks remained at `~/.codex/skills/<name>` pointing to the now-deleted dotfiles paths. **Stow does not clean up orphan symlinks** whose target source has been deleted from the package — it only manages symlinks for content that still exists in the package.

Cleanup performed in Stage 9: `for skill in catchup coordinator deep-audit fix-issue merge open-pr rebase review ship workmux worktree; do rm "$HOME/.codex/skills/$skill"; done`. After cleanup, `~/.codex/skills/` contains only `.system/` (Codex's bundled system skills).

**Lesson recorded in section 16 (Procedures: Re-stow after deletions).** Future deletions of dotfiles content should be followed by manual `find` for broken symlinks in `$HOME` and explicit `rm`.

### 2026-05-07 — Global skills cleanup + 4 official skills brought back

**Removed** (14 inappropriately-global skills at `~/.agents/skills/` that were real directories outside dotfiles, source unknown but not Codex-installed):

`vercel-cli-with-tokens`, `vercel-composition-patterns`, `vercel-react-best-practices`, `vercel-react-native-skills`, `vercel-react-view-transitions`, `deploy-to-vercel`, `supabase` (v0.1.2 stale), `supabase-postgres-best-practices` (stale), `web-design-guidelines`, `webapp-testing`, `doc-coauthoring`, `find-docs`, `find-skills`, `frontend-design`

After cleanup, `~/.agents/skills/` count: 44 → 30. All 30 remaining entries are stow-managed symlinks pointing into `.dotfiles/Agents/.agents/skills/`. The `supabase` and `supabase-postgres-best-practices` skills remain available via the project-scoped `supabase@claude-plugins-official` plugin (newer v0.1.6, namespaced as `supabase:supabase`). The `frontend-design` skill remains available via the globally-enabled `frontend-design@claude-plugins-official` plugin (namespaced as `frontend-design:frontend-design`).

**Brought back** (4 official Anthropic skills from [anthropics/skills](https://github.com/anthropics/skills/tree/main/skills) repo, version-tracked in dotfiles):

| Skill                    | Path                                                                                      | Modifications                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| ------------------------ | ----------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `skill-creator`          | `Agents/.agents/skills/skill-creator/` (248 KB with `scripts/`, `references/`, `assets/`) | None (verbatim copy)                                                                                                                                                                                                                                                                                                                                                                                                                            |
| `webapp-testing`         | `Agents/.agents/skills/webapp-testing/` (32 KB with `scripts/`)                           | None (verbatim copy)                                                                                                                                                                                                                                                                                                                                                                                                                            |
| `doc-coauthoring`        | `Agents/.agents/skills/doc-coauthoring/` (16 KB)                                          | None (verbatim copy)                                                                                                                                                                                                                                                                                                                                                                                                                            |
| `frontend-design-global` | `Agents/.agents/skills/frontend-design-global/` (20 KB)                                   | **Renamed** from `frontend-design` to avoid namespace collision with the `frontend-design@claude-plugins-official` plugin's bundled skill. **Generalized** language: replaced "Claude is capable of extraordinary creative work" → "a frontier LLM is capable of extraordinary creative work". Added `metadata.origin: anthropics/skills (frontend-design)` and `metadata.fork-reason: Cross-harness availability and harness-neutral language` |

All 4 are now visible globally to all 4 harnesses via `~/.agents/skills/` (Codex / OpenCode / Pi read natively; Claude Code reads via stow-installed symlink at `~/.claude/skills/...` if added there, otherwise via the agentic-coding-harnesses cross-harness layer).

If Anthropic publishes updates to these skills, manual sync from `https://github.com/anthropics/skills/tree/main/skills` is required (no auto-update mechanism). For `frontend-design-global`, re-apply the rename + harness-neutral language tweaks after pulling a new upstream version.

### 2026-05-09: Pi inline skill invocation extension

Added `Pi/.pi/agent/extensions/inline-skill-invocations.ts`, a user-owned Pi input-transform extension. It detects `/skill:<name>` or `/<skill-name>` on its own non-fenced line anywhere in the user's prompt, rewrites the message to start with `/skill:<name>`, and preserves the surrounding text as skill arguments. This works around core Pi's documented behavior: skill command expansion only happens when the raw prompt starts with `/skill:`.

Validation performed with a Node unit test for explicit, bare, inline-argument, fenced-code, unknown-command, and already-wrapped cases, plus Pi's `loadExtensions()` loader against the new extension file.

### 2026-05-10: Upstash Context7 skills added

Added two Upstash Context7 skills from `https://github.com/upstash/context7/tree/master/skills` at commit `78b98266954d35da8aa93ad40c67df33a3ff4443`:

| Skill          | Path                                                     | Modifications       |
| -------------- | -------------------------------------------------------- | ------------------- |
| `context7-cli` | `Agents/.agents/skills/context7-cli/` with `references/` | None, verbatim copy |
| `find-docs`    | `Agents/.agents/skills/find-docs/`                       | None, verbatim copy |

Both skills are visible through the canonical cross-harness path at `~/.agents/skills/`. Claude Code also gets directory symlinks at `Claude/.claude/skills/context7-cli` and `Claude/.claude/skills/find-docs`. A pre-existing unmanaged live Claude copy of `~/.claude/skills/find-docs` was byte-identical to the upstream copy, so it was removed before `stow --restow Agents Claude` replaced it with the tracked symlink.

If Upstash publishes updates, sync manually from the same repository and re-run `stow --restow Agents Claude`.

### 2026-05-10: Firecrawl CLI skills added

Added three Firecrawl CLI skills from `https://github.com/firecrawl/cli/tree/main/skills` at commit `efeb34d3fbe936d631e17ab55c19f096fb3ef189`:

| Skill              | Path                                                 | Modifications                                                                                                                  |
| ------------------ | ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `firecrawl-cli`    | `Agents/.agents/skills/firecrawl-cli/` with `rules/` | Changed frontmatter `name` from upstream `firecrawl` to `firecrawl-cli` so Pi's skill loader accepts the directory-name match. |
| `firecrawl-scrape` | `Agents/.agents/skills/firecrawl-scrape/`            | None, verbatim copy                                                                                                            |
| `firecrawl-map`    | `Agents/.agents/skills/firecrawl-map/`               | None, verbatim copy                                                                                                            |

All three are visible through the canonical cross-harness path at `~/.agents/skills/`. Claude Code also gets directory symlinks at `Claude/.claude/skills/firecrawl-cli`, `Claude/.claude/skills/firecrawl-scrape`, and `Claude/.claude/skills/firecrawl-map`.

If Firecrawl publishes updates, sync manually from the same repository and re-run `stow --restow Agents Claude`.

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

### Discovered during execution (post-Stage 9)

10. **wedding-site AGENTS.md at 98% of Codex cap** (32,181 bytes / 32,768 cap; 587 bytes margin). Any future addition triggers silent truncation in Codex. Future trim pass needed; could move git-workflow + paulinas-branch sections into a project-scoped runbook.
11. **Stow does not clean up orphan symlinks** when target sources are deleted (Stage 6 → Stage 9 lesson). Section 16 procedure now documents the manual cleanup step.
12. **invest-platform `claude-progress.md` modification + `CONTEXT.md` untracked** at execution time. Left untouched (user's in-flight work). User decides commit timing.

### Deferred to consolidation phase (post-alignment)

- Whether plugin-installed global skills (vercel-_, supabase-_, etc., 14 total) should move to project-only scope
- Tooling for automated plugin-reinstall diff resolution
- Generalizing wedding-site `skills-lock.json` pattern across projects (or removing entirely)
- Worktree branching strategy for large refactors
- wedding-site AGENTS.md secondary trim pass to recover headroom under Codex cap
- Convert wedding-site `frontend-ui.md` from rule to skill with `paths:` frontmatter (cross-harness visibility)
- Convert invest-platform's 4 remaining path-scoped rules (frontend-ui, testing-patterns, typescript-conventions, writing-style) from rules to skills with `paths:` frontmatter (cross-harness visibility)
- Pre-Launch Password Gate code in invest-platform `src/proxy.ts` and `turbo.json` `globalEnv` (was removed from AGENTS.md docs in Stage 8c-2; remove from code at site launch)
- Convert pre-existing absolute symlink at `Config/.config/opencode/plugins/workmux-status.ts` to a relative symlink so stow can manage Config without aborting

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

The plugin-installed / Claude.ai-app-installed / setup-script-installed skills (vercel-_, supabase-_, deploy-to-vercel, doc-coauthoring, find-skills, frontend-design, web-design-guidelines, webapp-testing) are NOT version-tracked. They stay outside dotfiles. Documented as external in section 14. `find-docs` moved into the canonical dotfiles pool on 2026-05-10 alongside `context7-cli`.

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

### Stage 4 outcome (2026-05-07) — Global AGENTS.md consolidation (HIGH RISK, completed)

- Drafted canonical `Agents/.agents/AGENTS.md` (226 lines / 11.4 KiB / 36% of Codex cap) consolidating ~80% common content from the three drifted global instruction files. Tool-specific 20% drift placed in clearly-marked sections.
- Replaced `Claude/.claude/CLAUDE.md`, `Codex/.codex/AGENTS.md`, `Config/.config/opencode/AGENTS.md` with committed in-repo symlinks → canonical.
- Verified all 4 harness `$HOME` paths resolve to identical SHA-256.
- Net change: -278 lines across 4 files. Pre-existing absolute symlink at `Config/.config/opencode/plugins/workmux-status.ts` flagged as future stow-cleanup item (unrelated to alignment).

### Stage 5 outcome — Skill canonical-location migration

- Moved 11 user-authored personal-workflow skill directories from `Claude/.claude/skills/` to `Agents/.agents/skills/` via `git mv` (rename detection: 13 file moves at 100% similarity).
- Replaced each original location with a directory skill-symlink. `Claude/.claude/skills/` is now composed entirely of symlinks pointing into `Agents/.agents/skills/`.
- All 11 skills now natively visible to Codex / OpenCode / Pi via `~/.agents/skills/`; Claude reaches them via the in-repo symlink chain.

### Stage 6 outcome — Codex/.codex/skills/ deletion

- Verified Codex CLI source code (`codex-rs/core-skills/src/loader.rs:293-320`) confirms `~/.agents/skills/` is canonical and the deprecated `~/.codex/skills/` is also scanned (legacy support, higher precedence).
- Diff verification: the 11 Codex duplicates were SUBSETS of canonical (Claude versions had Claude-specific frontmatter not present in Codex versions, but body content was identical or near-identical). No unique Codex content to preserve.
- Deleted `Codex/.codex/skills/` entire directory (-2,556 lines committed).
- Stage 9 follow-up: cleaned up 11 orphan symlinks at `~/.codex/skills/` that stow left behind. See section 18.

### Stage 7 outcome — Pi stow package

- New `Pi/` stow package created with `Pi/.pi/agent/AGENTS.md` as committed in-repo symlink to canonical.
- Stowed; `~/.pi/agent/AGENTS.md` now resolves through to canonical AGENTS.md content.
- All four harnesses confirmed reading identical content via SHA-256 verification.
- Follow-up: `Pi/.pi/agent/settings.json` is also tracked so Pi package/model defaults are version-controlled like Claude `settings.json`, Codex `config.toml`, and OpenCode `opencode.jsonc`. Sensitive/runtime files (`auth.json`, sessions, caches, local databases) remain untracked.

### Stage 8 outcome — Project-level migrations (3 sub-stages)

**Houndarr (Stage 8a)**: Net -422 lines.

- 7 `.claude/rules/houndarr-*.md` rule-symlinks replaced with `.claude/skills/<name>` directory skill-symlinks.
- `.claude/rules/hook-compliance.md` (77 lines) folded into AGENTS.md as new "Hook compliance" subsection.
- 3 commands (bump, check, test) consolidated to canonical at `.agents/skills/<name>/SKILL.md` with `.claude/skills/<name>` symlinks; deleted `.claude/commands/` and `.opencode/commands/` (untracked).
- `.claude/rules/` is now empty.

**wedding-site (Stage 8b)**: Net -72 lines.

- AGENTS.md H1 fixed: `# CLAUDE.md` → `# AGENTS.md` (stale heading from prior rename).
- `git-workflow.md` and `paulinas-branch.md` rule contents folded into AGENTS.md as new sections.
- `skills-lock.json` SHA-256 hashes recomputed for all 3 stripe skills (skills modified May 3 but lock not updated).
- `frontend-ui.md` rule kept as path-scoped (deferred conversion to skill).

**invest-platform (Stage 8c)**: Net -1,384 lines across 3 commits.

- 8c-1: Migrated 3 `.claude/skills/` (opengrep, sprint-plan, sprint-pr) to canonical. Added 6 skill-symlinks for existing `.agents/skills/` (check, linear-sync, new-adapter, new-component, new-migration, progress-update). Deleted 6 stale duplicates each in `.claude/commands/` and `.opencode/commands/`. linear-sync 270-line drift resolved by deletion.
- 8c-2: Trimmed AGENTS.md from 695 lines / 32 KiB (AT cap) to 200 lines / 15 KiB (53% reduction). Created 4 new docs: `docs/runbooks/dev-reference.md`, `testing-guide.md`, `observability.md`, `component-library.md`. Deleted "Pre-Launch Password Gate" temporary section.
- 8c-3: Merged 5 unscoped rule contents (commenting, dev-credentials, git-workflow, linear-conventions, security-compliance) into AGENTS.md as new sections; condensed during merge to fit cap. Deleted 6 rule files (5 unscoped + plan-mode). Final AGENTS.md: 397 lines / 28.6 KiB / 87% of cap, 4 KiB headroom. `.claude/rules/` retains only the 4 path-scoped rules.

### Stage 9 outcome — End-to-end verification

- All 4 harness `$HOME` paths verified to resolve to identical canonical AGENTS.md (SHA-256 `760e2130...`).
- All CLI versions present and current.
- Pi packages intact (8 packages including `rpiv-args` for argument substitution) plus the local `all-core-tools.ts` extension.
- Cleaned up 11 orphan Codex symlinks (see section 18).
- Per-project size verification: Houndarr 72%, wedding-site **98%**, invest-platform 87% of Codex cap.
- **Open concern**: wedding-site AGENTS.md at 98% has only 587 bytes margin. Future additions trigger silent Codex truncation. Flagged in section 19.

### Stage 10 outcome — Runbook finalize

- Sections 1-13, 15-17 filled in with verified per-harness behavior, compatibility matrix, file layout, procedures, and cap cheatsheet.
- Decision log (this section) updated with all stage execution outcomes.
- Modification ledger (section 18) updated with the Stage 6 orphan-symlink lesson.
- Open questions (section 19) updated with wedding-site cap concern.
