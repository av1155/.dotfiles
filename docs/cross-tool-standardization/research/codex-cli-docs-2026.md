---
title: OpenAI Codex CLI: 2026 Documentation Reference
generated: 2026-05-02
sources_root: https://developers.openai.com/codex
github_root: https://github.com/openai/codex/tree/main/docs
---

# OpenAI Codex CLI Documentation Reference (May 2026)

This is a dense factual extract from the official OpenAI Codex CLI documentation as of May 2026. Every claim has a source URL. Where a claim is "not documented", that is stated explicitly.

The GitHub `docs/` tree is largely a set of stub files that delegate to `https://developers.openai.com/codex`. Authoritative reference material lives on the developer portal. Verified file inventory of `docs/` (May 2026): `CLA.md`, `agents_md.md`, `authentication.md`, `config.md`, `contributing.md`, `example-config.md`, `exec.md`, `execpolicy.md`, `exit-confirmation-prompt-design.md`, `getting-started.md`, `install.md`, `license.md`, `open-source-fund.md`, `sandbox.md`, `skills.md`, `slash_commands.md`, plus several `tui-*.md` design docs ([github.com/openai/codex/tree/main/docs](https://github.com/openai/codex/tree/main/docs)). There are no `hooks.md`, `mcp.md`, `plugins.md`, `subagents.md`, `agents.md`, or `advanced.md` files in the repo; all those topics live on the developer portal.

Current stable version observed: **0.128.0** (released April 30, 2026), distributed via `npm i -g @openai/codex` or `brew install --cask codex`, with platform binaries on the GitHub releases page ([github.com/openai/codex](https://github.com/openai/codex)).

---

## 1. Installation, Auth, and Layout

System requirements: macOS 12+, Ubuntu 20.04+/Debian 10+, or Windows 11 via WSL2; Git 2.23+ recommended; 4 GB RAM minimum, 8 GB recommended ([install.md](https://github.com/openai/codex/blob/main/docs/install.md)).

Authentication options: "Sign in with ChatGPT" (Plus, Pro, Business, Edu, or Enterprise) or API key. CI/non-interactive runs use the `CODEX_API_KEY` environment variable ([developers.openai.com/codex/cli](https://developers.openai.com/codex/cli), [developers.openai.com/codex/noninteractive](https://developers.openai.com/codex/noninteractive)).

Default Codex home directory: `~/.codex/` (override via `CODEX_HOME`). Logs default to `~/.codex/log/codex-tui.log` ([install.md](https://github.com/openai/codex/blob/main/docs/install.md)). State DB path is `sqlite_home` (config key) or `CODEX_SQLITE_HOME` env var, defaulting to `CODEX_HOME` for most modes ([config.md](https://raw.githubusercontent.com/openai/codex/main/docs/config.md)).

---

## 2. Configuration Files and Precedence

Two main TOML files exist:

- User-level: `~/.codex/config.toml`
- Project-level: `<repo>/.codex/config.toml` (loaded only if the project is marked **trusted**)

System-level admin config: `/etc/codex/config.toml` on Unix ([developers.openai.com/codex/config-basic](https://developers.openai.com/codex/config-basic)).

A separate `requirements.toml` file enforces admin-level guardrails (allowed sandbox modes, allowed approval policies, mandated MCP server identity hashes, hook managed dirs, prefix-rule denylists) ([developers.openai.com/codex/config-reference](https://developers.openai.com/codex/config-reference)).

**Precedence (highest to lowest):**

1. CLI flags and `--config` overrides
2. Active profile (`--profile <name>`)
3. Project config (closest directory wins; trusted projects only)
4. User config (`~/.codex/config.toml`)
5. System config (`/etc/codex/config.toml`)
6. Built-in defaults

Source: [developers.openai.com/codex/config-basic](https://developers.openai.com/codex/config-basic).

The generated JSON Schema for `config.toml` lives at `codex-rs/core/config.schema.json` and is published at `https://developers.openai.com/codex/config-schema.json` for IDE autocompletion ([config.md](https://raw.githubusercontent.com/openai/codex/main/docs/config.md), [developers.openai.com/codex/config-reference](https://developers.openai.com/codex/config-reference)).

---

## 3. AGENTS.md Loading and Precedence

AGENTS.md is the cross-tool open standard now stewarded by the **Agentic AI Foundation under the Linux Foundation**, with 20+ compatible tools including OpenAI Codex, Anthropic Claude, Cursor, VS Code, GitHub Copilot, JetBrains Junie, Aider, Zed, Warp, UiPath Autopilot, Factory.ai, and Google Jules ([agents.md](https://agents.md)).

**Codex discovery order** ([developers.openai.com/codex/guides/agents-md](https://developers.openai.com/codex/guides/agents-md)):

1. Global: `~/.codex/AGENTS.override.md` if present, otherwise `~/.codex/AGENTS.md`
2. Project scope: starting at the project root (typically the Git root), walks down to the current working directory. At each level it checks for `AGENTS.override.md`, then `AGENTS.md`, then any `project_doc_fallback_filenames`.

**Concatenation rule:** "Codex concatenates files from the root down, joining them with blank lines. Files closer to your current directory override earlier guidance because they appear later in the combined prompt" ([developers.openai.com/codex/guides/agents-md](https://developers.openai.com/codex/guides/agents-md)).

**Size cap:** Codex skips empty files and stops appending once the combined size reaches `project_doc_max_bytes` (default 32 KiB). Configurable in `~/.codex/config.toml` ([developers.openai.com/codex/guides/agents-md](https://developers.openai.com/codex/guides/agents-md)).

Fallback filenames example:

```toml
project_doc_fallback_filenames = ["TEAM_GUIDE.md", ".agents.md"]
```

A feature flag `child_agents_md` under `[features]` causes Codex to append additional guidance about AGENTS.md scope and precedence to the user-instructions message and to emit that message even when no AGENTS.md is present ([agents_md.md](https://raw.githubusercontent.com/openai/codex/main/docs/agents_md.md)).

Frontmatter is **not documented** as required or supported. AGENTS.md is plain Markdown ([agents.md](https://agents.md)).

---

## 4. Sandbox Modes, Approval Policies, and Trust Levels

Note: the `docs/sandbox.md` file in the repo only links to [developers.openai.com/codex/security](https://developers.openai.com/codex/security), and the linked page focuses on "Codex Security" (the GitHub vulnerability scanner product), not CLI sandboxing. Sandbox CLI specifics are documented in [config-reference](https://developers.openai.com/codex/config-reference) and [config-advanced](https://developers.openai.com/codex/config-advanced).

**Sandbox modes** (`sandbox_mode`): `read-only`, `workspace-write`, `danger-full-access` ([config-reference](https://developers.openai.com/codex/config-reference), [config-basic](https://developers.openai.com/codex/config-basic)).

**Approval policies** (`approval_policy`): `untrusted`, `on-request`, `never`. A `granular` variant exists with sub-fields ([config-reference](https://developers.openai.com/codex/config-reference)).

**Reviewer:** `approvals_reviewer = "user"` or `"auto_review"` ([config-reference](https://developers.openai.com/codex/config-reference)).

**Workspace-write fields** ([config-reference](https://developers.openai.com/codex/config-reference)):

```toml
[sandbox_workspace_write]
network_access = false
exclude_slash_tmp = false
exclude_tmpdir_env_var = false
writable_roots = ["/home/user/project"]
```

**Granular approvals:**

```toml
[approval_policy.granular]
sandbox_approval = true
rules = true
mcp_elicitations = false
request_permissions = true
skill_approval = true
```

**Project trust:**

```toml
[projects."/path/to/project"]
trust_level = "trusted"   # or "untrusted"
```

Project-scoped config and project-local hooks load **only if** the project is `trusted` ([config-reference](https://developers.openai.com/codex/config-reference), [developers.openai.com/codex/hooks](https://developers.openai.com/codex/hooks)).

**Permission profiles** are a richer named system layered on top, with `default_permissions` selecting one. Built-in profiles: `:read-only`, `:workspace`, `:danger-no-sandbox`. Custom profiles allow per-path filesystem permissions (`read`/`write`/`none`), per-domain network rules (`allow`/`deny`), proxy/SOCKS settings, and Unix-socket allowlists ([config-reference](https://developers.openai.com/codex/config-reference)).

OS-specific sandbox primitives (macOS Seatbelt, Linux Landlock) are **not explicitly documented** in the May 2026 published references; sandbox enforcement is described abstractly via `sandbox_mode`. Windows uses `[windows] sandbox = "elevated" | "unelevated"` ([config-reference](https://developers.openai.com/codex/config-reference)).

---

## 5. MCP Server Configuration

Source: [developers.openai.com/codex/mcp](https://developers.openai.com/codex/mcp), [config.md](https://raw.githubusercontent.com/openai/codex/main/docs/config.md), [config-reference](https://developers.openai.com/codex/config-reference).

Two transports: STDIO (local subprocess) and Streamable HTTP (remote URL).

**STDIO server example:**

```toml
[mcp_servers.my-server]
enabled = true
command = "/usr/local/bin/server"
args = ["--config", "config.json"]
cwd = "/var/lib/server"
startup_timeout_sec = 10        # default 10
tool_timeout_sec = 60           # default 60
required = false
enabled_tools = ["tool1", "tool2"]
disabled_tools = ["dangerous_tool"]
experimental_environment = "local"   # or "remote"
supports_parallel_tool_calls = true  # opt-in; default serialized

[mcp_servers.my-server.env]
LOG_LEVEL = "debug"

[mcp_servers.my-server.env_vars]
"INHERIT_THIS" = { source = "local" }
"REMOTE_VAR"  = { source = "remote" }

[mcp_servers.my-server.oauth]
scopes = ["read", "write"]
oauth_resource = "https://resource.example.com"
```

**Streamable HTTP server example:**

```toml
[mcp_servers.http-server]
url = "https://api.example.com/mcp"
startup_timeout_sec = 15
tool_timeout_sec = 90
http_headers = { "Authorization" = "Bearer token" }
env_http_headers = { "X-Custom-Header" = "ENV_VAR_NAME" }
bearer_token_env_var = "HTTP_SERVER_TOKEN"
```

**OAuth callback configuration (top-level keys):**

```toml
mcp_oauth_callback_port = 3000
mcp_oauth_callback_url  = "https://devbox.example.com/callback"
mcp_oauth_credentials_store = "keyring"   # or "file", "auto"
```

**Per-tool approval defaults** ([config.md](https://raw.githubusercontent.com/openai/codex/main/docs/config.md)):

```toml
[mcp_servers.docs]
command = "docs-server"
default_tools_approval_mode = "approve"

[mcp_servers.docs.tools.search]
approval_mode = "prompt"
```

**CLI shortcut:** `codex mcp add <name> --env VAR=VALUE -- <command>` ([developers.openai.com/codex/mcp](https://developers.openai.com/codex/mcp)).

**`/mcp` slash command** lists available MCP tools at runtime ([slash-commands](https://developers.openai.com/codex/cli/slash-commands)).

Parallel-tool-call safety note: enable `supports_parallel_tool_calls` only for servers whose tools tolerate concurrent execution; review read/write race conditions before flipping the flag ([config.md](https://raw.githubusercontent.com/openai/codex/main/docs/config.md)).

---

## 6. Hooks (codex_hooks)

Source: [developers.openai.com/codex/hooks](https://developers.openai.com/codex/hooks), [config-advanced](https://developers.openai.com/codex/config-advanced), [config-reference](https://developers.openai.com/codex/config-reference).

**Status (May 2026):** Originally introduced in Codex `v0.114.0` with `SessionStart` and `Stop`; now expanded to a full lifecycle hook set. Codex hooks are described as "stable/default-enabled" in 2026 per public discussion threads, but the docs still gate them behind a feature flag and label them experimental in [config-advanced](https://developers.openai.com/codex/config-advanced) ([Issue #14754](https://github.com/openai/codex/issues/14754), [Issue #14882](https://github.com/openai/codex/issues/14882), [Issue #19385](https://github.com/openai/codex/issues/19385)).

**Enable:**

```toml
[features]
codex_hooks = true
```

**Discovery locations** (loaded additively across all layers):

- `~/.codex/hooks.json`
- `~/.codex/config.toml` (inline `[[hooks.<Event>]]` arrays)
- `<repo>/.codex/hooks.json`
- `<repo>/.codex/config.toml`

Higher-precedence layers do **not** replace lower-precedence hooks; they accumulate. Project-local hooks require a trusted `.codex/` layer ([developers.openai.com/codex/hooks](https://developers.openai.com/codex/hooks)).

**Hook events:**

| Event | Scope | Matcher fields |
|---|---|---|
| `SessionStart` | session | `source` (`startup`, `resume`, `clear`) |
| `PreToolUse` | turn | `tool_name`/`tool_names` (regex; `Edit`/`Write` aliases for file edits, MCP tool patterns like `mcp__filesystem__.*`) |
| `PostToolUse` | turn | `tool_name`/`tool_names`, optional `exit_code` predicates (e.g., `{ gte = 1 }`) |
| `PermissionRequest` | turn | `request_type` (e.g., `network`), `tool_name` |
| `UserPromptSubmit` | turn | no matcher filtering |
| `Stop` | session | no matcher filtering; `reason` available in payload |

Sources: [developers.openai.com/codex/hooks](https://developers.openai.com/codex/hooks), [config-reference](https://developers.openai.com/codex/config-reference).

**TOML shape:**

```toml
[[hooks.PreToolUse]]
matcher = "^Bash$"            # regex; "*", "", or omitted matches all

[[hooks.PreToolUse.hooks]]
type = "command"              # only "command" is documented
command = '/usr/bin/python3 .codex/hooks/policy.py'
timeout = 30                  # seconds; default 600
statusMessage = "Validating shell command"
```

**JSON shape (`hooks.json`):**

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "^Bash$",
        "hooks": [
          { "type": "command", "command": "script.py", "timeout": 30 }
        ]
      }
    ]
  }
}
```

**Stdin payload to every hook command:**

- `session_id`: current session id
- `transcript_path`: path to session transcript (nullable)
- `cwd`: working directory
- `hook_event_name`: event type
- `model`: active model slug
- `turn_id`: present on turn-scoped hooks (PreToolUse, PostToolUse, PermissionRequest, UserPromptSubmit)

Plus event-specific fields (e.g., tool name and arguments for `PreToolUse`/`PostToolUse`).

**Hook output contract:**

- Exit code `0` with no output: success.
- Exit code `2` with stderr: blocking; stderr text becomes the block reason.
- Plain stdout: appended as developer context for `SessionStart` and `UserPromptSubmit`.
- JSON stdout: structured response.
- JSON output is **mandatory** for `Stop`.

Common JSON output fields: `continue` (bool), `stopReason` (string), `systemMessage` (string), `suppressOutput` (bool), event-specific `permissionDecision`, `additionalContext`, `decision`.

Compatibility caveats: `PreToolUse` and `PermissionRequest` support `systemMessage` but **not** `continue`, `stopReason`, or `suppressOutput`. `PostToolUse` supports `systemMessage`, `continue: false`, and `stopReason`. `PreToolUse` does **not** currently support `additionalContext`, which is a known parity gap with Claude-style hooks ([Issue #19385](https://github.com/openai/codex/issues/19385)).

Multiple matching hooks for one event run concurrently ([developers.openai.com/codex/hooks](https://developers.openai.com/codex/hooks)).

**Admin-managed hooks** (`requirements.toml`):

```toml
[hooks]
managed_dir = "/etc/codex/hooks"
windows_managed_dir = "C:\\ProgramData\\Codex\\hooks"

[[hooks.PreToolUse]]
pattern = { tool_names = ["shell"] }

[[hooks.PreToolUse.hooks]]
type = "command"
command = "/etc/codex/hooks/validate-shell"
```

Source: [config-reference](https://developers.openai.com/codex/config-reference).

---

## 7. Plugins

Source: [developers.openai.com/codex/plugins](https://developers.openai.com/codex/plugins).

Plugins **bundle skills, app/connector integrations, and MCP servers** as one installable unit. Examples cited: Gmail, Google Drive, Slack.

**Marketplace and install:**

- Codex App: Plugins section to browse and install curated plugins.
- CLI: `codex /plugins` (the `/plugins` slash command) lists installed and discoverable plugins, with marketplace tabs.

**Invocation:**

- Implicit: describe the task ("Summarize unread Gmail threads from today").
- Explicit: `@<plugin-name>` to invoke a specific plugin or one of its bundled skills.

**Disable / uninstall:**

- Uninstall via the plugin browser ("Uninstall plugin"); the bundled apps remain installed in ChatGPT.
- Disable without uninstalling by setting `enabled = false` in `~/.codex/config.toml` and restarting Codex.

**Suggestion suppression:**

```toml
[tool_suggest]
disabled_tools = [
  { type = "plugin",    id = "slack@openai-curated" },
  { type = "connector", id = "connector_google_calendar" },
]
```

Source: [config.md](https://raw.githubusercontent.com/openai/codex/main/docs/config.md).

The custom-plugin authoring path ("local scaffolding, marketplace setup, manifests, and packaging") is referenced from the Plugins page but the manifest schema itself is **not documented in the pages reviewed**.

---

## 8. Skills

Source: [developers.openai.com/codex/skills](https://developers.openai.com/codex/skills).

**File layout:**

```
my-skill/
├── SKILL.md           (required)
├── scripts/           (optional)
├── references/        (optional)
├── assets/            (optional)
└── agents/openai.yaml (optional)
```

**`SKILL.md` frontmatter:**

```yaml
---
name: skill-name
description: Explain exactly when this skill should and should not trigger.
---

Skill instructions for Codex to follow.
```

`name` and `description` are required. Codex relies on `description` for implicit matching, so triggers should be front-loaded.

**Discovery locations (hierarchical):**

| Scope | Path | Use case |
|---|---|---|
| REPO | `.agents/skills` (current dir) | Folder-specific |
| REPO | `../.agents/skills` | Nested repo shared area |
| REPO | `$REPO_ROOT/.agents/skills` | Org-wide repo skills |
| USER | `$HOME/.agents/skills` | Personal cross-repo |
| ADMIN | `/etc/codex/skills` | System-wide defaults |
| SYSTEM | bundled | Built-ins (e.g., skill-creator) |

Symlinks are followed.

**Progressive disclosure:** Codex initially loads only each skill's `name`, `description`, and file path; the full `SKILL.md` body loads only when the skill is selected. The initial summary list is capped at "roughly 2% of the model's context window, or 8,000 characters when the context window is unknown" ([developers.openai.com/codex/skills](https://developers.openai.com/codex/skills)).

**Invocation:**

- Explicit: `/skills` menu, or `$skill-name` in the composer.
- Implicit: model selects when the task matches `description`. Disable via `agents/openai.yaml` with `allow_implicit_invocation: false`.

**Conflicts:** Same-named skills are not merged; both appear in selectors.

**Config-level toggles:**

```toml
[[skills.config]]
path = "/home/user/skills/python-expert"
enabled = true
```

Source: [config-reference](https://developers.openai.com/codex/config-reference).

`find-skills` is referenced as a discovery convention, but no Codex CLI subcommand for it is documented in the pages reviewed.

---

## 9. Subagents (Agents)

Source: [developers.openai.com/codex/subagents](https://developers.openai.com/codex/subagents), [config-reference](https://developers.openai.com/codex/config-reference).

**Built-in agents (defaults):**

- `default`: general-purpose fallback.
- `worker`: execution-focused for implementation and fixes.
- `explorer`: read-heavy code exploration.

**Global config block:**

```toml
[agents]
max_threads = 6                  # default 6
max_depth = 1                    # default 1
job_max_runtime_seconds = 1800   # default 1800
```

`max_depth = 1` allows direct child agents but prevents deeper nesting; raising it increases token, latency, and resource use ([developers.openai.com/codex/subagents](https://developers.openai.com/codex/subagents)).

**Custom agent files:**

Located at `~/.codex/agents/<name>.toml` (personal) or `<repo>/.codex/agents/<name>.toml` (project). Each file defines one agent. Custom agent names matching built-ins take precedence.

**Required fields:** `name`, `description`, `developer_instructions`.

**Optional fields (inherit from parent session if omitted):** `nickname_candidates`, `model`, `model_reasoning_effort`, `sandbox_mode`, `mcp_servers`, `skills.config`.

**Example custom agent:**

```toml
name = "reviewer"
description = "PR reviewer focused on correctness, security, and missing tests."
model = "gpt-5.4"
model_reasoning_effort = "high"
sandbox_mode = "read-only"
developer_instructions = """
Review code like an owner.
Prioritize correctness, security, behavior regressions, and missing test coverage.
Lead with concrete findings, include reproduction steps when possible, and avoid style-only comments unless they hide a real bug.
"""
```

**Multi-agent feature flag:**

```toml
[features]
multi_agent = true
```

Source: [config-reference](https://developers.openai.com/codex/config-reference).

**Slash command:** `/agent` switches between active agent threads. `/fork` and `/side` create parallel/ephemeral conversation threads ([slash-commands](https://developers.openai.com/codex/cli/slash-commands)).

**CSV batch worker contract:** each worker in CSV batch jobs must call `report_agent_job_result` exactly once.

---

## 10. Model, Providers, Profiles

Source: [config-reference](https://developers.openai.com/codex/config-reference), [config-advanced](https://developers.openai.com/codex/config-advanced).

**Core model keys:** `model`, `model_provider`, `model_context_window`, `model_auto_compact_token_limit`, `model_instructions_file`, `model_reasoning_effort` (`minimal`/`low`/`medium`/`high`/`xhigh`), `model_reasoning_summary` (`auto`/`concise`/`detailed`/`none`), `model_verbosity`, `model_supports_reasoning_summaries`.

**Built-in providers** (reserved IDs): `openai`, `ollama`, `lmstudio`. Custom providers use `[model_providers.<id>]` with `name`, `base_url`, `env_key`, `env_key_instructions`, `wire_api = "responses"`, `supports_websockets`, `request_max_retries`, `stream_idle_timeout_ms`, `stream_max_retries`, `http_headers`, `env_http_headers`, `query_params`. Optional `[model_providers.<id>.auth]` defines a command-backed token (`command`, `args`, `cwd`, `timeout_ms`, `refresh_interval_ms`).

**Amazon Bedrock:**

```toml
[model_providers.amazon-bedrock.aws]
profile = "default"
region = "us-east-1"
```

**Profiles:**

```toml
[profiles.coding]
model = "gpt-5.1-codex-max"
service_tier = "fast"
sandbox_mode = "workspace-write"

profile = "coding"   # default profile selection
```

Activate ad hoc with `--profile <name>`.

---

## 11. Web Search, Memories, History

**Web search:**

```toml
web_search = "cached"          # or "live", "disabled"

[tools.web_search]
context_size = "medium"
allowed_domains = ["github.com", "stackoverflow.com"]

[tools.web_search.location]
country = "US"
region = "California"
city = "San Francisco"
timezone = "America/Los_Angeles"
```

**Memories** (`[features] memories = true`):

```toml
[memories]
generate_memories = true
use_memories = true
disable_on_external_context = false
consolidation_model = "gpt-5.5"
extract_model = "gpt-5.5"
min_rollout_idle_hours = 6
max_rollout_age_days = 30
max_unused_days = 30
max_rollouts_per_startup = 16
max_raw_memories_for_consolidation = 256
min_rate_limit_remaining_percent = 25
```

**History:**

```toml
[history]
persistence = "save-all"   # or "none"
max_bytes = 10485760

sqlite_home = "~/.codex/state"
tool_output_token_limit = 4096
```

Source: [config-reference](https://developers.openai.com/codex/config-reference).

---

## 12. Slash Commands (Built-in)

Source: [developers.openai.com/codex/cli/slash-commands](https://developers.openai.com/codex/cli/slash-commands).

Selected commands relevant to this reference:

- `/model`, `/fast`, `/personality`
- `/new`, `/resume`, `/fork`, `/side`
- `/plan`, `/review`, `/diff`
- `/permissions`, `/sandbox-add-read-dir` (Windows only)
- `/mention`, `/copy`
- `/status`, `/debug-config`, `/statusline`, `/title`, `/keymap`
- `/mcp`, `/apps`, `/plugins`, `/agent`
- `/clear`, `/compact`, `/experimental`, `/ps`, `/stop`
- `/init` (scaffold AGENTS.md), `/feedback`, `/logout`, `/quit`, `/exit`
- `/skills` (skill selector)

Custom slash commands ("custom team-specific shortcuts") are referenced ([developers.openai.com/codex/cli/features](https://developers.openai.com/codex/cli/features)) but the file format and location are **not documented** in the pages reviewed.

---

## 13. Non-Interactive Mode (`codex exec`)

Source: [developers.openai.com/codex/noninteractive](https://developers.openai.com/codex/noninteractive).

Key flags:

- `--json`: streaming JSON Lines (`thread.started`, `turn.started`, `item.*`, `turn.completed`, etc.)
- `-o, --output-last-message <path>`: write final message to file
- `--output-schema <path>`: structured output conforming to JSON Schema
- `--sandbox <level>`: `workspace-write`, `danger-full-access`
- `--ignore-user-config`: skip `$CODEX_HOME/config.toml`
- `--ignore-rules`: bypass user/project execution policy rules
- `--ephemeral`: do not persist session rollout to disk
- `--skip-git-repo-check`: bypass Git repo requirement
- `resume [SESSION_ID]` and `--last`: continue previous run

Auth via `CODEX_API_KEY` (recommended for CI). Stdin can supply prompt via `codex exec -`. Final message goes to stdout; progress to stderr.

A `--dangerously-bypass-approvals-and-sandbox` flag is referenced in community discussion but is **not documented** in the [noninteractive](https://developers.openai.com/codex/noninteractive) page reviewed; treat as undocumented in the May 2026 references.

---

## 14. What Is New in 2026

Compared to earlier Codex CLI generations:

1. **Codex hooks (`codex_hooks`)** expanded from `SessionStart`/`Stop` (added in `v0.114.0`) to a full lifecycle: `PreToolUse`, `PostToolUse`, `PermissionRequest`, `UserPromptSubmit`, plus the originals. Now described as default-enabled in 2026 community discussion; still gated behind `[features] codex_hooks = true` in current docs ([developers.openai.com/codex/hooks](https://developers.openai.com/codex/hooks), [Issue #14754](https://github.com/openai/codex/issues/14754), [PR #18385](https://github.com/openai/codex/pull/18385)).

2. **Plugins system** with marketplace, `/plugins` slash command, and bundled skills+apps+MCP installs ([developers.openai.com/codex/plugins](https://developers.openai.com/codex/plugins)).

3. **Skills with progressive disclosure** at `~/.agents/skills` and `$REPO_ROOT/.agents/skills`, bounded at ~2% of context window for the initial summary list ([developers.openai.com/codex/skills](https://developers.openai.com/codex/skills)).

4. **Subagents/multi-agent** with built-in `default`/`worker`/`explorer` plus user-defined TOML agents under `~/.codex/agents/` and `<repo>/.codex/agents/`, governed by `[agents] max_threads`/`max_depth`/`job_max_runtime_seconds` and `[features] multi_agent = true` ([developers.openai.com/codex/subagents](https://developers.openai.com/codex/subagents)).

5. **AGENTS.md hierarchy:** root-to-cwd concatenation with `AGENTS.override.md` precedence, `project_doc_max_bytes = 32 KiB` cap, and `child_agents_md` feature flag for explicit hierarchy guidance ([developers.openai.com/codex/guides/agents-md](https://developers.openai.com/codex/guides/agents-md), [agents_md.md](https://raw.githubusercontent.com/openai/codex/main/docs/agents_md.md)).

6. **Permission profiles** (`:read-only`, `:workspace`, `:danger-no-sandbox`, plus custom) with per-path filesystem rules, per-domain network rules, SOCKS/proxy/Unix-socket controls, layered on top of `sandbox_mode` ([developers.openai.com/codex/config-reference](https://developers.openai.com/codex/config-reference)).

7. **Granular approvals** (`approval_policy.granular`) splitting sandbox approval, rules, MCP elicitations, request permissions, and skill approval ([developers.openai.com/codex/config-reference](https://developers.openai.com/codex/config-reference)).

8. **MCP improvements:** `supports_parallel_tool_calls`, `default_tools_approval_mode` and per-tool `approval_mode`, OAuth callback config, `experimental_environment = "remote"`, and CLI `codex mcp add` ([config.md](https://raw.githubusercontent.com/openai/codex/main/docs/config.md), [developers.openai.com/codex/mcp](https://developers.openai.com/codex/mcp)).

9. **Notify deprecation:** the legacy `notify` command "is deprecated and will be removed in a future release. Existing configurations still work for compatibility, but new automation should use lifecycle hooks instead." ([config.md](https://raw.githubusercontent.com/openai/codex/main/docs/config.md))

10. **Admin guardrails (`requirements.toml`):** allowed sandbox/approval modes, allowed MCP server identities, managed hooks dirs, prefix-rule denylists, remote-sandbox host patterns ([developers.openai.com/codex/config-reference](https://developers.openai.com/codex/config-reference)).

11. **Custom CA bundle** via `CODEX_CA_CERTIFICATE` (PEM), falling back to `SSL_CERT_FILE`, then system roots; tolerates OpenSSL `TRUSTED CERTIFICATE` and `X509 CRL` blocks ([config.md](https://raw.githubusercontent.com/openai/codex/main/docs/config.md)).

12. **OpenTelemetry** export via `[otel]` (`exporter`, `metrics_exporter`, `trace_exporter`, OTLP HTTP/gRPC, headers, TLS) ([config-reference](https://developers.openai.com/codex/config-reference)).

13. **AGENTS.md cross-tool standard** is now stewarded by the **Agentic AI Foundation under the Linux Foundation** with 20+ tools implementing it ([agents.md](https://agents.md)).

14. **Plan mode reasoning override:** `plan_mode_reasoning_effort` (default `medium`; explicit `none` means "no reasoning", not "inherit") ([config.md](https://raw.githubusercontent.com/openai/codex/main/docs/config.md)).

15. **Realtime start instructions:** `experimental_realtime_start_instructions` overrides the developer message Codex inserts when realtime activates ([config.md](https://raw.githubusercontent.com/openai/codex/main/docs/config.md)).

---

## 15. Items Marked "Not Documented"

These were searched for but not present in the May 2026 docs reviewed:

- `docs/hooks.md`, `docs/mcp.md`, `docs/plugins.md`, `docs/subagents.md`, `docs/agents.md`, `docs/advanced.md`: do not exist in the GitHub `docs/` tree.
- macOS Seatbelt and Linux Landlock specifics: alluded to via `sandbox_mode` but not described in the published references.
- Custom slash command file format and storage path.
- Plugin manifest schema (the format for authoring marketplace-publishable plugins).
- `find-skills` as a Codex CLI subcommand; the term appears as a convention in user instructions but no Codex CLI command is documented.
- AGENTS.md frontmatter: not specified as required or supported.
- `--dangerously-bypass-approvals-and-sandbox` as a documented `codex exec` flag in the [noninteractive](https://developers.openai.com/codex/noninteractive) reference.

---

## Source Index

GitHub repo and stub docs:

- [github.com/openai/codex](https://github.com/openai/codex)
- [github.com/openai/codex/tree/main/docs](https://github.com/openai/codex/tree/main/docs)
- [docs/config.md (raw)](https://raw.githubusercontent.com/openai/codex/main/docs/config.md)
- [docs/agents_md.md (raw)](https://raw.githubusercontent.com/openai/codex/main/docs/agents_md.md)
- [docs/sandbox.md (raw)](https://raw.githubusercontent.com/openai/codex/main/docs/sandbox.md)
- [docs/skills.md (raw)](https://raw.githubusercontent.com/openai/codex/main/docs/skills.md)
- [docs/slash_commands.md (raw)](https://raw.githubusercontent.com/openai/codex/main/docs/slash_commands.md)
- [docs/exec.md (raw)](https://raw.githubusercontent.com/openai/codex/main/docs/exec.md)
- [docs/install.md](https://github.com/openai/codex/blob/main/docs/install.md)

OpenAI Developers portal:

- [Codex CLI overview](https://developers.openai.com/codex/cli)
- [CLI features](https://developers.openai.com/codex/cli/features)
- [Slash commands](https://developers.openai.com/codex/cli/slash-commands)
- [Configuration basics](https://developers.openai.com/codex/config-basic)
- [Advanced configuration](https://developers.openai.com/codex/config-advanced)
- [Configuration reference](https://developers.openai.com/codex/config-reference)
- [Hooks](https://developers.openai.com/codex/hooks)
- [MCP](https://developers.openai.com/codex/mcp)
- [Plugins](https://developers.openai.com/codex/plugins)
- [Skills](https://developers.openai.com/codex/skills)
- [Subagents](https://developers.openai.com/codex/subagents)
- [AGENTS.md guide](https://developers.openai.com/codex/guides/agents-md)
- [Non-interactive mode](https://developers.openai.com/codex/noninteractive)
- [Best practices](https://developers.openai.com/codex/learn/best-practices)
- [Codex Security product (sandbox.md target)](https://developers.openai.com/codex/security)

External standard:

- [agents.md](https://agents.md)

GitHub issues / PRs (for hooks evolution):

- [Issue #14754: Add PreToolUse and PostToolUse hook events](https://github.com/openai/codex/issues/14754)
- [Issue #14882: Proposal: lifecycle hooks](https://github.com/openai/codex/issues/14882)
- [Issue #19385: PreToolUse additionalContext parity gap](https://github.com/openai/codex/issues/19385)
- [PR #18385: Support MCP tools in hooks](https://github.com/openai/codex/pull/18385)
- [Discussion #2150: Hook would be a great feature](https://github.com/openai/codex/discussions/2150)
