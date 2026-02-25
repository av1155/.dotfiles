# Agent Cheat Sheet

## Overview & Operating Principles

- **Primary vs Subagents:** The primary agent orchestrates tasks and can call specialized subagents for specific needs. Subagents run in isolated sessions with limited permissions.
- **Read-only first:** Default to non-destructive actions (review, audit, research) before making changes.
- **Safe actions & idempotence:** Never create/modify files unless authorized by policy. Use tools in read-only mode whenever possible. Always prefer the smallest viable change.
- **Routing limits:** The `@router` subagent may delegate tasks up to 3 times, then must halt (no infinite loops).
- **Audit trail:** Subagents should write outputs to `.opencode/` (review reports, test results, etc.) for traceability. Keep diffs minimal and reproducible.
- **PR early, CI often:** Open draft PRs early, run CI tests frequently, and let automated checks verify correctness.

---

## Subagents: What You Can Call & When

**Delegation Policy:**

- **Development flow:** Use read-only checks first (code review, security audit, research). For code changes, hand off to `@refactorer` → then `@linter` (auto-fix ≤2 passes) → then `@test-runner` → then `@code-reviewer`.
    - If tests fail: `@debugger` diagnoses, then back to `@refactorer` for a fix.
    - Documentation or changelog updates: `@docs-writer`.
    - Dependency upgrades: `@dependency-updater`.
    - Unsure which agent to use? Call `@router` (max 3 attempts) to decide or ask for help.
- **Automatic invocation:** The primary agent should automatically call these subagents based on task type (you can also manually `@mention` them).

**Quick Reference – Subagents & Permissions:**

- **@code-reviewer** – _Performs static code/diff review_ (reads changed files and diffs; **read-only git via bash allow-list**: `git status`, `git diff`/`--staged`, `git show`, `git log -n`; `bash` otherwise limited to `mkdir -p .opencode*`/`ls`; **webfetch allowed** for spec lookups; **edits denied**) → returns review markdown; a write-capable agent (e.g., `@docs-writer`) may persist it to `.opencode/reports/review.md`.
- **@investigator** – _Scopes the work & maps flows_ (finds relevant files with read/grep/glob + read-only git via bash allow-list; **no edits**, **no webfetch**) → writes `.opencode/research/investigation_report.md` and `.opencode/research/flow_report.md`.
- **@visual-checker** – _UI smoke test_ (tools: read/glob, **`playwright*` enabled**, **`webfetch` on ask**; **edits denied**) → emits checklist + screenshots to `.opencode/reports/visual-check.md`.
- **@design-review** – _Full UX audit_ (tools: read/grep/glob, **`playwright*` enabled**, **`webfetch` allowed**; **edits denied**) → emits report to `.opencode/reports/design-review.md`.
- **@security-auditor** – _Secrets & CVE scan_ (tools: read/grep/glob, `bash` limited to `mkdir/ls`; **`webfetch` allowed**; **edits denied**) → emits `.opencode/reports/security.md`.
- **@research** – _External info with citations_ (tools: read/write; **`brave-search*`/`duckduckgo*`/`firecrawl*`/`fetch*`/`context7*` enabled**, **`webfetch` allowed**; **edits ask**) → writes `.opencode/research/notes.md`, `.opencode/research/citations.json`.
- **@refactorer** – _Implement/refactor code_ (tools: write/edit/patch; **`webfetch` denied**; `bash` on ask) → writes changes (≤3 files/batch) + `.opencode/refactor/changes.md`.
- **@linter** – _Format & lint_ (tools: write/edit/patch; `bash` allows configured linters; **`webfetch` denied**) → `.opencode/lint/report.json` (max 2 autofix rounds).
- **@test-runner** – _Run tests_ (`bash` allows common test commands; **`webfetch` denied**; **edits denied**) → emits summary intended for `.opencode/test/summary.json`.
- **@debugger** – _Diagnose test failures_ (tools: read/grep/glob; **`webfetch` allowed**; `bash` limited to `mkdir/ls`; **edits denied**) → emits `.opencode/debug/hypothesis.md`.
- **@docs-writer** – _Update docs/ADR_ (tools: read/write/edit; **`webfetch` on ask**; `bash` limited to `mkdir/ls`) → writes to `.opencode/docs/*`.
- **@dependency-updater** – _Safe dependency upgrades_ (tools: write/edit/patch; `bash` allows pkg-mgr commands; **`webfetch` denied**) → `.opencode/deps/upgrade_report.md`. **Tests are delegated to `@test-runner`.**
- **@router** – _Decision maker_ (tools: read/grep/glob; **`webfetch` on ask**; **no edits**) → returns `STATUS::router` with next agent or `halt`.

