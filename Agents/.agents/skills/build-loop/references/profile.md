# Repo profiles

A profile holds everything about one repository that the generic loop cannot know. The
skill looks for it at `docs/implementation-plans/build-loop.md`, then `docs/build-loop.md`,
then a build-loop section in AGENTS.md.

A profile may change resources and commands: ports, who owns a shared service, gate
commands, stop-and-ask surfaces. It may add rules and raise tiers. It never drops a safety
rule from the skill.

## What it contains

Keep the skill's step numbers as headings so citations from plans keep working.

- A scope line at the top: this file applies to this repository only.
- Tier defaults: which work is always T3 (for example every flow wave, or anything under
  a money or compliance path).
- Step 1, workspace: main checkout or worktree, branch naming (tracker branch names),
  the env files a worktree needs (the agent copies them with the security skill's
  `envfile`), whether stacked PRs work with the repo's CI.
- Step 3: vendor documentation rules (which reference to fetch first, which mirrors are
  unreliable).
- Step 4: the stop-and-ask surfaces.
- Step 5: the skills and conventions to load, and the comment depth the repo mandates.
- Step 6: design-to-code rules, viewports, accessibility checks.
- Step 7: the gate commands, fastest first, the extra lanes for migrations or other
  areas, formatter scope, and any `refine.exempt` paths (set them with
  `git config --add refine.exempt '<glob>'` in the repo).
- Step 8: how to drive the change: tools, ports, mock modes, env.
- Rounds: the process rules Prompts 2 and 3 need, meaning which suites need shared
  services, who owns them, how the auditor gets a port, which vendor lanes are off
  limits.
- Step 12: push and merge authority, CI behavior (shared runners, known flakes and the
  rerun rule), post-merge commands only the user may run.
- Step 13: where the ledger lives.
- What a green check does not prove in this repo.
