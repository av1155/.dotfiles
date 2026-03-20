# CLAUDE.md

## Purpose

This file defines the default operating rules for agents in this environment.

It is a global baseline intended to keep behavior consistent across repositories and tasks. Do not rely on hidden provider-specific behavior. Rely on explicit instructions, repository evidence, and stated workflow.

If this file conflicts with a repository-local `AGENTS.md` or `CLAUDE.md`, follow the repository-local file for instructions, guidance, workflow, delegation, and behavioral policy.

---

## Instruction Precedence

Apply instructions in this order:

1. Direct user instruction
2. Repository-local `AGENTS.md` or `CLAUDE.md`
3. Additional repository or config-linked instruction files
4. This global `CLAUDE.md`
5. Other fallback compatible instruction files only when applicable

If repository-specific workflow rules are missing, say so briefly and proceed with the safest minimal behavior allowed.

---

## Core Operating Principles

- Default to read-first, scope-first execution.
- Never modify files unless the task, active mode, and repository policy allow it.
- Prefer the smallest correct change.
- Keep diffs minimal, reviewable, reproducible, and easy to validate.
- Prefer direct evidence over assumptions.
- Avoid redundant exploration, repeated reads, and unnecessary work.
- State uncertainty explicitly instead of inventing confidence.
- Do not attempt to bypass safeguards.
- Repository-local rules override this file when they conflict.

---

## Confidence Marking

When useful, label conclusions as:

- `verified` — directly supported by inspected code, config, or test results
- `likely` — strongly supported but not fully confirmed
- `inferred` — reasoned from partial evidence
- `unknown` — not established from available evidence

Do not present inferred conclusions as verified facts.

---

## Execution Modes

### Planning, review, and read-only work

- do not modify files
- do not perform incidental cleanup or speculative edits
- gather enough evidence to define scope before proposing implementation

### Build and implementation work

- investigate before editing
- define a narrow scope
- change only what is needed
- run the smallest relevant validation first
- follow repository workflow requirements when present
- stop broadening scope unless evidence requires it

---

## Investigation and Token Discipline

Optimize for correctness with minimal unnecessary work.

### Default investigation pattern

1. Establish repository shape cheaply
2. Identify likely source roots, tests, docs, config, workflows, and large files
3. Map relevant files, symbols, and call paths
4. Read only the most relevant ranges
5. Escalate to deeper inspection only when justified

### Required efficiency rules

- Do not start by reading many full files.
- Prefer cheap discovery before deep inspection.
- Prefer partial or line-range reads over full-file reads.
- Read full files only when they are small or clearly central.
- Reuse facts already gathered.
- Do not ask multiple agents to rediscover the same area.
- Stop exploring a branch once enough evidence has been gathered.
- Prefer exact file and function references over long narration.
- Quote only short snippets when necessary.
- Do not perform broad rediscovery on follow-up tasks unless scope changed.

### Anti-waste rules

- Do not give vague prompts like “analyze the repo”.
- Do not paste large code excerpts unless essential.
- Do not reread the same content without a reason.
- Do not use heavier approaches when a cheaper one is sufficient.

---

## Environment Summary

This environment may provide:

- built-in capabilities
- skills loaded through `SKILL.md`
- repository-defined instruction files
- isolated execution contexts or delegated agents

The primary agent is responsible for scope, synthesis, and cross-cutting decisions.

Do not assume every capability is enabled in every session. Use only what is actually available to the current agent.

---

## Skills

This environment may support reusable skills loaded via `SKILL.md`.

### Skill behavior

- Skills may exist in repository-local directories, user/global directories, or compatible shared locations.
- Skills are typically loaded on demand.
- Do not assume all skills are preloaded into context.
- Prefer using an existing skill when the task clearly matches it.

### Known globally available skills in this environment

The environment may include skills such as:

- `doc-coauthoring`
- `find-skills`
- `frontend-design`
- `webapp-testing`

Additional repository-local or user-local skills may also exist.

---

## Delegation and Parallel Work

This environment may support delegated agents or isolated execution contexts.

### Delegation policy

Use read-only checks first where appropriate.

When delegating:

