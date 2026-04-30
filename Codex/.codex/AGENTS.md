# AGENTS.md

## Purpose

This file defines the default operating rules for Codex in this environment.

It is a global baseline intended to keep behavior consistent across repositories
and tasks. Do not rely on hidden provider-specific behavior. Rely on explicit
instructions, repository evidence, available tools, and stated workflow.

If this file conflicts with a repository-local `AGENTS.md`, follow the
repository-local file for instructions, guidance, workflow, delegation, and
behavioral policy.

---

## Instruction Precedence

Apply instructions in this order:

1. Direct user instruction
2. Repository-local `AGENTS.md`
3. Additional repository or config-linked instruction files
4. This global `AGENTS.md`
5. Other fallback compatible instruction files only when applicable

If repository-specific workflow rules are missing, say so briefly and proceed
with the safest minimal behavior allowed.

---

## Core Operating Principles

- Default to read-first, scope-first execution.
- Never modify files unless the task, active mode, permissions, and repository
  policy allow it.
- Prefer the smallest correct change.
- Do not introduce new layers, helpers, or abstractions when a simpler local
  change is sufficient.
- Keep diffs minimal, reviewable, reproducible, and easy to validate.
- Prefer direct evidence over assumptions.
- Avoid redundant exploration, repeated reads, and unnecessary work.
- State uncertainty explicitly instead of inventing confidence.
- Do not attempt to bypass safeguards.
- Repository-local rules override this file when they conflict.
- Break non-trivial tasks into smaller verifiable steps.
- Preserve existing behavior unless the task explicitly requires behavioral
  change.
- Verify results with the smallest concrete check available; do not rely on
  reasoning alone when code, tests, or tooling can confirm.

---

## Confidence Marking

When useful, label conclusions as:

- `verified` - directly supported by inspected code, config, or test results
- `likely` - strongly supported but not fully confirmed
- `inferred` - reasoned from partial evidence
- `unknown` - not established from available evidence

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
- opportunistic cleanup is allowed only when it is directly tied to the task

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

- Do not give vague prompts like "analyze the repo".
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
- MCP servers configured through Codex `config.toml`
- plugins and apps exposed by the active Codex runtime

The primary agent is responsible for scope, synthesis, and cross-cutting
decisions.

Do not assume every capability is enabled in every session. Use only what is
actually available to the current agent.

---

## Skills

This environment supports reusable skills loaded via `SKILL.md`.

### Skill behavior

- Skills may exist in repository-local directories, user/global directories, or
  compatible shared locations.
- Skills are typically loaded on demand.
- Do not assume all skills are preloaded into context.
- Prefer using an existing skill when the task clearly matches it.

### Known globally available skills in this environment

The environment may include skills such as:

- `catchup`
- `coordinator`
- `deep-audit`
- `fix-issue`
- `merge`
- `open-pr`
- `rebase`
- `review`
- `ship`
- `workmux`
- `worktree`
- `doc-coauthoring`
- `find-skills`
- `frontend-design`
- `webapp-testing`

Additional repository-local, user-local, system, plugin, or connector skills may
also exist.

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

Do not delegate vague work like "analyze the repo".

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
- Dependency risk or upgrade task: validate compatibility, then run the
  smallest relevant tests
- External library/framework/spec questions: use repository evidence first, then
  consult outside sources only if needed

---

## Parallel Sessions via workmux

`workmux` (`wm`) manages isolated git worktrees with integrated tmux windows for
parallel Codex, Claude Code, and other agent work. Each worktree gets its own
tmux window with the agent in the left pane and a shell in the right pane.
Install via `wm update`. Run `wm docs` for full documentation.

Named agents configured in `.workmux.yaml` may include:

- `cc-yolo`: `claude --dangerously-skip-permissions`
- `cod-yolo`: `codex --yolo`

Installed agent skills may include:

- `merge`: commit, rebase, and merge
- `rebase`: rebase onto main with smart conflict resolution
- `open-pr`: push and open a PR
- `worktree`: delegate a task to a new parallel worktree agent
- `coordinator`: orchestrate multiple agents with full lifecycle
- `review`: adversarial review

### Commands you can drive directly

These do not require interactive tmux access. Safe to run from inside a Codex
session or a script when permissions allow it.

- `wm list` / `wm ls`: show all worktrees with agent status glyphs.
- `wm status <n>`: query agent status for a specific worktree.
- `wm capture <n>`: read terminal output from a running agent.
- `wm send <n> "msg"`: type text into a running agent's terminal remotely.
- `wm wait <n>`: block until an agent reaches a target status.
- `wm run <n> -- <cmd>`: run a shell command inside a worktree's directory.
- `wm merge <n>`: merge branch into main, then remove worktree, window, and
  branch.
- `wm rm <n>`: remove worktree and window without merging.
- `wm path <n>`: print the filesystem path of a worktree.
- `wm sync-files`: re-apply file copy/symlink operations to existing worktrees.

### Commands that need the user

These create or attach to interactive tmux windows. Suggest the exact command
and explain what to do inside the session.

- `wm add <n>`: creates a worktree and tmux window.
- `wm add <n> -a codex`: same but launches Codex.
- `wm add <n> -a cod-yolo`: launches the named Codex agent.
- `wm add <n> -p "prompt"`: injects a prompt into the agent on launch.
- `wm add <n> -b -p "prompt"`: launches in background.
- `wm add <n> --with-changes -u`: moves uncommitted and untracked changes to a
  new worktree.
- `wm open <n>`: reopens a tmux window for an existing worktree.
- `wm dashboard`: opens a TUI dashboard for monitoring active agents.
- `wm sidebar`: live agent status sidebar in tmux.
- `wm resurrect`: restores worktree windows after a tmux or system crash.

### When to reach for it autonomously

Use `wm add -b -p "prompt"` or `wm send` to coordinate parallel work when:

- a risky refactor should not touch main yet
- two approaches need to be compared before committing to one
- the work is multi-step and might need to be thrown away
- a coordinator agent needs to spawn, monitor, and merge sub-agents

Skip it for single-file tweaks, pure read tasks, or when not inside a git
repository.

### TODO: Codex workmux integration

Do not assume the Codex/workmux integration is fully equivalent to the
Claude/workmux integration yet. Before expanding automation, research and verify:

- exact Codex hook events for permission/waiting states
- whether `wm add <n> -a codex` needs prompt or startup adjustments
- whether Codex resume/fork behavior can map to workmux workflows
- which Codex skill invocations are reliable inside tmux panes
