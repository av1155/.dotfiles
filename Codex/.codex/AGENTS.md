# AGENTS.md

Global defaults for Codex CLI under this user account.
Repository-local `AGENTS.md` always wins over this file.

## Instruction precedence

1. Direct user instruction in the current turn
2. Repository-local `AGENTS.md`
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

- TypeScript / Next.js conventions live in the `typescript` skill (at `~/.agents/skills/typescript/`). Load when touching `.ts` or `.tsx` files.
- Python conventions live in the `python` skill (at `~/.agents/skills/python/`). Load when touching `.py` files.
- Backend code follows the `scalability` skill (at `~/.agents/skills/scalability/`). Load when working on database queries, API endpoints, queues, caches, or server-side code under load.
- Comment authority is the `commenting` skill. Load when writing or reviewing substantial comments. Project `docs/commenting-standard.md` overrides it when present.
- Security-relevant code (auth, secrets, user input, external calls, LLM prompts) follows the `security` skill. Load when working in those areas.
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
- Do not bypass approval policies, sandbox modes, or trust boundaries.

## Tool order

Prefer the cheapest tool that does the job.

```
list / glob / grep        discovery
read                      targeted ranges, not full files
shell                     only when builtins are insufficient
edit / patch              localized in-place changes
write                     new files or full replacement only
webfetch                  known URLs (docs, specs)
websearch                 only when no source is known
skill                     when an existing SKILL.md fits
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
- Bypass a denied tool by routing through `shell` or another path
- Commit, print, or paste secrets
- Mix feature work with cleanup or formatting churn in the same commit

## Production scalability

Backend code must be production-scalable from the first version. Load the `scalability` skill (at `~/.agents/skills/scalability/`) when working on database queries, API endpoints, background jobs, caching, or any server-side code that runs under load. Top-level non-negotiables: no N+1 queries, always paginate, queue blocking work, set timeouts on external calls, emit p50/p95/p99 latency metrics.

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

| Server       | When to reach for it                                              |
| ------------ | ----------------------------------------------------------------- |
| `magic`      | UI component generation via 21st.dev                              |
| `stitch`     | Design system generation via Google Stitch                        |

Prefer MCP-native tools over shell when both work. For version-sensitive library docs use the `ctx7` CLI (embedded steps below) rather than memory.

## Skills

Use `find-skills` to browse and load skills on demand.

## Local rules and skills

Repos may ship their own. Always check on entering a new repo:

- `<repo>/AGENTS.md`: project instructions, take precedence over this file
- Subdirectory `<repo>/<subdir>/AGENTS.md`: concatenates from root down to cwd
- `<repo>/.codex/skills/<name>/SKILL.md`: project-specific skills
- `<repo>/.codex/agents/<name>.toml`: project-scoped custom subagents
- `<repo>/.codex/config.toml`: per-project MCP servers, hooks, and trust overrides
- `<repo>/.codex/hooks.json`: project-specific hook handlers

Project-local rules override globals.

## Subagents

Codex spawns subagents only when explicitly asked. They consume more tokens than single-agent runs; reach for them only when work is genuinely parallelizable (multi-point reviews, fan-out across files).

Built-in:

- `default`: general-purpose fallback
- `worker`: execution-focused implementation and fixes
- `explorer`: read-only codebase exploration

Custom subagents at `~/.codex/agents/<name>.toml` (global) or `<repo>/.codex/agents/<name>.toml`.

Before spawning: narrow scope, explicit success criteria, file shortlist. Never delegate vague work like "analyze the repo".



<!-- context7 -->
Use the `ctx7` CLI to fetch current documentation whenever the user asks about a library, framework, SDK, API, CLI tool, or cloud service -- even well-known ones like React, Next.js, Prisma, Express, Tailwind, Django, or Spring Boot. This includes API syntax, configuration, version migration, library-specific debugging, setup instructions, and CLI tool usage. Use even when you think you know the answer -- your training data may not reflect recent changes. Prefer this over web search for library docs.

Do not use for: refactoring, writing scripts from scratch, debugging business logic, code review, or general programming concepts.

## Steps

1. Resolve library: `ctx7 library <name> "<user's question>"` (or `npx ctx7@latest library ...` if `ctx7` is not on PATH): use the official library name with proper punctuation (e.g., "Next.js" not "nextjs", "Customer.io" not "customerio", "Three.js" not "threejs")
2. Pick the best match (ID format: `/org/project`) by: exact name match, description relevance, code snippet count, source reputation (High/Medium preferred), and benchmark score (higher is better). If results don't look right, try alternate names or queries (e.g., "next.js" not "nextjs", or rephrase the question)
3. Fetch docs: `ctx7 docs <libraryId> "<user's question>"`
4. Answer using the fetched documentation

You MUST call `library` first to get a valid ID unless the user provides one directly in `/org/project` format. Use the user's full question as the query -- specific and detailed queries return better results than vague single words. Do not run more than 3 commands per question. Do not include sensitive information (API keys, passwords, credentials) in queries.

For version-specific docs, use `/org/project/version` from the `library` output (e.g., `/vercel/next.js/v14.3.0`).

If a command fails with a quota error, inform the user and suggest `ctx7 login` or setting `CONTEXT7_API_KEY` env var for higher limits. Do not silently fall back to training data.
Run `ctx7` CLI requests outside Codex's default sandbox. If a `ctx7` command fails with DNS or network errors such as ENOTFOUND, host resolution failures, or fetch failed, rerun it outside the sandbox instead of retrying inside the sandbox.
<!-- context7 -->
