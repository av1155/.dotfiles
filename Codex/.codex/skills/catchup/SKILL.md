---
name: catchup
description: Restore coding-session context after a clear, compaction, new Codex session, or resume. Shows current branch, uncommitted changes, open PRs, recent commits, issue tracker state, and next steps. Use when the user says catchup, where was I, what was I doing, restore context, resume, status, or asks to reorient.
---

# Catch Up — Restore Session Context

You are restoring context after a session start, clear, resume, or context compaction. Gather everything the developer needs to resume work without asking questions. Be fast, be comprehensive, report concisely.

## 1. Orientation

Always run these regardless of branch:

```bash
git branch --show-current
git status --short
git log --oneline -10
```

This gives: current branch, uncommitted changes, and recent history.

## 2. Open PRs

Detect what's available and use it:

**On a feature branch:**
```bash
gh pr list --state open --head "$(git branch --show-current)" \
  --json number,title,url,statusCheckRollup --limit 1 2>/dev/null
```

**On main/master/develop:**
```bash
gh pr list --state open --limit 5 \
  --json number,title,headRefName 2>/dev/null
```

If `gh` is unavailable, skip and note "PR status unavailable (no `gh` CLI)."

## 3. Issue Tracker Context

Detect which tracker this project uses and pull current state:

**Linear:** If the Linear MCP is connected and the project references Linear (check AGENTS.md, README, or `.codex/` configs), pull the active sprint/cycle and any issues assigned to the current user or linked to the current branch.

**GitHub Issues:** If no Linear, use `gh` to check for issues linked to the current branch or recent PRs.

**Neither:** Skip. Don't fail the catchup over missing tracker access.

## 4. Changed Files

**On a feature branch** (not main/master/develop):
```bash
git diff --name-only main...HEAD 2>/dev/null || git diff --name-only master...HEAD 2>/dev/null
```

Read key changed files to understand work-in-progress context. For large diffs (20+ files), read only the most recently modified files rather than all of them.

**On the default branch:** Skip. Recent context comes from git log.

## 5. Progress File

Look for a project progress or session state file:
```bash
ls claude-progress.md PROGRESS.md .claude-progress progress.md AGENTS.md 2>/dev/null
```

If one exists, read it. These files carry forward decisions, blockers, and next steps across sessions.

## 6. Project Slash Commands

```bash
ls .codex/commands/ .codex/skills/ 2>/dev/null
```

If project-specific commands exist, mention them briefly so the developer knows what's available in this project.

## 7. Summarize

Report concisely in this structure:

- **Branch:** current branch name and commit
- **Uncommitted changes:** list or "clean"
- **Open PR:** number, title, CI status — or "none"
- **What's been done:** synthesized from recent commits, PR descriptions, progress file
- **Current state:** what the code looks like right now (green CI? failing tests? mid-refactor?)
- **Next steps:** inferred from progress file, open issues, or branch name
- **Blockers:** from progress file or issue tracker, if any
- **Available workflows:** project-specific skills, commands, or scripts, if any

Do not ask follow-up questions. The developer invoked `/catchup` because they want context delivered, not a conversation.
