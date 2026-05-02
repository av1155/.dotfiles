# Claude Code Documentation Reference (May 2026)

Compiled from the official Claude Code docs at `code.claude.com/docs` (formerly `docs.claude.com/en/docs/claude-code/*`, which now 301-redirects to the new host). All facts cited; anything not stated in the docs is marked as "not documented".

## 1. Overview

- Claude Code is "an agentic coding tool that reads your codebase, edits files, runs commands, and integrates with your development tools. Available in your terminal, IDE, desktop app, and browser." Source: <https://code.claude.com/docs/en/overview>
- Surfaces: Terminal CLI, VS Code (and Cursor), JetBrains plugin, Desktop app (macOS / Windows / Windows ARM64), Web (`claude.ai/code`). All surfaces share the same underlying engine, so CLAUDE.md, settings, and MCP servers are reused across them. Source: <https://code.claude.com/docs/en/overview>
- Install methods (terminal): `curl -fsSL https://claude.ai/install.sh | bash` (macOS / Linux / WSL), `irm https://claude.ai/install.ps1 | iex` (Windows PowerShell), `brew install --cask claude-code` (Homebrew offers `claude-code` stable and `claude-code@latest` channels), `winget install Anthropic.ClaudeCode`, plus `apt`, `dnf`, `apk`. Native installs auto-update. Source: <https://code.claude.com/docs/en/overview>
- Provider options for teams: Anthropic, Amazon Bedrock, Microsoft Foundry, Google Vertex AI. Source: <https://code.claude.com/docs/en/overview>
- 2026 surface additions explicitly named in overview: Microsoft Foundry provider (alongside Bedrock and Vertex), `claude --teleport`, Dispatch, Routines (Anthropic-managed schedules), Channels, Remote Control, Claude iOS app, agent teams, Agent SDK. Source: <https://code.claude.com/docs/en/overview>

## 2. Settings

Doc: <https://code.claude.com/docs/en/settings>

### 2.1 Settings file scopes (precedence high to low)

1. Managed (org-deployed): `/Library/Application Support/ClaudeCode/managed-settings.json` (macOS), `/etc/claude-code/` (Linux/WSL), `C:\Program Files\ClaudeCode\` (Windows).
2. Command-line flags.
3. Local: `.claude/settings.local.json` (gitignored, per-developer).
4. Project: `.claude/settings.json` (committed, team-shared).
5. User: `~/.claude/settings.json` (per-user defaults).

Merging rules: arrays concatenate and dedupe; objects deep-merge; scalars are replaced by higher-precedence values. A separate global config file lives at `~/.claude.json` for `autoConnectIde`, `autoInstallIdeExtension`, `externalEditorContext`. Source: <https://code.claude.com/docs/en/settings>

### 2.2 Canonical schema URL

`"$schema": "https://json.schemastore.org/claude-code-settings.json"`. Source: <https://code.claude.com/docs/en/settings>

### 2.3 Notable top-level keys (selected)

- `model`, `availableModels`, `modelOverrides`, `effortLevel` (`low|medium|high|xhigh`), `agent`.
- `permissions.{allow,deny,ask,additionalDirectories,defaultMode,disableBypassPermissionsMode,skipDangerousModePermissionPrompt}`. `defaultMode` accepts `default|acceptEdits|plan|auto|dontAsk|bypassPermissions`.
- `env` (env-var injection), `apiKeyHelper`, `awsCredentialExport`, `awsAuthRefresh`, `otelHeadersHelper`.
- `autoMode` (`environment`, `allow`, `soft_deny` lists), `useAutoModeDuringPlan`, `disableAutoMode`, `fastModePerSessionOptIn`.
- `alwaysThinkingEnabled`, `showThinkingSummaries`.
- UI: `editorMode` (`normal|vim`), `tui`, `viewMode`, `autoScrollEnabled`, `spinnerTipsEnabled`, `spinnerTipsOverride`, `spinnerVerbs`, `showTurnDuration`, `terminalProgressBarEnabled`, `prefersReducedMotion`, `autoUpdatesChannel` (`stable|latest`), `minimumVersion`, `awaySummaryEnabled`, `language`, `outputStyle`.
- `preferredNotifChannel` (`auto|terminal_bell|iterm2|iterm2_with_bell|kitty|ghostty|notifications_disabled`).
- `respectGitignore`, `fileSuggestion`, `attribution.{commit,pr}`, `includeGitInstructions`, `prUrlTemplate`.
- Memory & storage: `autoMemoryDirectory`, `plansDirectory`, `cleanupPeriodDays`, `autoMemoryEnabled`, `claudeMdExcludes`.
- Voice: `voice.{enabled,mode,autoSubmit}` and legacy `voiceEnabled`.
- `hooks` (event-keyed map; full schema in section 4), `disableAllHooks`, `allowManagedHooksOnly`, `allowedHttpHookUrls`, `httpHookAllowedEnvVars`.
- MCP: `enableAllProjectMcpServers`, `enabledMcpjsonServers`, `disabledMcpjsonServers`, `allowedMcpServers`, `deniedMcpServers`, `allowManagedMcpServersOnly`.
- Plugins: `enabledPlugins` (`{"plugin@marketplace": true}`), `extraKnownMarketplaces`, `strictKnownMarketplaces`, `blockedMarketplaces`, `allowedChannelPlugins`.
- `channelsEnabled`, `skipWebFetchPreflight`.
- Sandboxing: full `sandbox.{enabled,failIfUnavailable,autoAllowBashIfSandboxed,excludedCommands,allowUnsandboxedCommands,filesystem,network,enableWeakerNestedSandbox,enableWeakerNetworkIsolation}` block with nested filesystem/network allow/deny lists.
- `teammateMode` (`auto|in-process|tmux`), `defaultShell` (`bash|powershell`).
- Advanced: `companyAnnouncements`, `pluginTrustMessage`, `forceLoginMethod`, `forceLoginOrgUUID`, `forceRemoteSettingsRefresh`, `disableDeepLinkRegistration`, `allowPermissionRulesOnly`, `disableSkillShellExecution`, `showClearContextOnPlanAccept`, `feedbackSurveyRate`, `sshConfigs`, `statusLine`, `wslInheritsWindowsSettings`.
- `worktree.{symlinkDirectories,sparsePaths}`.

Source: <https://code.claude.com/docs/en/settings>

### 2.4 Permission rule grammar

```
Tool                        # all uses of a tool
Tool(pattern)               # specifier
Bash(npm run *)             # glob
Read(./.env)                # path (~ for home, no prefix => project root)
WebFetch(domain:example.com)
MCP(server-name)
Agent(agent-name)
Skill(name) | Skill(name *) # exact / prefix
```

Path prefix table: `/` absolute, `~/` home, `./` (or none) relative to project root in project settings or `~/.claude` in user settings, `//` legacy absolute. Source: <https://code.claude.com/docs/en/settings>

