# AGENTS.md

Global defaults for AI coding agents under this user account. The canonical source of truth lives at `~/.agents/AGENTS.md` (stowed from `.dotfiles/Agents/.agents/AGENTS.md`); each harness reads it via a committed symlink at its expected path:

- Claude Code: `~/.claude/CLAUDE.md` → this file
- Codex CLI: `~/.codex/AGENTS.md` → this file
- OpenCode: `~/.config/opencode/AGENTS.md` → this file
- Pi (earendil-works): `~/.pi/agent/AGENTS.md` → this file

Repository-local `AGENTS.md` (or `CLAUDE.md` for Claude) always wins over this file. For the architecture and procedures behind this multi-harness setup, see the runbook at `~/.dotfiles/docs/AGENTIC-CODING-HARNESSES.md`, or invoke the `agentic-coding-harnesses` skill.

## Instruction precedence

1. Direct user instruction in the current turn
2. Repository-local `AGENTS.md` (or `CLAUDE.md`)
3. Other repository or config-linked instruction files
4. This file

If the repository has no rules, say so briefly and proceed with the safest minimal behavior.

## Personal conventions (Andrea Venti)

### Writing

- Never use em dashes. Use colons, semicolons, commas, periods, or parentheses.
- Avoid the "Bold header: description" list pattern. Use plain bullets.
- Avoid "It's not X, it's Y" negative parallelism.
- Do not default to lists of exactly three items. Use the count that fits.
- Vary sentence length and structure.

### Code

Path-conditional and on-demand skills live at `~/.agents/skills/<name>/SKILL.md`. They auto-load when matching files are accessed (via `paths:` frontmatter) or when invoked by description match.

- TypeScript / Next.js: `typescript` skill, auto-loads on `.ts` / `.tsx`
- Python: `python` skill, auto-loads on `.py`
- Backend code (API, database, queue, cache, migration files): `scalability` skill
- Comments: `commenting` skill (project `docs/commenting-standard.md` overrides when present)
- Security-relevant code (auth, secrets, user input, external calls, LLM prompts): `security` skill
- General preference everywhere: smallest correct change, no over-decomposition, no premature abstraction.

## Working principles

- Read first, scope first. Investigate before editing.
- Smallest correct change wins. Do not bundle unrelated concerns; do not over-decompose; three similar lines beats a premature abstraction.
- Preserve existing behavior unless the task explicitly requires a change. Refactor outside the task scope only when asked.
- Establish repo shape cheaply (manifests, workspace config, primary languages); targeted glob/grep before opening files; range reads not full files.
- Stop once enough evidence is gathered. Reuse facts collected; do not rediscover on follow-up tasks.
- State uncertainty honestly. Verify with the smallest concrete check (test, build, code read) before claiming done.
- No vague delegations like "analyze the repo"; no pasting large excerpts; no re-reading without reason.
- When refactoring untested code, write characterization tests first or skip the refactor.
- Do not bypass plugin, permission, sandbox, approval, or runtime safeguards.

## Tool order

Prefer the cheapest tool that does the job. Each harness exposes equivalents under different names; the order of preference is the same.

```
Discovery        list / glob / grep / read
Targeted read    read (range, not full)
Diagnostics      lsp (where supported)
Shell            only when builtins are insufficient
Localized edit   edit / patch
File creation    write (full replacement only)
Web fetch        known URLs (docs, specs)
Web search       only when no source is known
Multi-step task  todo / task list (where supported)
Skill            when an existing SKILL.md fits
Subagent         multi-step work or genuinely parallelizable fan-out
```

## Boundaries

### Always do

- Discovery via `list` / `glob` / `grep` / `read`
- Reading docs, configs, git history
- Running the smallest relevant validation before declaring done
- Conventional Commits with 50-char title and 72-col body
- Boy Scout cleanups in a separate `chore: cleanup` commit

### Ask first

- Edits in repos without test coverage
- Dependency upgrades or lockfile changes
- Schema, migration, CI, or release-workflow edits
- New abstractions, helpers, or layers
- Anything outside the stated task scope
- `git push`, branch creation on remote, opening or merging PRs

### Never do

- Force-push, `git reset --hard` on shared branches, branch deletion, or skipped hooks without explicit approval
- Bypass a denied tool by routing through another tool or shell path
- Commit, print, or paste secrets
- Mix feature work with cleanup or formatting churn in the same commit

## Production scalability

Backend code must be production-scalable from the first version. Load the `scalability` skill (`~/.agents/skills/scalability/`) when working on database queries, API endpoints, background jobs, caching, or any server-side code that runs under load. Top-level non-negotiables: no N+1 queries, always paginate, queue blocking work, set timeouts on external calls, emit p50/p95/p99 latency metrics.

## Git defaults

- Branch from the primary dev branch. Short, lowercase, hyphenated names.
- One focused branch per logical change.
- Conventional Commits: `<type>(<scope>)!: <description>`.
- Common types: feat, fix, docs, refactor, perf, test, build, ci, chore, revert.
- Prefer `gh` CLI over the web UI for issues, PRs, checks.
- Never push directly to protected branches. Verify protection status with `gh api repos/<owner>/<repo>/branches/<branch>/protection` (404 means unprotected) before refusing to push. Never force-push without explicit authorization.

Example body:

```
fix(auth): invalidate stale session tokens on logout

Tokens were retained in Redis after logout because the destroy
hook ran asynchronously and could be skipped if the response
stream closed early. Move the destroy call before response flush.
```

## MCP servers

Pi supports MCP through the `pi-mcp-adapter` extension; servers are lazy-connected by default.

