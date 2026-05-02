# AGENTS.md

Global defaults for AI coding agents running in opencode under this user account.
Repository-local `AGENTS.md` always wins over this file.

## Instruction precedence

1. Direct user instruction in the current turn
2. Repository-local `AGENTS.md` or `CLAUDE.md`
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

- TypeScript-specific conventions live in the `typescript` skill (at `~/.agents/skills/typescript/`). Load it when touching `.ts` or `.tsx` files.
- General preference everywhere: smallest correct change, no over-decomposition, no premature abstraction.

## Operating principles

- Read first, scope first. Investigate before editing.
- Smallest correct change wins. Do not bundle unrelated concerns.
- Preserve existing behavior unless the task explicitly requires a change.
- State uncertainty honestly. Do not invent confidence.
- Verify with the smallest concrete check (test, build, code read) before claiming done.
- Do not bypass plugin, permission, or runtime safeguards.

## Tool order

Prefer the cheapest tool that does the job.

```
list / glob / grep        discovery
read                      targeted ranges, not full files
lsp                       diagnostics, symbol lookup
bash                      only when builtins are insufficient
edit / patch              localized in-place changes
write                     new files or full replacement only
webfetch                  known URLs (docs, specs)
websearch                 only when no source is known
todoread / todowrite      non-trivial multi-step work
skill                     when an existing SKILL.md fits
question                  only when ambiguity blocks safe progress
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
- Bypass a denied tool by routing through `bash` or another path
- Commit, print, or paste secrets
- Read `.env`, SSH keys, AWS credentials, or any plugin-blocked path
- Refactor untested code without writing characterization tests first
- Mix feature work with cleanup or formatting churn in the same commit

## Investigation discipline

1. Establish repository shape cheaply (manifests, workspace config, primary languages).
2. Targeted glob/grep for the affected area before opening files.
3. Range reads, not full-file reads.
4. Stop once enough evidence is gathered.
5. Reuse facts already collected; do not rediscover on follow-up tasks.

Anti-waste:

- No vague delegations like "analyze the repo".
- No pasting large excerpts.
- No re-reading without reason.

## Refactoring

- Apply Boy Scout cleanups in a separate `chore: cleanup` commit, never bundled with feature or bug work.
- Do not refactor untested code; write characterization tests first or skip the refactor.
- Do not over-decompose. Three similar lines beats a premature abstraction.
- Do not refactor outside task scope unless asked.

## Production scalability

Backend code must be production-scalable from the first version. Load the `scalability` skill (at `~/.agents/skills/scalability/`) when working on database queries, API endpoints, background jobs, caching, or any server-side code that runs under load. Top-level non-negotiables: no N+1 queries, always paginate, queue blocking work, set timeouts on external calls, emit p50/p95/p99 latency metrics.

## Git defaults

- Branch from the primary dev branch. Short, lowercase, hyphenated names.
- One focused branch per logical change.
- Conventional Commits: `<type>(<scope>)!: <description>`.
- Common types: feat, fix, docs, refactor, perf, test, build, ci, chore, revert.
- Prefer `gh` CLI over the web UI for issues, PRs, checks.
- Never push directly to protected branches. Never force-push without explicit authorization.

Example body:

```
fix(auth): invalidate stale session tokens on logout

Tokens were retained in Redis after logout because the destroy
hook ran asynchronously and could be skipped if the response
stream closed early. Move the destroy call before response flush.
```

## MCP servers

Global:

| Server       | When to reach for it                                              |
| ------------ | ----------------------------------------------------------------- |
| `context7`   | Version-sensitive library or framework documentation              |
| `firecrawl`  | JS-rendered docs, structured extraction, multi-page scraping      |
| `github`     | Issues, PRs, repository metadata, code search                     |
| `semgrep`    | Security scanning and rule-based static analysis                  |
| `magic`      | UI component generation via 21st.dev                              |
| `stitch`     | Design system generation via Google Stitch                        |

Project-scoped (only available in repos that declare them in `opencode.json`/`opencode.jsonc`): commonly `supabase`, `vercel`, plus repo-specific ones like `shadcn`, `stripe`, `cloudflare`, `sentry`, `grafana`.

Prefer MCP-native tools over shell when both work. Prefer `context7` over memory for version-sensitive technical questions.

## Skills

Use `find-skills` to browse and load skills on demand.

## Local rules and skills

Repos may ship their own. Always check on entering a new repo:

- `<repo>/AGENTS.md` (or `<repo>/CLAUDE.md` as fallback): project instructions, take precedence over this file
- `<repo>/.opencode/skills/<name>/SKILL.md`: project-specific skills
- `<repo>/.claude/skills/<name>/SKILL.md` and `<repo>/.agents/skills/<name>/SKILL.md`: also auto-loaded
- `<repo>/opencode.json` or `<repo>/opencode.jsonc`: per-project MCP servers, permissions, agents
- `<repo>/.opencode/plugins/`: project-specific JS/TS plugin hooks

Project-local rules override globals.

## Subagents

- `@general`: bounded execution, may modify when permitted. Use for multi-step research or work outside the main thread.
- `@explore`: read-only discovery. Use for file search, symbol lookup, call-path tracing, large-file triage.

Before delegating: narrow scope, explicit success criteria, file shortlist.
Never delegate vague work like "analyze the repo".

## Workmux

`workmux` (`wm`) manages parallel git worktrees with isolated tmux windows. Reach for it when a risky refactor should not touch main, two approaches need comparison, or a multi-step task may need to be discarded.

Detailed command reference lives in the `workmux` skill. Skip workmux for single-file tweaks or read-only tasks.

## Artifacts

When persisting findings, write under `<project-root>/.opencode/`:

```
research/  reports/  test/  debug/  lint/  deps/  docs/  refactor/
```

`.opencode` is always project-relative, never an absolute root.

## UI work

For UI-affecting changes:

1. Identify affected views and acceptance criteria.
2. Check accessibility basics: labels, focus order, contrast, keyboard, reduced motion.
3. Check responsive behavior at representative breakpoints.
4. Verify theme parity.
5. Capture screenshots when useful.
6. Inspect browser console output.

Use the `playwright-cli` skill for browser-based smoke checks and screenshots.

## Confidence marking

When useful:

- `verified`: directly supported by code, config, or test output
- `likely`: strongly supported but not fully confirmed
- `inferred`: reasoned from partial evidence
- `unknown`: not established from available evidence

Never present `inferred` conclusions as `verified`.
