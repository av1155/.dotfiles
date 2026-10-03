# The tree and the machine are shared

## The tree is shared

A subagent runs in your working directory. There is one tree, and a pass that writes to
it writes to yours.

- The tree is frozen while a pass runs: commit, spawn, wait, then edit. While a round is
  in flight, the only safe edits are to files outside the repo, and that holds until
  both subagents have reported.
- Never `git checkout` or `git restore` to undo a probe, and say so in every prompt. They
  revert the whole file rather than the edit, so any uncommitted work in it goes too.
  Restore from a copy taken before the write. This binds the implementer as well.
- Forbid `git stash` in every prompt. A pass that stashes to get a clean tree and never
  restores it makes earlier edits appear silently reverted; `git status` shows nothing
  because the stash is the clean state. Check `git stash list` after every fan-out, and
  before dropping a stray stash, diff its files against the current ones.
- Do not run a review pass and a mutation sweep concurrently. An audit that detects
  concurrent edits mid-sweep kills its own harness and returns a bare count.
- Verify the tree yourself after every pass: `git status --porcelain`, `git stash list`
  and a search for probe files. A pass's report of a clean tree is a claim like any other.

None of this argues against letting a pass write: a mutation sweep is often the highest
yield of a change. The point is to bound the writes, which is what Prompt 3a is for.

## The machine is shared

A pass leaves things in the process table as well as in the tree. Check after every
fan-out.

```bash
ps -Ao pid,ppid,%cpu,etime,command | awk '$2==1'   # orphans: parent died, still running
lsof -nP -iTCP -sTCP:LISTEN                          # servers a probe started and left
```

- Identify before killing. Other sessions run their own servers and suites, so a hit is
  not by itself stale. Read the full command line and the elapsed time and confirm the
  PID belongs to this work.
- Kill by PID, one at a time, never by pattern. A batch `kill $PIDS` built from `ps` or
  `awk` output can silently do nothing because the list is newline-separated; loop
  instead: `for pid in $PIDS; do kill "$pid"; done`.
- Some dev servers fork a child under another name (Next.js renames its child
  `next-server`), so killing the launch command orphans the child, which keeps the port.
  Kill by PID from `lsof -iTCP:<port>` and check the port is free afterwards.
- Every probe gets its own port, passed explicitly. A test runner told to reuse an
  existing server attaches to whatever already listens on the default port, which may be
  another session's tree and environment.
- The running app and shared local services (databases, local stacks, mock servers) have
  one owner per round, the auditor. Two probes on a shared database collide on rows and
  on setup and teardown files.
- Nothing builds while a round runs. A build rewrites output a running server is serving,
  and specs the change never touched start failing. The implementer runs the gates before
  spawning.

## Skills must actually load

A subagent told to run `/review` or `/deep-audit` whose Skill call is rejected (for
example because the skill disables model invocation) quietly works from its prompt
instead. If a pass comes back suspiciously thin, check that the skill loaded.

## A green check is worth reading twice

Required checks can be green on a pull request where some never ran: skipped jobs count
as success under branch protection, path filters skip workflows, and skip shims report
synthetic passes under the real check's name. Open the check run rather than trusting the
roster, and keep the repo's known cases in its profile.
