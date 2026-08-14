# Working tree safety for review and audit passes

Read this when a pass needs to write to the repository: a mutation test, a probe
file, a seeded row, or any experiment that is not a pure read. The operative
rules are in each skill's own body. This file carries the reasons, the recipes,
and the failure history.

## The situation

A review or audit subagent runs in the implementer's working directory. There
is one tree. Anything the pass writes, the implementer sees, and anything the
pass reverts, the implementer loses.

This is not hypothetical. On one wave of a real build:

- A reviewer tested a hypothesis by mutating a source file and undid it with
  `git checkout -- <file>`. That reverts the whole file to HEAD, not the one
  line the reviewer changed, and it took roughly twenty minutes of the
  implementer's uncommitted work with it. The reviewer then reported the tree
  as clean, truthfully, because by then it was.
- An auditor's mutation sweep was running while the implementer was editing.
  The implementer saw an unexplained diff in a file they had just written,
  which reads exactly like a defect somebody introduced.
- That same sweep detected the implementer's edits mid-run and killed its own
  harness to avoid corrupting them. Twelve planned mutations never ran, and the
  pass reported a bare count with no survivor list. The cost of a shared tree is
  not only lost work; it is lost measurement.

The lesson is not that passes should stop writing. Mutation testing was the
highest-yield technique of that entire wave: it proved that a hardcoded constant
was indistinguishable from a database read under the whole test suite, and that
a build with two regulation minimums swapped would ship with every check green.
Neither was reachable by reading. The lesson is that writes need a protocol.

## The baseline is the whole mechanism

Capture this before anything else, and report it at the end:

```bash
git rev-parse HEAD
git status --porcelain
```

The baseline defines three things at once:

1. **What is not yours.** Every path in that `status` output is someone else's
   uncommitted work. You may read it. You may not write it, revert it, stash it,
   or check it out.
2. **What "clean afterwards" means.** Not "empty", which would be wrong on a
   dirty baseline, but "identical to the baseline".
3. **Whether the tree is moving under you.** Re-run `git status --porcelain`
   before each write. If it differs from the baseline in a way you did not
   cause, another session is editing. Stop writing, finish read-only, and say so
   in the report.

## Restoring a file you mutated

Never with git. `git checkout`, `git restore` and `git stash` all operate on
whole files or the whole tree, and none of them can tell your probe from the
implementer's work in the same file.

Take a copy first and put it back in a `finally`, so an exception or a failed
test run cannot strand the mutation:

```python
import pathlib, subprocess
target = pathlib.Path("src/thing.ts")
original = target.read_text()          # the copy IS the undo
try:
    target.write_text(original.replace("a === b", "true"))
    result = subprocess.run(["pnpm", "test"], capture_output=True, text=True)
finally:
    target.write_text(original)        # unconditional
```

The same applies to the implementer. Reverting your own mutation with
`git checkout --` destroys your own uncommitted edits in that file just as
efficiently.

## When the baseline is dirty

Do not write to the tree at all. Two ways forward, in order of preference:

**Report the finding as unverified.** Say what you would have run and what it
would have proved. A finding marked unverified costs the reader five minutes. A
finding that cost them their uncommitted work costs a great deal more.

**Or take your own checkout.** This is the escape hatch that gives a pass full
freedom on a dirty tree:

```bash
WT="$(mktemp -d)/audit"
git worktree add --detach "$WT" HEAD
# work in "$WT" with total freedom; nothing here touches the implementer
git worktree remove --force "$WT"
```

The caveat is dependencies. A fresh worktree has no `node_modules`,
`target/`, `.venv` or equivalent, so anything that runs the test suite needs
them. Symlinking from the main checkout is usually faster than reinstalling,
though it is package-manager dependent and pnpm workspaces in particular hold
absolute paths that may not survive it:

```bash
ln -s "$(pwd)/node_modules" "$WT/node_modules"
```

If neither the symlink nor an install works, fall back to reporting the finding
unverified. That is a better outcome than a measurement taken in a broken
environment, which is a wrong answer wearing a right answer's clothes.

## Probes and seeds

A probe test file, a scratch config, a seeded database row and a temporary
fixture are all writes. Same rules: not on a dirty baseline, deleted before you
finish, and counted in the exit report. Prefer somewhere outside the repository
for anything that does not have to live inside it.

For a database, report the row count of every table you touched, not just
"cleaned up". Two passes on the wave above reported a clean tree while a probe
file or a live mutation was still present. The report is a claim like any other
and belongs in the same evidence discipline as the findings.

## The exit report

Close every pass that wrote anything with the actual output, not a summary of
it:

```
Working tree: HEAD <sha> unchanged; `git status --porcelain` matches the
baseline (<N> entries, all pre-existing). Probe files deleted: <list or none>.
Seeded rows removed: <table>=<count> or none.
```

Printing the command output is what makes the claim checkable. A pass that
asserts "tree is clean" and a pass that shows an empty `git status --porcelain`
are not the same evidence, and only one of them survives being wrong.