### 2.5 New / 2026 settings

`alwaysThinkingEnabled`, `showThinkingSummaries`, `strictKnownMarketplaces`, `allowedChannelPlugins`, `channelsEnabled`, `fastModePerSessionOptIn`, `useAutoModeDuringPlan`, `wslInheritsWindowsSettings`, `feedbackSurveyRate`. Source: <https://code.claude.com/docs/en/settings>

## 3. Memory (CLAUDE.md, AGENTS.md, Auto memory)

Doc: <https://code.claude.com/docs/en/memory>

### 3.1 Two systems

- CLAUDE.md files (you write).
- Auto memory (Claude writes; first 200 lines or 25 KB of `MEMORY.md` are loaded each session). Auto memory requires Claude Code v2.1.59+. Auto memory directory: `~/.claude/projects/<project>/memory/`. Toggle with `autoMemoryEnabled` or `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`. `autoMemoryDirectory` is accepted from policy/local/user settings only (not project), to prevent shared repos redirecting writes.

### 3.2 CLAUDE.md scopes

| Scope | Path | Shared with |
|---|---|---|
| Managed policy | `/Library/Application Support/ClaudeCode/CLAUDE.md` (macOS), `/etc/claude-code/CLAUDE.md` (Linux/WSL), `C:\Program Files\ClaudeCode\CLAUDE.md` (Windows) | Whole org; cannot be excluded |
| Project | `./CLAUDE.md` or `./.claude/CLAUDE.md` | Team via VCS |
| User | `~/.claude/CLAUDE.md` | You, all projects |
| Local | `./CLAUDE.local.md` | You, current project (gitignore) |

CLAUDE.md files are concatenated by walking up the directory tree; nested files in subdirectories load on-demand when Claude reads files there. `CLAUDE.local.md` is appended after `CLAUDE.md` at each level. Block-level HTML comments are stripped before injection. Source: <https://code.claude.com/docs/en/memory>

### 3.3 AGENTS.md handling (explicit doc statement)

> "Claude Code reads `CLAUDE.md`, not `AGENTS.md`. If your repository already uses `AGENTS.md` for other coding agents, create a `CLAUDE.md` that imports it so both tools read the same instructions without duplicating them."

Recommended pattern:

```markdown
@AGENTS.md

## Claude Code
Use plan mode for changes under `src/billing/`.
```

Source: <https://code.claude.com/docs/en/memory> (section "AGENTS.md")

### 3.4 Imports

`@path/to/file` syntax in CLAUDE.md expands files at launch (relative paths resolve to the file containing the import; max recursion depth 5 hops). First time external imports are seen, an approval dialog is shown; declining disables them silently afterward. Source: <https://code.claude.com/docs/en/memory>

### 3.5 Path-specific rules (`.claude/rules/`)

Markdown files in `.claude/rules/` (recursive). Default load = unconditional, same priority as `.claude/CLAUDE.md`. Add YAML frontmatter to scope:

```yaml
---
paths:
  - "src/api/**/*.ts"
  - "src/**/*.{ts,tsx}"
---
```

Conditional rules trigger when Claude reads a file matching a pattern. User-level rules at `~/.claude/rules/` load before project rules (project rules win conflicts). Symlinks are supported with cycle detection. Source: <https://code.claude.com/docs/en/memory>

### 3.6 Excludes and additional directories

- `claudeMdExcludes` (array of glob/path patterns) skips ancestor CLAUDE.md files; arrays merge across layers; managed-policy CLAUDE.md cannot be excluded.
- `--add-dir` does not load CLAUDE.md by default; set `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1` to opt in.

### 3.7 `/init`

`/init` generates a starter CLAUDE.md by analyzing the repo; suggests improvements rather than overwriting. Set `CLAUDE_CODE_NEW_INIT=1` for the multi-phase interactive flow that proposes CLAUDE.md, skills, and hooks. Source: <https://code.claude.com/docs/en/memory>

## 4. Hooks

Refs: <https://code.claude.com/docs/en/hooks> (reference) and <https://code.claude.com/docs/en/hooks-guide> (walkthroughs).

### 4.1 Configuration shape

```json
{
  "hooks": {
    "EventName": [
      {
        "matcher": "ToolName|OtherTool",
        "hooks": [
          {
            "type": "command|http|mcp_tool|prompt|agent",
            "command": "path/to/script.sh",
            "url": "http://localhost:8080/hook",
            "headers": { "Authorization": "Bearer $TOKEN" },
            "allowedEnvVars": ["TOKEN"],
            "server": "mcp_server_name",
            "tool": "tool_name",
            "input": { "file_path": "${tool_input.file_path}" },
            "prompt": "Evaluate: $ARGUMENTS",
            "model": "model-name",
            "if": "Bash(git *)",
            "timeout": 600,
            "statusMessage": "Running validation...",
            "once": false,
            "async": false,
            "asyncRewake": false,
            "shell": "bash|powershell"
          }
        ]
      }
    ]
  },
  "disableAllHooks": false
}
```

