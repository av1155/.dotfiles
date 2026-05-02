# Cross-Tool Standardization Audit — Claude Code · Codex CLI · OpenCode

Date: 2026-05-02 (revised). Source of truth for "what should match": **Claude Code**, since you use it most. Each finding cites the official docs that produced it. Research notes are at `~/.dotfiles/docs/cross-tool-standardization/research/{claude-code,codex-cli,opencode,agents-md-standard}-*.md`. The dotfiles repo manages all three configs via GNU Stow; `~/.dotfiles/` is the canonical source of truth (per `~/.dotfiles/README.md`).

**Revision note (added after live verification with `codex exec`):** Codex *does* read `~/.codex/skills/` despite that path being absent from the public docs page. The bundled `skill-installer` SKILL.md documents `$CODEX_HOME/skills` (= `~/.codex/skills/`) as the canonical install path, and a non-interactive `codex exec` query confirmed all 11 user skills plus the `~/.agents/skills/` cross-tool symlinks plus plugin-bundled skills are loaded. The "skills are in the wrong place" finding from the original report was wrong; the actual gap is **content drift between the two manually-curated copies**.

---

## TL;DR scorecard

| Capability | Claude Code | Codex CLI | OpenCode | Cross-tool grade |
| --- | --- | --- | --- | --- |
| Project instruction file | CLAUDE.md (no AGENTS.md fallback) | AGENTS.md (root → cwd, 32 KiB cap) | AGENTS.md (CLAUDE.md fallback) | ⚠️ Partial — only Houndarr uses the canonical interop pattern |
| Path-conditional rules | `.claude/rules/*.md` with `paths:` frontmatter (auto-load) | None equivalent | None equivalent | ❌ CC-only |
| Skills location | `~/.claude/skills/`, `.claude/skills/`, plugin skills | `$CODEX_HOME/skills` (= `~/.codex/skills/`) ✓ verified, `~/.agents/skills/`, `$REPO_ROOT/.agents/skills/`, `/etc/codex/skills` | `.opencode/skills/`, `.claude/skills/`, `.agents/skills/`, plus globals | ✅ Each tool reads its own dir; `~/.agents/skills/` shared cross-tool |
| Skill content | 14 personal skills | 11 personal skills loaded (`~/.codex/skills/` stow target) — manually-curated copies of CC's | 0 local; reads `~/.claude/skills/` natively | ⚠️ Drift risk between CC and Codex copies (frontmatter and prose manually swapped) |
| Hooks events used | 7 events configured (Notification, PostToolUse, PreToolUse, Stop, UserPromptSubmit, SessionStart, SessionEnd) | 3 events configured (PostToolUse, Stop, UserPromptSubmit) | 4 events via TS plugin | ⚠️ Codex parity gap |
| MCP global | Plugin-bundled (context7, firecrawl, semgrep, supabase, vercel, plus claude-in-chrome) | TOML: context7, firecrawl + 3 disabled | JSON: context7 + 4 disabled | ⚠️ OpenCode/Codex thinner than CC |
| MCP project-level | `.mcp.json` | `.codex/config.toml [mcp_servers.X]` | `opencode.jsonc "mcp"` | ✅ All three configured per repo, contents aligned |
| Plugins ecosystem | Marketplace, 14 enabled across 5 sources | Marketplace `openai-curated`, 4 enabled | TS file plugins; no marketplace concept | ❌ Structurally different |
| Subagents (custom) | Built-ins only (no custom files) | Built-ins only (no `~/.codex/agents/*.toml`) | Built-ins only (no `~/.config/opencode/agents/*.md`) | ✅ Consistent (all empty) |
| Permissions baseline | Detailed allow/deny/ask | `default.rules` shell prefix allowlist + sandbox modes | `permission.{read,edit,bash,...}` allow/ask/deny | ⚠️ Same intent, divergent shape |
| Status-line / activity | `workmux` via `statusline.sh` and 5 hooks | `workmux` via 3 hooks | `workmux` via TS plugin | ✅ Functional parity |

Legend: ✅ aligned, ⚠️ aligned in spirit only, ❌ structural gap.

---

## 1. Inventory snapshot

### 1.1 Global configs

```
~/.claude/                                 ~/.codex/                           ~/.config/opencode/
├── CLAUDE.md (7.4 KB)                     ├── AGENTS.md (7.6 KB)              ├── AGENTS.md (8.1 KB)
├── settings.json (4.4 KB)                 ├── config.toml (1.8 KB)            ├── opencode.jsonc (5.5 KB)
├── statusline.sh                          ├── hooks.json (576 B)              ├── tui.json (keybinds)
├── rules/                                 ├── rules/default.rules             ├── plugins/workmux-status.ts
│   ├── git-protected/  (empty stub)       │   (shell prefix-rule allowlists)  └── (no skills/, no agents/)
│   ├── python/SKILL.md                    ├── skills/  (11 stowed dirs, loaded)
│   ├── scalability/SKILL.md               │   .system/  (5 auto-installed)
│   └── typescript/SKILL.md                │   catchup, coordinator, deep-audit,
├── skills/  (14 dirs)                     │   fix-issue, merge, open-pr,
│   catchup, commenting, coordinator,      │   rebase, review, ship, workmux,
│   deep-audit, fix-issue, merge,          │   worktree
│   open-pr, playwright-cli, rebase,       └── (no agents/)
│   review, security, ship, workmux,
│   worktree
└── plugins/  (14 enabled)
```

