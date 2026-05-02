# OpenCode Documentation Reference (May 2026)

Snapshot of `opencode.ai/docs/*` and the `sst/opencode` repository as fetched on 2026-05-02. Every claim cites a source URL. Items not stated by the docs are flagged "not documented".

---

## 1. Project overview and identity

OpenCode is an open-source, MIT-licensed AI coding agent with TUI, desktop, web, and IDE entry points; it is provider-agnostic and supports 75+ LLM providers via the Vercel AI SDK and Models.dev. Sources: <https://opencode.ai/docs/>, <https://github.com/sst/opencode>, <https://opencode.ai/docs/providers/>.

Install paths documented: shell installer (`curl -fsSL https://opencode.ai/install | bash`), npm/bun/pnpm/yarn, Homebrew, Scoop/Chocolatey, Pacman, plus desktop apps for macOS/Windows/Linux. Source: <https://github.com/sst/opencode>.

---

## 2. Configuration shape (`opencode.json` / `opencode.jsonc`)

Schema URL: `https://opencode.ai/config.json`. Both JSON and JSONC are supported. Source: <https://opencode.ai/docs/config/>.

Precedence (lowest to highest), per the config docs:

1. Remote config at `.well-known/opencode`
2. Global `~/.config/opencode/opencode.json`
3. `OPENCODE_CONFIG` env var pointing to a custom file
4. Project `opencode.json` in project root
5. `.opencode` directories
6. Inline `OPENCODE_CONFIG_CONTENT` env var
7. Managed config files (system directories)
8. macOS managed preferences (MDM)

Configuration files are merged; later layers override conflicting keys only. Source: <https://opencode.ai/docs/config/>.

Top-level keys (from the config page):

| Key | Purpose |
| --- | --- |
| `$schema` | Schema URL for IntelliSense |
| `model` | Primary model, e.g. `"anthropic/claude-sonnet-4-5"` |
| `small_model` | Lightweight model used for ancillary tasks |
| `provider` | Per-provider options (timeouts, baseURL, models) |
| `default_agent` | Default primary agent (`build` or `plan`) |
| `agent` | Custom agent definitions (JSON form) |
| `server` | `port`, `hostname`, `mdns` for the headless server |
| `shell` | Interactive shell command, e.g. `"pwsh"` |
| `tools` | Enable/disable individual built-in tools |
| `command` | Custom slash commands |
| `share` | `"manual" \| "auto" \| "disabled"` |
| `permission` | Tool approval policies |
| `formatter` | Formatter overrides |
| `snapshot` | Boolean, change-tracking on/off |
| `autoupdate` | `true \| false \| "notify"` |
| `compaction` | `{ auto, prune }` for context management |
| `watcher` | File-watcher ignore patterns |
| `mcp` | MCP server registry |
| `plugin` | Plugin references (npm packages) |
| `instructions` | Extra instruction files (globs / paths) |
| `disabled_providers` / `enabled_providers` | Allow/deny provider IDs |
| `experimental` | In-development features |

Source: <https://opencode.ai/docs/config/>.

Variable substitution in any string value: `"{env:VAR_NAME}"` and `"{file:path}"` (`~` and absolute paths supported). Source: <https://opencode.ai/docs/config/>.

---

## 3. AGENTS.md / CLAUDE.md / rules handling

Lookup hierarchy used by OpenCode (first match wins per category):

1. Project-level (walking up from cwd): `AGENTS.md`, then `CLAUDE.md` as fallback.
2. Global: `~/.config/opencode/AGENTS.md`, then `~/.claude/CLAUDE.md` as fallback.
3. Anything listed in `instructions` in `opencode.json`.

Local `AGENTS.md` overrides `CLAUDE.md`; `~/.config/opencode/AGENTS.md` overrides `~/.claude/CLAUDE.md`; project-level supersedes global. Source: <https://opencode.ai/docs/rules/>.

Claude Code compatibility: project `CLAUDE.md`, global `~/.claude/CLAUDE.md`, and skills under `~/.claude/skills/` are recognized; can be disabled via `OPENCODE_DISABLE_CLAUDE_CODE`, `OPENCODE_DISABLE_CLAUDE_CODE_PROMPT`, `OPENCODE_DISABLE_CLAUDE_CODE_SKILLS`. Source: <https://opencode.ai/docs/rules/>.