Hook locations: `~/.claude/settings.json`, `.claude/settings.json`, `.claude/settings.local.json`, managed policy settings, plugin `hooks/hooks.json`, and skill/agent frontmatter (lifecycle-scoped). Source: <https://code.claude.com/docs/en/hooks>

### 4.2 Event names (May 2026)

Once per session: `SessionStart`, `SessionEnd`, `Setup`.
Once per turn: `UserPromptSubmit`, `UserPromptExpansion`, `Stop`, `StopFailure`.
Per tool call: `PreToolUse`, `PermissionRequest`, `PermissionDenied`, `PostToolUse`, `PostToolUseFailure`, `PostToolBatch`.
Subagents: `SubagentStart`, `SubagentStop`.
Tasks: `TaskCreated`, `TaskCompleted`.
Teammates: `TeammateIdle`.
Files / config / cwd: `InstructionsLoaded`, `ConfigChange`, `CwdChanged`, `FileChanged`.
Worktrees: `WorktreeCreate`, `WorktreeRemove`.
Compaction: `PreCompact`, `PostCompact`.
Notifications & MCP elicitation: `Notification`, `Elicitation`, `ElicitationResult`.

Source: <https://code.claude.com/docs/en/hooks-guide> (lifecycle table) and <https://code.claude.com/docs/en/hooks>.

### 4.3 Matcher syntax

- `"*"`, `""`, or omitted = match all.
- Letters / digits / `_` / `|` = exact string or pipe-separated list (e.g. `Edit|Write`).
- Other characters = JavaScript regex (e.g. `^Notebook`, `mcp__memory__.*`).
- MCP tools follow `mcp__<server>__<tool>`.
- Per-event matcher targets:
  - tool name (`PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PermissionRequest`, `PermissionDenied`).
  - session origin (`startup|resume|clear|compact`) for `SessionStart`.
  - CLI flag (`init|maintenance`) for `Setup`.
  - exit reason (`clear|logout|other`) for `SessionEnd`.
  - notification type (`permission_prompt|auth_success|...`) for `Notification`.
  - agent type for `SubagentStart`/`SubagentStop`.
  - config source (`user_settings|project_settings|policy_settings`) for `ConfigChange`.
  - error type (`rate_limit|authentication_failed|billing_error`) for `StopFailure`.
  - literal filenames (e.g. `.envrc|.env`) for `FileChanged`.
  - command/skill name for `UserPromptExpansion`.
  - MCP server name for `Elicitation`/`ElicitationResult`.
  - No matcher: `CwdChanged`, `UserPromptSubmit`, `PostToolBatch`, `Stop`, `TaskCreated`, `TaskCompleted`, `WorktreeCreate`, `WorktreeRemove`.

Source: <https://code.claude.com/docs/en/hooks>

### 4.4 Handler types

`command` (shell), `http` (POST event JSON to URL), `mcp_tool` (call a connected MCP tool), `prompt` (single-turn LLM call), `agent` (multi-turn, experimental). Common fields: `type`, `if`, `timeout` (default 600 s for command, 30 s for prompt, 60 s for agent), `statusMessage`, `once` (skill frontmatter only). Source: <https://code.claude.com/docs/en/hooks>

### 4.5 Command-hook IO

- Stdin = JSON event payload. Common fields: `session_id`, `transcript_path`, `cwd`, `permission_mode`, `hook_event_name`, plus per-event extras (`tool_name`, `tool_input`, `tool_use_id`, `tool_result`, `prompt`, `source`, etc.).
- Stdout: JSON or plain text. JSON keys include `continue`, `stopReason`, `suppressOutput`, `systemMessage`, `decision`, `reason`, `hookSpecificOutput.{hookEventName, additionalContext, permissionDecision, updatedInput, decision, sessionTitle, ...}`.
- Exit codes: 0 = success (stdout parsed for context/decision); 2 = blocking error (stderr returned to Claude, blocks the action for `PreToolUse`, `PermissionRequest`, `UserPromptSubmit`, `UserPromptExpansion`, `Stop`, `SubagentStop`, `TaskCreated`, `TaskCompleted`, `ConfigChange`, `PreCompact`, `PostToolBatch`, `WorktreeCreate`); other codes = non-blocking error, first stderr line shown.
- HTTP hook: 2xx + empty body = success, 2xx + plain text = injected as context, 2xx + JSON = parsed for decision, non-2xx = non-blocking error.
- Environment vars: `$CLAUDE_PROJECT_DIR`, `${CLAUDE_PLUGIN_ROOT}`, `${CLAUDE_PLUGIN_DATA}`, `CLAUDE_ENV_FILE` (for `SessionStart`, `Setup`, `CwdChanged`, `FileChanged`).
- Async: `"async": true` runs in background; `"asyncRewake": true` wakes Claude when an exit-2 hook finishes.
- v2.1.89+ adds `"permissionDecision": "defer"` for `PreToolUse` to hand off to external UIs.
- Identical hook commands/URLs are deduplicated automatically.

Source: <https://code.claude.com/docs/en/hooks>

### 4.6 Skill/agent frontmatter hooks

```yaml
---
name: secure-operations
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/security-check.sh"
---
```

Source: <https://code.claude.com/docs/en/hooks>

### 4.7 Hooks-guide highlights