Stow note: every file under `~/.codex/skills/` (and the equivalent CC and OpenCode paths) is a Stow-managed symlink to `~/.dotfiles/<package>/...`. Adding new skills means dropping them into the dotfiles tree and re-running `stow --restow Codex` (per `~/.dotfiles/README.md`). The `~/.codex/skills/.system/` dir is the only non-stowed entry — it holds Codex's auto-installed system skills (`imagegen`, `openai-docs`, `plugin-creator`, `skill-creator`, `skill-installer`).

Shared cross-tool dir at `~/.agents/skills/`:

```
commenting     -> dotfiles/.../skills/commenting     (Claude skill)
playwright-cli -> dotfiles/.../skills/playwright-cli (Claude skill)
security       -> dotfiles/.../skills/security       (Claude skill)
python         -> dotfiles/.../rules/python          (Claude rule)
scalability    -> dotfiles/.../rules/scalability     (Claude rule)
typescript     -> dotfiles/.../rules/typescript      (Claude rule)
deploy-to-vercel, doc-coauthoring, find-skills,
frontend-design, supabase, supabase-postgres-best-practices,
vercel-cli-with-tokens, vercel-composition-patterns,
vercel-react-best-practices, vercel-react-native-skills,
vercel-react-view-transitions, web-design-guidelines, webapp-testing
```

