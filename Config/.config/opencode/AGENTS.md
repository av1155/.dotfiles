# MCP Server Operations Guide

## Core Principle: Choose the Right Tool First

This document defines how AI agents should interact with the available Model Context Protocol (MCP) servers. Always select the most appropriate tool for the task, considering efficiency, safety, and user experience.

## Available MCP Servers

| Server       | Primary Purpose       | Key Capabilities                           |
| ------------ | --------------------- | ------------------------------------------ |
| **git**      | Version control       | Status, diff, commit, branch management    |
| **fetch**    | Simple web content    | Single URL fetching, markdown conversion   |
| **context7** | Library documentation | Resolve library IDs, fetch up-to-date docs |
| **time**     | Temporal operations   | Current time, timezone conversion          |

---

## Decision Trees

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

- Prefer `git MCP` for all VCS; restrict `bash` to read-only diagnostics.

### 📚 Context7 MCP Server

**When to Use:**

- Generating code with modern frameworks/APIs
- Need current, version-specific library documentation
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

### ⏰ Time MCP Server

**Usage:**

- Current time: `get_current_time` with IANA timezone
- Conversions: `convert_time` between timezones
- Always use IANA format: 'America/New_York', not 'EST'

---

## Quick Reference Card

```
Git ops        → git
Simple URL     → fetch
Library docs   → context7
Time/timezone  → time

ALWAYS:
- git_status before commits
- prefer smallest safe changes
```

---

## Troubleshooting

| Problem             | Solution                                   |
| ------------------- | ------------------------------------------ |
| Token overflow      | Use limits, pagination, selective reading  |
| Tool unavailable    | Check env vars, use fallback tool          |
| Git conflicts       | Show diff, explain options, await decision |
| Web content missing | Try different extraction method/tool       |

---

_This document is the authoritative guide for MCP server operations. When in doubt, refer to the decision trees and best practices above._