- `/hooks` opens a read-only browser of configured hooks; edit settings JSON to change them.
- Ready-made examples: desktop notifications via `osascript`/`notify-send`/PowerShell; auto-format with Prettier in `PostToolUse Edit|Write`; protect files via `PreToolUse` script; re-inject context with `SessionStart` matcher `compact`; audit `ConfigChange`; reload env via `direnv export bash > "$CLAUDE_ENV_FILE"` in `SessionStart` and `CwdChanged`/`FileChanged`; auto-approve `ExitPlanMode` with `PermissionRequest` JSON output.
- "When multiple hooks match, each one returns its own result. For decisions, Claude Code picks the most restrictive answer." Source: <https://code.claude.com/docs/en/hooks-guide>

## 5. Plugins

Refs: <https://code.claude.com/docs/en/plugins> (authoring), <https://code.claude.com/docs/en/discover-plugins> (marketplace mechanics).

### 5.1 Plugin layout

```
my-plugin/
├── .claude-plugin/
│   └── plugin.json        # required manifest (only file inside .claude-plugin/)
├── skills/                # <name>/SKILL.md directories
├── commands/              # legacy flat-Markdown commands (still works)
├── agents/                # custom subagents (no hooks/mcpServers/permissionMode)
├── hooks/hooks.json       # event handlers
├── .mcp.json              # MCP servers
├── .lsp.json              # Language servers
├── monitors/monitors.json # background monitors
├── bin/                   # executables added to Bash PATH while enabled
└── settings.json          # plugin defaults (only `agent` and `subagentStatusLine` honored today)
```

Common mistake: only `plugin.json` belongs inside `.claude-plugin/`. All other directories live at the plugin root. Source: <https://code.claude.com/docs/en/plugins>

### 5.2 `plugin.json` manifest fields

```json
{
  "name": "my-first-plugin",
  "description": "A greeting plugin to learn the basics",
  "version": "1.0.0",
  "author": { "name": "Your Name" }
}
```

Optional: `homepage`, `repository`, `license`, plus inline `mcpServers`. The full manifest schema is in `/en/plugins-reference#plugin-manifest-schema`. `name` is the namespace prefix for skills (`/<plugin>:<skill>`). If `version` is omitted and the plugin is git-distributed, the commit SHA is used. Source: <https://code.claude.com/docs/en/plugins>

### 5.3 Local development

- `claude --plugin-dir ./my-plugin` (multiple `--plugin-dir` flags allowed).
- Local copy overrides installed marketplace plugin with the same name (except managed-pinned plugins).
- `/reload-plugins` picks up changes to plugins, skills, agents, hooks, plugin MCP, and plugin LSP without restart.
- For security, plugin subagents ignore `hooks`, `mcpServers`, `permissionMode` frontmatter.

### 5.4 Marketplace mechanics

Doc: <https://code.claude.com/docs/en/discover-plugins>

- Two-step model: `/plugin marketplace add` registers the catalog; `/plugin install` installs individual plugins.
- Official marketplace `claude-plugins-official` is auto-available; browse via `/plugin` Discover tab or <https://claude.com/plugins>. Install with `/plugin install <name>@claude-plugins-official`.
- Source types accepted by `/plugin marketplace add`:
  - GitHub repo: `owner/repo`.
  - Any git URL (HTTPS or SSH), optionally pinned with `#ref`.
  - Local path: directory containing `.claude-plugin/marketplace.json`, or direct file path.
  - Remote URL to a hosted `marketplace.json`.
- Plugin install scopes: User (default), Project (writes to `.claude/settings.json`), Local (per-developer, this repo), and Managed (admin-installed; immutable). Source: <https://code.claude.com/docs/en/discover-plugins>
- Direct CLI: `/plugin install`, `/plugin disable`, `/plugin enable`, `/plugin uninstall`; the same with `claude plugin ... --scope project|local|user`.
- Auto-update: enabled by default for official Anthropic marketplaces, disabled by default for third-party / local; toggled per-marketplace in `/plugin`. `DISABLE_AUTOUPDATER` disables everything; `FORCE_AUTOUPDATE_PLUGINS=1` keeps plugin updates while disabling Claude Code self-updates.
- Team marketplaces via `extraKnownMarketplaces` in `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "my-team-tools": {
      "source": { "source": "github", "repo": "your-org/claude-plugins" }
    }
  }
}
```

Source kinds accepted in settings (`extraKnownMarketplaces` / `strictKnownMarketplaces`): `github`, `git`, `directory`, `hostPattern`, `settings`, `url`, `npm`, `file`. Source: <https://code.claude.com/docs/en/settings>

### 5.5 Code-intelligence plugins (LSP)

Pre-built per-language plugins from the official marketplace: `clangd-lsp`, `csharp-lsp`, `gopls-lsp`, `jdtls-lsp`, `kotlin-lsp`, `lua-lsp`, `php-lsp`, `pyright-lsp`, `rust-analyzer-lsp`, `swift-lsp`, `typescript-lsp`. Each requires the corresponding language server binary on PATH. Diagnostics flow back to Claude after every edit; Ctrl+O reveals inline. Source: <https://code.claude.com/docs/en/discover-plugins>

### 5.6 Plugin-bundled MCP servers

Defined either in `.mcp.json` at plugin root or inline under `mcpServers` in `plugin.json`. Use `${CLAUDE_PLUGIN_ROOT}` for bundled paths and `${CLAUDE_PLUGIN_DATA}` for persistent state. Lifecycle is automatic: connect when plugin enabled, refresh via `/reload-plugins`. Source: <https://code.claude.com/docs/en/plugins> and <https://code.claude.com/docs/en/mcp>

### 5.7 Background monitors

`monitors/monitors.json` with entries `{ name, command, description, ...when }`. Each stdout line from `command` is delivered to Claude as a notification. Schema details in `/en/plugins-reference#monitors`. Source: <https://code.claude.com/docs/en/plugins>

