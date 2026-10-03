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
| **Codex CLI** (OpenAI)      | 0.160.0     | `/opt/homebrew/Caskroom/codex/<v>/codex-aarch64-apple-darwin` (Rust binary) | `~/.codex/AGENTS.override.md` then `AGENTS.md` (not counted), project `AGENTS.md` walk-up (32 KiB cap on project files)                                                                |
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
| Codex CLI   | `AGENTS.override.md` then `AGENTS.md`, plus configurable `project_doc_fallback_filenames` | **32 KiB hard cap on project files** (`project_doc_max_bytes`); global file not counted            | No                                            | Concatenated root-to-cwd; later files override earlier                                  |
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

Global git config hooks (git 2.54+, declared in `Git/.gitconfig`): `hook.refine` runs
`~/.agents/skills/refine/scripts/refine gate` and `hook.build-loop-tier` runs `bl check-tier`
on pre-commit; `hook.build-loop-ledger` runs `bl check-ledger` on pre-push. Config hooks run
in every repository before the repo's own hookdir hook, even when `core.hooksPath` is set.
An older git ignores them without a word, so the gates do not run under Apple's
`/usr/bin/git` (2.50); Claude Code here resolves `git` to Homebrew's.
They act only on agent commits (`AI_AGENT` matching `refine.agents` or `buildloop.agents`,
default `claude-code`), and each command starts with `test -z "$AI_AGENT$CLAUDECODE" ||`,
so a human commit or push never starts a script. The refine gate blocks
(`refine.mode = block`); the build-loop checks end in `|| true`, so they only warn. The
scripts need Python 3.11 or later as `python3` on PATH. Procedure: section 16, "Pause,
tune or extend the agent commit gates".

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
| `extensions/inline-skill-invocations.ts` | Local input-transform extension that lets `/skill:<name>` or `/<skill-name>` appear on its own line or in same-line prose, then rewrites the prompt so Pi's normal skill expansion runs. It ignores inline code, code blocks, and path-like text. |

To mention a slash skill without invoking it in Pi, put it in inline code (`` `/review` ``), a fenced code block, or path-like text such as `/Users/andreaventi/.dotfiles/Agents/.agents/skills/review/SKILL.md`.

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
| zoom-out/SKILL.md                           | Matt Pocock                           | C (`disable-model-invocation: true`) | Stay as-is                                                                                                                                                                                |
| playwright-cli/SKILL.md                     | Matt Pocock-flavored / infrastructure | C                                    | Stay; `allowed-tools` inert outside Claude. No path constraints — description-triggered                                                                                                   |
| agentic-coding-harnesses/SKILL.md (Stage 1) | user-authored discovery               | C                                    | Stay; description-triggered when env modifications discussed                                                                                                                              |
| find-docs/SKILL.md                          | Upstash Context7                      | C                                    | Added 2026-05-10; verbatim from `upstash/context7` commit `78b98266954d35da8aa93ad40c67df33a3ff4443`; replaces unmanaged live Claude copy and restores universal availability             |
| firecrawl-cli/SKILL.md                      | Firecrawl CLI                         | C                                    | Added 2026-05-10 from `firecrawl/cli` commit `efeb34d3fbe936d631e17ab55c19f096fb3ef189`; frontmatter name changed to `firecrawl-cli` to match directory; skill-symlinked for Claude       |
| firecrawl-scrape/SKILL.md                   | Firecrawl CLI                         | C                                    | Added 2026-05-10; verbatim from `firecrawl/cli` commit `efeb34d3fbe936d631e17ab55c19f096fb3ef189`; skill-symlinked for Claude                                                             |
| firecrawl-map/SKILL.md                      | Firecrawl CLI                         | C                                    | Added 2026-05-10; verbatim from `firecrawl/cli` commit `efeb34d3fbe936d631e17ab55c19f096fb3ef189`; skill-symlinked for Claude                                                             |
| prototype/SKILL.md                          | Matt Pocock                           | C                                    | Added 2026-05-13 from `mattpocock/skills` commit `e74f0061bb67222181640effa98c675bdb2fdaa7`; verbatim copy; skill-symlinked for Claude                                                    |
| handoff/SKILL.md                            | Matt Pocock                           | C                                    | Added 2026-05-13 from `mattpocock/skills` commit `e74f0061bb67222181640effa98c675bdb2fdaa7`; verbatim copy; skill-symlinked for Claude                                                    |
| refine/SKILL.md                             | user-authored                         | C                                    | Added 2026-10-02 with scripts `refine` and `refine_core.py`, tests, and lens agents in `Claude/.claude/agents/`                                                                           |
| build-loop/SKILL.md                         | user-authored                         | C                                    | Added 2026-10-02, extracted from the invest-platform and wedding-site build loops; script `bl`, tests                                                                                     |
| end-to-end/SKILL.md                         | user-authored                         | C                                    | Added 2026-10-02: session lifecycle (workspace, plan and stop, ship, housekeeping, multi-session)                                                                                         |

