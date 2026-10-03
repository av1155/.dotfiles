---
name: build-loop
description: Claude Code only. Build and verify a code change to a fixed quality bar. Picks a risk tier, then implements, refines, runs the gates, drives the change for real, commits, and runs adversarial /review and /deep-audit rounds in fresh subagents until each loop reaches an ending. Use when implementing a feature, fix, wave or issue, when asked to follow or run the build loop, before opening a PR, or when the end-to-end skill hands over. Skip for questions, research and docs-only changes.
argument-hint: "[T0|T1|T2|T3]"
---

# Build loop

`bl` below means `~/.agents/skills/build-loop/scripts/bl`.

## After a compaction, interruption or reboot

1. `bl state` shows this branch's tier, plan path, rounds and loop endings.
2. Re-read the plan it names, this skill, and the repo profile.
3. Run `git status --porcelain` and `git stash list`, and confirm running subagents or
   workflows lost no work.
4. Resume at the stage `bl state` reports. Never restart a loop's counting.

## Tier

Start a new change with `bl state`. If it shows state from an earlier change on this
branch, which long-lived branches such as main keep, `bl reset` archives it; a change
you are resuming keeps its state. `bl tier` refuses a change whose loops have both
ended until you reset, or pass `--reopen` to retier that same change. Then pick the
tier before writing code and record it: `bl tier <T> --reason "<why>"`, which also
records the change's base commit. If you committed first, pass `--base` with the commit
the first hook warning names. Raise the tier the moment new risk appears, which reopens any
loop the lower tier's target or cap had closed; lower it only when the user says so. The
user's prompt or the repo profile can set it.

| Tier | When                                                                                                                                                                          | Loop                                                                                                    |
| ---- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| T0   | Docs, comments, config with no behavior change, generated or vendored refreshes                                                                                               | The gates for what changed, and a refine stamp for any code or config file. No rounds. Then `bl reset`. |
| T1   | A small single-concern fix, roughly under 150 changed code lines, touching no risk surface                                                                                    | Steps 2 to 13, `light` refine. Rounds until each loop has one clean pass, cap 2 per loop.               |
| T2   | A single-issue feature or fix touching no risk surface                                                                                                                        | Steps 1 to 13. Two clean passes per loop, cap 4.                                                        |
| T3   | Money, auth or sessions, PII or secrets, schema or migrations, data deletion, vendor contracts, security-sensitive code, several issues in one change, or the profile says so | Steps 1 to 13 with stop-and-ask surfaces. Two clean passes per loop, cap 8.                             |

Dependency or lockfile changes are never below T1, and need the user's yes first.

## Repo profile

Project specifics live in the repo: gate commands, stack and ports, shared services and
locks, stop-and-ask surfaces, vendor rules, issue tracker, push and merge authority. Look
for `docs/implementation-plans/build-loop.md`, `docs/build-loop.md`, or a build-loop
section in AGENTS.md. Where the profile and this skill differ, the profile wins, except
that a profile never drops a safety rule. With no profile, take the gates from AGENTS.md,
the package scripts or the Makefile, and ask before the first push. What a profile holds:
[profile.md](references/profile.md).

## Steps

Step numbers match the repo profiles, so a profile's "step 7" is this step 7.

1. Workspace: a clean, synced base, set up per the end-to-end skill, the prompt or the
   profile. Never stack on an unmerged branch unless the profile allows it.
