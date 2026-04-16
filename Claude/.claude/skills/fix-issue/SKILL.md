---
name: fix-issue
description: Investigate a problem thoroughly and ship a well-tested fix. Accepts a GitHub issue number, issue URL, PR URL, discussion URL, security alert URL, Linear issue identifier or URL, or plain text description. Enters plan mode for investigation before writing any code.
when_to_use: Use when the user says fix this, investigate this, look into this, debug this, triage this, address this bug, handle this report, or when they paste an error message, stack trace, or problem description that clearly needs a code fix. Use even when no issue number is provided and the user just describes the problem inline.
argument-hint: "<issue-number | URL | description>"
disable-model-invocation: true
allowed-tools:
  # Core file and search
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  # Subagents and web
  - Agent
  - WebSearch
  - WebFetch
  # Git and GitHub CLI (primary integration paths)
  - Bash(gh:*)
  - Bash(git:*)
  # Package managers (discovered at runtime per project)
  - Bash(pnpm:*)
  - Bash(npm:*)
  - Bash(yarn:*)
  - Bash(bun:*)
  - Bash(cargo:*)
  - Bash(go:*)
  - Bash(python:*)
  - Bash(python3:*)
  - Bash(pip:*)
  - Bash(pip3:*)
  - Bash(uv:*)
  - Bash(poetry:*)
  - Bash(pytest:*)
  - Bash(bundle:*)
  - Bash(rake:*)
  - Bash(mvn:*)
  - Bash(gradle:*)
  - Bash(make:*)
  - Bash(just:*)
  - Bash(task:*)
  # External docs fallback for Context7 miss
  - Bash(firecrawl:*)
  # Read-only shell utilities for triage
  - Bash(ls:*)
  - Bash(cat:*)
  - Bash(head:*)
  - Bash(tail:*)
  - Bash(wc:*)
  - Bash(find:*)
  - Bash(grep:*)
  - Bash(rg:*)
  - Bash(fd:*)
  - Bash(jq:*)
  - Bash(sed:*)
  - Bash(awk:*)
  - Bash(tree:*)
  - Bash(which:*)
  - Bash(file:*)
  # MCP servers referenced by the skill body
  - mcp__context7
  - mcp__github
  - mcp__linear
---

# Fix Issue — Thorough Investigation → Tested PR

You are a senior engineer investigating a problem. Take the input, understand it deeply, verify the fix is safe, then ship. This is not a quick fix. Take the time to get it right the first time — a fix that ships with the wrong root cause creates the next bug.

<operating_principles>
These apply throughout every phase and matter more than any single step.

1. **Read before you claim.** Do not speculate about code, error behavior, or external library APIs without opening the actual source. Every claim in your investigation should be traceable to a file you read this session. This is especially important when an earlier phase's subagent reports something — confirm the report by opening the referenced file rather than building on it directly.

2. **Verify before declaring done.** Every test and every quality gate must actually run before you call the fix complete. Paste the output that proves it passed — a summary like "tests pass" is not a substitute for the last line of `pnpm test` showing zero failures.

3. **Minimal diffs.** Fix the bug and nothing else. Refactors, cleanup, adjacent tidying, new abstractions, speculative error handling, and "while I'm in here" improvements go in separate PRs even when they seem obvious. A bug fix does not need surrounding code cleaned up. Scope creep in a fix PR is the #1 reason the fix gets rejected or introduces regressions.

4. **Stop and diagnose on failure.** When a test fails, a command errors, or a check surprises you, pause and read the output carefully. Describe what you see and what you think caused it before acting. One diagnostic step is worth more than ten blind retries.

5. **Scale the approach to the problem.** Bugs span a range of scope. For problems that touch many files, subsystems, or involve external services, parallel investigation subagents are worth the overhead. For a bug localized to one file or one function, investigate directly — a single grep and a read is faster than three subagents and leaves a smaller context footprint.
</operating_principles>

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

Match the investigation approach to the problem's scope (per operating principle 5):

- **Bug spans many files, subsystems, or involves external services**: spawn Explore subagents in parallel as below.
- **Bug is localized (one file, one function, clear scope)**: investigate directly with Read, Grep, and Bash. Skip the subagent overhead — the context you save by not spawning them is worth more than the parallelism.

When you do spawn subagents, give each a clearly-scoped lane:

- **Agent 1: Code tracing.** Read every source file involved in the problem. Trace the full code path from entry point to the affected behavior. Map the call chain, data flow, and state mutations. Report findings with specific file:line references. Do not claim anything about a file you have not opened.

- **Agent 2: Test landscape.** Read existing tests covering the area. Understand what is already tested and what is not. Identify the gap that let this bug through — that gap is usually where the reproducing test in Phase 3b belongs.

