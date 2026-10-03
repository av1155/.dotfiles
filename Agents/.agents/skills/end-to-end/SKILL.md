---
name: end-to-end
description: Take a planned work item end to end. Resolves the next wave or issue, sets up the workspace, plans and stops for /compact, implements through the build-loop skill, then ships, merges and cleans up within the session's authorization. Use when asked for the next wave, to work a progress file or a session section of a planning note, or to take a change end to end (PR, green checks, merge, housekeeping). Skip a bare "continue" or "proceed" with no work item, questions, and research.
---

# End to end

`bl` below means `~/.agents/skills/build-loop/scripts/bl`.

## After a compaction, interruption or reboot

1. `bl state` names the plan file and the stage.
2. Re-read the plan, this skill, the build-loop skill, the repo profile, and any planning
   note the session follows (its shared rules first).
3. Run `git status --porcelain` and `git stash list`, and confirm running subagents or
   workflows lost no work.
4. Resume at the recorded stage.

## 1. Resolve the work

- A progress file: take the first wave not marked done. A planning note: follow the
  named session section, after its shared rules. Otherwise the named issue or request.
- Read the issue with all its comments (a later comment overrides the description), the
  plan sections it names, the code it touches, and the context sources the profile or
  the prompt names. When sources disagree, the newest dated one wins.

## 2. Workspace

Main checkout or worktree, as the prompt or the repo profile says. For a worktree follow
[workspace.md](references/workspace.md). Hand the user every command you may not run
yourself as a `!` line with absolute paths, for example copying an env file.

## 3. Plan, then stop

Default for T3 work, and whenever the prompt asks.

1. Pick and record the tier with the build-loop skill.
2. Write the plan to the path `bl plan --path` prints (outside the repo, so it survives
   compaction and reboots), then `bl plan <path>`. It holds the scope and acceptance
   criteria, files, tier and why, stop-and-ask surfaces, tests, gates, the review-loop
   plan, the PR body draft and the housekeeping steps.
3. Tell the user the plan path and give a `/compact` note to paste that names the plan
   path, the tier and the stage. Then stop.
4. On "proceed": re-read the plan and run build-loop steps 5 to 13 end to end.

## 4. Build

Follow the build-loop skill at the plan's tier. Stop only on stop-and-ask surfaces, for
commands only the user may run, and where the plan says to hand over a command. Never
stop for a judgement that the work is good enough.

## 5. Ship

Authorization comes from the session prompt or the flow's progress-file header. "End to
end" there means: open the PR, get every check green (fixing failures), merge, and clean
up. Without authorization, stop at the commit and hand over the PR body or the push
command. The procedure is in [ship.md](references/ship.md).

## 6. Housekeeping

After the merge, follow the housekeeping steps in [ship.md](references/ship.md): compare
trees, delete the branch locally and remotely, remove the worktree, prune, sync the main
checkout only if it is clean, stop your own processes, release locks, and confirm the
tracker closed the issue.

## 7. Report

Say plainly whether the work is done. List what remains, what is still running, and every
command the user must run, as `!` lines with absolute paths.

## Other sessions

When other sessions share the machine or the repo, follow
[multi-session.md](references/multi-session.md): roster, announcements, ports, locks,
broadcasts, merge order and resync.

## Scope and judgement

- Changes the work item's acceptance criteria need are in scope; record deviations in the
  progress file. The AGENTS.md ask-first boundaries still apply: dependencies, schema,
  CI, infrastructure, hosted systems, settings.
- Decide as a senior engineer, product manager and designer would. Put genuine product
  decisions to the user through AskUserQuestion with the recommendation first. Do not
  hand back work you can do yourself.
