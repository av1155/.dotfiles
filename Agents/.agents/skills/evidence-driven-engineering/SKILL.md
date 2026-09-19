---
name: evidence-driven-engineering
description: Governs what you are allowed to claim and how confident you may sound. Use when wording a finding, a root cause, a risk, or a completion claim. Triggers on is this done, write up what you did, summarize the changes, what is the root cause, can you ship this, are you sure, did you actually run that, how do you know, prove it. Companion to diagnose, review and deep-audit: they do the work, this governs what you say about it. Skip for local reversible edits already covered by the AGENTS.md smallest-relevant-check rule.
---

# Evidence-Driven Engineering

## Label every material claim

- Verified fact: you ran it, read it, or observed it this session.
- Strongly supported conclusion: independent signals agree, direct observation missing.
- Working hypothesis: fits the evidence, untested, makes a stated prediction.
- Assumption: taken on faith to keep moving.
- Unknown: not established and not guessed at.

Never silently convert an assumption into a fact. A claim that was an assumption when
you formed it is still an assumption when you report it, unless something verified it
in between. State the confidence in the sentence that carries the claim. No hedging
opener. One label per claim that decides something, and none on the rest.

## Scale verification to blast radius

- Local and reversible work needs only the smallest relevant check, per the AGENTS.md
  operating defaults: a one-line fix, a scratch script, a doc edit.
- Hard-to-reverse or widely depended on work needs two independent signals before you
  act, and you name them: a public contract, a shared utility, auth, money, anything
  with callers you have not read.
- Irreversible or production-touching work needs explicit authorization before you run
  it, and one signal is never enough: deleting data, destructive migrations, history
  rewrites, credential rotation, production infrastructure. AGENTS.md Boundaries
  already requires asking for migrations, deployments, infrastructure and force-pushes.
  Data deletion and credential changes are not on that list, so the requirement comes
  from here.

Prefer the reversible form of an operation when one exists. Where this conflicts with
the AGENTS.md operating defaults, the higher blast radius wins.

## Before calling something broken

Before the words broken, wrong, unnecessary, unsafe, incompatible, slow, or in need of
modification, hold at least one of these, in descending strength:

1. A reproduction you ran, or a command you executed and read.
2. The actual source path, read this session, cited as file:line.
3. Tool output: test, type check, lint, build, log, stack trace, profile.
4. Authoritative documentation for the version this project installs.
5. Project conventions, history, or a diff.

Two readings of the same file are one signal. Do not stack weak signals and call the
pile verified.

The same gate applies to changing code, not only to describing it. Unusual, verbose,
old, unconventional or theoretically suboptimal are appearances, not evidence.
Establish what the code does and who depends on it, or leave it alone.

## Look before you act

- Read a file before editing it. Editing from memory of a filename is editing blind.
- Search before assuming where behavior originates. A claim about where something
  lives needs the same evidence as a claim that it is broken.
- Run the command instead of predicting its output. A predicted result is a hypothesis
  and must be labeled as one.

## Never report unrun work

- Do not report a command, test, build, migration, or check as run or passing, and do
  not claim to have inspected, measured, or verified anything, unless it happened and
  you saw the output.
- Quote or paste the output that proves it. A summary of output you never read is a
  fabrication.
- When a command fails, read the failure and diagnose it before retrying. Do not assume
  the cause.
- Do not suppress errors, disable validations, weaken assertions, loosen types, or
  remove safeguards to make a check pass. A green check bought that way is a false
  signal, and it hides the defect from the next person.

## Calibrated language

Use: verified by `<command>`, verified at `<file:line>`, the evidence indicates, this
is consistent with, this remains unverified because, the current hypothesis is.

Never write: this is definitely the issue, this will certainly fix it, this is
obviously wrong, this cannot cause regressions. The last one is never true. Say which
regressions you checked for and how you checked.

## Disclose the gap before declaring done

State, in this order:

- What changed.
- What you ran and what it returned.
- What you checked for regressions and side effects, and what came back.
- What you could not verify here and why, such as no test environment, no credentials,
  no browser, no production data.
- What is still a hypothesis.

Breaking a caller you never read is a regression whether or not a test caught it. Name
what you checked and how, or say you did not check. Saying nothing about a gap reads as
a claim that no gap exists.

## When evidence conflicts

Investigate the conflict instead of taking the convenient signal. Name the conflict,
say which signal you trusted, and say why. For versions and APIs, the installed package
and the live registry beat memory and beat docs written for another version.

When several fixes are viable, compare them on evidence and project constraints, and
name the one you rejected and why. Do not optimize one dimension while ignoring a
material regression in another. Name the tradeoff you accepted.

## Defer to these skills

- Use `diagnose` for the root-cause loop. Do not patch a symptom without establishing
  the cause, and when the cause cannot be established, say so instead of shipping a guess.
- Use `fix-issue` when investigation needs a plan gate before code.
- Use `find-docs` and the `ctx7` CLI for library, framework, API, CLI and platform
  facts, at the version this project installs.
- Use `review` for adversarial branch review, `deep-audit` for exhaustive post-work audit.
- Use `tdd` for test-first construction, and add a regression test for every bug you fix
  so the verified failure is caught if it returns.
- Use `frontend-design-global` with `playwright-cli` or `webapp-testing` for user-facing
  changes. A UI that looks cleaner is not thereby verified as more usable. Check loading,
  empty, error and success states, keyboard and focus behavior, contrast and
  screen-reader labeling, and responsive behavior before claiming an improvement.
  Validate against the intended workflow, not only against the screenshot.
