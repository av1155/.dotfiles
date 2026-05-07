---
name: agentic-coding-harnesses
description: Use when modifying the user's agentic environment — skills, rules, AGENTS.md, dotfiles structure, or harness wiring across Claude Code, Codex, OpenCode, and Pi. Loads the runbook to follow canonical procedures and avoid breaking the cross-harness setup. Triggers on prompts about editing or adding skills, fixing rules, AGENTS.md size or content changes, plugin overwrote my skill, setting up the agentic environment, re-stow, or re-doing architecture work.
metadata:
  author: andrea
---

# Agentic Coding Harnesses Reference

Discovery skill that points to the comprehensive runbook for the user's multi-harness agentic environment.

## Read the runbook first

Before making any change to skills, rules, AGENTS.md, plugin configuration, MCP setup, or harness wiring, read:

```
~/.dotfiles/docs/AGENTIC-CODING-HARNESSES.md
```

The runbook is the source of truth for the canonical layout and procedures.

## What the runbook covers

- Per-harness loading mechanics for skills, rules, and instruction files (Claude Code, Codex CLI, OpenCode, Pi)
- Canonical file layout in `~/.dotfiles/`
- Procedures for: adding a skill, modifying imported skills, trimming AGENTS.md, handling plugin re-install conflicts, re-stowing, debugging skill discovery failures
- Size caps and adherence guidance per harness (Codex 32 KiB hard cap, Claude < 200 lines, "lost in the middle")
- Provenance tracking (user-authored vs. Matt Pocock vs. plugin vs. Claude.ai-app)
- Decision log explaining the architecture

## When to invoke this skill

Whenever the user's prompt involves modifying their agentic environment. Following the runbook prevents breaking the cross-harness setup. If a procedure isn't documented yet, add it to section 16 of the runbook before executing the change.
