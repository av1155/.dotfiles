# Workspace

## Main checkout

Start from a clean, synced default branch: `git status --porcelain` is empty and the
branch matches its remote. A change that starts on top of an unfinished one inherits its
diff into every review pass.

Create the branch under the tracker's branch name (for example Linear's "Copy git branch
name") so the tracker links and closes the issue on merge.

## Claude Code worktree

1. Fetch first: `git -C <repo> fetch origin`.
2. `EnterWorktree` with `name` set to the tracker branch name. It creates
   `.claude/worktrees/<name>` on a branch called `worktree-<name>`; rename it so the
   tracker links it: `git branch -m <tracker-branch-name>`.
3. Install dependencies in the worktree root with the repo's package manager.
4. Copy only what the profile lists as safe to copy (for example local stack version
   pins). Never copy files that link the worktree to hosted systems.
5. For files the agent may not copy, such as `.env.local`, hand the user the exact line
   with absolute paths and wait for it before any gate that needs it:
   `! cp <main checkout>/<path> <worktree>/<path>`
6. The main checkout is not yours while you work in a worktree: no `git checkout`,
   `git stash`, `git restore` or edits there. Stage files by explicit path, never
   `git add -A`, never `--amend`.
7. To leave mid-change, commit first and keep the worktree. Keep artifacts outside the
   repo.

## Shared local services

Never start or stop a shared local stack (a database or a container set that other
sessions use) from a worktree unless the profile says it is yours. Run anything that
writes to it under the profile's lock.