## 6. Skills

Doc: <https://code.claude.com/docs/en/skills>

### 6.1 Storage and precedence

| Location | Path | Applies to |
|---|---|---|
| Enterprise (managed) | via managed settings | All org users |
| Personal | `~/.claude/skills/<name>/SKILL.md` | All your projects |
| Project | `.claude/skills/<name>/SKILL.md` | Current project |
| Plugin | `<plugin>/skills/<name>/SKILL.md` | Where plugin is enabled |

Precedence: Enterprise > Personal > Project. Plugin skills are namespaced (`<plugin>:<skill>`), so they cannot collide. If a `.claude/commands/<name>.md` and a skill share a name, the skill wins. Source: <https://code.claude.com/docs/en/skills>

Live change detection watches `~/.claude/skills/`, `.claude/skills/`, and `.claude/skills/` inside any `--add-dir`. Creating a top-level skills directory mid-session requires a restart. Nested `.claude/skills/` in subdirectories load automatically when Claude reads files there (monorepo-friendly). Source: <https://code.claude.com/docs/en/skills>

### 6.2 SKILL.md frontmatter

| Field | Notes |
|---|---|
| `name` | Lowercase letters/digits/hyphens, max 64 chars; defaults to directory name. |
| `description` | Recommended; combined with `when_to_use` truncated at 1,536 chars in skill listing. |
| `when_to_use` | Trigger phrases, appended to `description` (still capped at 1,536). |
| `argument-hint` | Autocomplete hint (e.g., `[issue-number]`). |
| `arguments` | Named positional args for `$name` substitution (space-separated string or YAML list). |
| `disable-model-invocation` | `true` = manual-only; also blocks preload into subagents. |
| `user-invocable` | `false` = hidden from `/` menu, only Claude can invoke. |
| `allowed-tools` | Pre-approves tools while skill active (does not restrict). |
| `model` | Per-skill override (alias / full ID / `inherit`); resets next prompt. |
| `effort` | `low|medium|high|xhigh|max`. |
| `context` | `fork` runs skill in subagent context. |
| `agent` | Subagent type used when `context: fork` (defaults to `general-purpose`). |
| `hooks` | Skill-scoped lifecycle hooks. |
| `paths` | Glob patterns auto-loading the skill when matching files are touched. |
| `shell` | `bash` (default) or `powershell` (requires `CLAUDE_CODE_USE_POWERSHELL_TOOL=1`). |

Source: <https://code.claude.com/docs/en/skills>

### 6.3 Substitutions inside SKILL.md

`$ARGUMENTS`, `$ARGUMENTS[N]`, `$N`, `$name` (named arg), `${CLAUDE_SESSION_ID}`, `${CLAUDE_EFFORT}`, `${CLAUDE_SKILL_DIR}`. Indexed args use shell-style quoting. Source: <https://code.claude.com/docs/en/skills>

### 6.4 Dynamic context injection

