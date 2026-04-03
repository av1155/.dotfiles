---
name: ship
description: Stage, commit, push, create PR, wait for CI, merge, and clean up. Fully automatic end-to-end shipping workflow that detects current state and picks up from wherever the process left off. Use when shipping changes, merging, creating a PR, pushing code, or when the user says ship it, merge it, send it, land it, push this, create a PR, open a PR.
argument-hint: "[issue number or description]"
disable-model-invocation: true
allowed-tools: Read Grep Glob Bash(git *) Bash(gh *) Bash(sleep *) Bash(date *) Agent
---

# Ship — Stage to Merge in One Command

Fully automatic end-to-end workflow. Detect the current state and pick up from wherever the process left off. No unnecessary confirmation prompts — only stop if something fails or is ambiguous.

## 0. Detect State

```bash
git branch --show-current
git status --short
git diff --cached --name-only
git log --oneline -5
```

Check for an existing PR:
```bash
gh pr list --state open --head "$(git branch --show-current)" \
  --json number,title,url,statusCheckRollup --limit 1 2>/dev/null
```

If `gh` is unavailable, check the GitHub MCP. If neither is available, skip PR detection and handle manually at step 5.

Use the results to skip completed steps:
- Already on a feature branch? Skip step 2.
- No uncommitted changes and commits already ahead of default branch? Skip step 3.
- PR already exists? Skip step 5.
- CI already passing? Skip step 6.
- Already merged? Skip to cleanup.

If there are no changes (working tree clean, nothing staged, no commits ahead), stop: "Nothing to ship."

## 1. Issue

Every PR should link an issue. Check if one was provided via `$ARGUMENTS` (a number or description).

If `$ARGUMENTS` is an issue number, use it. If it's descriptive text, search for a matching open issue. If no issue exists and `gh` is available:

```bash
gh issue create --title "<type>: <short imperative description>" \
  --body "<brief description>"
```

Apply whatever label conventions the project uses (check existing issues for patterns). If `gh` is unavailable and no issue was provided, proceed without one and note it in the PR body.

## 2. Create Branch (if on the default branch)

Detect the default branch:
```bash
git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main"
```

If currently on the default branch:
```bash
git fetch origin
git checkout -b <type>/<short-slug> origin/<default-branch>
```

Branch naming: `type/short-slug` — lowercase, hyphenated. Derive the type from the nature of changes (feat, fix, chore, ci, docs, refactor, test).

## 3. Quality Gates, Stage, and Commit

### 3a. Discover and run quality gates

Detect what's available in this project (same discovery as deep-audit Step 1b):

**Project slash commands:** Check `.claude/commands/` and `.claude/skills/` for anything named review, check, lint, test, validate, qa. If a quality-gate command exists, invoke it.

**Package scripts:** Read the package manager config:
- `package.json` scripts: look for lint, typecheck, test, check, validate
- `Makefile` targets: look for lint, test, check
- `pyproject.toml`: look for ruff, mypy, pytest, bandit configs
- Rust: `cargo clippy && cargo test`
- Go: `go vet ./... && go test ./...`

Run whatever exists. If quality gates fail, stop and report the failures. Do not continue.

If only non-code files changed (markdown, yaml, config), skip quality gates that don't apply.

### 3b. Stage and commit

Stage relevant files (prefer explicit paths over `git add -A`). Write a conventional commit message:

```
type(scope): description
```

Commit rules:
- Subject line max 50 characters
- Body lines max 72 characters
- Imperative mood
- If there are multiple logical changes, create separate commits

## 4. Push

```bash
git push -u origin HEAD
```

## 5. Create PR (if none exists)

Check for a PR template:
```bash
cat .github/pull_request_template.md 2>/dev/null || cat .github/PULL_REQUEST_TEMPLATE.md 2>/dev/null
```

If a template exists, fill it in. If not, write a concise PR body with:
- What changed and why
- Issue link (`Closes #N` if an issue exists)
- Any notable decisions or trade-offs

```bash
gh pr create --title "<short title under 50 chars>" --body "<body>"
```

If `gh` is unavailable, use the GitHub MCP. If neither is available, report the branch name and say "Push complete. Create the PR manually."

## 6. Wait for CI

```bash
gh pr checks 2>/dev/null
```

If checks are still running, poll every 30 seconds:

```bash
while true; do
  FAILED=$(gh pr checks --json name,state --jq '[.[] | select(.state == "FAILURE")] | length' 2>/dev/null)
  if [ "$FAILED" -gt 0 ]; then
    echo "CI failed:"
    gh pr checks --json name,state --jq '.[] | select(.state == "FAILURE") | "\(.name): \(.state)"'
    break
  fi
  PENDING=$(gh pr checks --json name,state --jq '[.[] | select(.state != "SUCCESS" and .state != "SKIPPED")] | length' 2>/dev/null)
  if [ "$PENDING" -eq 0 ]; then
    echo "All checks passed."
    break
  fi
  echo "$PENDING checks still running... (polling in 30s)"
  sleep 30
done
```

If any check fails, stop and report which ones. Do not merge.

If `gh` is unavailable, skip polling and tell the user to check CI manually.

## 7. Merge

Attempt squash-merge (most common convention for linear history):

```bash
gh pr merge --squash --delete-branch 2>/dev/null
```

If squash is not allowed by repo settings, try:
```bash
gh pr merge --merge --delete-branch 2>/dev/null
```

If the PR requires review approval and doesn't have it, report that and stop.

If `gh` is unavailable, report "CI passed. Merge the PR manually."

## 8. Post-Merge Cleanup

```bash
git checkout <default-branch>
git pull origin <default-branch>
git fetch --all --prune --tags
```

Delete the local feature branch if it still exists:
```bash
git branch -d <branch-name> 2>/dev/null
```

Check for stale local branches:
```bash
git branch -vv | grep '\[.*: gone\]'
```

If any show `gone`, delete them too.

## 9. Report

Summarize:
- What was shipped (PR number, title, URL)
- Issue linked or created (number)
- New HEAD commit on the default branch
- Branches cleaned up
- Any remaining action items (e.g., "tag a release", "deploy to production")