| Server   | When to reach for it                       |
| -------- | ------------------------------------------ |
| `magic`  | UI component generation via 21st.dev       |
| `stitch` | Design system generation via Google Stitch |

Project-scoped MCP servers may be declared per-repo: `<repo>/.mcp.json` (Claude), `<repo>/.codex/config.toml` (Codex), `<repo>/opencode.jsonc` (OpenCode).

Prefer MCP-native tools over shell when both work.

## Skills

Available globally at `~/.agents/skills/<name>/SKILL.md`. Codex, OpenCode, and Pi read this directory natively; Claude reaches it via committed in-repo symlinks. Use `find-skills` to browse and load on demand.

- A skill with `paths:` frontmatter auto-loads when matching files are accessed.
- A skill without `paths:` is description-triggered (loaded when the model judges relevance, or invoked manually via `/<skill-name>` or `$<skill-name>`).
- The `agentic-coding-harnesses` skill documents this multi-harness setup; load it before modifying skills, rules, AGENTS.md, or harness wiring.

## Local rules and skills

Repos may ship their own. Always check on entering a new repo:

| Artifact | Location |
|---|---|
| Project instructions | `<repo>/AGENTS.md` (preferred); `<repo>/CLAUDE.md` typically `@AGENTS.md`-imports it for Claude Code |
| Cross-tool skills | `<repo>/.agents/skills/<name>/SKILL.md` |
| Claude path-conditional rules | `<repo>/.claude/rules/<name>.md` (`paths:` glob frontmatter) |
| Claude-specific skills | `<repo>/.claude/skills/<name>/` (typically a symlink into `.agents/skills/`) |
| OpenCode skills (alt path) | `<repo>/.opencode/skills/<name>/SKILL.md` |
| OpenCode plugins | `<repo>/.opencode/plugins/` |
| Codex per-project config | `<repo>/.codex/config.toml`, `<repo>/.codex/hooks.json` |
| Codex custom subagents | `<repo>/.codex/agents/<name>.toml` |
| MCP per-project | see "MCP servers" above |

Project-local rules override globals.

## Subagents

Each harness exposes its own subagent set. Reach for one only when work is genuinely parallelizable (multi-point reviews, fan-out across files), since subagents consume more tokens than a single-agent run.

| Harness | Read-only discovery | General execution / planning |
|---|---|---|
| Claude Code | `Explore` | `Plan` (architect), `general-purpose` |
| Codex CLI | `explorer` | `default`, `worker` |
| OpenCode | `@explore` | `@general` |
| Pi | via `pi-subagents` package | via `pi-subagents` package |

Custom subagents:

- Codex: `~/.codex/agents/<name>.toml` (global) or `<repo>/.codex/agents/<name>.toml`
- Claude: `~/.claude/agents/<name>.md` (global) or `<repo>/.claude/agents/<name>.md`

Before delegating: narrow scope, explicit success criteria, file shortlist. Never delegate vague work like "analyze the repo".

## UI work

For UI-affecting changes:

1. Identify affected views and acceptance criteria.
2. Check accessibility basics: labels, focus order, contrast, keyboard navigation, reduced motion.
3. Check responsive behavior at representative breakpoints.
4. Verify theme parity.
5. Capture screenshots when useful.
6. Inspect browser console output.

Use the `playwright-cli` skill for browser-based smoke checks and screenshots.

## Artifacts (OpenCode)

When OpenCode persists findings, write under `<project-root>/.opencode/`:

```
research/  reports/  test/  debug/  lint/  deps/  docs/  refactor/
```

`.opencode` is always project-relative, never an absolute root.

## Tool-specific notes

### Codex

- Run `ctx7` CLI requests outside Codex's default sandbox. If a `ctx7` command fails with DNS or network errors (`ENOTFOUND`, host resolution failures, fetch failed), rerun outside the sandbox.

<!-- context7 -->
## Library documentation via ctx7

Use the `ctx7` CLI to fetch current documentation whenever the user asks about a library, framework, SDK, API, CLI tool, or cloud service, even well-known ones like React, Next.js, Prisma, Express, Tailwind, Django, or Spring Boot. This includes API syntax, configuration, version migration, library-specific debugging, setup instructions, and CLI tool usage. Use even when you think you know the answer; your training data may not reflect recent changes. Prefer this over web search for library docs.

Do not use for: refactoring, writing scripts from scratch, debugging business logic, code review, or general programming concepts.

### Steps

1. Resolve library: `ctx7 library <name> "<user's question>"` (or `npx ctx7@latest library ...` if `ctx7` is not on PATH). Use the official library name with proper punctuation (e.g., "Next.js" not "nextjs", "Customer.io" not "customerio", "Three.js" not "threejs").
2. Pick the best match (ID format: `/org/project`) by exact name match, description relevance, code snippet count, source reputation (High/Medium preferred), and benchmark score (higher is better). If results don't look right, try alternate names or queries.
3. Fetch docs: `ctx7 docs <libraryId> "<user's question>"`.
4. Answer using the fetched documentation.

You MUST call `library` first to get a valid ID unless the user provides one directly in `/org/project` format. Use the user's full question as the query; specific and detailed queries return better results than vague single words. Do not run more than 3 commands per question. Do not include sensitive information (API keys, passwords, credentials) in queries.

For version-specific docs, use `/org/project/version` from the `library` output (e.g., `/vercel/next.js/v14.3.0`).

If a command fails with a quota error, inform the user and suggest `ctx7 login` or setting `CONTEXT7_API_KEY` env var for higher limits. Do not silently fall back to training data.
<!-- context7 -->
