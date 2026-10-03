---
name: refine
description: Claude Code only. Simplify and refine the staged code for clarity, consistency and maintainability without changing behavior, then stamp it so the commit gate lets it through. Use right before committing code, when a commit fails with "refine gate", or when asked to refine, simplify, de-slop or clean up changes about to be committed. Skip commits that only touch docs, lockfiles, generated or vendored files.
argument-hint: "[light|full]"
---

# Refine

Make the staged change as clear, consistent and small as it can be without changing
what it does. Work only on what is staged. A pass that changes nothing is a valid
result.

`refine` below means `~/.agents/skills/refine/scripts/refine`.

## Procedure

1. Scope: `refine scope`.
    - `mode: none`: run `refine stamp --mode none` and stop.
    - `in_progress` set (merge, rebase, cherry-pick, revert): stop; the gate skips those.
    - `partially_staged` not empty: stage or unstage those files completely first. Never
      stage a file the user did not mean to commit.
    - Depth is `mode` unless the caller passed `light` or `full`. The build-loop skill
      passes `full` before review round 1 at T2 and T3, and `light` at T1 and for
      review-fix commits.
2. Read the repo's rules before judging: AGENTS.md or CLAUDE.md, its commenting
   standard if one exists (for example `docs/commenting-standard.md`), its build-loop
   profile, and anything they mark as protected.
3. Snapshot: `refine snapshot`. It records HEAD and the staged blobs, and
   `refine restore` refuses once either has moved.
4. Review with `refine diff`, which writes the reviewable staged diff as shard files.
    - Claude Code: launch the lenses in one message with the Agent tool, one agent per
      lens per shard. `full`: four `refine-lens` agents (reuse, simplification,
      efficiency, altitude); use `refine-lens-deep` for altitude when `deep_altitude` is
      true. `light`: one `refine-lens` agent with lens `combined`. Give each the shard
      path, the lens, the repo root, the rule files from step 2, the rubric path
      `~/.agents/skills/refine/references/lenses.md` (expanded to an absolute path), and
      any pins: choices the session settled that must survive, such as a guard a reviewer
      asked for.
    - Without those agents (another harness, or a session that started before they
      existed), do one inline pass per shard with the combined rubric in
      [lenses.md](references/lenses.md), and say so in the summary.
    - A lens result without its final `END-OF-FINDINGS` line was cut off. Rerun that lens
      on smaller shards (`refine diff --shard-lines 300`); if it fails again, report the
      lens as incomplete.
5. Triage every finding. You are the only writer.
    - Apply: findings on the change's own lines in `code` files that keep behavior and
      respect the constraints in [lenses.md](references/lenses.md).
    - Defer to the tidy commit: findings on pre-existing lines of `code` files in this
      commit. Write them to `$(git rev-parse --git-path refine)/tidy.md`.
    - Report only: anything in `test`, `config` or `migration-existing` files, exported or
      public interface changes, cross-file moves, new files or dependencies, and anything
      the repo's rules protect.
    - Drop false positives and anything that would change behavior; list them briefly.
6. Verify: run the repo's fast checks for the touched files (typecheck, lint, and the
   tests that cover them, scoped variants first) and read the output. If any check
   fails, `refine restore` and keep the pre-pass content. Never edit a test or a check to
   make the pass green. If no check can run, keep only behavior-inert edits (comment
   removal, code proven unreferenced by search) and record the result as `unverified`.
7. Re-stage exactly the files you edited (`git add -- <paths>`), then stamp:
   `refine stamp --mode <light|full> --applied N --reported N --deferred N --result <pass|rolled-back|unverified> --checks "<commands run>"`
8. The caller commits. After that commit lands, if `tidy.md` lists anything:
   `refine snapshot <its files>` (paths from the repo root, as `tidy.md` lists them),
   apply it, run the same checks, stage those files,
   `refine stamp --mode light --tidy ...`, then commit them on their own as
   `refactor(<scope>): <what got simpler>`. If a check fails, `refine restore` and skip
   the tidy commit. Delete `tidy.md` afterwards.
9. Summarize in at most five lines: applied, deferred, reported and dropped counts; the
   checks run and their results; anything incomplete or unverified.

## Rules

- Behavior stays identical: outputs, errors, logging, side effects, ordering, public API.
- The feature commit holds only edits to its own lines. Pre-existing lines go to the
  tidy commit.
- Undo with `refine restore`, never `git checkout`, `git restore` or `git stash`.
- Never run while a review or audit round is in flight.
- Never bypass the gate with `--no-verify` or `REFINE_SKIP=1` unless the user says so in
  this session.

## The gate

A global git `pre-commit` hook (`hook.refine` in the user's git config) runs
`refine gate` whenever `AI_AGENT` or `CLAUDECODE` is set. For agent commits
(`AI_AGENT` matching `refine.agents`, default `claude-code`) it compares each staged
reviewable file with the last stamp and blocks the commit when any differs. Human
commits, merges in progress and exempt-only commits pass untouched. A file moved or
re-moded without line changes is exempt, and a moved file counts only its changed
lines.

Settings live in git config: `refine.mode` (`block`, `warn` or `off`; any other value
blocks), `refine.agents` (several values allowed), `refine.exempt` (extra globs,
multi-valued, for example generated paths), `refine.fullThreshold` (40 changed code
lines), `refine.deepThreshold` (300), `refine.shardLines` (800). Stamps, `REFINE_SKIP`
commits, merge skips, blocks, warnings and passes are logged to
`$(git rev-parse --git-path refine)/log.jsonl`; exempt-only commits and
`refine.mode = off` leave no entry.
