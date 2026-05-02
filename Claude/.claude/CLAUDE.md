# CLAUDE.md

Global defaults for Claude Code under this user account.
Repository-local `CLAUDE.md` or `AGENTS.md` always wins over this file.

## Instruction precedence

1. Direct user instruction in the current turn
2. Repository-local `CLAUDE.md` or `AGENTS.md`
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

- TypeScript-specific conventions live in `~/.claude/rules/typescript/SKILL.md` and load only when touching `.ts` or `.tsx` files.
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
Glob / Grep / Read    discovery
Read                  targeted ranges, not full files
Bash                  only when builtins are insufficient
Edit                  localized in-place changes
Write                 new files or full replacement only
WebFetch              known URLs (docs, specs)
WebSearch             only when no source is known
TodoWrite             non-trivial multi-step work
Skill                 when an existing SKILL.md fits
Agent                 multi-step research or work outside the main thread
```

## Boundaries

### Always do

- Discovery via `Glob`, `Grep`, `Read`
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
- Bypass a denied tool by routing through `Bash` or another path
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

Backend code must be production-scalable from the first version. Detailed rules live at `~/.claude/rules/scalability/SKILL.md` and auto-load when touching API, database, queue, cache, or migration files. Top-level non-negotiables: no N+1 queries, always paginate, queue blocking work, set timeouts on external calls, emit p50/p95/p99 latency metrics.

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
| `context7`   | Version-sensitive library or framework documentation              |
| `firecrawl`  | JS-rendered docs, structured extraction, multi-page scraping      |
| `github`     | Issues, PRs, repository metadata, code search                     |
| `playwright` | UI smoke checks, screenshots, accessibility, console inspection   |
| `semgrep`    | Security scanning and rule-based static analysis                  |
| `supabase`   | Database schema, migrations, RLS, query inspection                |
| `vercel`     | Deployments, logs, project status                                 |
| `magic`      | UI component generation via 21st.dev                              |
| `stitch`     | Design system generation via Google Stitch                        |

Prefer MCP-native tools over shell when both work. Prefer `context7` over memory for version-sensitive technical questions.

## Skills

Available globally across `~/.agents/skills/`, `~/.claude/skills/`, and (in Claude) plugin caches. Use `find-skills` to browse and load on demand.

Path-conditional rules at `~/.claude/rules/<name>/SKILL.md` auto-load when matching files are touched.

## Local rules and skills

Repos may ship their own. Always check on entering a new repo:

- `<repo>/CLAUDE.md` or `<repo>/.claude/CLAUDE.md`: project instructions, take precedence over this file
- `<repo>/.claude/rules/<name>/SKILL.md`: path-conditional rules with `paths:` glob frontmatter
- `<repo>/.claude/skills/<name>/SKILL.md`: project-specific skills
- `<repo>/.mcp.json`: project-specific MCP servers

Project-local rules override globals.

## Subagents

- `Explore`: read-only discovery. Use for file search, symbol lookup, call-path tracing.
- `Plan`: software architect, designs implementation plans.
- `general-purpose`: bounded execution for multi-step research or work outside the main thread.

Before delegating: narrow scope, explicit success criteria, file shortlist.
Never delegate vague work like "analyze the repo".

## Workmux

`workmux` (`wm`) manages parallel git worktrees with isolated tmux windows.
Reach for it when a risky refactor should not touch main, two approaches need comparison, or a multi-step task may need to be discarded.

Detailed command reference is in the `workmux` skill. Start there before scripting against `wm`.

Skip workmux for single-file tweaks or read-only tasks.

## Confidence marking

When useful:

- `verified`: directly supported by code, config, or test output
- `likely`: strongly supported but not fully confirmed
- `inferred`: reasoned from partial evidence
- `unknown`: not established from available evidence

Never present `inferred` conclusions as `verified`.
