# Rounds, endings and the ledger

## Clean passes

- A review pass is clean when it returns zero unresolved CRITICAL, HIGH and MEDIUM, three
  of the four headings the `review` skill reports under. Findings under `LOW / NIT` never
  stop a pass from counting as clean, however many there are.
- An audit pass is clean when it returns zero FAIL. WARNs never stop a pass from counting
  as clean.
- Every finding is still dispositioned under Prompt 1: LOW and NIT fixed if trivial and
  skipped otherwise, each WARN triaged. The threshold exists so a pass that surfaces only
  cosmetics does not cost another full round.

## Documentation findings are fixed by deletion

A finding against prose is normally a wrong claim, and the instinct is to replace it with
a longer, more careful one. That makes a loop diverge: the replacement carries new
assertions and the next pass audits those.

- Prefer deleting the claim to narrowing it. A sentence that has been wrong twice is a
  sentence the document does not need.
- Do not explain why the old claim was wrong; the commit message is for that.
- Never quote a number you have not measured, and check the instrument as well as the
  document.
- A change is a documentation wave when its product is prose. That is decided at step 1
  and does not change mid-change. Findings against a code change's own progress entry or
  commit messages are ordinary findings and leave it a code change.
- On a documentation wave, the clean-pass ending is suspended: record the tier with
  `bl tier <T> --docs-wave`. Run the loops until they stop finding anything that is not
  about text the wave itself wrote, then end each with
  `bl ending --loop <loop> --token "documentation wave"` and record the count.

## Endings

This is the whole list of ways a loop ends. Caps are per loop: T1 2, T2 4, T3 8 passes.

| Ending                       | When                                                                                                      | Ledger token                  |
| ---------------------------- | --------------------------------------------------------------------------------------------------------- | ----------------------------- |
| Clean target banked          | T1: one clean pass. T2 and T3: two clean passes, counted cumulatively. Suspended on a documentation wave. | `one clean` / `two clean`     |
| Cap reached                  | Fix that pass's findings under the severity gate, record them, continue to step 11.                       | `cap of two`, `four`, `eight` |
| Documentation wave converged | Only when the change's product is prose.                                                                  | `documentation wave`          |
| The user ends it             | Said in that session. Nothing else authorises it.                                                         | `stopped early (authorised)`  |
| Still running                | An early push left a loop open when the ledger was written. Amend it when an ending lands.                | `in progress`                 |

If more than one could apply, record the first reached. An agent that stops without one
of these has broken the loop rather than ended it: the ledger then says
`stopped early (unauthorised)`, which is a defect to report, not an ending to pick.

These are observations, never exits: the findings are getting thin, the remaining
findings are only about prose on a code change, the code has clearly converged, the last
pass found nothing above MEDIUM, further passes are not worth the tokens. If they are
true, write them in the ledger and keep going to the cap, which is what bounds the spend.
A judgement that the loop has converged is the judgement an independent pass exists to
test, so it cannot also be the reason to stop running them. An agent that wants to stop
early asks, and keeps going until answered.

The cap bounds how long a loop runs, never whether the change finishes. The last pass's
findings are fixed under the severity gate and recorded, and the work goes on to step 11.

## Why two clean passes

A single clean pass is as likely to mean the reviewer missed the change as that the change
is finished, and the passes that find the most are often not the first. Cumulative
counting keeps that property while forgiving a dirty pass in between: the count reaches
two only when two separate reviewers each found nothing above the threshold. It gives up
part of it too: an earlier clean pass was clean on an earlier commit, so only the final
pass is known clean on the state that ships. An exhausted cap gives up more. The ledger is
where that is disclosed.

## Findings that will not die, and findings that keep coming

- The same CRITICAL, HIGH or MEDIUM surviving two fix cycles is a structural problem: an
  ambiguous spec, a wrong abstraction, or a reviewer and an implementer talking past each
  other. Fix it a different way, or record it as a trap with the evidence and carry on.
  On a stop-and-ask surface, put it to the user through AskUserQuestion with a
  recommendation, keep the loop running, and do not merge until answered. In an
  unattended change, hold it instead.
- A LOW or NIT you consciously skipped recurs every pass by design; that is not the
  signal.
- A loop that turns up a fresh CRITICAL, HIGH or MEDIUM each pass is working. Keep going
  to the cap.

## Running the two loops together

- Both loops run in every round from T1 up. `/review` reads the diff; `/deep-audit`
  checks the claims against the installed packages and a running system.
- They run concurrently, both against the same commit, so their findings are directly
  comparable and a disagreement between them shows up in the same round.
- The round counter is per change; the pass counters and caps are per loop. A loop that
  reaches its ending first stops while the other keeps running alone, and a resumed
  session keeps counting each from where it was. The ledger reports passes, not rounds.
- Fixes land at the end of every round, so a loop that exits early never saw later
  rounds' fixes. If the surviving loop's findings touch code the exited loop reviewed,
  reopen the exited loop for one more pass rather than reasoning about whether it would
  have cared: `bl ending --loop <loop> --token "in progress"`. It stays open until a pass
  closes it, on a clean pass or at the cap.
- Concurrency needs the audit to leave the tree alone, which is why Prompt 3 is
  read-only. When correctness genuinely turns on a mutation sweep, that audit round runs
  alone under Prompt 3a, and the ledger says so.

## The ledger

Written at step 13, before the push, where the profile says. One row per loop: passes run,
clean passes banked, the ending's token, and the findings above the threshold. Then what
the last pass had open and how each item was dispositioned, and whether any round ran
alone under Prompt 3a. A ledger that reports counts without the token reads as compliance
while hiding the one fact that decides whether it was.
