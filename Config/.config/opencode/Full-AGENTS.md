# Agent Cheat Sheet

## Overview & Operating Principles

This global guide defines how agents and developers work in this repo: shared Git/GitHub conventions (commits, branches, PRs, reviews), repository hygiene, and how to use our MCP servers (`git`, `fetch`, `context7`, `time`). The goals are correctness, minimal diffs, reproducible builds, strong automation, and a linear, auditable history. Agents should prefer the smallest safe change, open draft PRs early, and rely on CI to validate changes.

---

## Subagents: What You Can Call & When

**Delegation policy (Build/Plan):**

- Prefer **read-only** first (review/security/research).
- For code changes → **@refactorer** → **@linter** (≤2 passes) → **@test-runner** → **@code-reviewer**.
- If tests fail → **@debugger** (diagnose) → **@refactorer** (minimal fix).
- Docs/CHANGELOG → **@docs-writer**. Deps → **@dependency-updater**.
- Unsure? **@router** (max 3 loops), then halt and ask.

**Cheat sheet (trigger → agent → tools & notes → artifact/path):**

- Review a diff/PR → **@code-reviewer** → `read, grep, glob, bash (mkdir/ls only); edit: deny` → `.opencode/reports/review.md`
- Security/secrets/CVEs → **@security-auditor** → `read, grep, glob, bash (mkdir/ls only); edit: deny` → `.opencode/reports/security.md`
- Find specs/compare libs → **@research** → `webfetch: allow; read, write; bash (mkdir/ls only)` → `.opencode/research/{notes.md,citations.json}` (stop at ≥3 vetted or 2 dead ends)
- Implement/refactor (small/medium) → **@refactorer** → `edit/write/patch: allow; bash: ask; webfetch: deny` → `.opencode/refactor/changes.md` (batch ≤3 edit sets)
- Format/lint → **@linter** → `bash: ask (eslint/prettier/ruff/etc allowed); edit: allow` → `.opencode/lint/report.json` (≤2 autofix passes)
- Run tests → **@test-runner** → `bash: ask (common test cmds allowed)` → `.opencode/test/summary.json`
- Debug failing test/trace → **@debugger** → `read, grep, glob, webfetch: allow; bash (mkdir/ls only); edit: ask` → `.opencode/debug/hypothesis.md`
- Write docs/ADR/changelog → **@docs-writer** → `read/write/edit: allow; webfetch: ask; bash (mkdir/ls only)` → `.opencode/docs/*` or patches
- Update dependencies safely → **@dependency-updater** → `bash: ask (install/upgrade cmds allowed); edit: allow` → `.opencode/deps/upgrade_report.md`
- Pick next agent → **@router** → `read, grep, glob; webfetch: ask; bash (mkdir/ls only); edit: deny` → emits `STATUS::router` (≤3 loops)

**Routing hints:**

- Reviewer → Refactorer if **≤100 LOC** and tests exist; else escalate to Plan.
- Tests → Refactorer if **single-file fix ≤50 LOC**; otherwise Tests → Debugger.
- Security → Dependency-updater for vulnerable deps, then back to Security to validate.

---

## Available MCP Servers

| Server                  | Primary Purpose           | Key Capabilities                             |
| ----------------------- | ------------------------- | -------------------------------------------- |
| **filesystem**          | File/directory operations | Read, write, edit, search, tree navigation   |
| **git**                 | Version control           | Status, diff, commit, branch management      |
| **fetch**               | Simple web content        | Single URL fetching, markdown conversion     |
| **context7**            | Library documentation     | Resolve library IDs, fetch up-to-date docs   |
| **firecrawl**           | Advanced web scraping     | Batch scraping, crawling, search, extraction |
| **playwright**          | Browser automation        | Click, type, navigate, screenshots           |
| **time**                | Temporal operations       | Current time, timezone conversion            |
| **sequential-thinking** | Complex problem solving   | Step-by-step reasoning, revision, branching  |

---

## Decision Trees

### File Operations Decision Tree

```
Need to work with files?
├── Read file(s)?
│   ├── Single file → read_text_file / read_media_file
│   ├── Multiple files → read_multiple_files
│   └── Explore structure → directory_tree
├── Write/Create?
│   ├── New file → write_file
│   ├── Edit existing → edit_file (ALWAYS dry_run first!)
│   └── New directory → create_directory
├── Search/Find?
│   ├── By pattern → search_files
│   └── List contents → list_directory / list_directory_with_sizes
└── Reorganize?
    └── Move/rename → move_file
```