2. Load only what the work needs; map wide changes with Explore subagents.
3. Verify every external API, library or vendor call against current docs (`find-docs`,
   the vendor's reference) and the pinned version before writing it.
4. Plan. Stop for sign-off on stop-and-ask surfaces: the profile's list plus the
   AGENTS.md ask-first boundaries. For decisions outside engineering, decide as a senior
   practitioner and ask through AskUserQuestion with the recommendation first.
5. Implement to senior standard, loading the matching skills (security, scalability,
   commenting, the language skill).
6. Designed UI: follow the profile's design-to-code rules.
7. Refine, then gates. Run the `refine` skill on the staged change (`full` before round
   1 at T2 and T3, `light` at T1), then the profile's gates on that tree. Gates must be
   green on the exact commit a round reviews, including a tidy commit refine adds.
8. Drive it for real: browser, CLI, API or sandbox lane, per the profile. Mocked unit
   tests alone are not evidence.
9. Commit, then run rounds. Commits stay local until step 12.
10. Rounds continue until both loops have an ending.
11. Disposition every item the plan or issue enumerates: done, deviated (recorded), or
    held (with the reason). A count in a plan is a checklist.
12. Ship under the authorization in the session prompt or the profile. Without one, stop
    at the commit and hand over the PR body or push command. Push once, after both loops
    have an ending and the local gates are green.
13. Ledger: record passes run, clean passes banked, each loop's ending token, findings
    above the threshold and the last pass's dispositions where the profile says,
    usually the progress file, before the push. Then `bl reset`, which refuses while a
    loop is still open.

## Rounds

A round, for T1 to T3:

1. Commit, with the gates green on that commit. Then run `bl context`: if it says
   `compact` before a round (60% of the window by default), stop and give the user a
   `/compact` note naming the round number, the commit under review and `bl state`, and
   resume from `bl state` afterwards.
2. In one message, launch a fresh `/review` subagent (Prompt 2) and a fresh `/deep-audit`
   subagent (Prompt 3) on the change's range, `<range>` as
   [prompts.md](references/prompts.md) defines it.
3. Change nothing in the repo while either runs.
4. Disposition both reports under Prompt 1: a `light` refine pass on the fix hunks, the
   gates, then commit.
5. Record it: `bl round --round <round> --review clean|dirty|done --audit clean|dirty|done`,
   with `done` for a loop that already has an ending. A round number that is not the
   next one is refused, so a retry never counts twice.
6. Start the next round until each loop has an ending.

The prompts are in [prompts.md](references/prompts.md). Counting, endings and the ledger
are in [rounds.md](references/rounds.md).

- Reviews and audits always run as fresh subagents with their skill loaded; check that
  it loaded. Never review your own work in the main context.
- A review pass is clean with zero unresolved CRITICAL, HIGH and MEDIUM; an audit pass
  with zero FAIL. LOW, NIT and WARN are dispositioned but never stop a pass counting
  as clean.
- Clean passes count cumulatively; a dirty pass resets nothing.
- The endings are: the tier's clean-pass target, the tier's cap (fix that pass's findings
  under the severity gate, record, continue to step 11), a converged documentation wave,
  the user ends it, or in progress when an early push left a loop open. Anything else is
  stopping early: ask, and keep going until answered.
- A CRITICAL, HIGH or MEDIUM that survives two fix cycles is structural. Change approach
  or record it as a trap. On a stop-and-ask surface, ask the user and do not merge until
  answered.
- Under ultracode or a workflow, a round replaces any other verification pass for the
  same change, and each round is one review agent plus one audit agent.

## Safety

Binding. Detail and the commands are in [safety.md](references/safety.md).

- The tree is shared. Commit before spawning, freeze the tree while a round runs, never
  `git checkout`, `git restore` or `git stash` to undo a probe (restore from a copy), and
  check `git status --porcelain` and `git stash list` after every pass.
- The machine is shared. The running app and shared local services have one owner per
  round, the auditor. Every probe gets its own port, never a default another session may
  hold. Nothing builds while a round runs. Stop what you start, and kill by PID, one at a
  time, never by pattern.
- Before a causal claim reaches a tracker, a comment, a progress file or a PR body, name
  the one command that would prove it wrong and run it where the user is. If you cannot,
  label it a hypothesis.

## State

`bl` keeps per-branch state under `$(git rev-parse --git-common-dir)/build-loop/`, which
survives reboots and is shared by worktrees: `bl tier` (the first one also records the
change's base commit), `bl plan` (`bl plan --path` prints where to write the plan),
`bl round`, `bl ending`, `bl state`, `bl context` (this session's context use, read
from its transcript), and `bl reset`,
which moves a finished change's state and plan to `build-loop/.archive/`. Git hooks warn
on an agent commit with no tier and on an agent push before both loops have an ending.
