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

- TypeScript / Next.js conventions live in the `typescript` rule (at `~/.claude/rules/typescript.md`); auto-loads on `.ts` / `.tsx` edits via `paths:` frontmatter.
- Python conventions live in the `python` rule (at `~/.claude/rules/python.md`); auto-loads on `.py` edits.
- Backend code follows the `scalability` rule (at `~/.claude/rules/scalability.md`); auto-loads on API / db / queue / cache files.
- Comment authority is the `commenting` skill; load when writing or reviewing substantial comments. Project `docs/commenting-standard.md` overrides it when present.
- Security-relevant code (auth, secrets, user input, external calls, LLM prompts) follows the `security` skill; load when working in those areas.
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
- Mix feature work with cleanup or formatting churn in the same commit

## Production scalability

Backend code must be production-scalable from the first version. Detailed rules live at `~/.claude/rules/scalability.md` and auto-load when touching API, database, queue, cache, or migration files. Top-level non-negotiables: no N+1 queries, always paginate, queue blocking work, set timeouts on external calls, emit p50/p95/p99 latency metrics.

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

Prefer MCP-native tools over shell when both work. For version-sensitive library docs use the `ctx7` CLI (see `~/.claude/rules/context7.md`) rather than memory.

## Skills

Available globally across `~/.agents/skills/`, `~/.claude/skills/`, and (in Claude) plugin caches. Use `find-skills` to browse and load on demand.

Path-conditional rules at `~/.claude/rules/<name>.md` auto-load when matching files are touched (via `paths:` YAML frontmatter).

## Local rules and skills

Repos may ship their own. Always check on entering a new repo:

- `<repo>/CLAUDE.md` or `<repo>/.claude/CLAUDE.md`: project instructions, take precedence over this file
- `<repo>/.claude/rules/<name>.md`: path-conditional rules with `paths:` glob frontmatter
- `<repo>/.claude/skills/<name>/SKILL.md`: project-specific skills
- `<repo>/.mcp.json`: project-specific MCP servers

Project-local rules override globals.

## Subagents

- `Explore`: read-only discovery. Use for file search, symbol lookup, call-path tracing.
- `Plan`: software architect, designs implementation plans.
- `general-purpose`: bounded execution for multi-step research or work outside the main thread.

Before delegating: narrow scope, explicit success criteria, file shortlist.
Never delegate vague work like "analyze the repo".