### Web Content Decision Tree

```
Need web content?
├── Know exact URL?
│   ├── Single page → fetch (simple) or firecrawl_scrape (complex)
│   ├── Multiple pages → firecrawl_batch_scrape
│   └── Need interaction → playwright
├── Need to discover URLs?
│   ├── Within a site → firecrawl_map
│   └── Across the web → firecrawl_search
├── Need structured data?
│   └── Extract specific fields → firecrawl_extract
└── Need comprehensive coverage?
    └── Crawl site section → firecrawl_crawl (USE LIMITS!)
```

### Documentation Decision Tree

```
Need library/framework documentation?
├── For code generation/implementation?
│   ├── Know exact library → context7_get_library_docs with /org/project ID
│   ├── General library name → context7_resolve_library_id, then get-library-docs
│   └── Specific topic → use topic parameter ("routing", "auth", etc.)
├── Historical/archived docs?
│   └── Use firecrawl_scrape or fetch
└── General web documentation?
    └── Use firecrawl_search or fetch
```

### Git Operations Decision Tree

```
Working with git?
├── Check current state?
│   ├── Working tree → git_status
│   ├── Unstaged changes → git_diff_unstaged
│   └── Staged changes → git_diff_staged
├── Make changes?
│   ├── Stage files → git_add
│   ├── Commit → git_commit
│   └── Unstage → git_reset
└── Navigate history?
    ├── View commits → git_log
    ├── Switch branch → git_checkout
    └── Create branch → git_create_branch
```

---

## Tool-Specific Best Practices

### 🗂️ Filesystem MCP Server

**Key Rules:**

- **ALWAYS use dry_run for edit_file** before applying changes
- Check allowed directories with `list_allowed_directories`
- Use `head`/`tail` for large files to avoid token overflow
- Prefer `directory_tree` for understanding project structure
- Prefer `git MCP` for all VCS; restrict `bash` to read-only diagnostics.

**Example Workflow:**

```
1. directory_tree → understand structure
2. read_text_file → examine specific file
3. edit_file with dryRun=true → preview changes
4. edit_file with dryRun=false → apply changes
```

---

### 🔧 Git MCP Server

**Workflow Standards:**

1. **Before any changes:** `git_status` to understand current state
2. **Review changes:** `git_diff_unstaged` before staging
3. **Stage selectively:** `git_add` with specific files
4. **Meaningful commits:** Clear, conventional commit messages
5. **Branch strategy:** `feat/`, `fix/`, `chore/` prefixes

**Commit Message Format:**

```
type(scope): description

- feat: new feature
- fix: bug fix
- docs: documentation
- chore: maintenance
- test: testing
```

---

### 📚 Context7 MCP Server

**When to Use:**

- Need current, version-specific library documentation
- Generating code with modern frameworks/APIs
- Avoiding outdated training data and hallucinated APIs
- Getting working code examples from official sources

**Two-Step Workflow:**

1. **resolve-library-id** → Convert package name to Context7 ID
2. **get-library-docs** → Fetch documentation with optional topic focus

**Key Insights:**

- Always resolve library ID first unless user provides `/org/project` format
- Use `topic` parameter to focus docs (e.g., "routing", "authentication")
- Default token limit is 5000 (min 1000)
- Add "use context7" to prompts or create a rule for automatic invocation
- If you know the exact library, use `/org/project` syntax directly

**Example Usage:**

```
User: "Create Next.js middleware for JWT validation. use context7"

1. resolve-library-id("next.js") → /vercel/next.js
2. get-library-docs("/vercel/next.js", topic="middleware")
3. Generate code with current API
```

**Pro Tips:**

- Create a rule: "Always use context7 for code generation"
- Use library IDs directly: "use library /supabase/supabase"
- Prefer Context7 over generic knowledge for framework-specific code

---

### 🌐 Fetch MCP Server

**When to Use:**

- Single page content
- APIs returning JSON/XML
- Quick content checks
- When you don't need JavaScript rendering

**Limitations:**

- 5000 character default limit (use `start_index` for pagination)
- No JavaScript execution
- No authentication support

---

### 🔥 Firecrawl MCP Server

**Tool Selection Matrix:**