**Routing Hints:**

- Small diff (<100 LOC) with tests? → `@code-reviewer` might suggest directly using `@refactorer`.
- Test failures isolated to one area? → `@debugger` to analyze, then back to `@refactorer`.
- Ambiguous/broad tasks? → Start with `@investigator` → primary ingests the reports → then delegate to `@refactorer` / `@test-runner` / `@code-reviewer` as needed.
- Security issues in dependencies? → `@dependency-updater` to patch, then `@security-auditor` to re-check.

---

## Visual Development

**Design Principles & Sources:**

- Treat the project’s `design-principles.md` and `style-guide.md` in `./context/` as the truth for UI/UX decisions.
    - _If those files don’t exist, assume no significant UI work is needed; skip visual checks entirely (do NOT create them)._
- Prioritize clarity, consistency, and accessibility. Make incremental UI changes that preserve the intended hierarchy and user flow.
- Never override the documented design principles or style guide without explicit instruction.

**Quick Visual Check (Smoke Test):** _(for primary agent or @visual-checker)_

1. **Views & guidelines** — List affected views and open each; ensure design principles and style guide are followed.
2. **Intent & criteria** — Confirm the change satisfies the user need and acceptance criteria.
3. **Accessibility & prefs** — Verify color contrast, focus order, labels/alt text, keyboard navigation; honor reduced motion and text scaling preferences.
4. **Responsive & evidence** — Test at small, medium, and large breakpoints (no overflow/clipping); capture full-page screenshots (desktop and any failing size).
5. **Theme parity** — Ensure light/dark (and high-contrast) themes display consistently.

**Comprehensive Design Review:** Invoke the `@design-review` subagent when:

- Introducing or modifying core UI patterns, navigation, layout, or design tokens.
- Changes are large or highly visible.
- There’s any significant accessibility or responsive design risk.
- Right before merging any major visual update.

The design review will check against all principles and the style guide, test across required themes and breakpoints, verify accessibility (focus, labels, contrast), and compile a list of issues with evidence (screenshots, console errors). It outputs a prioritized fix list in markdown.

---

## 🧭 Git & GitHub Conventions and Standards

**1. Commit Messages (Conventional Commits):**

- Use **Conventional Commits** format: `<type>(<scope>)!: <description>` with optional body and footers.
- **Allowed types:** feat, fix, docs, refactor, perf, test, build, ci, chore, revert.
- Keep subject ≤50 chars, in present tense (no period). Wrap body lines at ~72 chars.
- If a commit introduces breaking changes, add `!` after type/scope or include a `BREAKING CHANGE:` footer.
- Reference issues in footers (e.g. `Fixes #123`, `Refs #456`).
- One logical change per commit. Commit early, commit often.
- **SemVer bump guide:** `feat` = **minor**, `fix` = **patch**, `!` (breaking) = **major**; other types (docs/chore/etc) typically do not bump version.

**2. Branching Strategy – Trunk-Based:**

