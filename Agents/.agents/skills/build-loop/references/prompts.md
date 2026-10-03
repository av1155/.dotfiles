# Round prompts

Prompt 1 goes to the implementer, the main session. Prompts 2 and 3 launch the two
subagents of a round. Prompt 3a replaces Prompt 3 in a round that runs alone because the
audit must mutate something.

Fill every `<placeholder>` from the repo profile before sending, including `<PORT>`, a
free port that is never a default another session may hold, and `<range>`, the change's
commits as `<base>..<the commit under review>` with the base from `bl state` (after a
rebase, the merge-base with the default branch). `<n>` is the pass number. A prompt sent
with a placeholder still in it has not been read.

## Prompt 1, fix (implementer)

```
Fix the findings from the review and the audit below.

Rules:
- CRITICAL and HIGH [verified]: fix these, no debate.
- CRITICAL and HIGH without [verified]: fix, or explain why the reviewer is
  wrong with specific evidence (file, line, docs link). "I think it's fine" is
  not evidence.
- MEDIUM: fix, or briefly note why you are skipping.
- LOW / NIT: fix only if trivial; skip the rest.
- FAIL: fix these, no debate.
- WARN: triage each one. Fix, or say why not.

Do NOT touch any files not mentioned in the findings.

Then run the refine skill (light) on the fix hunks, run the profile's gates, and
commit all changes with a descriptive Conventional Commit message. If anything
fails, fix it before committing.

--- Adversarial findings: <paste both reports from this round>
```

## Prompt 2, review (fresh reviewer subagent)

```
Run /review on the change's commits, <range> (`git log <range>`). Review pass <n>.
You are in a fresh context, isolated from
the implementer, so trust only the code and the diff, not any prior narrative.
The implementer committed fixes for the previous findings. Focus on:
1. Whether the previous CRITICAL/HIGH/MEDIUM findings are actually resolved.
2. Whether the fixes introduced new problems.
3. Anything you missed last pass.
Do not re-report findings that were fixed.
If you find nothing above LOW, say so plainly. A clean pass is a real
outcome; manufacturing a finding to look thorough is worse than reporting
none.

Working tree rules. Do not write into the repo: an auditor is reading the
same tree concurrently, and a write of yours reads to it as a defect.
Scratch files go in a directory of your own outside the repo, named for this
pass (for example review-<n> under your scratchpad); delete only what you
created there. Never run `git checkout`, `git restore`
or `git stash`. Before you finish, run `git status --porcelain` and
`git stash list` and report what they say.

Process rules. The auditor beside you owns the running app and the shared
local services this round. Start no dev server, run no browser tests, and
run no test that needs a shared service: <profile: which suites need them>.
Do not run the build or the full suites; the implementer ran them on this
commit before the round. Stop anything long-running you start, confirm it
stopped, and report any process you started and whether it is gone.
```

## Prompt 3, deep audit, read-only (fresh auditor subagent, the default)

```
Run /deep-audit --range <range>. Audit pass <n>. You are isolated from the
implementer. Hunt the classes /review under-weights: discarded
response data, cross-field validation gaps, happy-path bias, idempotency and
retry safety, and observable-behavior gaps on partial failure. Report
FAIL/WARN/PASS with file:line evidence. Do not manufacture concerns about
correct code. If you find no FAIL, say so plainly; a WARN you cannot
substantiate is noise.

This round is READ-ONLY on the tree, because a review pass is running beside
you. Do not modify any repo file. Where a mutation would settle a question,
describe the experiment and what it would show instead of running it.
Scratch files go in a directory of your own outside the repo, named for this
pass (for example audit-<n> under your scratchpad); delete only what you
created there. Never run `git checkout`, `git restore` or `git stash`. Before you finish, run `git status --porcelain` and
`git stash list` and report what they say.

You own the running app and the shared local services this round:
<profile: how to start them on port <PORT>, never a default port; which
vendor lanes never to touch; what data you may seed and how to remove it>.
Run individual specs, never whole suites: the round waits on whichever
subagent is slower.

Process rules. Do not run the build or the full suites; the implementer ran
them on this commit before the round. Stop every server, watcher or
long-running command you start, and confirm it stopped rather than assuming
it. A dev server may fork a child under another name, so kill by PID from
`lsof -iTCP:<PORT>` and check the port is free. Before you finish, report any
process you started and whether it is gone.
```

## Prompt 3a, deep audit with a mutation sweep (runs alone)

Prompt 3 verbatim, with the paragraph that begins "This round is READ-ONLY" replaced by:

```
You are the only subagent running against this tree, so you may mutate to
prove a point. Mutations are limited to the working tree: restore each one
from an in-memory copy in a `finally`, and delete every probe file. Never
run `git checkout`, `git restore` or `git stash`; they revert or hide whole
files and will destroy work the implementer has not committed. Before you
finish, run `git status --porcelain` and `git stash list` and report what
they say. Scratch files go in a directory of your own outside the repo,
named for this pass; delete only what you created there.
```

Use 3a only when the change's correctness genuinely turns on a mutation sweep, and record
in the ledger that the round ran alone.