This is the only **shared** dir read by all three. Codex also reads `$CODEX_HOME/skills` (=`~/.codex/skills/`, undocumented in the public skills page but documented in the bundled `skill-installer` SKILL.md and verified live with `codex exec`); OpenCode also reads `~/.claude/skills/` natively (https://opencode.ai/docs/skills/, https://opencode.ai/docs/rules/).

### 1.2 Per-repo configs observed

| Repo | CLAUDE.md | AGENTS.md | `.claude/` | `.codex/` | `.agents/` | `.opencode/` | `.mcp.json` | `opencode.jsonc` |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| **Houndarr** | `@AGENTS.md` only (1 line) | 1102 lines, primary | settings.json, commands/, rules/, settings.local.json | empty dir | absent | bun.lock + package.json | absent | absent |
| **wedding-site** | 204 lines, primary | absent | settings.local.json, rules/, skills/ (3 symlinks) | config.toml (small) | skills/ (3 dirs) | absent | shadcn/next-devtools/stripe | supabase, vercel, shadcn, next-devtools, stripe |
| **invest-platform** | full project doc | absent | settings.json, settings.local.json, commands/, rules/, skills/ | config.toml (small) | absent | absent | cloudflare/grafana/sentry/shadcn | supabase, vercel, cloudflare, sentry, grafana, shadcn |

Houndarr is the only repo using the canonical Claude Code → AGENTS.md interop pattern documented at https://code.claude.com/docs/en/memory: `@AGENTS.md` as the first line of `CLAUDE.md`. The other two repos duplicate intent across CLAUDE.md and tool-specific configs.

---

## 2. AGENTS.md / CLAUDE.md handling

### 2.1 What each tool actually does

- **Claude Code does NOT auto-fallback to AGENTS.md.** From https://code.claude.com/docs/en/memory: "Claude Code reads `CLAUDE.md`, not `AGENTS.md`. If your repository already uses `AGENTS.md` for other coding agents, create a `CLAUDE.md` that imports it so both tools read the same instructions without duplicating them."
- **Codex CLI** walks Git root → cwd, concatenates AGENTS.md files joined by blank lines, deeper files override shallower, with a `project_doc_max_bytes = 32 KiB` cap and an `AGENTS.override.md` precedence variant (https://developers.openai.com/codex/guides/agents-md).
- **OpenCode** walks upward only; `AGENTS.md` beats `CLAUDE.md`; project beats global; also reads `~/.claude/CLAUDE.md` as a fallback. v1.14.30 (Apr 29 2026) made global instructions apply before project and skill instructions (https://opencode.ai/docs/rules, https://opencode.ai/changelog).

### 2.2 Your global files

All three globals are near-clones (the writing/code/principles sections match line-for-line). Only the tool-specific bits differ:
- CC mentions `Skill Agent` in tool-order; Codex mentions `skill`; OpenCode adds `lsp`/`question`/`todoread/todowrite`.
- CC paths point at `~/.claude/rules/<name>/`; Codex/OpenCode point at `~/.agents/skills/<name>/`.
- CC has the broader "MCP servers" list (9 entries); Codex/OpenCode list 5 globals plus a project-scoped section.

This is acceptable convergence given each tool's vocabulary. The intent is identical.

### 2.3 Your project files

| Repo | Pattern observed | Recommended pattern (Anthropic docs) |
| --- | --- | --- |
| Houndarr | `CLAUDE.md` is `@AGENTS.md` only; AGENTS.md holds everything | ✅ Already canonical |
| wedding-site | `CLAUDE.md` 204 lines; no AGENTS.md | ❌ Codex sees nothing; OpenCode sees only via CLAUDE.md fallback |
| invest-platform | Full `CLAUDE.md`; no AGENTS.md | ❌ Same as wedding-site |

**The Houndarr pattern is the standard Anthropic recommends.** Apply it to the other two: rename each `CLAUDE.md` to `AGENTS.md`, then drop a one-line `CLAUDE.md` containing `@AGENTS.md`. Result: Codex reads AGENTS.md natively (https://developers.openai.com/codex/guides/agents-md), OpenCode reads AGENTS.md natively (https://opencode.ai/docs/rules), and Claude Code reads it via the import (https://code.claude.com/docs/en/memory). One source, three readers.

---

## 3. Skills and rules

### 3.1 Storage paths each tool actually scans

| Tool | Personal | Project | Notes |
| --- | --- | --- | --- |
| Claude Code | `~/.claude/skills/<name>/SKILL.md` (also auto-loaded `.claude/rules/<name>.md` with `paths:` frontmatter) | `.claude/skills/<name>/SKILL.md`, `.claude/rules/<name>.md` | https://code.claude.com/docs/en/skills, https://code.claude.com/docs/en/memory |
| Codex CLI | `$CODEX_HOME/skills` (= `~/.codex/skills/`, documented in bundled `skill-installer` SKILL.md), `$HOME/.agents/skills/<name>/SKILL.md`, `/etc/codex/skills` | `.agents/skills/<name>/SKILL.md` (current dir), `../.agents/skills`, `$REPO_ROOT/.agents/skills` | https://developers.openai.com/codex/skills, plus `$CODEX_HOME/skills` (verified live) |
| OpenCode | `~/.config/opencode/skills/<name>/SKILL.md` plus equivalents under `~/.claude/` and `~/.agents/` | `.opencode/skills/`, `.claude/skills/`, `.agents/skills/` | https://opencode.ai/docs/skills/ |

**Verified live with `codex exec --skip-git-repo-check`** (Codex 0.128.0): Codex sees all 11 of your `~/.codex/skills/` user skills (catchup, coordinator, deep-audit, fix-issue, merge, open-pr, rebase, review, ship, workmux, worktree), plus all 13 entries in `~/.agents/skills/` (commenting, deploy-to-vercel, doc-coauthoring, find-skills, frontend-design, playwright-cli, python, scalability, security, supabase, supabase-postgres-best-practices, typescript, vercel-cli-with-tokens, vercel-composition-patterns, vercel-react-best-practices, vercel-react-native-skills, vercel-react-view-transitions, web-design-guidelines, webapp-testing), plus the 5 auto-installed `.system` skills, plus plugin-bundled namespaced skills (`build-web-apps:*`, `linear:*`, `vercel:*` totaling ~50). 80+ skills total — Codex actually has the **broadest** skill surface of the three.

So `$CODEX_HOME/skills` IS the canonical user-install path for Codex (per the bundled `skill-installer`); the public skills doc just doesn't list it explicitly. Andrea's stow setup is correct: `~/.dotfiles/Codex/.codex/skills/` → `~/.codex/skills/` works as designed.

### 3.2 Skill content drift between CC and Codex

`diff /Users/andreaventi/.dotfiles/Claude/.claude/skills/catchup/SKILL.md /Users/andreaventi/.dotfiles/Codex/.codex/skills/catchup/SKILL.md` shows:

- `allowed-tools` frontmatter present in CC, absent in Codex (Codex skills frontmatter is only `name` + `description`, https://developers.openai.com/codex/skills).
- `disable-model-invocation: true` present in CC, absent in Codex.
- CC version references `.claude/`, Codex version references `.codex/`; same intent, manually swapped.
- CC version references slash commands like `/merge`, Codex version uses prose ("the merge skill").

The Codex skills are **manually curated copies** of CC skills, with frontmatter stripped because Codex doesn't honor it. There is no automation keeping them in sync.

OpenCode honors all skill frontmatter that matches its allowlist (`name`, `description`, `license`, `compatibility`, `metadata`; unknown fields ignored, https://opencode.ai/docs/skills/) and reads `.claude/skills/` natively, so OpenCode would happily reuse the CC versions verbatim.

### 3.3 Path-conditional rules (`.claude/rules/<name>/SKILL.md` with `paths:` frontmatter)

This is a **Claude-Code-only feature**. Per https://code.claude.com/docs/en/memory:

```yaml
---
paths:
  - "src/api/**/*.ts"
---
```

Triggers only when Claude reads a file matching the pattern. Codex docs do not document an equivalent (https://developers.openai.com/codex/skills); OpenCode skills are name/description-driven, not path-driven.

Implication: your `~/.claude/rules/typescript/SKILL.md`, `python/SKILL.md`, `scalability/SKILL.md` auto-load in Claude Code on path match, but in Codex/OpenCode they only fire when something explicitly invokes "the typescript skill". This is a real loss of automation that no amount of config standardization can recover. Closest mitigation: move the contents into the AGENTS.md so it is always present in Codex/OpenCode contexts, OR write project-local `.codex/skills/` and `.opencode/skills/` shims that the user explicitly invokes.

### 3.4 The `~/.agents/skills/` symlink hub

The shared dir today exposes the **content-only** skills (the ones that are pure prose: writing conventions, language rules, library guidance):

```
~/.agents/skills/commenting   -> ~/.dotfiles/.../skills/commenting   ✓
~/.agents/skills/playwright-cli -> ~/.dotfiles/.../skills/playwright-cli ✓
~/.agents/skills/security     -> ~/.dotfiles/.../skills/security     ✓
~/.agents/skills/python       -> ~/.dotfiles/.../rules/python        ✓
~/.agents/skills/scalability  -> ~/.dotfiles/.../rules/scalability   ✓
~/.agents/skills/typescript   -> ~/.dotfiles/.../rules/typescript    ✓
```

The **workflow** skills (catchup, merge, ship, rebase, etc.) are intentionally split: CC reads its native `~/.claude/skills/` versions (which use `Bash(git:*)` allowed-tools and slash-command references), Codex reads its variant from `~/.codex/skills/` (no frontmatter, prose references), and OpenCode reads CC's via `~/.claude/skills/` fallback. This split is deliberate per Codex's frontmatter limitations (https://developers.openai.com/codex/skills) — but it forces manual sync.

If you want Codex/OpenCode to see the same workflow skills CC has via the shared dir (and skip the duplicated maintenance), symlink the additional CC skills into `~/.agents/skills/` — Codex will silently ignore CC's extra frontmatter (`allowed-tools`, `disable-model-invocation`) per the skills doc, so the same SKILL.md works for both.

---

## 4. Hooks

### 4.1 What each tool supports in 2026

- **Claude Code** documents 30+ hook events (https://code.claude.com/docs/en/hooks-guide), including `SessionStart`, `SessionEnd`, `Setup`, `UserPromptSubmit`, `UserPromptExpansion`, `Stop`, `StopFailure`, `PreToolUse`, `PermissionRequest`, `PermissionDenied`, `PostToolUse`, `PostToolUseFailure`, `PostToolBatch`, `SubagentStart`, `SubagentStop`, `TaskCreated`, `TaskCompleted`, `TeammateIdle`, `InstructionsLoaded`, `ConfigChange`, `CwdChanged`, `FileChanged`, `WorktreeCreate`, `WorktreeRemove`, `PreCompact`, `PostCompact`, `Notification`, `Elicitation`, `ElicitationResult`. Handlers can be `command | http | mcp_tool | prompt | agent`.
- **Codex CLI** documents 6 events (https://developers.openai.com/codex/hooks): `SessionStart`, `PreToolUse`, `PostToolUse`, `PermissionRequest`, `UserPromptSubmit`, `Stop`. Only `command` handlers. Gated behind `[features] codex_hooks = true`.
- **OpenCode** has no separate hooks system; "hooks" are plugin events delivered through the TS Plugin module (https://opencode.ai/docs/plugins/). Documented events span session, permission, file, LSP, MCP, message, todo, shell, tool, TUI categories — broadly comparable to CC's lifecycle but with different names (e.g. `session.idle` ≈ `Stop`, `permission.asked` ≈ `Notification`, `tool.execute.before/after` ≈ `PreToolUse`/`PostToolUse`).

### 4.2 What you have today

- **Claude Code (settings.json)**: 5 events wired to `workmux` (Notification, PostToolUse, Stop, UserPromptSubmit), plus SessionStart and SessionEnd to `claude-session-track.sh` / `claude-session-cleanup.sh`. Looks correct.
- **Codex (hooks.json)**: 3 events (PostToolUse, Stop, UserPromptSubmit). **Missing SessionStart and PermissionRequest** — both available in Codex 0.128.0 per the docs. SessionStart in particular would let you call `workmux set-window-status working` at session start (mirroring CC). PermissionRequest would mirror CC's Notification matcher for `permission_prompt`.
- **OpenCode (workmux-status.ts)**: 4 event branches (`session.status` busy, `permission.asked`, `question.asked`, `permission.replied`, `question.replied`, `session.idle`). Closest 1:1 to CC's behavior, missing only an explicit "session start" trigger.

### 4.3 Concrete delta to close

Update `~/.dotfiles/Codex/.codex/hooks.json` to add SessionStart (mirrors CC's "working" status on start) and PermissionRequest (mirrors CC's "waiting"):

```json
{
  "hooks": {
    "SessionStart": [
      { "hooks": [{ "type": "command", "command": "workmux set-window-status working" }] }
    ],
    "PermissionRequest": [
      { "hooks": [{ "type": "command", "command": "workmux set-window-status waiting" }] }
    ],
    "PostToolUse": [
      { "hooks": [{ "type": "command", "command": "workmux set-window-status working" }] }
    ],
    "UserPromptSubmit": [
      { "hooks": [{ "type": "command", "command": "workmux set-window-status working" }] }
    ],
    "Stop": [
      { "hooks": [{ "type": "command", "command": "workmux set-window-status done" }] }
    ]
  }
}
```

Confirm `[features] codex_hooks = true` is in `~/.codex/config.toml` (it already is). For OpenCode, the existing `workmux-status.ts` already covers the equivalent events; consider adding a `session.created` branch to mirror SessionStart explicitly.

---

## 5. MCP servers

### 5.1 Configuration shapes (different but composable)

| Tool | File | Schema |
| --- | --- | --- |
| Claude Code | `.mcp.json` (project), `~/.claude.json` (user/local) | `mcpServers.<name>.{command,args,env,type,url,headers}`; `${VAR}` and `${VAR:-default}` expansion (https://code.claude.com/docs/en/mcp) |
| Codex CLI | `~/.codex/config.toml` `[mcp_servers.<name>]` | `command/args/cwd/env/env_vars/oauth/...` for STDIO; `url/http_headers/env_http_headers/bearer_token_env_var` for HTTP (https://developers.openai.com/codex/mcp) |
| OpenCode | `opencode.jsonc` `mcp.<name>` | `type: "local"` with `command[]/environment{}/timeout`; `type: "remote"` with `url/headers{}/timeout/oauth{}` (https://opencode.ai/docs/mcp-servers/) |

### 5.2 Your global state

All three list `context7` + `firecrawl` (only context7 + firecrawl currently `enabled`). `github`, `magic`, `stitch` are present but disabled in all three. CC additionally gets `supabase`, `vercel`, `semgrep`, `playwright`, `claude-in-chrome`, plus the bundled `claude.ai/Linear` and `claude.ai/HubSpot` connectors via plugins.

The reason CC has more MCPs at the global level: **plugin-bundled MCPs.** Per https://code.claude.com/docs/en/mcp, plugins can ship `.mcp.json` or inline `mcpServers`, and they auto-connect when the plugin is enabled. Codex plugins also support this (https://developers.openai.com/codex/plugins) but you only have four Codex plugins enabled (`build-web-apps`, `linear`, `vercel`; `github` disabled). OpenCode has no plugin-bundled MCP concept — every MCP is in `opencode.jsonc`.

Implication: to mirror CC's `supabase` / `vercel` / `semgrep` / `playwright` MCPs in Codex globally, either enable Codex curated plugins that bundle them or add explicit `[mcp_servers.X]` blocks. To mirror them in OpenCode globally, add explicit blocks to `~/.config/opencode/opencode.jsonc`.

### 5.3 Project-level MCP is well-aligned

Both wedding-site and invest-platform define identical sets across `.mcp.json` and `opencode.jsonc`, with parallel `.codex/config.toml` for supabase + vercel only. The pattern works:

- `.mcp.json` shape uses `command/args` arrays for stdio and `type: "http"` + `url` for HTTP.
- `opencode.jsonc` shape uses `command: []` + `type: "local"` for stdio and `type: "remote"` + `url` + `oauth: {}` for HTTP.
- `.codex/config.toml` shape uses `[mcp_servers.X]` with `command/args` or `url`.

These are translations of the same intent. Recommendation: keep maintaining all three when adding a project MCP. Or write a small generator (one source file, three outputs) — see §11.

---

## 6. Plugins

### 6.1 Conceptual differences

- **Claude Code**: full marketplace ecosystem with `enabledPlugins` map, multiple sources (`github`, `git`, `directory`, `npm`, etc.), bundled skills + commands + agents + hooks + LSP + MCP per plugin (https://code.claude.com/docs/en/plugins, https://code.claude.com/docs/en/discover-plugins).
- **Codex CLI**: smaller marketplace (`openai-curated` is the canonical source), bundles "skills + apps + MCP servers" (https://developers.openai.com/codex/plugins). Toggled via `[plugins."<name>@<source>"] enabled = true/false` in config.toml.
- **OpenCode**: "plugins" are **JS/TS files in `~/.config/opencode/plugins/` or via `plugin` array in opencode.json** that subscribe to event hooks (https://opencode.ai/docs/plugins/). NOT a marketplace concept; closer to webhooks/middleware.

These are not interchangeable. The closest cross-tool primitive is "the official marketplace plugin for service X bundles its MCP server", which both CC and Codex support.

### 6.2 Your enabled plugins

| Service | Claude Code | Codex CLI | OpenCode |
| --- | --- | --- | --- |
| context7 | plugin (claude-plugins-official) | mcp_servers entry | mcp entry |
| firecrawl | plugin | mcp_servers entry | mcp entry |
| supabase | plugin | (project only) | (project only) |
| vercel | plugin (vercel-vercel-plugin) | plugin (openai-curated) | (project only) |
| semgrep | plugin | n/a | n/a |
| playwright | plugin (via code-review chain) | n/a | n/a |
| github | plugin disabled | plugin disabled | mcp disabled |
| linear | (claude.ai built-in) | plugin enabled | n/a |
| frontend-design | plugin | n/a | n/a |
| ui-ux-pro-max | plugin | n/a | n/a |
| skill-codex | plugin | n/a | n/a |
| build-web-apps | n/a | plugin enabled | n/a |
| pyright-lsp | plugin | n/a (Codex doesn't ship LSP plugins) | (built-in LSP server) |
| typescript-lsp | plugin | n/a | (built-in LSP server) |
| lua-lsp | plugin | n/a | (built-in LSP server) |
| claude-notifications-go | plugin | n/a | workmux plugin (TS) |

The takeaway: OpenCode and Codex are a strict subset of CC's plugin-driven feature surface. That's structural — neither tool has Claude-Code-equivalent plugin distribution. The best you can do is keep the **shared MCP servers** in lock-step (already in good shape).

---

## 7. Subagents

| Tool | Built-ins | Custom location | Format |
| --- | --- | --- | --- |
| Claude Code | `Explore` (Haiku, read-only), `Plan`, `general-purpose`, `statusline-setup`, `Claude Code Guide` (https://code.claude.com/docs/en/sub-agents) | `~/.claude/agents/<name>.md` (user), `.claude/agents/<name>.md` (project) | YAML frontmatter + Markdown system prompt |
| Codex CLI | `default`, `worker`, `explorer` (https://developers.openai.com/codex/subagents) | `~/.codex/agents/<name>.toml` (user), `<repo>/.codex/agents/<name>.toml` (project) | TOML, requires `name`, `description`, `developer_instructions` |
| OpenCode | `build` (primary), `plan` (primary), `general` (subagent), `explore` (subagent) (https://opencode.ai/docs/agents/) | `~/.config/opencode/agents/<name>.md` (user), `.opencode/agents/<name>.md` (project) | YAML frontmatter + Markdown system prompt |

Your current state: **no custom subagents anywhere**. That's fine and consistent. If you ever want one (e.g. a "review" agent), the pattern would be:

```
~/.claude/agents/review.md            (CC, YAML+MD)
~/.codex/agents/review.toml           (Codex, TOML)
~/.config/opencode/agents/review.md   (OpenCode, YAML+MD)
```

Keep the system prompt body identical, adjust frontmatter to each schema.

---

## 8. Permissions, sandbox, trust

### 8.1 Three different vocabularies

- **Claude Code**: `permissions.{allow,deny,ask}` arrays of strings. Tool grammar like `Bash(git push *)`, `Read(./.env)`, `MCP(server)`, `Skill(name)`, `Agent(agent)` (https://code.claude.com/docs/en/settings).
- **Codex CLI**: `sandbox_mode` (`read-only|workspace-write|danger-full-access`) + `approval_policy` (`untrusted|on-request|never|granular`) + per-project `trust_level`. Plus `requirements.toml` admin guardrails and `default.rules` shell prefix-rule allowlist (https://developers.openai.com/codex/config-reference, https://developers.openai.com/codex/hooks).
- **OpenCode**: `permission.{read,edit,glob,grep,list,bash,task,skill,lsp,question,webfetch,websearch,external_directory,doom_loop,todowrite}` with three states (`allow|ask|deny`) and per-agent overrides (https://opencode.ai/docs/permissions/).

### 8.2 What you have

- **CC global** (`~/.claude/settings.json`): denies env files, secrets, ssh, aws, gnupg, npmrc, gh config; asks on sudo, chmod 777, git push, git merge, git reset --hard, curl|sh, pnpm install/add/remove/publish, drop table, dd, mkfs.
- **OpenCode global** (`~/.config/opencode/opencode.jsonc`): same secret denylist (under `read`), same sudo/chmod/dd/mkfs/drop denylist, same git push/merge/reset asks, plus same pnpm install/add/remove/publish asks. **Excellent parity with CC.**
- **Codex global** (`~/.codex/rules/default.rules`): a totally different syntax — `prefix_rule(pattern=["pnpm","build"], decision="allow")`. It only contains **allowlist additions**, not the secret denylist. Codex relies on `sandbox_mode = workspace-write` (default) plus per-project `trust_level = "trusted"` for the broader policy. The secret denylist isn't expressible in Codex's prefix-rule syntax.

### 8.3 Per-repo permission consistency

- **Houndarr** (`.claude/settings.json`): full CC-style allow/deny/ask, with explicit deny for `git push --force*`, `git push -f*`, `git push origin main*`, `git push origin master*`, `git push origin :*`. Solid.
- **invest-platform** (`.claude/settings.json`): same shape, plus `Bash(npx supabase db reset*)` deny. Adds `pnpm install/add/remove` asks. Solid.
- **wedding-site** (`.claude/settings.local.json`): only contains additive allows for tools the user accepted during sessions (mcp__plugin_playwright_*, etc.) — no denylist of its own. Inherits the global. That's by design (settings.local.json is per-developer transient state, https://code.claude.com/docs/en/settings).

The CC-level baseline is solid and well-replicated in OpenCode. The Codex side is the structural odd one out: its policy lives in a completely different layer (sandbox + trust + prefix-rule), so there is no clean way to mirror the CC denylist into Codex. Acceptable, because Codex's sandbox enforces by default.

---

## 9. Slash commands

- **Claude Code**: `.claude/commands/<name>.md` (legacy, still works) and `.claude/skills/<name>/SKILL.md` both produce `/<name>`. Skill wins on conflict (https://code.claude.com/docs/en/skills).
- **Codex CLI**: built-in slash commands documented (https://developers.openai.com/codex/cli/slash-commands), but **the file format and location for custom commands are not documented** in any source I could fetch.
- **OpenCode**: `.opencode/commands/<name>.md` or `command` map in `opencode.json`. Frontmatter keys: `template`, `description`, `agent`, `model`, `subtask`. Templates support `$ARGUMENTS`, positional args, ` !`cmd` ` shell expansion, `@filename` includes (https://opencode.ai/docs/commands/).

Your `.claude/commands/` (Houndarr: bump.md, check.md, test.md; invest-platform: check.md, linear-sync.md, new-adapter.md, new-component.md, new-migration.md, progress-update.md) live in CC only. Mirroring them in OpenCode is mechanical: copy each .md, drop into `.opencode/commands/<name>.md`, adapt the frontmatter to OpenCode's `template:` key.

---

## 10. Status line and notifications

| Tool | Mechanism | Your config |
| --- | --- | --- |
| Claude Code | `statusLine.{type,command,refreshInterval}` in settings.json (https://code.claude.com/docs/en/statusline) | `~/.claude/statusline.sh`, refreshInterval 2 |
| Codex CLI | `/statusline` slash command + agent-level `subagentStatusLine` settings | (no custom statusline shipped) |
| OpenCode | `tui.json` keybinds + theme; no per-line custom statusline documented | tui.json with custom keybinds |

Status-line is largely a CC-only customization surface. Notification-wise, the workmux integration is the consistent thread across all three — see §4.

---

## 11. Concrete recommendations, ranked by impact

### High impact

1. **Apply the Houndarr CLAUDE.md → @AGENTS.md pattern to wedding-site and invest-platform.**
   - Move the current `CLAUDE.md` content into `AGENTS.md`.
   - Replace `CLAUDE.md` with one line: `@AGENTS.md`, plus any Claude-only sections after.
   - Effect: Codex finally sees your full project doc; OpenCode prefers AGENTS.md natively; CC continues to read it via the documented import (https://code.claude.com/docs/en/memory).

2. **Decide whether you want one shared skill set or two intentional variants.** Live verification confirmed Codex DOES load `~/.codex/skills/`. Today you have two manually-curated copies (one in `~/.dotfiles/Claude/.claude/skills/`, another in `~/.dotfiles/Codex/.codex/skills/`) that drift. Two paths:
   - **Option A — single source.** Symlink CC's skills into `~/.agents/skills/` (which Codex AND OpenCode read), delete `~/.dotfiles/Codex/.codex/skills/`. Codex silently ignores CC's extra frontmatter (`allowed-tools`, `disable-model-invocation`) per https://developers.openai.com/codex/skills, so the same SKILL.md works for both.
     ```bash
     cd ~/.agents/skills
     for s in catchup coordinator deep-audit fix-issue merge open-pr rebase review ship workmux worktree; do
       ln -sfn "$HOME/.dotfiles/Claude/.claude/skills/$s" "$s"
     done
     # then drop the stowed Codex copies:
     cd ~/.dotfiles/Codex/.codex && rm -r skills && cd ~/.dotfiles && stow --restow Codex
     ```
   - **Option B — keep two variants intentionally.** If the Codex versions are deliberately stripped (no frontmatter, prose instead of slash-command references), commit to that explicitly: add a top-of-file `# Codex variant of ../../Claude/.claude/skills/<name>/SKILL.md — keep in sync` header so future-you remembers which is the source. Either way, document the choice somewhere in `~/.dotfiles/README.md`.

3. **Expand Codex `hooks.json` to mirror CC's status events.** Add `SessionStart` and `PermissionRequest` per the snippet in §4.3.

### Medium impact

4. **Mirror the global MCP set across tools.** Today CC gets `supabase` / `vercel` / `semgrep` / `playwright` for free via plugins; Codex and OpenCode see only `context7` + `firecrawl` globally. Either:
   - Enable Codex curated plugins for parity (`vercel@openai-curated` already enabled; check whether `supabase@openai-curated` exists), OR
   - Add explicit `[mcp_servers.supabase]`, `[mcp_servers.vercel]`, `[mcp_servers.playwright]` blocks to `~/.codex/config.toml` and `mcp.supabase`, `mcp.vercel`, `mcp.playwright` blocks to `~/.config/opencode/opencode.jsonc`.

5. **Mirror your `.claude/commands/` into OpenCode `.opencode/commands/`.** Mechanical translation: `.md` → `.md`, frontmatter `description` stays, body becomes `template:` key. See https://opencode.ai/docs/commands/ for the schema.

6. **Add an `~/.agents/skills/` index for the remaining Claude Code skills you want Codex/OpenCode to see.** Currently only 6 of your 14 CC skills are exposed cross-tool via this dir.

### Low impact (polish)

7. **Empty the empty stubs.** `~/.dotfiles/Claude/.claude/rules/git-protected/` exists but contains no `SKILL.md`. Either populate it or delete the directory; it does nothing today.

8. **Remove the dead `install-mcps.sh` symlink** at `~/install-mcps.sh -> .dotfiles/Claude/install-mcps.sh` (target file does not exist).

9. **Decide where wedding-site's project skills should live.** Today `wedding-site/.claude/skills/{stripe-best-practices,stripe-projects,upgrade-stripe}` are symlinks into `wedding-site/.agents/skills/`. That's the right pattern (skills live in `.agents/skills` and are exposed to CC via `.claude/skills` symlinks). Consider extending it to invest-platform too (currently has `.claude/skills/{opengrep,sprint-plan,sprint-pr}` only in CC location).

10. **Document the `~/.opencode/cache/codex-instructions.md` cache.** OpenCode silently caches the Codex system prompt at this path (etag tag `rust-v0.45.0`). It's likely stale (Codex 0.128.0 is current). If you don't use Codex models in OpenCode, ignore it; otherwise force a refresh.

### Structural gaps you cannot fully close

- **Path-conditional auto-load rules** (`.claude/rules/<name>.md` with `paths:` frontmatter) is Claude-Code-only. The closest workaround is to put the most critical content in your AGENTS.md so it is always present in Codex/OpenCode contexts. Your `~/.claude/rules/typescript/SKILL.md` is 50+ lines of detailed Next.js 16 / React 19 guidance — that's worth promoting into AGENTS.md if it applies project-wide.
- **Plugin-bundled MCP servers**: only CC and Codex have the concept, in different forms. OpenCode requires explicit MCP entries.
- **Output styles, statusline customization, channels, routines, dispatch, remote control, /loop, /schedule**: all CC-only features (https://code.claude.com/docs/en/overview, https://code.claude.com/docs/en/output-styles, https://code.claude.com/docs/en/statusline). Nothing to mirror.

---

## 12. What stays the same regardless

These already match across all three:

- Writing conventions (no em dashes, no "Bold header: description", no negative parallelism, vary sentence length).
- Working principles (read first, smallest correct change, no premature abstraction).
- Boundaries (always do / ask first / never do lists).
- Production scalability non-negotiables (no N+1, paginate, queue blocking work, timeouts on external calls).
- Git defaults (Conventional Commits, 50-char title, 72-col body, branch protection check).
- MCP intent (when to reach for context7, firecrawl, github, etc.).
- Per-repo skill patterns and permission denials of secrets.

That's a lot of agreement. The misalignments are concentrated in three places: discovery paths (skills under `~/.agents/skills/` vs `~/.codex/skills/`), the AGENTS.md vs CLAUDE.md project file, and Codex hook event coverage.

---

## 13. Source index

### Claude Code
- Overview · https://code.claude.com/docs/en/overview
- Memory (CLAUDE.md) · https://code.claude.com/docs/en/memory
- Settings · https://code.claude.com/docs/en/settings
- Hooks ref · https://code.claude.com/docs/en/hooks · guide · https://code.claude.com/docs/en/hooks-guide
- Plugins authoring · https://code.claude.com/docs/en/plugins · marketplaces · https://code.claude.com/docs/en/discover-plugins
- Skills · https://code.claude.com/docs/en/skills
- MCP · https://code.claude.com/docs/en/mcp
- Subagents · https://code.claude.com/docs/en/sub-agents
- Statusline · https://code.claude.com/docs/en/statusline
- Output styles · https://code.claude.com/docs/en/output-styles
- Settings JSON schema · https://json.schemastore.org/claude-code-settings.json

### Codex CLI
- Codex CLI overview · https://developers.openai.com/codex/cli
- AGENTS.md guide · https://developers.openai.com/codex/guides/agents-md
- Configuration reference · https://developers.openai.com/codex/config-reference
- Hooks · https://developers.openai.com/codex/hooks
- MCP · https://developers.openai.com/codex/mcp
- Plugins · https://developers.openai.com/codex/plugins
- Skills · https://developers.openai.com/codex/skills
- Subagents · https://developers.openai.com/codex/subagents
- Slash commands · https://developers.openai.com/codex/cli/slash-commands
- GitHub repo · https://github.com/openai/codex

### OpenCode
- Docs root · https://opencode.ai/docs/
- Config · https://opencode.ai/docs/config/
- Rules (AGENTS.md handling) · https://opencode.ai/docs/rules/
- Permissions · https://opencode.ai/docs/permissions/
- MCP servers · https://opencode.ai/docs/mcp-servers/
- Plugins · https://opencode.ai/docs/plugins/
- Skills · https://opencode.ai/docs/skills/
- Agents · https://opencode.ai/docs/agents/
- Commands · https://opencode.ai/docs/commands/
- Custom tools · https://opencode.ai/docs/custom-tools/
- LSP · https://opencode.ai/docs/lsp/
- Changelog · https://opencode.ai/changelog
- GitHub repo · https://github.com/sst/opencode

### Cross-tool
- AGENTS.md spec · https://agents.md
- Agent Skills standard · https://agentskills.io