#### Skills currently in `.dotfiles/Claude/.claude/skills/` (16 personal-workflow)

All bucket **C** (description-triggered, most use `$ARGUMENTS`). All migrate to `.agents/skills/<name>/` in Stage 5; replace original with directory skill-symlink.

**Migration done, verified 2026-08-14.** Every skill in this table now lives in
`Agents/.agents/skills/<name>/` with a directory symlink left behind in
`Claude/.claude/skills/`. Edit the `.agents` copy; the heading above describes
where these used to be. The frontmatter column is accurate as of the same date.

| Skill       | Uses args?         | Notable frontmatter                               |
| ----------- | ------------------ | ------------------------------------------------- |
| catchup     | no                 | `allowed-tools`                                   |
| coordinator | no                 | `disable-model-invocation: true`                  |
| deep-audit  | yes (`$ARGUMENTS`) | `argument-hint`, `allowed-tools`                  |
| fix-issue   | yes (`$ARGUMENTS`) | `argument-hint`, `disable-model-invocation: true` |
| merge       | yes (`$ARGUMENTS`) | `disable-model-invocation: true`                  |
| open-pr     | no                 | `disable-model-invocation: true`                  |
| rebase      | yes (`$ARGUMENTS`) | `disable-model-invocation: true`                  |
| review      | no                 | `allowed-tools`                                   |
| ship        | yes (`$ARGUMENTS`) | `argument-hint`, `disable-model-invocation: true` |
| workmux     | no                 | `disable-model-invocation: true`                  |
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
│           └── ...                         (11 Matt Pocock + 5 conventions + 11 personal workflow + 1 discovery = 28 canonical skills before later additions)
├── Claude/
│   └── .claude/
│       ├── CLAUDE.md       S→ ../../Agents/.agents/AGENTS.md
│       ├── settings.json   (R)             # permissions, hooks, plugins, statusline
│       ├── agents/                         # refine-lens, refine-lens-deep (R)
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
└── (other stow packages: App-Configs/, Fonts/, Formatting-Files/,
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

### Pin a merged, unreleased Pi package fix

1. Confirm the upstream fix is merged and record its full commit SHA. Inspect the changed source and tests before trusting the pin.
2. Ask before changing the dependency source. Prefer a merged fix commit over a moving branch.
3. Replace the package entry in `Pi/.pi/agent/settings.json` with `git:<repo>@<full-sha>`. If the live `~/.pi/agent/settings.json` is a regular file rather than the Stow symlink, make the same targeted replacement there without overwriting unrelated live settings.
4. Run `pi install git:<repo>@<full-sha>` so Pi materializes the pinned package, then reload Pi.
5. Exercise the failing package path end to end. Source inspection or a passing upstream unit test alone is insufficient.
6. Return to an npm release after it contains the fix, so normal package updates resume.

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

### Restore the Claude settings.json symlink and guard it

`~/.claude/settings.json` drifts back into a real file whenever it is replaced
rather than edited through the symlink. While it is a real file, `stow --restow
Claude` aborts on the whole package, and the repo copy has to be hand-synced.

Symptom:

```
cannot stow .dotfiles/Claude/.claude/settings.json over existing target
.claude/settings.json since neither a link nor a directory
```

Fix:

1. Diff the live file against the repo copy and merge by hand. Keep whichever
   side is newer per key; hook commands should use the `"$HOME"` form rather
   than an absolute `/Users/...` path.
2. Strip any `autoMode` key. It is scoped "User or managed" and is only honored
   in `~/.claude/settings.json`, so it cannot be relocated to a project file or
   a local override. There is no user-level `settings.local.json`. Auto mode
   must be reconfigured through `/config` after this, and the key will be
   written back into the now-tracked file.
3. `rm ~/.claude/settings.json && stow --restow Claude`.
4. Confirm `readlink ~/.claude/settings.json` resolves into the repo.

The `scripts/hooks/pre-commit` guard blocks step 2 from regressing. `.git/hooks`
is not tracked, so install it after a fresh clone:

```
ln -sf ../../scripts/hooks/pre-commit .git/hooks/pre-commit
```

### Pause, tune or extend the agent commit gates

1. Pause the refine gate everywhere: `git config --global refine.mode warn` (warn and log)
   or `off`. Let one commit through, only with the user's say-so: `REFINE_SKIP=1 git commit ...`.
   With a python3 older than 3.11 first on PATH the gate blocks whatever `refine.mode` says;
   `git config --global hook.refine.enabled false` turns the hook off without starting Python.
2. Per repository: `git config refine.mode off`, or exempt generated or data paths with
   `git config --add refine.exempt '<glob>'` (repo-local and untracked). invest-platform,
   wedding-site and BAI-Capital-Platform carry their generated paths this way.
3. Extend the gates to another harness: add its `AI_AGENT` prefix with
   `git config --global --add refine.agents <prefix>` and the same for `buildloop.agents`,
   and drop "Claude Code only." from the refine, build-loop and end-to-end descriptions.
   Codex exports `CODEX_THREAD_ID` instead of `AI_AGENT`, so it needs a code change in both
   scripts and in the hook guard first.
4. Silence the build-loop warnings: `git config --global buildloop.checks off`, or, with a
   python3 older than 3.11, set `hook.build-loop-tier.enabled` and
   `hook.build-loop-ledger.enabled` to `false`.
5. Verify after any change: `git hook list --show-scope pre-commit` lists `refine` and
   `build-loop-tier`, and both suites pass:
   `python3 -m unittest discover -s ~/.agents/skills/refine/scripts -p 'test_*.py'`, then the
   same for `~/.agents/skills/build-loop/scripts`.

### Add a global git hook

1. Declare it in `Git/.gitconfig`: `[hook "<name>"]` with `event = <hook event>` and
   `command = <command>`. Git runs the command through the shell, so `~` expands and the
   hook's arguments are appended. Git 2.54 or later runs config hooks in every repository,
   before the hookdir hook, whatever `core.hooksPath` says.
2. Keep it fast. When human commits should pass untouched, start the command with
   `test -z "$AI_AGENT$CLAUDECODE" ||`, so a broken or missing script can only block an
   agent, and end a warn-only hook with `|| true`. Git appends the hook's arguments to the
   end of the command, so after `|| true` they reach `true`; a warn-only hook that needs
   them masks its own exit status instead. Test it by driving real commits in throwaway
   repositories with
   `GIT_CONFIG_GLOBAL` pointed at a scratch config.
3. Confirm it is registered with `git hook list --show-scope <event>` in a few repositories.

### Debug "skill not loading"

Per-harness diagnostic flow:

| Harness     | Symptom                                                     | Check                                                                                                                                                                                                                                                            |
| ----------- | ----------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Pi          | Skill is invisible to model                                 | (1) Does SKILL.md have a non-empty `description:` field? Pi hard-skips skills without one. (2) Is the skill in a Pi-discoverable path? Run `pi list-skills` if available; verify `skills:` array in `~/.pi/agent/settings.json` includes the skill's parent dir. |
| Pi          | `/skill:<name>` or `/<skill-name>` does not load            | Core Pi only expands skill commands when the prompt starts with `/skill:`. This setup includes `extensions/inline-skill-invocations.ts`; reload Pi, then put `/skill:<name>` or `/<skill-name>` on its own line or in same-line prose. Use inline code, fenced code blocks, or path-like text to mention a slash skill without invoking it. |
| Claude Code | Skill doesn't auto-load on path match                       | Verify `paths:` frontmatter is correct YAML. Use the `InstructionsLoaded` hook to log what loaded.                                                                                                                                                               |
| Codex       | Skill not in slash menu / `$<name>` invocation fails        | Verify SKILL.md is at `~/.agents/skills/<name>/SKILL.md` (canonical) or `~/.codex/skills/<name>/SKILL.md` (deprecated). Ensure name is lowercase-alphanumeric-hyphens.                                                                                           |
| OpenCode    | Skill not surfaced                                          | OpenCode validates name regex `^[a-z0-9]+(-[a-z0-9]+)*$`. Capital letters or underscores cause silent skip.                                                                                                                                                      |
| All         | Description-discovery failing                               | The model picks skills based on description trigger words. If the description is generic ("Helps with X"), the model won't reach for it. Rewrite description as "Use when X. Triggers on Y/Z. Skip if Q."                                                        |

### Verify each harness loads correctly

1. Hash check: `for p in ~/.claude/CLAUDE.md ~/.codex/AGENTS.md ~/.config/opencode/AGENTS.md ~/.pi/agent/AGENTS.md ~/.agents/AGENTS.md; do shasum -a 256 "$p"; done` — all 5 should match.
2. Claude Code: launch any session, run `/memory`, confirm CLAUDE.md content matches canonical.
3. Codex: launch `codex` in any directory, confirm session-start instructions match. For repos near the 32 KiB cap, watch for missing trailing content: Codex keeps the first bytes of an oversized project AGENTS.md and logs a warning.
4. OpenCode: launch `opencode`, check session-start.
5. Pi: launch `pi`, ask about agentic environment to confirm `agentic-coding-harnesses` skill triggers.
6. Slash invocation: in Claude, try `/ship` or `/catchup` — should resolve to canonical skill.
7. Path-conditional: edit a `.py` file in any project — Claude should auto-load `python` rule (it's a `paths:`-frontmatter symlink to the canonical skill).

## 17. Cap & Adherence Cheatsheet

| Harness     | Hard cap                                                   | Soft guideline                                  | Truncation behavior                                          |
| ----------- | ---------------------------------------------------------- | ----------------------------------------------- | ------------------------------------------------------------ |
| Claude Code | None                                                       | < 200 lines per CLAUDE.md/AGENTS.md (Anthropic) | None — full file loaded; adherence drops on long files       |
| Codex CLI   | **32 KiB `project_doc_max_bytes`**, project files only     | Same                                            | Keeps the first bytes, drops the rest; logs a warning        |
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

### Per-project current state (measured 2026-10-02)

Codex 0.160.0 charges only project AGENTS.md files against `project_doc_max_bytes` (32,768
bytes by default). The global file arrives separately as user instructions and is not
counted, and a project file that crosses the budget keeps its first bytes and loses the
rest, with a logged warning (`codex-rs/core/src/agents_md.rs`, lines 56 to 116 and 156 to
164, at tag `rust-v0.160.0`). The figures before this date added the global file in. Sizes
are each project's `main`.

| Project         | Project AGENTS.md    | Utilization | Margin       |
| --------------- | -------------------- | ----------- | ------------ |
| invest-platform | 518 lines / 27,489 B | 84%         | 5,279 bytes  |
| Houndarr        | 563 lines / 24,773 B | 76%         | 7,995 bytes  |
| wedding-site    | 224 lines / 22,549 B | 69%         | 10,219 bytes |

The global file has no cap of its own, but every line of it costs attention in all four
harnesses.

## 18. Modification Ledger

### 2026-10-03: context-based /compact stops

end-to-end used to stop after every T3 plan with a `/compact` note. It now stops
only when `bl context` puts the session at 25% of its context window or more after
planning, when the plan touches a stop-and-ask surface, or when the prompt asks for
a plan review; otherwise it goes straight into implementation. build-loop runs the
same check before each review round and stops for `/compact` at 60%. `bl context`
(in `bl_context.py`) reads the latest main-thread request's token usage from the
session transcript that `CLAUDE_CODE_SESSION_ID` names. Tune it with
`git config --global` keys `buildloop.compactAfterPlan`,
`buildloop.compactBeforeRound` and `buildloop.contextWindow` (default 1000000).

Why: long planning sessions reached 30 to 50% of the window before implementation
started, and a fixed stop also interrupted short ones that had room to spare.

To re-apply if overwritten: restore `bl`, `bl_state.py`, `bl_context.py` and
`test_context.py` under build-loop's scripts, end-to-end's step 3, and build-loop's
round step 1.

### 2026-10-02: refine, build-loop and end-to-end skills, agent commit gates

Added three user-authored global skills (bucket C), each with its committed
`Claude/.claude/skills/<name>` symlink, plus a restow of Agents and Claude:

- `refine` simplifies and refines the staged diff before every agent commit:
  read-only lens subagents (reuse, simplification, efficiency, altitude), edits
  confined to the change's own lines, pre-existing lines in a separate refactor
  commit, tests report-only, the repo's fast checks with snapshot rollback, then a
  stamp bound to the staged blobs. Scripts `refine` and `refine_core.py`, with
  tests. The bundled `/simplify` is untouched; the different name means Claude
  Code's built-in "run simplify before each commit" instruction does not fire, so
  a hook enforces the step instead.
- `build-loop` is the generic core of the invest-platform and wedding-site build
  loops with four risk tiers (T0 gates only; T1 one clean pass or a cap of 2; T2
  two clean or a cap of 4; T3 two clean or a cap of 8), the round prompts, and
  the tree and machine safety rules from both copies. Scripts `bl` and
  `bl_state.py`, with tests, keep per-branch state under
  `$(git rev-parse --git-common-dir)/build-loop/` and archive a finished change's
  state with `bl reset`. Both repos'
  `build-loop.md` files became their profiles in place.
- `end-to-end` is the session lifecycle the user typed every session: resolve the
  work item, workspace, plan and stop for `/compact`, ship, housekeeping, the
  final report, and the multi-session protocol from the 2026-10-01
  concurrent-sessions note.

Also: `Claude/.claude/agents/` with `refine-lens.md` (effort high) and
`refine-lens-deep.md` (effort xhigh). A Claude Code session that started before
this directory existed did not list the two agents until it was restarted
(observed 2026-10-02). `Git/.gitconfig` gained the three hooks, each behind a
`test -z "$AI_AGENT$CLAUDECODE" ||` guard so human commits never start a script,
with the two build-loop checks ending in `|| true` so they only warn, and
`[refine] mode = block, agents = claude-code`. The three skill descriptions start
with "Claude Code only.", because Codex, OpenCode and Pi load `~/.agents/skills`
natively. AGENTS.md gained a two-line
pointer to build-loop and end-to-end under Operating defaults, and ask-first
exceptions for refine's file-private helpers and tidy commits. No Claude Code
settings changed.

Why: in the user's Claude Code transcripts (measured 2026-10-02), a skill the
instructions said to run before committing was invoked before about 0% of
commits, while some gate command ran before about 80%, so a hook enforces the
step. A prompted cleanup
pass broke 8 to 15% of passing SWE-bench Verified fixes, while a variant that
discarded refinements failing the tests lost none (RECAP, arXiv 2608.13292,
preprint), hence the checks and rollback. LLM test-smell refactoring broke 11% of
refactored tests (UTRefactor, arXiv 2409.16739, FSE 2025) and changed test
behavior in about 15% of cases (SBES 2025, doi:10.5753/sbes.2025.11568), hence
report-only tests.

Verified with the build loop at T2 across dotfiles, invest-platform and
wedding-site, 2026-10-02 to 10-03: the review loop ran 4 passes, clean on
passes 3 and 4; the audit loop ran 4 passes, clean on passes 2 and 4; both
ended `two clean`. Passes 1 to 3 found 1 HIGH, 5 MEDIUM and 4 FAIL, all fixed
with regression tests. The last pass's LOW and WARN findings were fixed after
pass 4 and had no further independent pass.

To re-apply if overwritten: restore the three skill directories and
`Claude/.claude/agents/`, the three Claude skill symlinks, the `Git/.gitconfig`
block and the AGENTS.md lines, then `stow --restow Agents Claude`.

Running log of modifications made to imported / external skills, and of plugin re-install conflicts resolved. Each entry captures: date, skill name, what changed, why, how to re-apply if overwritten. Populated during execution and ongoing thereafter.

### 2026-09-18 — evidence-driven-engineering: new skill, split against the Codex cap

New user-authored skill at
`~/.dotfiles/Agents/.agents/skills/evidence-driven-engineering/SKILL.md` (125
lines), symlinked into `Claude/.claude/skills/`. A 672-byte `## Evidence`
section was added to `Agents/.agents/AGENTS.md`, inserted before the
`<!-- keep as last line -->` marker so the existing tail reminder keeps the
high-attention final slot.

Source material was a 278-line / 9,284-byte "Evidence-Driven Engineering
Instructions" block the user wanted applied globally. Appending it whole to the
canonical AGENTS.md was ruled out by measurement, not preference: Codex caps
global + project AGENTS.md at a combined 32 KiB and truncates silently from the
start. The full block would have put invest-platform 8,014 bytes over, Houndarr
5,741 over, and wedding-site 1,904 over.

Section 16 step 1 routes always-on content to AGENTS.md and forbids making it a
skill. That rule is right about the mechanism: all four harnesses evaluate
`description:` at session-prompt time, when no claim exists yet, so a skill
saying "load before you assert something is broken" fires late or not at all.
The cap made full compliance impossible, so the content was split by
enforceability instead. What must hold even when nothing loads went inline:
proportionality to impact and reversibility, confidence labeling, the ban on
reporting unrun work, and disclosure of what was not verified. The
proportionality bullet is load-bearing because it supersedes two Operating
defaults ("stop exploring once there is enough evidence to act" and "the
smallest relevant check"); without it inline those read as settled.

Roughly half the source was cut as already covered: the 9-step root-cause
procedure duplicates `diagnose`, dependency verification duplicates `find-docs`
and the always-on context7 rule, and the Code Changes and Safety sections
duplicate AGENTS.md Boundaries, which is stricter because it requires asking
rather than merely refraining. The persona preamble was dropped.

Cap after the change: invest-platform 32,170 / 32,768 (98%, 598 bytes margin),
Houndarr 91%, wedding-site 79%. invest-platform is now tight enough that the
next AGENTS.md addition there needs this arithmetic run first.

Known gap not filled: no skill in either pool carries a keyboard, focus, or WCAG
checklist. `evidence-driven-engineering` names those concerns and cannot enforce
them.

To re-apply if overwritten: restore the SKILL.md, re-create the
`Claude/.claude/skills/` symlink, `stow --restow Agents`, and re-insert the
`## Evidence` section before the last-line marker.

### 2026-09-18 — deep-audit: four dimensions the skill could not catch

`~/.dotfiles/Agents/.agents/skills/deep-audit/SKILL.md` and
`references/audit-dimensions.md`, both user-authored, edited in place. No
re-stow needed: both are real files under the stow package and the harnesses
read them through existing symlinks.

Four defect classes got past five review passes and three deep-audit passes on
one branch (invest-platform #501), and each is now a dimension:

- 13, Delivery-Context Assumptions. A per-route response header is delivered on
  the DOCUMENT. A route reached by a server-action redirect renders inside the
  previous document and inherits its policy, so the route-scoped exception does
  not apply and only a reload works. Opening the URL directly always passes,
  which is why three investigations closed as "cannot reproduce".
- 14, Reconstruction Fidelity. Code that rebuilds a third party's artifact must
  refuse what it cannot reproduce. Six separate passes each found another way
  the same parser drew a plausible, wrong QR code instead of refusing.
- 15, Assertions That Cannot Fail. A negative assertion about telemetry kept
  passing after the payload was widened to carry the whole secret, because
  nothing could turn it red.
- 16, Claims the Diff Ships. Comments and PR prose assert facts about browsers
  and vendors that no gate reads. The sharpest case is a causal claim attached
  to a fix that works: three successive explanations for one Safari fix were
  written into the code as settled and all three were later falsified by
  driving the real engine.

Step 4 gained three methods beside mutation testing: falsify the tests rather
than only the code, drive the real engine or tool instead of reasoning about
it, and capture the producer's artifact rather than authoring a fixture from
its documentation.

To re-apply if overwritten: dimensions 13 to 16 in the Step 3 list in SKILL.md,
the matching sections in `references/audit-dimensions.md`, the "thirteen" to
"sixteen" count at the reference link, and the three method paragraphs before
"Observable behavior verification" in Step 4.

### 2026-08-14 — review, deep-audit: a working-tree contract for passes that write

`~/.dotfiles/Agents/.agents/skills/review/SKILL.md` and
`deep-audit/SKILL.md`, both user-authored, edited in place, plus a new shared
reference at `review/references/working-tree-safety.md` that deep-audit links
across as `../review/references/working-tree-safety.md`.

Why. Both skills run in the implementer's working directory and neither had a
protocol for it. `review` declared READ-ONLY in three places and nothing
enforced it: two of the four harnesses ignore `allowed-tools` (see the support
matrix in section 4), and where it is honoured it does not re-restrict a
subagent that already holds broader tools, which is how these skills are
usually invoked. `deep-audit` had no write posture at all while its own Step 2
runs the project's gates and its best technique mutates source; its
`allowed-tools` did not even permit a test runner.

On one invest-platform wave a reviewer undid a one-line probe with
`git checkout -- <file>`, which reverts the whole file and took about twenty
minutes of uncommitted implementer work with it, then truthfully reported the
tree as clean. A second pass mutated a file the implementer was editing. A
third detected the implementer's edits mid-sweep and killed its own harness,
losing twelve planned mutations and returning a bare count with no survivor
list.

What changed. A prohibition with no sanctioned alternative gets broken quietly,
so both skills now carry a contract instead: capture `git status --porcelain`
up front and treat everything in it as someone else's; never `checkout`,
`restore` or `stash` to undo a probe, since all three act on whole files;
restore from a copy in a `finally`; on a dirty baseline do not write at all,
and either report the finding unverified or take a `git worktree`; re-check
before each write so a moving tree stops the sweep rather than corrupting it;
and close with the literal command output rather than a claim. Both output
formats gained a Working tree section so the exit state is checkable.

`deep-audit` also gained mutation testing as a named technique in Step 4, with
the rule that every survivor is classified (real gap, operator-only signal,
inert observability string, or equivalent mutant) because an unclassified
survivor list is noise. Its `allowed-tools` gained Write, Edit, the package
managers and the doc-lookup tools. `review` stays read-only by default, which
is still the right posture; it now has a reason and an escape hatch rather than
a bare "don't".

To re-apply if overwritten: re-add the "Working tree safety" section to both
SKILL.md bodies, the Working tree block to both output formats, the mutation
testing paragraph to deep-audit Step 4, and restore the shared reference. The
binding rules are inline in each skill deliberately, so losing the reference
degrades the detail rather than the safety.

### 2026-08-11 — deep-audit: make the report say its findings are unverified

`~/.dotfiles/Agents/.agents/skills/deep-audit/SKILL.md`, user-authored, edited in
place. Two additive edits, both generic:

- The Step 5 report template gained a closing `### Verify Before Acting` section.
  It tells the reader to re-derive each finding at the source, names the finding
  types most likely to be confidently wrong (framework and library internals,
  byte counts, timings, "X never happens"), asks the audit to distinguish what it
  reproduced from what it only read, and says a PASS means the audit found
  nothing rather than that the code is right.
- A new rule 10 makes emitting that section mandatory and explains why, in terms
  of the reader being someone (often an agent) who will act immediately. The old
  rule 10, "PASS means PASS", renumbered to 11 and is otherwise untouched.

Prompted by an invest-platform wave where a deep audit returned seven FAILs, two
of which were confident, specifically-cited claims about framework internals. One
said Turbopack caches a rejected chunk promise so the network is never retried;
reading the build's own runtime showed it retries once and then deletes the
registry entry. The other explained a type annotation by saying `dynamic()` cannot
see through `React.memo`; `tsc` disagreed. Both were caught only because the
findings were checked at the source before acting. The audit was right about the
underlying defects and wrong about the reasons, which is the failure shape worth
warning about: a real file path and a line number read as proof.

To re-apply if overwritten: append the `### Verify Before Acting` block to the end
of the Step 5 report template, and add the mandate as a numbered rule ahead of
"PASS means PASS". Nothing structural changed and no frontmatter was touched.

### 2026-07-24 — catchup: de-sprint, add active-plan detection

`~/.dotfiles/Agents/.agents/skills/catchup/SKILL.md`, user-authored, edited in place.

Prompted by the invest-platform harness rebuild, which replaced a sprint-based
workflow with a per-flow one. Two edits, both kept deliberately generic so the
skill stays correct for every project rather than encoding one repo's model:

- Section 3 no longer assumes a sprint or cycle exists. It pulls issues assigned
  to the user or linked to the branch, treats a cycle as optional, and points at
  the plan document as the better source of ordering. Also now says to read issue
  comments, not just descriptions: Linear's `get_issue` omits them and decisions
  routinely land there.
- Section 5 gained active-plan detection (`docs/implementation-plans/`,
  `docs/plans/`, `ROADMAP.md`, `PLAN.md`). Where a plan carries an ordered queue,
  the first unmarked item is the real next step and beats anything inferred from
  a branch name.

Nothing project-specific was added. No BAI names, paths, or flow labels appear
in the skill.

To re-apply if overwritten by an upstream import: both edits are additive prose
inside existing sections 3 and 5; re-read the sections and restate the two points
above. Nothing structural changed, and no frontmatter was touched.

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

**Brought back** (4 official Anthropic skills from [anthropics/skills](https://github.com/anthropics/skills/tree/main/skills) repo, version-tracked in dotfiles at the time):

| Skill                    | Path                                            | Modifications                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| ------------------------ | ----------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `webapp-testing`         | `Agents/.agents/skills/webapp-testing/`         | None, verbatim copy                                                                                                                                                                                                                                                                                                                                                                                                                             |
| `doc-coauthoring`        | `Agents/.agents/skills/doc-coauthoring/`        | None, verbatim copy                                                                                                                                                                                                                                                                                                                                                                                                                             |
| `frontend-design-global` | `Agents/.agents/skills/frontend-design-global/` | **Renamed** from `frontend-design` to avoid namespace collision with the `frontend-design@claude-plugins-official` plugin's bundled skill. **Generalized** language: replaced "Claude is capable of extraordinary creative work" → "a frontier LLM is capable of extraordinary creative work". Added `metadata.origin: anthropics/skills (frontend-design)` and `metadata.fork-reason: Cross-harness availability and harness-neutral language` |

`skill-creator` was also brought back here initially, then removed on 2026-05-12 after `skill-creator-global` became the canonical skill-authoring craft skill.

The remaining skills are visible globally via `~/.agents/skills/` (Codex / OpenCode / Pi read natively; Claude Code reads via stow-installed symlink at `~/.claude/skills/...` if added there, otherwise via the agentic-coding-harnesses cross-harness layer).

If Anthropic publishes updates to these skills, manual sync from `https://github.com/anthropics/skills/tree/main/skills` is required (no auto-update mechanism). For `frontend-design-global`, re-apply the rename + harness-neutral language tweaks after pulling a new upstream version.

### 2026-05-09: Pi inline skill invocation extension

Added `Pi/.pi/agent/extensions/inline-skill-invocations.ts`, a user-owned Pi input-transform extension. It detects `/skill:<name>` or `/<skill-name>` on its own non-fenced line or in same-line prose anywhere in the user's prompt, rewrites the message to start with `/skill:<name>`, and preserves the surrounding text as skill arguments. Inline code spans, fenced/indented code blocks, and path-like text intentionally do not invoke skills. This works around core Pi's documented behavior: skill command expansion only happens when the raw prompt starts with `/skill:`.

Validation performed with a Node unit test for explicit, bare, inline-argument, same-line prose, inline-code, fenced-code, path-like, unknown-command, command-conflict, and already-wrapped cases, plus Pi's `loadExtensions()` loader against the extension file.

### 2026-05-10: Upstash Context7 skill added

Added the Upstash Context7 `find-docs` skill from `https://github.com/upstash/context7/tree/master/skills` at commit `78b98266954d35da8aa93ad40c67df33a3ff4443`:

| Skill       | Path                               | Modifications       |
| ----------- | ---------------------------------- | ------------------- |
| `find-docs` | `Agents/.agents/skills/find-docs/` | None, verbatim copy |

The skill is visible through the canonical cross-harness path at `~/.agents/skills/`. Claude Code also gets a directory symlink at `Claude/.claude/skills/find-docs`. A pre-existing unmanaged live Claude copy of `~/.claude/skills/find-docs` was byte-identical to the upstream copy, so it was removed before `stow --restow Agents Claude` replaced it with the tracked symlink.

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

### 2026-05-12: Removed legacy `write-a-skill`

Removed the Matt Pocock `write-a-skill` skill from `Agents/.agents/skills/` and its Claude-facing symlink at `Claude/.claude/skills/write-a-skill`. The skill was superseded by the user-authored `skill-creator-global` skill, which now owns skill-authoring craft, description quality, and progressive-disclosure guidance. Live Stow symlinks at `~/.agents/skills/write-a-skill` and `~/.claude/skills/write-a-skill` were also removed to avoid orphaned skill entries.

### 2026-05-12: Removed `context7-cli`

Removed the deleted `context7-cli` skill's stale symlinks from `Claude/.claude/skills/context7-cli`, `~/.agents/skills/context7-cli`, and `~/.claude/skills/context7-cli`. `find-docs` remains the canonical Context7 docs skill.

### 2026-05-12: Removed upstream `skill-creator`

Removed the tracked upstream Anthropic `skill-creator` skill from `Agents/.agents/skills/skill-creator/` and the live `~/.agents/skills/skill-creator` symlink. It was not visible in Claude Code because no Claude-facing symlink or enabled plugin exposed it. The user-authored `skill-creator-global` skill is now the canonical skill-authoring craft skill.

### 2026-05-13: Synced Matt Pocock skills with upstream

Synced from `https://github.com/mattpocock/skills` at commit `e74f0061bb67222181640effa98c675bdb2fdaa7` (2026-05-13). Manual sync only — installer not used, to preserve the canonical pool layout and the cross-harness symlinks.

Upstream reorganised the repo into category subdirs (`engineering/`, `productivity/`, `misc/`, `personal/`, `in-progress/`, `deprecated/`). The canonical pool keeps its flat layout under `Agents/.agents/skills/`.

Updated in place (file-level copy through the canonical pool; symlinks untouched):

| Skill                                                        | Change                                                                                              |
| ------------------------------------------------------------ | --------------------------------------------------------------------------------------------------- |
| `grill-with-docs/SKILL.md`                                   | Tightens `CONTEXT.md` guidance: glossary-only, not a spec or scratch pad.                           |
| `setup-matt-pocock-skills/issue-tracker-gitlab.md`           | Simplifies `glab issue list` example (drops `--state opened` note).                                 |
| `to-issues/SKILL.md`                                         | Drops `needs-triage` advice; adds AFK-ready posture and prototype-snippet exception.                |
| `to-prd/SKILL.md`                                            | Switches `needs-triage` → `ready-for-agent`; adds prototype-snippet exception.                      |

Added (new upstream skills; verbatim copy):

| Skill       | Path                               | Claude symlink                          | Modifications       |
| ----------- | ---------------------------------- | --------------------------------------- | ------------------- |
| `prototype` | `Agents/.agents/skills/prototype/` | `Claude/.claude/skills/prototype`       | None, verbatim copy |
| `handoff`   | `Agents/.agents/skills/handoff/`   | `Claude/.claude/skills/handoff`         | None, verbatim copy |

Both new skills are referenced from existing pool content: the updated `to-issues` and `to-prd` skills both call out a "prototype produced a snippet" exception, and `handoff` complements the existing `catchup` skill (catchup is incoming context restore; handoff is outgoing context capture).

Deliberately not installed from this upstream sync:

- `productivity/write-a-skill` — removed 2026-05-12; superseded by `skill-creator-global`.
- `personal/edit-article`, `personal/obsidian-vault` — Matt-personal.
- `in-progress/review` (would collide with the user-authored `review` skill), `in-progress/writing-beats`, `in-progress/writing-fragments`, `in-progress/writing-shape` — upstream marks these unfinished.
- `deprecated/design-an-interface`, `deprecated/qa`, `deprecated/request-refactor-plan`, `deprecated/ubiquitous-language` — upstream-deprecated.
- `misc/git-guardrails-claude-code`, `misc/migrate-to-shoehorn`, `misc/scaffold-exercises`, `misc/setup-pre-commit` — narrow/project-scaffolding skills; not adopted into the global pool. Revisit if a specific need arises.

After sync, ran `stow --restow Agents Claude` to wire the two new `$HOME` symlinks. Verified all 13 Matt Pocock skills (11 existing + 2 new) resolve under both `~/.agents/skills/<name>/SKILL.md` and `~/.claude/skills/<name>/SKILL.md`.

If Matt publishes further updates, repeat: clone `mattpocock/skills`, `diff -rq` each tracked skill against `skills/{engineering,productivity}/<name>/`, copy changed files through the canonical pool, restow.

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

The plugin-installed / Claude.ai-app-installed / setup-script-installed skills (vercel-_, supabase-_, deploy-to-vercel, doc-coauthoring, find-skills, frontend-design, web-design-guidelines, webapp-testing) are NOT version-tracked. They stay outside dotfiles. Documented as external in section 14. `find-docs` moved into the canonical dotfiles pool on 2026-05-10.

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