Concatenation: all instruction files, plus glob entries from `instructions`, plus remote URLs (5-second timeout) are combined into the LLM context. Source: <https://opencode.ai/docs/rules/>.

April 2026 change: global instructions now apply before project and skill instructions for more predictable precedence (changelog entry for v1.14.30). Source: <https://opencode.ai/changelog>.

---

## 4. Permissions

Three resolution states: `allow`, `ask`, `deny`. Source: <https://opencode.ai/docs/permissions/>.

Permission keys documented: `read`, `edit` (covers edit/write/patch), `glob`, `grep`, `list`, `bash`, `task`, `skill`, `lsp`, `question`, `webfetch`, `websearch`, `external_directory`, `doom_loop`, `todowrite`. Source: <https://opencode.ai/docs/permissions/> and <https://opencode.ai/docs/agents/>.

Defaults: most keys default to `allow`; `doom_loop` and `external_directory` default to `ask`. Files matching `.env*` are blocked by default, with `.env.example` excepted. Source: <https://opencode.ai/docs/permissions/>.

Granular forms:

```json
{
  "permission": {
    "*": "ask",
    "bash": "allow",
    "edit": "deny"
  }
}
```

```json
{
  "permission": {
    "bash": {
      "*": "ask",
      "git *": "allow",
      "rm *": "deny"
    }
  }
}
```

Patterns use `*`, `?`, literal characters, and `~`/`$HOME` expansion. Source: <https://opencode.ai/docs/permissions/>.

Per-agent overrides take precedence over global rules, e.g. blocking `git push *` only inside `build`. Source: <https://opencode.ai/docs/permissions/>.

Approval workflow when `ask`: user picks `once`, `always`, or `reject`. Source: <https://opencode.ai/docs/permissions/>.

April 2026 changes: LSP permission prompts now include operation, file, and cursor position; `opencode agent create` now writes valid `permissions.deny`; task child sessions inherit parent `external_dir` and deny rules. Source: <https://opencode.ai/changelog>.

---

## 5. MCP servers

Two server types: `local` and `remote`. Source: <https://opencode.ai/docs/mcp-servers/>.

Local schema:

```json
{
  "mcp": {
    "server-name": {
      "type": "local",
      "command": ["npx", "-y", "my-mcp-command"],
      "enabled": true,
      "environment": { "MY_ENV_VAR": "value" },
      "timeout": 5000
    }
  }
}
```

Remote schema:

```json
{
  "mcp": {
    "server-name": {
      "type": "remote",
      "url": "https://mcp-server.com",
      "enabled": true,
      "headers": { "Authorization": "Bearer API_KEY" },
      "timeout": 5000
    }
  }
}
```

Default timeout 5000 ms. Source: <https://opencode.ai/docs/mcp-servers/>.

OAuth: Dynamic Client Registration is automatic; pre-registered creds can be supplied via `oauth.clientId`, `oauth.clientSecret`, `oauth.scope`. Setting `"oauth": false` opts out for API-key servers. Source: <https://opencode.ai/docs/mcp-servers/>.

CLI helpers: `opencode mcp add`, `opencode mcp list/ls`, `opencode mcp auth`, `opencode mcp logout`, `opencode mcp debug`. Source: <https://opencode.ai/docs/cli/>.

April 2026 changes: remote MCP URLs that fail now return clear errors; MCP OAuth errors now match the native API more closely; experimental HTTP API endpoint for MCP server status added. Source: <https://opencode.ai/changelog>.

---

## 6. Plugins

Load order: global `~/.config/opencode/opencode.json`, then project `opencode.json`, then global plugin dir `~/.config/opencode/plugins/`, then project `.opencode/plugins/`. Files in plugin directories are auto-loaded at startup. Source: <https://opencode.ai/docs/plugins/>.

Distribution: local JS/TS files OR npm packages declared in the `plugin` array. Bun installs npm plugins at startup; cache lives at `~/.cache/opencode/node_modules/`. A `.opencode/package.json` may declare local plugin dependencies. Source: <https://opencode.ai/docs/plugins/>.

Module shape:

```js
export const MyPlugin = async ({ project, client, $, directory, worktree }) => {
  return { /* hooks */ }
}
```

Source: <https://opencode.ai/docs/plugins/>.

Hook events documented:

- Command: `command.executed`
- Files: `file.edited`, `file.watcher.updated`
- Installation: `installation.updated`
- LSP: `lsp.client.diagnostics`, `lsp.updated`
- Messages: `message.part.removed`, `message.part.updated`, `message.removed`, `message.updated`
- Permissions: `permission.asked`, `permission.replied`
- Server: `server.connected`
- Sessions: `session.created`, `session.compacted`, `session.deleted`, `session.diff`, `session.error`, `session.idle`, `session.status`, `session.updated`
- Todos: `todo.updated`
- Shell: `shell.env`
- Tools: `tool.execute.before`, `tool.execute.after`
- TUI: `tui.prompt.append`, `tui.command.execute`, `tui.toast.show`

Source: <https://opencode.ai/docs/plugins/>.

There is no separate `/docs/hooks/` page (404 on fetch); hooks are exclusively the plugin events above. Source: <https://opencode.ai/docs/hooks/> (returns 404).

---

## 7. Skills

Storage paths walked from cwd up to git worktree root, plus globals:

- Project: `.opencode/skills/<name>/SKILL.md`, `.claude/skills/<name>/SKILL.md`, `.agents/skills/<name>/SKILL.md`
- Global: `~/.config/opencode/skills/<name>/SKILL.md` and the equivalent Claude/agent dirs

Source: <https://opencode.ai/docs/skills/>.

`SKILL.md` frontmatter:

- Required: `name`, `description`
- Optional: `license`, `compatibility`, `metadata` (string-to-string map)
- Unknown fields are ignored

Source: <https://opencode.ai/docs/skills/>.

Name validation: 1-64 chars matching `^[a-z0-9]+(-[a-z0-9]+)*$`. Source: <https://opencode.ai/docs/skills/>.

Discovery: automatic walk-up plus globals; no explicit registration. Skills are exposed via the built-in `skill` tool, which lists name/description pairs that the agent reads to decide whether to load full content. Source: <https://opencode.ai/docs/skills/>.

A dedicated `find-skills` tool is not documented in the OpenCode skills page; discovery is handled by the `skill` tool itself. Source: <https://opencode.ai/docs/skills/>.

Difference vs agents: skills are reusable instruction sets loaded on-demand; agents are autonomous entities with their own permissions/tools. Source: <https://opencode.ai/docs/skills/>.

---

## 8. Agents

Two categories: primary (cycled with Tab or `switch_agent`) and subagent (auto-invoked or user-invoked via `@name`). Source: <https://opencode.ai/docs/agents/>.

Built-in agents: `build` (primary, full tools), `plan` (primary, edits/bash default to `ask`), `general` (subagent, full access for multi-step work, no todo tool), `explore` (subagent, read-only). Three hidden system agents (Compaction, Title, Summary) handle background work. Source: <https://opencode.ai/docs/agents/>.

Custom agent definition - markdown form at `~/.config/opencode/agents/<name>.md` or `.opencode/agents/<name>.md`:

```yaml
---
description: Agent purpose here
mode: subagent
model: anthropic/claude-sonnet-4-20250514
temperature: 0.1
permission:
  edit: deny
  bash: deny
---
System prompt content describing the agent's behavior and instructions.
```

JSON form inside `opencode.json`:

```json
{
  "agent": {
    "code-reviewer": {
      "description": "Reviews code for best practices",
      "mode": "subagent",
      "prompt": "You are a code reviewer..."
    }
  }
}
```

Source: <https://opencode.ai/docs/agents/>.

Agent options: `description` (required for subagents), `mode` (`primary | subagent | all`), `model`, `temperature`, `top_p`, `steps`, `prompt` (path to file), `permission`, `disable`, `hidden`, `color`. Source: <https://opencode.ai/docs/agents/>.

Subagent capabilities: read, analyze, run multi-step tasks, optionally edit/run shell depending on permissions; `explore` cannot edit. Subagents are invoked by primary agents or via `@mention`. The `task` permission controls which subagents an agent can call. Source: <https://opencode.ai/docs/agents/>.

CLI helpers: `opencode agent create` (interactive wizard), `opencode agent list`. Source: <https://opencode.ai/docs/cli/>.

Subagent navigation keybinds: `session_child_first` (Leader+Down), `session_child_cycle` (Right), `session_child_cycle_reverse` (Left), `session_parent` (Up). Source: <https://opencode.ai/docs/keybinds/>.

---

## 9. Custom commands

