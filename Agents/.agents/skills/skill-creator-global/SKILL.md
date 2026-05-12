---
name: skill-creator-global
description: Create, revise, or review Agent Skills for authoring quality. Use when writing SKILL.md content, improving skill descriptions and trigger words, deciding what belongs in SKILL.md versus references/scripts, or diagnosing why a skill over-triggers or under-triggers. Defer to agentic-coding-harnesses for dotfiles, Stow, symlinks, harness visibility, AGENTS.md, plugins, MCP, or environment wiring.
metadata:
    purpose: skill authoring craft guidance
---

# Skill Creator Global

Use this skill to create, revise, or review Agent Skills for authoring quality.

## When to use

Use this for skill-authoring craft:

- Drafting a new `SKILL.md`.
- Revising an existing skill for clarity, scope, or progressive disclosure.
- Improving a skill description so it triggers at the right time.
- Reviewing whether instructions belong in `SKILL.md`, references, templates, or scripts.

## When not to use

Defer to [agentic-coding-harnesses](../agentic-coding-harnesses/SKILL.md) for dotfiles, Stow, symlinks, harness visibility, AGENTS.md/CLAUDE.md loading, plugins, MCP, hooks, or environment wiring.

## Modes

- New skill: capture intent, write a focused description, draft the minimal useful `SKILL.md`, then add supporting files only when needed.
- Revise skill: preserve the existing purpose, tighten triggers, remove generic advice, and move rare details out of the main file.
- Review skill: check description quality, frontmatter shape, progressive disclosure, and whether the skill has a clear boundary.

## Core authoring rules

- Directory name and `name` should match.
- Put YAML frontmatter first.
- Keep `description` trigger-focused; put description craft details in [description-writing.md](references/description-writing.md).
- Keep the body concise and action-oriented.
- Move detailed references, examples, templates, or scripts into supporting files.
- Link supporting files from `SKILL.md` with when-to-read guidance.
- Do not hide, replace, or delete overlapping skills without explicit approval.

## Supporting files

- For description and trigger guidance, read [description-writing.md](references/description-writing.md).
- For a minimal skill skeleton, use [portable-skill.md](templates/portable-skill.md).
