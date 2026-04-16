---
name: merge
description: Commit, rebase, and merge the current branch.
disable-model-invocation: true
allowed-tools: Read, Bash, Glob, Grep
---

<!-- Customize the commit style and rebase behavior to match your workflow. -->

**Arguments:** `$ARGUMENTS`

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
before the merge runs, so they can be notified to rebase onto the
updated main.

```bash
MERGED=$(git rev-parse --show-toplevel | xargs basename)
SIBLINGS=$(workmux status --json | jq -r --arg self "$MERGED" '
    [.[] | select(.worktree != $self)] | unique_by(.worktree) | .[].worktree
')
```

`$SIBLINGS` may be empty (no other worktrees active) — that's fine,
Step 5 handles both cases.

## Step 4: Schedule post-merge notification (if --keep NOT set)

If `--keep` is NOT in the arguments AND `$SIBLINGS` is non-empty,
schedule a detached background process to notify siblings after the
merge completes. This must run BEFORE `workmux merge` because the
current window dies during merge.

```bash
if [ -n "$SIBLINGS" ]; then
    SIBLINGS_FILE=$(mktemp)
    echo "$SIBLINGS" > "$SIBLINGS_FILE"
    nohup bash -c "
        sleep 8
        while IFS= read -r sibling; do
            [ -z \"\$sibling\" ] && continue
            workmux send \"\$sibling\" '📌 Main advanced — finish your current step, then run /rebase origin before continuing to avoid working on a stale base.'
        done < $SIBLINGS_FILE
        rm -f $SIBLINGS_FILE
    " > /dev/null 2>&1 &
    disown
fi
```

The notification fires 8 seconds after scheduling, giving `workmux
merge` time to complete. If the merge fails and main doesn't advance,
siblings receive a spurious rebase ping — harmless but worth noting.

If `--keep` IS in the arguments, skip this step. Inline notification
runs in Step 6 instead.

## Step 5: Run the merge

Run: `workmux merge --rebase --notification [--keep] [--no-verify]`

Include `--keep` only if the `--keep` flag was passed in arguments.
Include `--no-verify` only if the `--no-verify` flag was passed in
arguments.

This merges the branch into the base branch and cleans up the worktree
and tmux window (unless `--keep` is used).

## Step 6: Notify siblings inline (only if --keep IS set)

If `--keep` was in the arguments, the current window survives the
merge and notification runs inline here:

```bash
if [ -n "$SIBLINGS" ]; then
    echo "$SIBLINGS" | while IFS= read -r sibling; do
        [ -z "$sibling" ] && continue
        workmux send "$sibling" "📌 Main advanced — finish your current step, then run /rebase origin before continuing to avoid working on a stale base."
    done
fi
```

If `--keep` was NOT set, skip this step — Step 4 already scheduled the
notification.
