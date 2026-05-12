# AGENTS.md

Global defaults for coding agents.

## Precedence

1. Current user instruction
2. Project `AGENTS.md` or `CLAUDE.md`
3. Other repo-local instruction files
4. This file

If a repo has no local guidance, say so briefly and proceed safely.

## Operating defaults

- Scope the task before acting.
- Make the smallest correct change.
- Preserve existing behavior unless the task explicitly requires a change.
- Reuse existing patterns, utilities, and conventions.
- Prefer targeted search and range reads over broad file reads.
- Stop exploring once there is enough evidence to act.
- Verify with the smallest relevant check before claiming done.
- Do not bypass permissions, sandboxing, hooks, denied tools, or runtime safeguards.

## Boundaries

Ask before:

- Dependency installs, upgrades, or lockfile changes
- Schema, migration, CI, release, deployment, or infrastructure edits
- New abstractions, helpers, frameworks, or broad refactors
- Changes outside the stated task scope
- `git push`, remote branch creation, PR merge, force-push, or branch deletion

Never:

- IMPORTANT: Expose, print, commit, or paste secrets
- Skip hooks or checks without explicit approval. If a hook or check blocks progress, surface it and ask.
- Route around a denied tool by using another tool or shell path. If access is blocked, stop and ask.
- Mix unrelated cleanup, formatting churn, and feature work in one change

## Style

- Do not use em dashes.
- Avoid the "Bold header: description" list pattern.
- Avoid "not X, but Y" phrasing.
- Use the number of bullets that fits the content.
- Prefer direct, concise wording.

## Git

- Keep changes focused.
- Use Conventional Commits.
- Ask before changing remote state.
- Do not push directly to protected branches unless explicitly authorized.

## Skills

Frequently relevant global skills:

- `security`: secrets, auth, input validation, crypto, dependencies, LLM safety
- `commenting`: comments, docstrings, file headers, migration notes
- `typescript`: TypeScript and Next.js conventions
- `python`: Python conventions
- `scalability`: database queries, API endpoints, queues, caches, migrations, backend performance
- `frontend-design-global`: distinctive, production-grade UI for components, pages, dashboards
- `playwright-cli`: browser automation, Playwright tests, debugging, screenshots
- `agentic-coding-harnesses`: skills, rules, AGENTS.md, plugins, MCP, harness wiring
- `skill-creator-global`: cross-harness skill creation

Before changing skills, rules, AGENTS.md, plugins, MCP, or harness wiring, load `agentic-coding-harnesses`.

When training data may be stale or wrong, fetch from the source:

- `ctx7` CLI and `find-docs` skill: library, framework, SDK, API, CLI, or cloud docs (Next.js, React, Prisma, AWS, etc.). Use even for well-known libraries.
- Web fetch: when the URL is already known (user-provided or from a prior search). Read release notes, changelogs, GitHub issues/PRs, RFCs, specific blog posts.
- Web search: when no URL is known. Find sources for unfamiliar error messages, current best practices, library maintenance or deprecation status, comparing approaches.

## Subagents

Use subagents only for bounded parallel exploration, review, or verification. Give them a narrow scope, explicit success criteria, a file shortlist, and the expected return format (summary, findings, file list — not raw content).
