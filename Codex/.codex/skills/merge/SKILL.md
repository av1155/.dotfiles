---
name: merge
description: Commit staged work, rebase the current branch, merge through workmux, and notify sibling worktrees. Use when the user asks to merge, land, finish, cleanly rebase and merge, or run the current branch's workmux merge flow.
---

<!-- Customize the commit style and rebase behavior to match your workflow. -->

Use any flags or context provided in the user's request as the merge arguments.

Check the arguments for flags:

- `--keep`, `-k` → pass `--keep` to `workmux merge` (keeps the worktree and tmux window after merging)
- `--no-verify`, `-n` → pass `--no-verify` to `workmux merge`

Strip all flags from arguments.

Commit, rebase, merge the current branch, and notify other active
worktrees that main has advanced.

This command finishes work on the current branch by:

1. Committing any staged changes
2. Rebasing onto the base branch
3. Capturing sibling worktrees for post-merge notification
4. Running `workmux merge` to merge and clean up
5. Notifying sibling worktrees to rebase

## Step 1: Commit

If there are staged changes, commit them. Use lowercase, imperative
mood, no conventional commit prefixes. Skip if nothing is staged.

## Step 2: Rebase

Get the base branch from git config:

```
git config --local --get "branch.$(git branch --show-current).workmux-base"
```

If no base branch is configured, default to "main".

Rebase onto the local base branch (do NOT fetch from origin first):

```
git rebase <base-branch>
```

IMPORTANT: Do NOT run `git fetch`. Do NOT rebase onto `origin/<branch>`.
Only rebase onto the local branch name (e.g., `git rebase main`, not
`git rebase origin/main`).

If conflicts occur:

- BEFORE resolving any conflict, understand what changes were made to
  each conflicting file in the base branch
- For each conflicting file, run `git log -p -n 3 <base-branch> -- <file>`
  to see recent changes to that file in the base branch
- The goal is to preserve BOTH the changes from the base branch AND our
  branch's changes
- After resolving each conflict, stage the file and continue with
  `git rebase --continue`
- If a conflict is too complex or unclear, ask for guidance before
  proceeding

## Step 2.5: Refresh dependencies if manifests changed

If the rebase touched any dependency manifest or lock file, the worktree's
installed dependencies may be stale and the merge's pre-verify hook will fail.
Detect and refresh.

```bash
git diff HEAD@{1} HEAD --name-only
```

If the output includes a manifest or lock file for this project's language/ecosystem,
run the appropriate install command for this project before proceeding.
If nothing relevant changed, skip.

## Step 3: Capture sibling worktrees

`workmux merge` closes the current tmux window and kills this skill's
shell process mid-execution. Sibling worktrees must be identified NOW,
before the merge runs, so the pre-merge advisory in Step 4 can be sent
before the merger window dies.

```bash
MERGED=$(git rev-parse --show-toplevel | xargs basename)
SIBLINGS=$(workmux status --json | jq -r --arg self "$MERGED" '
    [.[] | select(.worktree != $self)] | unique_by(.worktree) | .[].worktree
')
```

`$SIBLINGS` may be empty (no other worktrees active) — that's fine,
Step 5 handles both cases.

## Step 4: Send pre-merge advisory to siblings (if --keep NOT set)

If `--keep` is NOT in the arguments AND `$SIBLINGS` is non-empty,
send each sibling a self-describing advisory now, before `workmux
merge` runs. This must happen BEFORE Step 5 because the current
tmux window dies during merge.

The advisory identifies the merger by handle and asks the receiver
to verify whether the merge actually completed (by checking `wm
list`) before rebasing. This avoids hardcoding any wait time:

- if the merger handle is still in `wm list`, the merge has not
  finished yet and the receiver should defer the rebase
- if the merger handle is gone, the merge succeeded and the
  receiver can fetch and rebase onto whichever of local main or
  origin/main is ahead

```bash
if [ -n "$SIBLINGS" ]; then
    MSG="📌 Heads up from workmux worktree '$MERGED'. I'm about to merge my branch into main and don't know exactly when it will complete (pre-merge hooks, tests, etc may run first). Before you rebase: run \`wm list\` and check whether '$MERGED' is listed. If yes, the merge has not happened yet, so don't rebase, finish your current step and recheck later. If gone, the merge succeeded; run \`git fetch\` if you have an origin remote, then rebase onto whichever of local main or origin/main is ahead so you don't build on a stale base."
    echo "$SIBLINGS" | while IFS= read -r sibling; do
        [ -z "$sibling" ] && continue
        workmux send "$sibling" "$MSG"
    done
fi
```

AI: if ANY earlier step failed (commit, rebase, dependency refresh,
sibling capture), abort the flow BEFORE reaching this step. Do not
send the advisory at all. The advisory should only go out after
Steps 1 to 3 have succeeded and you are about to run the merge.

If `--keep` IS in the arguments, skip this step. Step 6 sends an
inline notification after the merge instead.

## Step 5: Run the merge

Run: `workmux merge --rebase --notification [--keep] [--no-verify]`

Include `--keep` only if the `--keep` flag was passed in arguments.
Include `--no-verify` only if the `--no-verify` flag was passed in
arguments.

This merges the branch into the base branch and cleans up the worktree
and tmux window (unless `--keep` is used).

## Step 6: Notify siblings inline (only if --keep IS set)

If `--keep` was in the arguments, the current window survives the
merge. The merger does not disappear from `wm list`, so siblings
cannot use the existence check from Step 4. Send a simpler
post-merge confirmation inline:

```bash
if [ -n "$SIBLINGS" ]; then
    MSG="📌 From workmux worktree '$MERGED'. I just merged my branch into main and kept this worktree open with --keep. Main has advanced. Finish your current step, then run \`git fetch\` if you have an origin remote and rebase onto whichever of local main or origin/main is ahead so you stay current."
    echo "$SIBLINGS" | while IFS= read -r sibling; do
        [ -z "$sibling" ] && continue
        workmux send "$sibling" "$MSG"
    done
fi
```

AI: if `workmux merge` in Step 5 failed (non-zero exit, or main did
not actually advance), do NOT run this block. Siblings should only be
notified when the merge truly succeeded.

If `--keep` was NOT set, skip this step. Step 4 already sent the
advisory.
