# Ship and housekeeping

## Push

- Push once, after both review loops have an ending and every check that can run locally
  is green. A local failure is quick; a remote lap waits on shared runners.
- Push earlier only for a reason only the remote can serve, and say what it is.
- When other sessions are present, announce "pushing <branch>" first.

## CI

- If a job fails only on a known infrastructure cause (a runner lock wait, a gateway 5xx,
  a flake the profile names), rerun it once with `gh run rerun <run-id> --failed` before
  debugging.
- Do not push repeatedly to retrigger CI; each push cancels your own run.
- Read the full check roster before merging, and open check runs that look skipped or
  synthetic.

## Merge

- When the default branch requires branches to be up to date, merge the default branch
  into yours (never rebase and force-push without asking), rerun the checks the merge
  touched, and push.
- Before merging with other sessions present, announce "merging #N in two minutes" and
  confirm the merge state is clean (`gh pr view N --json mergeStateStatus`).
- Merge with the repo's method (squash unless the profile says otherwise), with an
  explicit subject and body. Leave branch deletion to housekeeping while a worktree
  holds the branch.
- If the permission classifier refuses the merge, hand the user the exact line prefixed
  with `!` and wait. Never route around it through the API or a subagent.
- Commands only the user may run after the merge (for example pushing a database
  migration to a hosted project) are handed over as a block; never run them.

## Housekeeping after the merge

1. Compare trees before removing anything: the merge commit's tree must equal the
   branch tip's (`git rev-parse <tip>^{tree}` against `git rev-parse <merge-sha>^{tree}`),
   unless the default branch moved between your last sync and the merge; then diff the
   squash against your tip.
2. Delete the remote branch if the repo does not: `git push origin --delete <branch>`.
3. Remove the worktree (`ExitWorktree` with `action: "remove"`, passing
   `discard_changes: true` once step 1 holds), delete the renamed local branch, then
   `git worktree prune` and `git fetch --prune`.
4. Sync the main checkout's default branch only if it is on that branch with an empty
   `git status --short`: `git pull --ff-only`. Otherwise leave it and say so.
5. Release any lock you hold. Stop your own servers and orphans by PID.
6. Confirm the tracker closed the issue by reading its state back.
7. With other sessions present, announce "merged #N" and the ports you freed.