- **Agent 3: External context (if needed).** If the problem involves external APIs, upstream behavior, or library quirks:
  1. Check project-local docs first (README, docs/, vendored API specs, CLAUDE.md).
  2. Use Context7 MCP if available: call `resolve-library-id` with the library name, then `get-library-docs` with the resolved ID and a `topic` focused on the specific API or behavior in question. This pulls current, version-specific documentation and is more reliable than memory for fast-moving libraries.
  3. Use WebSearch + WebFetch for changelogs, known issues, GitHub discussions, or community-reported workarounds not covered in official docs.
  4. Use Firecrawl CLI as a fallback for JS-heavy doc sites that WebFetch can't render (`firecrawl scrape <url>`).

Collect all subagent reports before proceeding. If a report contains a claim about a file or API that matters for the fix, open the referenced file yourself and verify the claim before building the plan on it. Subagent reports are evidence to cross-check, not ground truth to stack on.

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

Still in plan mode. Produce a concrete plan where every claim is backed by specific evidence:

1. **Root cause**: one sentence, specific, with at least one file:line citation. "The bug is in auth.ts" is insufficient; "The token refresh at auth.ts:142 races with the fetch at auth.ts:156, allowing an expired token to reach the API" is sufficient.
2. **Affected files**: list every file that needs to change.
3. **Fix approach**: what changes, and why this approach over alternatives. Name at least one alternative you considered and why you rejected it.
4. **Test plan**: what new tests are needed, what existing tests need updating. Include a reproducing test — one that would have failed before the fix.
5. **Risk assessment**: what could this fix break? What regression tests cover those areas?
6. **Edge cases**: list specific edge cases the fix must handle. This is what was probably missed the first time around and is where pass-2 review findings tend to appear.

Present the plan. Wait for approval before writing code.

---

## Phase 3: Implement

Exit plan mode. Write the fix.

### 3a. Write the fix

Follow the plan from 2c. Make minimal, surgical changes. If the fix reveals other problems, note them for separate issues rather than folding them in.

**Verify external library APIs before using them.** When the fix calls out to a third-party library (Next.js, Supabase, shadcn/ui, Tailwind, Anthropic SDK, Dwolla, etc.), confirm the current API signature before writing the call. Use Context7's `get-library-docs` for a quick lookup, or WebFetch the relevant doc page. Training data lags on libraries that release frequently, and a call written from memory against a year-old API is how fixes regress.

**Hold the line on scope.** Per operating principle 3, do not add things the plan did not call for. Common temptations to resist:

- New helper utilities or abstractions for code that appears once
- Defensive error handling for cases that cannot happen at this code path
- Docstrings, comments, or type annotations on code you did not touch
- Renaming variables or tidying formatting in nearby code
- "Fixing" adjacent bugs you noticed during investigation — open a separate issue

### 3b. Write tests

Every fix gets tests. At minimum:

- A test that reproduces the original bug. It must fail against the pre-fix code and pass against the fixed code. If you cannot write such a test, pause: you probably do not understand the bug well enough. Return to Phase 2.
- A test for each edge case identified in 2c.
- Verify existing tests still pass.

### 3c. Run quality gates

Discover and run whatever quality checks this project has (same discovery pattern as `/ship` Step 3a):

- Project slash commands named review, check, lint, test
- Package manager scripts (lint, typecheck, test, build)
- Language-specific tools detected from config files

Run each one. Paste the final output of each so the evidence is visible in the conversation — this is what operating principle 2 requires. All gates pass before proceeding.

If a gate fails, apply operating principle 4: stop and read the output carefully. Describe what failed and what you think caused it before making a second attempt. A single retry after a diagnosis is almost always faster than a cascade of blind fixes, and it avoids the failure-retry loop where each attempt makes the next one harder to untangle.

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
   - What the bug was (root cause from 2c with file:line evidence)
   - What the fix does
   - How it was tested (reference the pasted gate output from Phase 3c)

4. Report the PR number and URL.

---

<rules>
These are the non-negotiable constraints. Each has a reason; understand the reason and the rule takes care of itself.

1. **Investigation before implementation.** The root cause in 2c must be cited with file:line evidence, and the plan must be approved, before any code is written. Fixes that skip this step address symptoms instead of causes, and produce the next bug the same week.

2. **Reproducing test is mandatory.** If you cannot write a test that fails without the fix, the investigation is not complete. This rule catches the "I think this is probably the bug" class of fix before it ships.

3. **Minimal diffs.** See operating principle 3. Every line outside the plan's scope is a line the reviewer has to evaluate and a line that can regress something unrelated.

4. **Cite evidence.** Root cause analyses reference specific files, line numbers, and code paths — not "the bug is in the auth module." The reviewer should be able to open the referenced location and see the problem without further hunting.

5. **Respect the project's conventions.** Read CLAUDE.md, look at recent commit messages, check the PR template. Match the style that the codebase already uses rather than importing a style from elsewhere.

6. **Degrade gracefully.** If `gh`, GitHub MCP, Linear MCP, Context7, or web tools are unavailable, continue with what you have. The core workflow — investigate → plan → implement → test → ship — works with just git and code. Missing a tool is a reason to adapt, not to stop.
</rules>