| Scenario                            | Tool           | Why                         |
| ----------------------------------- | -------------- | --------------------------- |
| "Get content from example.com/page" | `scrape`       | Single known URL            |
| "Get these 5 blog posts"            | `batch_scrape` | Multiple known URLs         |
| "Find all product pages"            | `map`          | Discover URLs               |
| "Find articles about X"             | `search`       | Web-wide search             |
| "Extract prices from pages"         | `extract`      | Structured data             |
| "Get all docs from site"            | `crawl`        | Comprehensive (USE LIMITS!) |

**Critical: Crawl Limits**

```javascript
// ALWAYS limit crawls to prevent token overflow
{
  "maxDepth": 2,      // Never exceed 3
  "limit": 100,       // Start small
  "deduplicateSimilarURLs": true
}
```

---

### 🎭 Playwright MCP Server

**Core Workflow:**

1. `browser_navigate` → go to page
2. `browser_snapshot` → understand page structure (NOT screenshot)
3. Interact using element refs from snapshot
4. `browser_wait_for` → ensure actions complete
5. `browser_close` → cleanup

**Key Insights:**

- Use snapshots for navigation, not screenshots
- Element `ref` values come from snapshots
- Always provide both `element` (human description) and `ref`
- Use `browser_fill_form` for multiple fields

### ⏰ Time MCP Server

**Usage:**

- Current time: `get_current_time` with IANA timezone
- Conversions: `convert_time` between timezones
- Always use IANA format: 'America/New_York', not 'EST'

---

### 🧠 Sequential Thinking MCP Server

**When to Engage:**

- Multi-step problems with unclear scope
- Tasks requiring revision/backtracking
- Complex planning before execution
- Analysis with potential pivots

**Effective Pattern:**

```
1. Initial thought: Define problem
2. Break down: Identify sub-tasks
3. Execute: Work through steps
4. Revise: Adjust as needed
5. Conclude: Synthesize solution
```

---

## Operational Guidelines

### 1. Safety First

- **Never force-push** without explicit confirmation
- **Always dry-run** edits before applying
- **Limit crawls** to prevent token overflow
- **Check git status** before commits

### 2. Efficiency Patterns

- Use batch operations when available
- Cache/reuse data from previous operations
- Choose the simplest tool that meets needs
- Parallelize independent operations

### 3. Error Recovery

```
Tool fails?
├── Check prerequisites (env vars, permissions)
├── Try alternative tool
├── Explain limitation to user
└── Suggest manual steps if critical
```

### 4. Communication Standards

- Show relevant diffs/changes concisely
- Explain tool selection when non-obvious
- Provide progress updates for long operations
- Summarize outcomes with next steps

---

## Common Workflows

### 📝 Code Review & Modification

```bash
1. git_status                    # Current state
2. directory_tree                # Project structure
3. read relevant files           # Understand code
4. edit_file (dry_run)          # Preview changes
5. edit_file                    # Apply changes
6. git_diff_unstaged            # Review changes
7. git_add                      # Stage files
8. git_commit                   # Commit with message
```

### 🔍 Research & Documentation

```bash
1. firecrawl_search             # Find relevant sources
2. firecrawl_batch_scrape       # Get specific pages
3. sequential_thinking          # Analyze & synthesize
4. write_file                   # Create documentation
```

### 🤖 Web Automation

```bash
1. browser_navigate             # Go to site
2. browser_snapshot             # Understand page
3. browser_type/click           # Interact
4. browser_wait_for             # Ensure completion
5. browser_take_screenshot      # Capture result
```

---

## Project-Specific Extensions

Projects may extend this guide via:

- `AGENTS.md` in project root
- `docs/**/AGENTS.md` for module-specific rules
- `opencode.jsonc` → `"instructions"` array

**Merge Strategy:** Project rules augment (never replace) global rules.

---

## Quick Reference Card

```
File ops       → filesystem
Git ops        → git
Simple URL     → fetch
Library docs   → context7
Complex web    → firecrawl
Interaction    → playwright
Time/timezone  → time
Complex logic  → sequential-thinking

ALWAYS:
- dry_run edits first
- git_status before commits
- limit crawl depth
- use element refs from snapshots
- prefer smallest safe changes
- use context7 for current library docs
```

---

## Troubleshooting

| Problem             | Solution                                   |
| ------------------- | ------------------------------------------ |
| Token overflow      | Use limits, pagination, selective reading  |
| Tool unavailable    | Check env vars, use fallback tool          |
| Git conflicts       | Show diff, explain options, await decision |
| Web content missing | Try different extraction method/tool       |
| Automation fails    | Check snapshot, verify element refs        |

---

_This document is the authoritative guide for MCP server operations. When in doubt, refer to the decision trees and best practices above._