`` !`<command>` `` runs a shell command at render time (output replaces the placeholder). Multi-line variant uses a fenced ` ```! ` block. Disable globally by setting `"disableSkillShellExecution": true` in settings; bundled and managed skills are exempt. Including the literal word `ultrathink` enables extended thinking. Source: <https://code.claude.com/docs/en/skills>

### 6.5 Bundled skills

Always available: `/simplify`, `/batch`, `/debug`, `/loop`, `/claude-api`, plus more. Bundled skills are prompt-based playbooks; they are listed in the commands reference with **Skill** marker. Source: <https://code.claude.com/docs/en/skills> and <https://code.claude.com/docs/en/commands>

### 6.6 Lifecycle and compaction

A skill's rendered SKILL.md enters the conversation as a single message and stays for the rest of the session (it is not re-read). On auto-compaction, Claude Code re-attaches the most recent invocation of each skill, keeping the first 5,000 tokens per skill, with a combined re-attach budget of 25,000 tokens (most-recent-first fill). Re-invoke explicitly to restore full content if dropped. Source: <https://code.claude.com/docs/en/skills>

### 6.7 Open standard

Claude Code skills follow the Agent Skills open standard at <https://agentskills.io>; Claude Code adds invocation control, subagent execution, and dynamic context injection on top. Source: <https://code.claude.com/docs/en/skills>

## 7. MCP

Doc: <https://code.claude.com/docs/en/mcp>

### 7.1 Server transports

`stdio` (local process), `http` (recommended for remote), `sse` (deprecated; use HTTP). Add via:

```bash
claude mcp add --transport http <name> <url>
claude mcp add --transport sse <name> <url> --header "X-API-Key: ..."
claude mcp add --transport stdio --env KEY=value <name> -- npx -y package
```

All flags must precede the server name; `--` separates Claude flags from the server's own args. Source: <https://code.claude.com/docs/en/mcp>

### 7.2 Scopes (precedence high to low)

1. Local (default) – `~/.claude.json` keyed by project path; private to you.
2. Project – `.mcp.json` at repo root; shared with team via VCS.
3. User – `~/.claude.json`, available across your projects.
4. Plugin-provided servers.
5. claude.ai connectors.

Local/Project/User match by name; plugin and connector entries match by endpoint. "Local scope" for MCP differs from `.claude/settings.local.json` general settings (MCP local lives in `~/.claude.json`). Source: <https://code.claude.com/docs/en/mcp>

### 7.3 `.mcp.json` shape and env expansion

```json
{
  "mcpServers": {
    "shared-server": {
      "command": "/path/to/server",
      "args": [],
      "env": {}
    },
    "api-server": {
      "type": "http",
      "url": "${API_BASE_URL:-https://api.example.com}/mcp",
      "headers": { "Authorization": "Bearer ${API_KEY}" }
    }
  }
}
```

Variable expansion supports `${VAR}` and `${VAR:-default}` in `command`, `args`, `env`, `url`, `headers`. Required vars without defaults cause parse failure. Source: <https://code.claude.com/docs/en/mcp>

### 7.4 Lifecycle and OAuth

- `list_changed` notifications dynamically refresh tools without reconnect.
- HTTP/SSE auto-reconnect with exponential backoff: up to five mid-session attempts (1 s, 2 s, 4 s, ...). Initial-connection retries (v2.1.121+) up to three times on 5xx / connection errors / timeouts. Auth and not-found errors are not retried. Stdio servers are not auto-reconnected.
- OAuth 2.0 supported; `/mcp` triggers browser login; `--callback-port` fixes the port; `--client-id` / `--client-secret` for pre-registered apps; `oauth.scopes` pins requested scopes; `authServerMetadataUrl` overrides discovery (requires v2.1.64+); `headersHelper` lets non-OAuth schemes generate headers via shell command (10 s timeout, JSON output). Source: <https://code.claude.com/docs/en/mcp>

### 7.5 Plugin MCP servers

Defined in plugin `.mcp.json` or inline in `plugin.json`. Use `${CLAUDE_PLUGIN_ROOT}` and `${CLAUDE_PLUGIN_DATA}`. Refresh with `/reload-plugins`. Source: <https://code.claude.com/docs/en/mcp>

### 7.6 Limits

`MCP_TIMEOUT` (e.g., `MCP_TIMEOUT=10000 claude`) controls startup timeout; `MAX_MCP_OUTPUT_TOKENS` raises the 10,000-token output warning threshold. Source: <https://code.claude.com/docs/en/mcp>

### 7.7 Channels

MCP servers can declare `claude/channel` capability and be opted in with `--channels` to push messages into the session. See `/en/channels` and `/en/channels-reference`. Source: <https://code.claude.com/docs/en/mcp>

## 8. Subagents

Doc: <https://code.claude.com/docs/en/sub-agents>

### 8.1 Built-ins

- `Explore`: read-only, model `Haiku`, denied Write/Edit; for codebase search.
- `Plan`: read-only, inherits model; backs Plan Mode (no nesting allowed).
- `general-purpose`: full tools, inherits model.
- `statusline-setup` (Sonnet, used by `/statusline`).
- `Claude Code Guide` (Haiku, answers questions about Claude Code).

Source: <https://code.claude.com/docs/en/sub-agents>

### 8.2 Scope and precedence

| Location | Priority | Notes |
|---|---|---|
| Managed settings `.claude/agents/` | 1 (highest) | Org-deployed |
| `--agents` CLI flag (JSON) | 2 | Session-only |
| `.claude/agents/` | 3 | Project, VCS-shared |
| `~/.claude/agents/` | 4 | Personal |
| Plugin `agents/` | 5 (lowest) | Plugin-scoped |

Project subagents are discovered by walking up from cwd; `--add-dir` does not scan for subagents. Plugin subagents ignore `hooks`, `mcpServers`, `permissionMode` for security.

`claude agents` lists all configured subagents from the CLI. The `/agents` command opens a tabbed UI (Running, Library) for create/edit/delete. Source: <https://code.claude.com/docs/en/sub-agents>

### 8.3 Frontmatter

Required: `name` (lowercase + hyphens), `description`. Optional: `tools`, `disallowedTools`, `model` (`sonnet|opus|haiku|<full id>|inherit`; default `inherit`), `permissionMode` (`default|acceptEdits|auto|dontAsk|bypassPermissions|plan`), `maxTurns`, `skills` (preload), `mcpServers` (string ref or inline definition), `hooks`, `memory` (`user|project|local`), `background`, `effort`, `isolation` (`worktree`), `color`, `initialPrompt`. Tools list supports `Agent(agent_type)` to allowlist which subagents the main thread can spawn (the Task tool was renamed to `Agent` in v2.1.63; `Task(...)` still works as alias). Source: <https://code.claude.com/docs/en/sub-agents>

### 8.4 Persistent memory

`memory: user|project|local` enables auto-managed memory directories (`~/.claude/agent-memory/<name>/`, `.claude/agent-memory/<name>/`, `.claude/agent-memory-local/<name>/`). The first 200 lines or 25 KB of `MEMORY.md` is injected on each subagent run. Source: <https://code.claude.com/docs/en/sub-agents>

### 8.5 Skill / subagent interop

- `context: fork` in a SKILL invokes a subagent whose system prompt comes from the agent type and whose user task comes from the SKILL body.
- `skills:` in a subagent preloads full SKILL content (subagents don't inherit skills from the parent). Source: <https://code.claude.com/docs/en/sub-agents>

## 9. Authentication & IAM

Doc: <https://code.claude.com/docs/en/iam>

### 9.1 Account types

Claude Pro/Max, Claude for Teams, Claude for Enterprise (adds SSO, domain capture, role-based permissions, compliance API, managed policy settings), Claude Console (with Claude Code role or Developer role), and cloud providers (Bedrock, Vertex AI, Foundry).

### 9.2 Credential storage

- macOS: encrypted Keychain.
- Linux/Windows: `~/.claude/.credentials.json` (Linux mode `0600`; Windows inherits user profile ACLs); honors `$CLAUDE_CONFIG_DIR`.

### 9.3 `apiKeyHelper` script

Refresh after 5 minutes or on HTTP 401 by default; `CLAUDE_CODE_API_KEY_HELPER_TTL_MS` overrides. Notice shown if helper takes > 10 s. Applies only to terminal CLI sessions (Desktop and remote sessions use OAuth).

### 9.4 Authentication precedence

1. Cloud provider credentials (`CLAUDE_CODE_USE_BEDROCK|VERTEX|FOUNDRY`).
2. `ANTHROPIC_AUTH_TOKEN` (sent as `Authorization: Bearer`).
3. `ANTHROPIC_API_KEY` (sent as `X-Api-Key`).
4. `apiKeyHelper` output.
5. `CLAUDE_CODE_OAUTH_TOKEN` (long-lived OAuth from `claude setup-token`; valid one year, scoped to inference, no Remote Control).
6. Subscription OAuth from `/login`.

Note: Web sessions always use subscription credentials regardless of env vars. Bare mode (`--bare`) does not read `CLAUDE_CODE_OAUTH_TOKEN`. Source: <https://code.claude.com/docs/en/iam>

## 10. Slash commands and Output styles

### 10.1 Slash commands

`/slash-commands` redirects to skills. The skills doc states explicitly: "Custom commands have been merged into skills. A file at `.claude/commands/deploy.md` and a skill at `.claude/skills/deploy/SKILL.md` both create `/deploy` and work the same way." Existing `.claude/commands/` flat-Markdown files keep working. The full reference of built-ins lives at <https://code.claude.com/docs/en/commands>. Source: <https://code.claude.com/docs/en/skills>

Built-in commands include (non-exhaustive, see `/en/commands`): `/help`, `/init`, `/memory`, `/agents`, `/plugin`, `/mcp`, `/hooks`, `/config`, `/compact`, `/clear`, `/review`, `/security-review`, `/loop`, `/schedule`, `/statusline`, `/output-style`, `/desktop`, `/upgrade`, `/effort`, `/model`, `/rename`. Bundled skills (marked **Skill**): `/simplify`, `/batch`, `/debug`, `/loop`, `/claude-api`. Source: <https://code.claude.com/docs/en/commands>

### 10.2 Output styles

Doc: <https://code.claude.com/docs/en/output-styles>

- Built-in: **Default**, **Explanatory**, **Learning**.
- Pick via `/config` (saved to `.claude/settings.local.json`) or set `outputStyle` in settings JSON. New sessions pick up the change (kept stable to preserve prompt caching).
- Custom files are Markdown with frontmatter:

```markdown
---
name: My Custom Style
description: Brief description shown in /config picker
keep-coding-instructions: false
---