Two surfaces: markdown files in `.opencode/commands/` (project) or `~/.config/opencode/commands/` (global), or the `command` map in `opencode.json`. Filename becomes the command name. Source: <https://opencode.ai/docs/commands/>.

Frontmatter / config keys: `template` (required prompt body), `description`, `agent`, `model`, `subtask`. Source: <https://opencode.ai/docs/commands/>.

Dynamic markup inside templates: `$ARGUMENTS`, positional `$1`/`$2`, shell expansion via `` !`cmd` ``, file inclusion via `@filename`. Custom commands can override built-ins like `/init`, `/undo`, `/redo`. Source: <https://opencode.ai/docs/commands/>.

---

## 10. Custom tools

Files in `.opencode/tools/` (project) or `~/.config/opencode/tools/` (global). Filename becomes the tool name; multiple named exports become `<filename>_<exportname>`. Source: <https://opencode.ai/docs/custom-tools/>.

Shape:

```ts
import { tool } from "@opencode-ai/plugin"
export default tool({
  description: "Query the project database",
  args: {
    query: tool.schema.string().describe("SQL query to execute"),
  },
  async execute(args, context) {
    return `Executed query: ${args.query}`
  },
})
```

Args use Zod via `tool.schema`. `context` exposes `agent`, `sessionID`, `messageID`, `directory`, `worktree`. Custom tools override built-ins of the same name. Underlying scripts can be any language (e.g. wrap Python via `Bun.$`). Source: <https://opencode.ai/docs/custom-tools/>.

---

## 11. Built-in tools

`bash`, `edit`, `write`, `read`, `grep`, `glob`, `lsp` (experimental), `apply_patch`, `skill`, `todowrite`, `webfetch`, `websearch`, `question`. Configured via `permission` in `opencode.json` (`allow | deny | ask`); wildcards accepted (e.g. `"mymcp_*": "ask"`). All tools enabled by default. Source: <https://opencode.ai/docs/tools/>.

---

## 12. Formatters

The `/docs/formatter/` page returned 404 on this fetch; formatter behavior is therefore documented only via the `formatter` key shown in the config reference (e.g. `{ "prettier": { "disabled": true } }`). The exact custom-formatter schema is not documented in the pages I could retrieve. Source: <https://opencode.ai/docs/config/>; failed fetch: <https://opencode.ai/docs/formatter/>.

---

## 13. LSP

Schema in `opencode.json`:

```json
{
  "lsp": {
    "server-name": {
      "disabled": false,
      "command": ["command", "args"],
      "extensions": [".ext"],
      "env": { "VAR": "value" },
      "initialization": { "options": {} }
    }
  }
}
```

Source: <https://opencode.ai/docs/lsp/>.

OpenCode ships 30+ pre-configured language servers (TypeScript, ESLint, Deno, Pyright, gopls, rust-analyzer, jdtls, intelephense, etc.), auto-enabled on file extension match. Disable everything with `"lsp": false` or per-server with `"disabled": true`. Custom servers require `command` and `extensions`. PHP Intelephense premium needs a license file at `$HOME/intelephense/license.txt`. Source: <https://opencode.ai/docs/lsp/>.

April 2026: Roslyn LSP added for Razor and C#; LSP tool now forwards workspace symbol queries; LSP prompts include operation/file/cursor metadata. Source: <https://opencode.ai/changelog>.

---

## 14. Models

Format: `provider_id/model_id` (e.g. `openai/gpt-5`, `opencode/<model-id>` for Zen). Source: <https://opencode.ai/docs/models/>.

Selection precedence: `--model` flag, then config, then last used, then internal priority order. Per-agent override via the agent's `model` field. `small_model` covers lightweight ancillary tasks. Source: <https://opencode.ai/docs/models/>.

Provider-specific options are nested under `provider.<id>.models.<id>.options`, e.g. OpenAI `reasoningEffort`, Anthropic `thinking`. Source: <https://opencode.ai/docs/models/>.

Variants let you reuse one model with different parameter sets without duplicating registration. Source: <https://opencode.ai/docs/models/>.

---

## 15. Providers

Auth is performed via `/connect` in the TUI or `opencode auth login`; credentials live at `~/.local/share/opencode/auth.json`. Providers configured in the `provider` block of `opencode.json`. Custom OpenAI-compatible providers use `npm: "@ai-sdk/openai-compatible"` with a `baseURL` and a `models` map. Source: <https://opencode.ai/docs/providers/>.

