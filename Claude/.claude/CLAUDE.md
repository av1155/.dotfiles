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
- Do not introduce new layers, helpers, or abstractions when a simpler local change is sufficient.
- Keep diffs minimal, reviewable, reproducible, and easy to validate.
- Prefer direct evidence over assumptions.
- Avoid redundant exploration, repeated reads, and unnecessary work.
- State uncertainty explicitly instead of inventing confidence.
- Do not attempt to bypass safeguards.
- Repository-local rules override this file when they conflict.
- Break non-trivial tasks into smaller verifiable steps.
- Prefer simple, local solutions over new abstractions unless evidence justifies them.
- Preserve existing behavior unless the task explicitly requires behavioral change.
- Verify results with the smallest concrete check available; do not rely on reasoning alone when code, tests, or tooling can confirm.

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

## Parallel Sessions via workmux

`workmux` (`wm`) manages isolated git worktrees with integrated tmux
windows for parallel Claude Code and Codex work. Each worktree gets its
own tmux window with the agent in the left pane and a shell in the right
pane. Install via `wm update`. Run `wm docs` for full documentation.

Named agents configured in `.workmux.yaml`:

- `cc-yolo`: `claude --dangerously-skip-permissions`
- `cod-yolo`: `codex --yolo`

Installed agent skills (available inside agent panes):

- `/merge`: commit, rebase, and merge (respects `merge_strategy` from `.workmux.yaml`)
- `/rebase`: rebase onto main with smart conflict resolution
- `/open-pr`: push and open a PR with conversation-aware description
- `/worktree <task>`: delegate a task to a new parallel worktree agent
- `/worktree --fork <task>`: delegate with full conversation context (CC only)
- `/coordinator <tasks>`: orchestrate multiple agents with full lifecycle
- `/review`: adversarial review (run from a fresh Claude session only)

### Commands you can drive directly

These do not require interactive tmux access. Safe to run from inside a
Claude Code session or a script.

- `wm list` / `wm ls`: show all worktrees with agent status glyphs (working, waiting, done). Add `--pr` for GitHub PR status, `--json` for scripting.
- `wm status <n>`: query agent status for a specific worktree. Add `--git` for staged/unstaged/unmerged info. Supports `project:handle` syntax for cross-project queries.
- `wm capture <n>`: read terminal output from a running agent. Use `-n <lines>` to control how many lines (default 200).
- `wm send <n> "msg"`: type text into a running agent's terminal remotely. Also accepts `--file <path>` or stdin.
- `wm wait <n>`: block until an agent reaches a target status. Default target is `done`. Use `--timeout <seconds>` and `--any` for multi-agent waits.
- `wm run <n> -- <cmd>`: run a shell command inside a worktree's directory. Add `--background` to run without blocking.
- `wm merge <n>`: merge branch into main (using `merge_strategy` from config), then remove worktree, window, and branch. Add `--keep` to verify before cleanup. Add `--rebase` or `--squash` to override the strategy.
- `wm rm <n>`: remove worktree and window without merging. `--gone` cleans up worktrees whose remote PRs already merged. `--all` removes everything except main.
- `wm path <n>`: print the filesystem path of a worktree.
- `wm sync-files`: re-apply file copy/symlink operations to existing worktrees. Use `--all` for all worktrees.
- `wm claude prune`: remove stale entries from `~/.claude.json` for deleted worktrees.

### Commands that need the user (suggest, do not run)

These create or attach to interactive tmux windows. Suggest the exact
command and explain what to do inside the session.

- `wm add <n>`: creates a worktree and tmux window, launches Claude Code in the left pane. The user pastes prompts interactively.
- `wm add <n> -a codex`: same but launches Codex.
- `wm add <n> -a cc-yolo`: launches the named agent `cc-yolo`.
- `wm add <n> -p "prompt"`: injects a prompt into the agent on launch. Also accepts `-P <file>` to inject from a file.
- `wm add <n> -b -p "prompt"`: launches in background without switching windows. The agent starts working immediately.
- `wm add -A -p "prompt"`: auto-generates the branch name from the prompt using an LLM.
- `wm add <n> --fork`: forks the most recent Claude Code conversation into a new worktree (CC only). Use `--fork=<session-id>` for a specific session.
- `wm add <n> --with-changes -u`: moves uncommitted and untracked changes from the current worktree to the new one.
- `wm open <n>`: reopens a tmux window for an existing worktree. Add `-c` to resume the agent's most recent conversation.
- `wm dashboard`: opens a TUI dashboard for monitoring all active agents. Also available via `C-a + C-s` tmux binding.
- `wm sidebar`: live agent status sidebar in tmux. Toggle via `C-a + d`.
- `wm resurrect`: restores all worktree windows after a tmux or system crash.

### When to reach for it autonomously

Use `wm add -b -p "prompt"` or `wm send` to coordinate parallel work when:

- a risky refactor should not touch main yet
- two approaches need to be compared before committing to one
- the work is multi-step and might need to be thrown away
- a coordinator agent needs to spawn, monitor, and merge sub-agents

Skip it for single-file tweaks, pure read tasks, or when not inside a git repository.

### Key behaviors worth relying on

- `wm list --json` and `wm status --json` are stable and pipe-safe for scripting
- `wm merge` respects the `merge_strategy` setting in `.workmux.yaml` (squash, rebase, or merge)
- `wm wait` blocks cleanly and supports `--timeout`, making it reliable for coordinator workflows
- `wm send <n> "/rebase"` and `wm send <n> "/merge"` trigger the agent skills remotely
- `wm rm --gone` is the standard cleanup after PR-based merges on GitHub
- cross-project targeting uses `project:handle` syntax in `send`, `capture`, `status`, `wait`, and `run`
- lifecycle commands (`add`, `open`, `merge`, `remove`, `close`) are always scoped to the current repository

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
- ask before push, force-push, branch deletion, or other irreversible remote actions unless repository policy or direct user instruction clearly authorizes them

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

---

## Personal Conventions (Andrea Venti)

### Writing

Never use em dashes anywhere. Not in code, comments, docs, commits, PRs,
or any text. Use colons, semicolons, commas, periods, or parentheses.

Never use the "**Bold header:** description" list pattern. Use plain text
or simple bullets without bolded lead-ins.

Do not use "It's not X, it's Y" negative parallelism constructions.

Do not default to listing exactly three items. Use the number that fits.

Vary sentence length and structure. Monotonous rhythm reads as generated.

### Coding

TypeScript strict mode. Full type signatures on all functions.
Use `interface` over `type` for object shapes.
Use `unknown` and narrow, never `any` in production code.
Named exports only (except where the framework requires default exports).
No file over 300 lines. Split if it grows past that.
