---
name: ship
description: Stage, commit, push, create a PR, wait for CI, merge, and clean up. Use for end-to-end shipping when the user says ship it, merge it, send it, land it, push this, create a PR, open a PR, or provides an issue number/description to ship.
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

Every PR should link an issue. Check if one was provided in the user's request as a number, URL, or description.

If the request includes an issue number, use it. If it includes descriptive text, search for a matching open issue. If no issue exists and `gh` is available:

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

## 3. Quality Gates, CHANGELOG, Stage, and Commit

### 3a. Update CHANGELOG.md (if Keep a Changelog format detected)

Check whether the project uses Keep a Changelog with an Unreleased section:

```bash
[ -f CHANGELOG.md ] && grep -qE '^## \[Unreleased\]$' CHANGELOG.md && echo "yes"
```

If no, skip this step.  If yes:

#### Decide whether this change deserves a bullet

The branch type is the first signal.  Default behaviour:

| Branch prefix | Default | Override only when... |
| --- | --- | --- |
| `feat`, `fix`, `revert` | **Add a bullet.** | The change is user-invisible (e.g. an internal-only fix). |
| `perf` | **Add a bullet.** | The diff has no measurable or user-observable effect. |
| `chore`, `refactor`, `test`, `ci`, `docs`, `build`, `style` | **Skip.** | The diff touches a user-visible surface (e.g. a `chore` that bumps a public dependency in a way users will notice). |

Then sanity-check by looking at the changed paths:

- User-facing if changed: source under `src/` or equivalent app root, public templates, public routes, env-var documentation, Dockerfile (deployer-visible), `requirements*.txt` / `package.json` deps when version constraints affect users.
- Never user-facing: `tests/`, `.github/`, `.codex/`, `.workmux.yaml`, internal docs, lock-file-only changes, comment-only edits.

When the signals disagree (e.g. `chore` branch but the diff touches a user-visible file), trust the diff over the prefix.  When in doubt, draft a bullet and let the user remove it on review.

#### Find the project's style guide before drafting

Before writing a single bullet, read whichever of these exist (in this order, stop at the first hit) and follow the rules you find:

1. A `### Changelog style guide` (or similarly-named) section in `AGENTS.md` / `AGENTS.md`.
2. `CONTRIBUTING.md` sections on changelog, release notes, or commit messages.
3. The project's most recent 5 release blocks in `CHANGELOG.md` itself: match their voice (imperative vs noun-led), tense, length, and level of detail.

If the project documents a banned-phrasings list, a length cap, or a "no internal class names" rule, honour it.  When a project has no documented guide, fall back to the **Generic rules** below.

#### Generic rules (when no project guide exists)

Sections per Keep a Changelog 1.1.0, in this order if you add a missing section header:

- `### Added` — new features
- `### Changed` — modifications to existing functionality
- `### Deprecated` — soon-to-be-removed features
- `### Removed` — removed features
- `### Fixed` — bug fixes
- `### Security` — vulnerability responses

Voice and length:

- One sentence per bullet.  A second sentence only when migration or upgrade-affecting context must ride with the change.
- Target 80 to 160 characters.  Hard ceiling 250.  If the bullet runs longer, split it or move detail to the PR body.
- Lead with user-facing impact, not implementation detail.
- End with `(#N)` referencing the linked issue from step 1 (the PR number is not yet known; GitHub auto-links either form).
- Use backticks for identifiers, file names, env vars, UI elements.
- Use markdown `[text](url)` syntax for external links.

Avoid (these read as auto-generated or low-effort):

- Vague: "Various bug fixes", "Improved X", "Enhanced X", "Better X", "Bug fixes and stability improvements".
- Marketing: "We are thrilled to...", "groundbreaking", "delightful new experience".
- Magic adverbs without measurement: "seamlessly", "robustly", "significantly", "dramatically".  Quantify or omit.
- Empty verbs: "leverages", "utilizes", "harnesses", "facilitates".  Pick the concrete verb.
- Bold lead-ins (`**Performance:** faster X`) and marketing trail clauses (`for a smoother experience`).

Audience-aware vocabulary:

- For tools targeting **developers / SDK users**: name the public API surface that changed (function, type, parameter, env var, config key, CLI flag).  Imperative mood ("Add", "Fix", "Bump") is the dominant convention.  Examples: Stripe, Tailwind, Pydantic, Anthropic SDKs.
- For tools targeting **self-hosters / sysadmins**: name the operator-visible surface (env var, config key, schema version, log line, HTTP route, container directive).  Avoid internal class names, private helpers, and source paths under `src/` unless they appear in operator-visible logs.  Noun-led present tense often reads more naturally here ("Logs page distinguishes...").  Examples: Authelia, AdGuard Home, Plausible, Caddy.
- For tools targeting **end-user applications**: marketing-style release notes are appropriate, but they belong on a separate Releases page, not in `CHANGELOG.md`.  Keep the markdown file focused on upgraders.

Match the project's audience.  If unsure, look at the README's "Who is this for" section, the Dockerfile (presence implies self-hosters), or the package metadata.

Stage `CHANGELOG.md` alongside the rest of the commit so the bullet ships with the change rather than as a follow-up.

### 3b. Discover and run quality gates

Detect what's available in this project (same discovery as deep-audit Step 1b):

**Project quality workflows:** Check `.codex/commands/`, `.codex/skills/`, `.agents/skills/`, and package scripts for anything named review, check, lint, test, validate, qa. If a quality-gate skill, command, or script exists, invoke it.

**Package scripts:** Read the package manager config:
- `package.json` scripts: look for lint, typecheck, test, check, validate
- `Makefile` targets: look for lint, test, check
- `pyproject.toml`: look for ruff, mypy, pytest, bandit configs
- Rust: `cargo clippy && cargo test`
- Go: `go vet ./... && go test ./...`

Run whatever exists. If quality gates fail, stop and report the failures. Do not continue.

If only non-code files changed (markdown, yaml, config), skip quality gates that don't apply.

### 3c. Stage and commit

Stage relevant files (prefer explicit paths over `git add -A`). Include `CHANGELOG.md` if you edited it in 3a. Write a conventional commit message:

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