Auth methods: manual API keys, OAuth (GitHub Copilot, OpenAI, GitLab), env vars (AWS, bearer tokens), service keys (SAP AI Core), credential chains (Bedrock). Source: <https://opencode.ai/docs/providers/>.

OpenCode Zen and OpenCode Go are first-party subscription gateways; Zen uses the `opencode/<model-id>` namespace and pay-as-you-go billing with auto-reload thresholds. Source: <https://opencode.ai/docs/zen/>.

April 2026 deltas: Mistral Medium 3.5 added with reasoning support; Cloudflare AI Gateway and Azure defaults received fixes; Bedrock sessions handle reasoning content more reliably; Azure setup now prompts for resource name when needed. Source: <https://opencode.ai/changelog>.

---

## 16. Themes

Built-in themes include `system`, `tokyonight`, `everforest`, `ayu`, `catppuccin` (with `macchiato` variant), `gruvbox`, `kanagawa`, `nord`, `matrix`, `one-dark`. Default is `opencode`. Source: <https://opencode.ai/docs/themes/>.

Theme load order: built-ins (embedded), then `~/.config/opencode/themes/*.json`, then `.opencode/themes/*.json`, then `./.opencode/themes/*.json`. Later directories override earlier ones. Source: <https://opencode.ai/docs/themes/>.

Theme JSON shape: `$schema: https://opencode.ai/theme.json`, optional `defs` for color variables, `theme` map with hex/ANSI colors and dark/light variants; `"none"` keeps terminal defaults. Truecolor (24-bit) terminal support required. Source: <https://opencode.ai/docs/themes/>.

---

## 17. Share

Modes via `share` config key: `manual` (default, requires `/share`), `auto` (auto-share new sessions), `disabled`. Shared URLs follow `opncd.ai/s/<share-id>`; `/unshare` deletes server-side data. Enterprise can disable, gate to SSO, or self-host. Source: <https://opencode.ai/docs/share/>.

---

## 18. Keybinds and TUI configuration

TUI lives in a separate `tui.json` file (schema `https://opencode.ai/tui.json`) loaded from the standard config path or from `OPENCODE_TUI_CONFIG`. Source: <https://opencode.ai/docs/tui/>.

Top-level TUI keys: `theme`, `keybinds`, `scroll_speed`, `scroll_acceleration`, `diff_style` (`auto | stacked`), `mouse`. Source: <https://opencode.ai/docs/tui/>.

Default leader is `ctrl+x`; chord example: `<leader>n` for `session_new`. The full keybind table is published with defaults for ~80 actions including `agent_cycle` (Tab), `command_list` (Ctrl+P), `session_compact` (`<leader>c`), `messages_undo` (`<leader>u`), `model_list` (`<leader>m`), and the new `display_thinking` (default `none`). Source: <https://opencode.ai/docs/keybinds/>.

---

## 19. CLI surface

Headline commands (full table):

- `opencode` (TUI), `opencode run` (one-shot prompt), `opencode serve` (headless API), `opencode web` (headless server with browser UI), `opencode attach` (remote backend)
- `opencode agent create | list`
- `opencode auth login | list/ls | logout`
- `opencode github install | run`
- `opencode mcp add | list/ls | auth | logout | debug`
- `opencode session list`, `opencode export`, `opencode import`, `opencode stats`
- `opencode models`, `opencode acp`, `opencode upgrade`, `opencode uninstall`

TUI flags: `--continue/-c`, `--session/-s`, `--fork`, `--prompt`, `--model/-m`, `--agent`, `--port`, `--hostname`. Run flags add `--share`, `--file/-f`, `--format`, `--attach`, `--dangerously-skip-permissions`. Server flags add `--mdns`, `--cors` (repeatable). Global: `--help/-h`, `--version/-v`, `--print-logs`, `--log-level`. Source: <https://opencode.ai/docs/cli/>.

---

## 20. Server / HTTP API

`opencode serve` exposes an OpenAPI 3.1 spec at `http://<hostname>:<port>/doc`; default port 4096, hostname 127.0.0.1. HTTP basic auth via `OPENCODE_SERVER_PASSWORD` (default user `opencode`, override with `OPENCODE_SERVER_USERNAME`). `--cors` flag whitelists origins. mDNS available. Endpoint groups cover health/events, projects, sessions, messages/commands, files, configuration, provider auth, LSP/formatters/MCP, and agents. Source: <https://opencode.ai/docs/server/>.

