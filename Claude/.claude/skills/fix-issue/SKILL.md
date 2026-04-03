---
name: fix-issue
description: Investigate a problem thoroughly and ship a well-tested fix. Accepts a GitHub issue number, issue URL, PR URL, discussion URL, security alert URL, or plain text description. Enters plan mode for investigation before writing any code. Use when fixing a bug, investigating an issue, addressing a report, triaging a problem, or when the user says fix this, investigate this, look into this, debug this, triage this.
argument-hint: "<issue-number | URL | description>"
disable-model-invocation: true
effort: high
allowed-tools: Read Write Edit Grep Glob Bash(*) Agent WebSearch WebFetch
---

# Fix Issue — Thorough Investigation → Tested PR

Take any input, understand it deeply, verify the fix is safe, then ship. This is not a quick fix. Take your time. Get it right.

---

## Phase 1: Understand the Input

Detect what `$ARGUMENTS` is and fetch context using whatever tools are available (`gh` CLI preferred, GitHub MCP as fallback, raw git as last resort):

**GitHub issue number** (bare digits like `322`):
```bash
gh issue view $ARGUMENTS --json title,body,labels,assignees,comments,url 2>/dev/null
```

**GitHub issue URL** (contains `/issues/`):
Extract the number, then fetch as above.

**GitHub PR URL** (contains `/pull/`):
Read as a problem description, not code to merge.
```bash
gh pr view <number> --json title,body,comments,files,reviews,url 2>/dev/null
```

**GitHub discussion URL** (contains `/discussions/`):
```bash
gh api repos/{owner}/{repo}/discussions/<number> 2>/dev/null
```

**Security alert URL** (CodeQL, Dependabot, secret scanning):
```bash
gh api repos/{owner}/{repo}/code-scanning/alerts/<number> 2>/dev/null
gh api repos/{owner}/{repo}/dependabot/alerts/<number> 2>/dev/null
gh api repos/{owner}/{repo}/secret-scanning/alerts/<number> 2>/dev/null
```

**Linear issue** (URL containing `linear.app` or identifier like `BAI-123`):
If the Linear MCP is connected, use it to fetch the issue details.

**Plain text description**: Use as-is.

If `gh` is unavailable for any of the above, try the GitHub MCP. If neither is available, ask the user to paste the issue content.

---

## Phase 2: Deep Investigation (Plan Mode)

Enter plan mode. Do not write code yet.

### 2a. Research the problem

Spawn **Explore** subagents to parallelize the investigation:

- **Agent 1: Code tracing.** Read every source file involved in the problem. Trace the full code path from entry point to the affected behavior. Map the call chain, data flow, and state mutations.

- **Agent 2: Test landscape.** Read existing tests covering the area. Understand what is already tested and what is not. Identify gaps that let this bug through.

- **Agent 3: External context (if needed).** If the problem involves external APIs, upstream behavior, or library quirks:
  1. Check project-local docs first (README, docs/, vendored API specs, CLAUDE.md)
  2. Use context7 MCP if available to pull current library docs
  3. Use WebSearch + WebFetch for changelogs, known issues, or prior discussions
  4. Use Firecrawl as a fallback for JS-heavy docs that standard fetching can't render

Collect all subagent reports before proceeding.

### 2b. Triage: is this ours to fix?

Not every issue needs a code change. After investigating, determine the category:

**A. Bug in this project** — proceed to 2c.

**B. Not our bug** (upstream library issue, user misconfiguration, environment problem, external service behavior):
- Draft a reply explaining what you found, with evidence (code traces, payload verification, upstream source references).
- Include actionable steps the reporter can take.
- Present the draft reply to the user for review before posting.
- Stop here unless the user says otherwise.

**C. Out of scope** (feature request beyond the project's purpose, or something the project explicitly does not handle):
- Draft a reply explaining why, referencing any scope documentation.
- Present to the user. Stop here.

### 2c. Plan the fix

Still in plan mode. Produce a concrete plan:

1. **Root cause**: one sentence, specific.
2. **Affected files**: list every file that needs to change.
3. **Fix approach**: what changes, and why this approach over alternatives.
4. **Test plan**: what new tests are needed, what existing tests need updating.
5. **Risk assessment**: what could this fix break? What regression tests cover those areas?
6. **Edge cases**: list specific edge cases the fix must handle (this is what was probably missed the first time).

Present the plan. Wait for approval before writing code.

---

## Phase 3: Implement

Exit plan mode. Write the fix.

### 3a. Write the fix

Follow the plan from 2c. Make minimal, surgical changes — do not refactor unrelated code in the same PR. If the fix reveals other problems, note them for separate issues.

### 3b. Write tests

Every fix gets tests. At minimum:
- A test that reproduces the original bug (would have failed before the fix)
- A test for each edge case identified in 2c
- Verify existing tests still pass

### 3c. Run quality gates

Discover and run whatever quality checks this project has (same discovery as `/ship` Step 3a):
- Project slash commands named review, check, lint, test
- Package manager scripts (lint, typecheck, test, build)
- Language-specific tools detected from config files

All gates must pass before proceeding.

---

## Phase 4: Ship

### 4a. If `/ship` skill is available

Invoke it:
```
/ship <issue-number>
```

This handles staging, committing, pushing, PR creation, CI, and merge.

### 4b. If `/ship` is not available

Do it manually:

1. Stage and commit with a conventional commit message referencing the issue:
   ```
   fix(scope): description

   Closes #N
   ```

2. Push:
   ```bash
   git push -u origin HEAD
   ```

3. Create PR using `gh` or GitHub MCP. Link the issue. Include:
   - What the bug was (root cause from 2c)
   - What the fix does
   - How it was tested

4. Report the PR number and URL.

---

## Rules

1. **Never skip the investigation phase.** Quick fixes that skip root cause analysis create new bugs.
2. **Always write a reproducing test.** If you can't write a test that fails without the fix, you don't understand the bug well enough.
3. **Minimal diffs.** Fix the bug, nothing else. Refactoring and cleanup go in separate PRs.
4. **Cite evidence.** When explaining the root cause, reference specific files, line numbers, and code paths.
5. **Respect the project's conventions.** Read CLAUDE.md, look at recent commit messages, check the PR template. Match the style.
6. **Degrade gracefully.** If `gh`, GitHub MCP, Linear MCP, context7, or web tools are unavailable, continue with what you have. The core workflow (investigate → plan → implement → test) works with just git and code.