# Custom Style Instructions
...
```

- Locations: `~/.claude/output-styles` (user) and `.claude/output-styles` (project). Plugins ship them in `output-styles/`.
- By default, custom styles strip the coding-engineering portion of Claude Code's system prompt unless `keep-coding-instructions: true`.
- Compared to other features:
  - vs CLAUDE.md: CLAUDE.md is appended as a user message after the system prompt; output styles modify the system prompt.
  - vs `--append-system-prompt`: that flag appends; output styles replace the engineering parts.
  - vs Skills: output styles are always-on and shape tone/structure; skills are task-specific and invoked.
  - vs Subagents: output styles affect the main loop only.

Source: <https://code.claude.com/docs/en/output-styles>

## 11. Status line

Doc: <https://code.claude.com/docs/en/statusline>

Configure via:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh",
    "padding": 2,
    "refreshInterval": 5,
    "hideVimModeIndicator": true
  }
}
```

- Script reads JSON from stdin; stdout is rendered (multi-line via multiple `echo`s; ANSI colors and OSC-8 hyperlinks supported).
- Updates after each new assistant message, on permission mode change, or vim mode toggle; debounced 300 ms; in-flight runs are cancelled when a new event fires.
- `refreshInterval` (>= 1 s) keeps time-based segments fresh during idle waits.

Available data fields (selected): `model.{id, display_name}`, `cwd`, `workspace.{current_dir, project_dir, added_dirs, git_worktree}`, `cost.{total_cost_usd, total_duration_ms, total_api_duration_ms, total_lines_added, total_lines_removed}`, `context_window.{total_input_tokens, total_output_tokens, context_window_size, used_percentage, remaining_percentage, current_usage}`, `exceeds_200k_tokens`, `effort.level`, `thinking.enabled`, `rate_limits.{five_hour, seven_day}.{used_percentage, resets_at}`, `session_id`, `session_name`, `transcript_path`, `version`, `output_style.name`, `vim.mode`, `agent.name`, `worktree.{name, path, branch, original_cwd, original_branch}`. Some fields are absent when irrelevant (`session_name`, `vim`, `agent`, `worktree`, `effort`, `rate_limits`). Source: <https://code.claude.com/docs/en/statusline>

`used_percentage` is computed from input tokens only (`input + cache_creation + cache_read`), not output tokens. `current_usage` is `null` before the first API call. Source: <https://code.claude.com/docs/en/statusline>

## 12. AGENTS.md cross-tool standard

Source: <https://agents.md>

- Open format described as "a simple, open format for guiding coding agents", positioned as a README for AI tools, in use across 60,000+ open-source projects (per the agents.md home page).
- No required fields. Recommended sections: project overview, build/test commands, code style, testing, security, dev environment tips, PR guidelines, deployment.
- Stewarded by the Agentic AI Foundation under the Linux Foundation; collaborators include OpenAI Codex, Amp, Jules (Google), Cursor, Factory.
- Supported by 20+ agents (Claude, Codex, Jules, Aider, Devin, VS Code, GitHub Copilot, Cursor, Zed, Gemini CLI, Warp, Windsurf, JetBrains Junie, ...).
- Resolution rule: "The closest AGENTS.md to the edited file wins" (nested files in monorepos).
- 2026-specific updates: not documented in the agents.md home page.

### Claude Code's stance

> "Claude Code reads `CLAUDE.md`, not `AGENTS.md`."
> Source: <https://code.claude.com/docs/en/memory> ("AGENTS.md" section)

Recommended bridge is to import AGENTS.md from the project's CLAUDE.md (`@AGENTS.md`). No automatic AGENTS.md fallback exists in Claude Code as of May 2026.

