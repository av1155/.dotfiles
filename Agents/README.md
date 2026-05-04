# Agents

Cross-tool agent skills shared across Claude Code, Codex, and OpenCode. This is a **GNU Stow package**: running `stow Agents` from `~/.dotfiles` symlinks the contents of `Agents/.agents/` into `~/.agents/`, where each tool reads them.

## Layout

```
Agents/
├── README.md                # this file (ignored by stow)
└── .agents/
    └── skills/
        ├── python/SKILL.md                       # path-conditional: auto-loads on .py edits
        ├── typescript/SKILL.md                   # path-conditional: auto-loads on .ts/.tsx edits
        ├── scalability/SKILL.md                  # path-conditional: backend code (api/routes/...)
        ├── commenting/SKILL.md                   # description-discovered: cross-language style
        ├── security/SKILL.md                     # description-discovered: secrets/auth/input/LLM
        ├── playwright-cli/SKILL.md               # description-discovered: Playwright tool reference
        ├── caveman/SKILL.md                      # description-discovered (mattpocock): ultra-compressed mode
        ├── diagnose/SKILL.md                     # description-discovered (mattpocock): debugging loop
        ├── grill-me/SKILL.md                     # description-discovered (mattpocock): plan interview
        ├── grill-with-docs/SKILL.md              # description-discovered (mattpocock): grill + ADR/CONTEXT updates
        ├── improve-codebase-architecture/SKILL.md # description-discovered (mattpocock): architecture deepening
        ├── setup-matt-pocock-skills/SKILL.md     # description-discovered (mattpocock): per-repo setup
        ├── tdd/SKILL.md                          # description-discovered (mattpocock): red-green-refactor
        ├── to-issues/SKILL.md                    # description-discovered (mattpocock): plan to issues
        ├── to-prd/SKILL.md                       # description-discovered (mattpocock): context to PRD
        ├── triage/SKILL.md                       # description-discovered (mattpocock): issue triage state machine
        ├── write-a-skill/SKILL.md                # description-discovered (mattpocock): scaffold a new skill
        └── zoom-out/SKILL.md                     # description-discovered (mattpocock): broader context view
```

After `stow Agents` (or `./install.sh`), each skill is reachable at:

- `~/.agents/skills/<name>/SKILL.md` → `~/.dotfiles/Agents/.agents/skills/<name>/SKILL.md`

The Claude side also gets in-repo relative symlinks back into the canonical content:

- `Claude/.claude/rules/<name>.md` → `Agents/.agents/skills/<name>/SKILL.md` (path-conditional: python, typescript, scalability)
- `Claude/.claude/skills/<name>` → `Agents/.agents/skills/<name>` (description-discovered: commenting, security, playwright-cli, caveman, diagnose, grill-me, grill-with-docs, improve-codebase-architecture, setup-matt-pocock-skills, tdd, to-issues, to-prd, triage, write-a-skill, zoom-out)

## How each agent picks them up

| Tool | Reads from | Loads as |
|---|---|---|
| **Claude Code** | `~/.claude/rules/python.md` (relative symlink to canonical) | path-conditional rule, auto-loads on matching files via `paths:` YAML frontmatter |
| **Codex** | `~/.agents/skills/python/SKILL.md` (this stow target) | skill, description-discovered when working with Python files |
| **OpenCode** | same as Codex | skill, description-discovered |

The Claude side is wired in `Claude/.claude/rules/<name>.md` as a **relative symlink** into `Agents/.agents/skills/<name>/SKILL.md`. Editing once at the canonical location updates all three tools simultaneously.

## Adding a new shared skill

1. Create `Agents/.agents/skills/<new-name>/` containing `SKILL.md` (standard Agent Skills frontmatter: `name`, `description`, optional `paths:` for path-conditional loading), plus any reference files the skill bundles.
2. Wire up the Claude side via an in-repo relative symlink. Pick one of:
   - **Path-conditional rule** (auto-loads on matching globs):
     ```bash
     cd ~/.dotfiles/Claude/.claude/rules
     ln -s ../../../Agents/.agents/skills/<new-name>/SKILL.md <new-name>.md
     ```
   - **Description-discovered skill** (loaded when description matches):
     ```bash
     cd ~/.dotfiles/Claude/.claude/skills
     ln -s ../../../Agents/.agents/skills/<new-name> <new-name>
     ```
3. Re-stow: `cd ~/.dotfiles && stow --restow Agents Claude` (or `./install.sh`). Codex and OpenCode pick the skill up automatically via `~/.agents/skills/<new-name>/SKILL.md`; no per-tool symlink needed.
4. Reference the skill in `Codex/.codex/AGENTS.md` and `Config/.config/opencode/AGENTS.md` if it should appear in their loading hints.

## Why a separate package

Keeping these in their own stow package (rather than nesting them under `Claude/`) means:

- **No tool-coupling**: the canonical content isn't owned by any single agent.
- **Stow-deterministic**: a fresh machine just runs `./install.sh` and gets the skills wired up the same way as the original.
- **Cross-machine portable**: relative symlinks survive a `~/.dotfiles` clone path change.