- Base all work on the `main` branch.
- Create short-lived feature branches (lifespan in hours or days). Name them like `feat/feature-name`, `fix/bug-name`, `chore/tool-name`.
- Rebase or merge from `main` frequently to keep branches up-to-date; resolve conflicts promptly.
- _GitFlow (develop/release branches) is only for multi-release or regulated environments – avoid unless explicitly required._

**3. Pull Requests & Code Review:**

- **Open Draft Early:** Start with a Draft PR as soon as work begins. Mark ready for review only after tests pass and the description is complete.
- **Scope:** One focused change per PR (aim for small diffs).
- **PR Title & Description:** Title follows Conventional Commits style. The description should clearly outline the context (why), the changes (what), how to test, any risks or rollback steps, and include screenshots for UI changes. Link any relevant issues (e.g. _Fixes #123_).
- **Review Process:** Require at least one approval (two for critical code). All CI checks must be green. Authors must address every comment or document follow-up tasks for later.
- **Merge Strategy:** Prefer squash merging to keep history linear. Rebase merge is acceptable for preserving multiple commits as long as the history remains linear. **Never merge** if CI checks are failing.
- **Branch Protection:** Protect `main` (and any release branches) with required PR review, required passing checks, linear history (no merge commits), and restricted push access (no force pushes or branch deletions).
- **CI & Automation:** Ensure CI runs on all PRs and on `main`. Leverage reusable workflows for common pipelines (build, test, security scanning). Enable automated dependency updates (e.g. Dependabot). Make CI checks required in branch settings so merges cannot bypass them.

**4. Repository Structure & Usage:**

- **Top-level:** Include `README.md` (overview & setup), `LICENSE`, `CONTRIBUTING.md` (contribution guidelines), typical config files (`.gitignore`, `.editorconfig`), and an auto-generated `CHANGELOG.md`.
- **Project docs:** Use `.github/` for community health files:
    - Issue templates (e.g. bug_report.yml, feature_request.yml), a Pull Request template (with checklist), and GitHub Actions workflows for CI/CD and releases.
- **Issues vs. Discussions:** Use **Discussions** for open-ended questions, ideas, or broad design topics. Promote to **Issues** only when there is a concrete, actionable task or bug to track.
- **Releases & Tags:** Tag releases as `vX.Y.Z` in line with SemVer. Automate release notes and changelog updates whenever possible, summarizing features and fixes.

---

## Available MCP Servers (Tools)

| Server           | Purpose               | Capabilities (common commands)            |
| ---------------- | --------------------- | ----------------------------------------- |
| **git**          | Version control       | Git status, diff, add, commit, branch ops |
| **time**         | Date/time utilities   | Current time, format conversion           |
| **fetch**        | Web fetch (no JS)     | Retrieve single-page content (HTML/JSON)  |
| **brave-search** | Web & news search     | Fresh web/news results; images, videos    |
| **duckduckgo**   | Web search + fetch    | Query DDG; fetch & clean page content     |
| **firecrawl**    | Crawl & scrape sites  | Crawl/scrape/search/extract full sites    |
| **context7**     | Library documentation | Fetch up-to-date official docs by package |
| **playwright**   | Browser automation    | Headless UI interaction, screenshots, PDF |

---

### 🔧 git (Version Control Server)

**Usage Guidelines:**

- Use the git MCP server for all repository interactions (instead of shell git when possible).
- Always run `git_status` before making commits to verify the working state.
- Review changes with `git_diff_unstaged` (and `git_diff_staged` if needed) prior to committing.
- Stage intentionally: use `git_add <file>` for specific files rather than mass staging.
- Write clear, conventional commit messages via `git_commit -m "<type>: <message>"`.
- Branch naming: follow the `feat/`, `fix/`, etc. prefix conventions.
- Restrict direct shell usage for git actions; rely on MCP `git` commands to avoid unsafe operations.

**Common git Operations:**

```text
Working with git?
├── Check state:
│   ├── git_status (overview)
│   ├── git_diff_unstaged (unstaged changes)
│   └── git_diff_staged (staged changes)
├── Make changes:
│   ├── git_add <file(s)> (stage)
│   ├── git_commit -m "<message>" (commit)
│   └── git_reset <file> (unstage)
└── Navigate:
    ├── git_log (view recent commits)
    ├── git_checkout <branch> (switch branch)
    └── git_create_branch <name> (new branch)
```

---

### ⏰ time (Time Server)

**Usage:** Provides current timestamps and timezone conversions.

- `get_current_time(timezone="Area/Location")` returns the current date-time in the specified IANA timezone.
- `convert_time(timestamp, from_timezone, to_timezone)` converts a given time between zones.

Use this for scheduling, logging, or any time-sensitive logic. (All timezones should be given in standard IANA format like `America/New_York`.)

---

### 🌐 fetch (Web Fetch Server)

**Purpose:** Fetch simple web content quickly (no dynamic JS or login).

**Use Cases:** Retrieving static pages or files, scraping raw HTML or text, calling open APIs returning JSON/XML.

**Limitations:**

- Max ~5000 characters per request (use `start_index` and multiple calls for longer content).
- No JavaScript execution (use `playwright` if the page needs scripts run).
- No support for authenticated pages or complex interactions.

---

### 🔥 firecrawl (Crawl & Scrape Server)

**Purpose:** Turn a **site or section of a site** into clean Markdown/HTML/structured data. Supports **scrape**, **crawl** (multi-page), **map** (URL discovery), **search**, and **extract** (structured data).

**When to Use:** Deep research, RAG seeding, or whenever you need more than one page (docs, handbooks, blogs). Handles JS-rendered pages, anti-bot hurdles, and large batches.

**Tips:**

- Scope crawls (limit depth/pages) and request only needed formats (e.g., `markdown`, `html`) to save credits/time.

---

### 🔎 brave-search (Web & News Search Server)

**Purpose:** High-signal web/news discovery; images & videos.

**When to Use:** External research and time-sensitive scans. Prefer over `fetch` for exploration; use `fetch` for a known single page or API.

**Core Commands:**

- `brave_web_search(query, freshness=pd|pw|pm|py, count=...)`
- `brave_news_search(query, freshness=...)`
- `brave_image_search(query, count=...)`
- `brave_video_search(query, freshness=...)`

**Best Practices:**

- Bound scope with `freshness` (`pd`=24h, `pw`=7d, `pm`=31d, `py`=365d) and `country/search_lang`.
- Keep `safesearch` ≥ `moderate`; use `strict` for images.

**Free plan:** no `brave_summarizer`; skip `brave_local_search` (fallback: `web_search` + `result_filter=locations`)

---

### 🦆 duckduckgo (Web Search + Content Fetch Server)

**Purpose:** Fast general web search and **content fetching** with built-in rate limiting and LLM-friendly output. Tools include `search(query, max_results=10)` and `fetch_content(url)` for cleaned page text.

**When to Use:** Broad discovery (non-news) and quick retrieval of readable page content—especially when you want DDG’s neutral coverage and lightweight fetch. Rate limits (e.g., ~30 search/min, ~20 fetch/min) are handled by the server.

**Tips:**

- Start with `search` to shortlist sources → `fetch_content` on the best few.
- Prefer **brave-search** for time-sensitive news filters; use **duckduckgo** for general web breadth.

---

### 📚 context7 (Library Docs Server)

**When to Use:** Whenever you need current documentation or code examples from a specific library or framework (especially if your training data might be outdated).

**How it Works:** Two main steps for using context7:

1. **resolve-library-id("lib-name")** – Get the unique context7 ID for the library (e.g. `"react"` → `/facebook/react`).
2. **get-library-docs("/org/project", topic="...")** – Fetch docs for that library (optionally focused on a topic or API).

**Key Tips:**

- Always resolve the library ID first, unless you already have the exact `/org/project` identifier.
- Use the `topic` filter to narrow results (e.g. topic="middleware" or "Authentication"). This saves token space and time.
- Include the phrase _"use context7"_ in user prompts or rules to signal that code generation should leverage live docs.
- Prefer context7-sourced information over potentially outdated knowledge, especially for anything version-sensitive.

**Example:**  
User asks for _"Next.js middleware for JWT validation"_ and says _"use context7"_.  
The agent should:

- `resolve-library-id("next.js")` → gets `/vercel/next.js`
- `get-library-docs("/vercel/next.js", topic="middleware")` → retrieves the latest Next.js middleware docs
- Then craft the middleware code using the retrieved official API details.

---

### 🎭 playwright (Browser Automation Server)

**Purpose:** Automate and test web UI flows with a headless browser, or capture screenshots and simulate user interactions for front-end changes.

**When to Use:** For anything that requires rendering a page or simulating user behavior:

- Validating UI changes (layout across breakpoints, theme toggling, form inputs).
- Capturing screenshots for visual evidence or comparisons.
- End-to-end testing of user flows (clicking buttons, navigating, etc.).
- Checking console errors or network requests after an interaction.

**Core Commands:**

- **Navigation & Waits:** `browser_navigate(url)` to load a page; `browser_wait_for(selector|event)` to wait for elements or events; `browser_navigate_back()` to go back.
- **Snapshots & Logs:** `browser_snapshot()` to get an accessibility tree snapshot for analysis; `browser_console_messages(onlyErrors=true)` to collect console errors/warnings; `browser_take_screenshot(fullPage=true, filename="file.png")` for screenshots.
- **Interactions:** `browser_click(selector)`, `browser_type(selector, "text", pressEnter?)`, `browser_fill_form({fieldSelector: "value", ...})`, `browser_select_option(selector, value)`, `browser_press_key(key)` – simulate user inputs.
- **Layout & Tabs:** `browser_resize(width, height)` to test responsive layouts; `browser_tabs("list"|"close"|"switch", index)` to handle multiple tabs or pop-ups.
- **Advanced:** `browser_pdf_save(filename?)` (if launched with `--caps=pdf`) to save page as PDF; additional vision/canvas inspection tools with `--caps=vision` (for debugging layout issues).

**Best Practices:**

- Run in headed mode (default) for realistic rendering; use `--headless` only in CI or automated environments.
- Use `--isolated` for each test session to avoid state leaks. Provide stored auth state via `--storage-state=path/to/state.json` if you need a logged-in session.
- Enable trace or video capture (`--save-trace`, `--save-video`) when debugging flaky tests or CI-only failures.

---

## Subagent Tool Access Overview

The following **MCP tool namespaces are globally disabled** and then **enabled per-agent**:

```jsonc
"tools": {
  "git*": false,
  "time*": false,
  "fetch*": false,
  "firecrawl*": false,
  "brave-search*": false,
  "duckduckgo*": false,
  "context7*": false,
  "playwright*": false,
}
```

**Hint-only registry (MCP namespaces each subagent enables):**

- **@research:** `brave-search*`, `duckduckgo*`, `firecrawl*`, `fetch*`, `context7*`, and built-ins
- **@visual-checker:** `playwright*`, and built-ins
- **@design-review:** `playwright*`, and built-ins
- **@refactorer:** (no MCP namespace; uses built-ins)
- **@code-reviewer:** - (no MCP namespace; uses built-ins)
- **@security-auditor:** - (no MCP namespace; uses built-ins)
- **@debugger:** - (no MCP namespace; uses built-ins)
- **@docs-writer:** - (no MCP namespace; uses built-ins)
- **@investigator:** — (no MCP namespace; uses built-ins)
- **@linter:** - (no MCP namespace; uses built-ins)
- **@test-runner:** - (no MCP namespace; uses built-ins)
- **@router:** - (no MCP namespace; uses built-ins)

> This list is **advisory** so the primary can phrase tool-aware requests.