## 13. Cross-cutting environment variables

Selected env vars referenced across the docs (not exhaustive):

- `CLAUDE_CODE_DISABLE_AUTO_MEMORY` – disable auto memory.
- `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD` – load CLAUDE.md from `--add-dir` paths.
- `CLAUDE_CODE_NEW_INIT` – multi-phase `/init`.
- `CLAUDE_CODE_USE_BEDROCK | _VERTEX | _FOUNDRY` – cloud provider routing.
- `CLAUDE_CODE_OAUTH_TOKEN` – long-lived OAuth token from `claude setup-token`.
- `CLAUDE_CODE_API_KEY_HELPER_TTL_MS` – override `apiKeyHelper` refresh.
- `CLAUDE_CODE_USE_POWERSHELL_TOOL` – enable PowerShell shell injection in skills.
- `CLAUDE_CODE_SUBAGENT_MODEL` – override subagent model resolution.
- `MCP_TIMEOUT`, `MAX_MCP_OUTPUT_TOKENS`, `MCP_CLIENT_SECRET` – MCP runtime tuning / OAuth automation.
- `SLASH_COMMAND_TOOL_CHAR_BUDGET` – widens skill description budget (default = 1% of context window, fallback 8,000 chars).
- `DISABLE_AUTOUPDATER`, `FORCE_AUTOUPDATE_PLUGINS` – auto-update controls.

Sources: <https://code.claude.com/docs/en/memory>, <https://code.claude.com/docs/en/iam>, <https://code.claude.com/docs/en/skills>, <https://code.claude.com/docs/en/mcp>, <https://code.claude.com/docs/en/sub-agents>, <https://code.claude.com/docs/en/discover-plugins>

## 14. Notable items new in 2025/2026

- Microsoft Foundry as a first-class provider (overview tabs and `CLAUDE_CODE_USE_FOUNDRY`). Source: <https://code.claude.com/docs/en/overview>, <https://code.claude.com/docs/en/iam>
- Routines (Anthropic-managed scheduled agents), Channels (push messages from MCP/3rd-party into a session), Remote Control, Dispatch, `claude --teleport`, `/loop`, `/schedule`. Source: <https://code.claude.com/docs/en/overview>
- Documentation host migration: `docs.claude.com/en/docs/claude-code/*` 301-redirects to `code.claude.com/docs/en/*` (verified during this research).
- Hook events `SubagentStart`, `SubagentStop`, `TaskCreated`, `TaskCompleted`, `TeammateIdle`, `ConfigChange`, `CwdChanged`, `FileChanged`, `WorktreeCreate`, `WorktreeRemove`, `Elicitation`, `ElicitationResult`, `PostToolBatch`, `StopFailure`, `Setup`, `UserPromptExpansion`, `InstructionsLoaded`, `PostToolUseFailure`. Source: <https://code.claude.com/docs/en/hooks-guide>
- `permissionDecision: "defer"` (v2.1.89+), MCP initial-connection retries (v2.1.121+), `authServerMetadataUrl` (v2.1.64+), Auto memory (v2.1.59+), Task tool renamed to Agent (v2.1.63). Sources cited above.
- Settings keys: `alwaysThinkingEnabled`, `showThinkingSummaries`, `strictKnownMarketplaces`, `allowedChannelPlugins`, `channelsEnabled`, `fastModePerSessionOptIn`, `useAutoModeDuringPlan`, `wslInheritsWindowsSettings`, `feedbackSurveyRate`, `disableSkillShellExecution`. Source: <https://code.claude.com/docs/en/settings>
- Code-intelligence LSP plugins shipped as official marketplace plugins (`typescript-lsp`, `pyright-lsp`, `rust-analyzer-lsp`, etc.); diagnostics surface inline via Ctrl+O. Source: <https://code.claude.com/docs/en/discover-plugins>
- Custom commands and skills are unified: `.claude/commands/<name>.md` and `.claude/skills/<name>/SKILL.md` both produce `/<name>`; skill wins on conflict. Source: <https://code.claude.com/docs/en/skills>

## 15. Canonical doc URLs

- Overview: <https://code.claude.com/docs/en/overview>
- Settings: <https://code.claude.com/docs/en/settings>
- Hooks reference: <https://code.claude.com/docs/en/hooks>
- Hooks guide: <https://code.claude.com/docs/en/hooks-guide>
- Plugins (authoring): <https://code.claude.com/docs/en/plugins>
- Plugins reference: <https://code.claude.com/docs/en/plugins-reference>
- Discover plugins (marketplaces): <https://code.claude.com/docs/en/discover-plugins>
- Plugin marketplaces (publishing): <https://code.claude.com/docs/en/plugin-marketplaces>
- Skills: <https://code.claude.com/docs/en/skills>
- MCP: <https://code.claude.com/docs/en/mcp>
- Subagents: <https://code.claude.com/docs/en/sub-agents>
- Memory: <https://code.claude.com/docs/en/memory>
- IAM / authentication: <https://code.claude.com/docs/en/iam>
- Commands reference: <https://code.claude.com/docs/en/commands>
- Output styles: <https://code.claude.com/docs/en/output-styles>
- Status line: <https://code.claude.com/docs/en/statusline>
- llms.txt index: <https://code.claude.com/docs/llms.txt>
- AGENTS.md spec: <https://agents.md>
- Agent Skills standard: <https://agentskills.io>
- Settings JSON schema: <https://json.schemastore.org/claude-code-settings.json>

There is no separate canonical `slash-commands` page; that path now lives in skills/commands. Anything not explicitly cited above (e.g., AGENTS.md 2026 changes, deeper plugin-monitor schema, full hook reference for every newer event payload) is not documented in the pages fetched.