April 2026: experimental `GET /config` endpoint added; new endpoints for listing files and checking project status; HTTP API workspace adapters now keep instance context across requests. Source: <https://opencode.ai/changelog>.

---

## 21. SDK

JS/TS SDK published as `@opencode-ai/sdk`. APIs cover sessions (create/get/update/delete, prompt with optional `json_schema` for structured output), file ops (search, find, read, status), project/config, app control (logs, agents, auth), TUI (append prompts, dialogs, toasts), and SSE event subscription. A Go SDK section is referenced in the docs nav but not detailed on this page. Source: <https://opencode.ai/docs/sdk/>.

---

## 22. What is new in 2026

From the official changelog (selected entries):

- v1.14.32 (May 2): shell-mode editing (backspace/cursor) restored; HTTP API workspace adapter context retention; agents granted permissionless access to global temp dir; Bedrock reasoning-content fixes. Source: <https://opencode.ai/changelog>.
- v1.14.31 (May 1): Azure resource-name prompts; task child sessions inherit `external_dir` and deny rules from parent; clearer remote-MCP URL failures. Source: <https://opencode.ai/changelog>.
- v1.14.30 (Apr 29): Predictable instruction precedence (global before project before skills); editor context reconnects on session switch across dirs; forked sessions preserve compacted history; Mistral Medium 3.5 with reasoning support. Source: <https://opencode.ai/changelog>.
- v1.14.29 (Apr 28): Sessions keep relative workspace paths; `opencode agent create` writes valid `permissions.deny`; MCP OAuth errors aligned with the native API; LSP workspace symbol forwarding. Source: <https://opencode.ai/changelog>.
- v1.14.25 (Apr 25): LSP permission prompts now display operation, file, and cursor; permission rule order preserved with full IntelliSense; Roslyn LSP for Razor and C#. Source: <https://opencode.ai/changelog>.
- v1.14.24 (Apr 24): Experimental HTTP API endpoint for MCP server status; new endpoints for file listing and project status. Source: <https://opencode.ai/changelog>.

Earlier-2026 highlights surfaced in third-party release trackers (not the official changelog page; treat as advisory): 2026.4 Windows ARM64 GA, Ollama streaming v2, VSCode command-palette refresh, `--session` flag for transcript pinning, broader test-runner detection (cargo, uv, bun, dotnet); 2026.3 JetBrains adapter preview, Sigstore key rotation, policy schema v3. Source: <https://releasebot.io/updates/sst/opencode>.

---

## 23. Items not documented (or doc page missing)

- `/docs/hooks/` returns 404; hook events are exclusively the plugin events listed in `/docs/plugins/`.
- `/docs/formatter/` returns 404; only the `formatter` key example in `/docs/config/` is published.
- A dedicated `find-skills` tool is not documented; discovery happens via the built-in `skill` tool.
- Go SDK details beyond the existence of a Go section in the nav are not documented in the SDK page.

---

## 24. Source index

- <https://opencode.ai/docs/>
- <https://opencode.ai/docs/config/>
- <https://opencode.ai/docs/agents/>
- <https://opencode.ai/docs/rules/>
- <https://opencode.ai/docs/permissions/>
- <https://opencode.ai/docs/mcp-servers/>
- <https://opencode.ai/docs/plugins/>
- <https://opencode.ai/docs/skills/>
- <https://opencode.ai/docs/keybinds/>
- <https://opencode.ai/docs/lsp/>
- <https://opencode.ai/docs/models/>
- <https://opencode.ai/docs/providers/>
- <https://opencode.ai/docs/themes/>
- <https://opencode.ai/docs/share/>
- <https://opencode.ai/docs/commands/>
- <https://opencode.ai/docs/tools/>
- <https://opencode.ai/docs/zen/>
- <https://opencode.ai/docs/cli/>
- <https://opencode.ai/docs/server/>
- <https://opencode.ai/docs/tui/>
- <https://opencode.ai/docs/troubleshooting/>
- <https://opencode.ai/docs/sdk/>
- <https://opencode.ai/docs/custom-tools/>
- <https://opencode.ai/changelog>
- <https://github.com/sst/opencode>
- <https://releasebot.io/updates/sst/opencode> (third-party tracker, advisory only)