1. identify the relevant area cheaply
2. define a narrow scope
3. provide explicit success criteria
4. provide a file or function shortlist when available

Do not delegate vague work like “analyze the repo”.

### Output expectations

Delegated outputs should be concise and actionable:

- exact file or function references
- short rationale
- confidence marking when useful
- minimal supporting snippets

### Routing hints

- Small scoped diff with tests: prefer direct implementation or narrow review
- Localized test failure: diagnose first, then apply the minimal fix
- Ambiguous or broad task: start with cheap discovery, then delegate narrowly
- Dependency risk or upgrade task: validate compatibility, then run the smallest relevant tests
- External library/framework/spec questions: use repository evidence first, then consult outside sources only if needed

---

## Git and GitHub Working Defaults

These are default working conventions, not universal repository truths. Repository-local rules override them.

### Core defaults

Unless the repository says otherwise:

1. define a tight scope before editing
2. identify or create the relevant issue when the repository uses issues
3. create a short-lived branch from the main development branch
4. implement only the scoped change
5. run the smallest relevant validation first, then required checks
6. commit with a clear conventional message
7. open or update a focused PR
8. merge only after required review and CI conditions are satisfied

### Additional defaults

- prefer one focused branch and PR per logical change
- prefer draft PRs early for non-trivial work
- do not merge with failing CI
- do not bypass branch protections or review requirements
- prefer templates and automation over ad hoc workflow

### GitHub CLI

When `gh` is available and appropriate:

- prefer `gh` for issues, PRs, checks, and repository metadata
- use `gh api` only when simpler commands are insufficient
- prefer reproducible commands over manual browser steps

### Commit messages

Use Conventional Commits when repository policy allows or requires them:

`<type>(<scope>)!: <description>`

Always follow the 50/72 rule for commit messages:

- limit the title to 50 characters
- wrap the body text at 72 characters

Common types:

- `feat`
- `fix`
- `docs`
- `refactor`
- `perf`
- `test`
- `build`
- `ci`
- `chore`
- `revert`

### Branching

Unless repository policy differs:

- base work on the primary development branch
- create short-lived scoped branches
- keep names short, specific, lowercase, and hyphenated
- avoid long-lived integration branches unless required

### Pull requests

- keep PRs focused
- include validation notes
- include screenshots for UI changes when useful
- link the relevant issue when the repository uses issues
- respect required reviews and required checks

### Protected branches

For protected branches such as `main`:

- do not push directly unless explicitly allowed
- do not force-push
- do not delete protected branches
- route changes through branches and PRs

---

## Change Delivery Discipline

- Investigate before editing.
- Do not mix unrelated concerns in one change set.
- Every behavior change should include the smallest appropriate validation.
- Add or update tests when warranted.
- Prefer regression tests for bug fixes.
- Avoid casual edits to release workflow, CI, versioning, schema, migrations, or shared fixtures unless required.
- If documentation and observed behavior conflict, follow the safer path and note the discrepancy.
- Surface genuine uncertainty instead of silently guessing.

---

## Project Navigation Guidance

When entering an unfamiliar repository:

1. identify the package manager, build system, and test entrypoints
2. locate the main application roots, config files, and documentation
3. identify the relevant module, service, route, or feature boundary
4. trace the smallest path from entrypoint to implementation
5. find existing tests covering the affected area
6. inspect adjacent patterns before introducing new structure

### Things to look for early

- root manifests such as `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `Gemfile`, `pom.xml`
- workspace definitions and monorepo config
- test config and test directories
- CI workflows
- environment and example config files
- migration or schema directories
- docs describing architecture, conventions, or contribution workflow

### Pattern-matching rules

- Prefer existing local conventions over generic best practices.
- Reuse nearby patterns for naming, structure, tests, and error handling.
- Do not introduce new abstractions unless repetition or evidence justifies them.
- Check whether the repository already has helper utilities before adding new ones.

---

## Final Behavior Summary

When acting in this environment:

- scope first
- read before editing
- use the smallest sufficient approach
- use todo-style planning for non-trivial multi-step work
- prefer minimal diffs
- validate the smallest relevant surface first
- state uncertainty honestly
- let repository-local rules override this file when present
