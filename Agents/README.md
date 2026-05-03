# Agents

Cross-tool agent skills shared across Claude Code, Codex, and OpenCode. This is a **GNU Stow package**: running `stow Agents` from `~/.dotfiles` symlinks the contents of `Agents/.agents/` into `~/.agents/`, where each tool reads them.

## Layout

```
Agents/
├── README.md                # this file (ignored by stow)
└── .agents/
    └── skills/
        ├── python/SKILL.md          # path-conditional: auto-loads on .py edits
        ├── typescript/SKILL.md      # path-conditional: auto-loads on .ts/.tsx edits
        ├── scalability/SKILL.md     # path-conditional: backend code (api/routes/...)
        ├── commenting/SKILL.md      # description-discovered: cross-language style
        ├── security/SKILL.md        # description-discovered: secrets/auth/input/LLM
        └── playwright-cli/SKILL.md  # description-discovered: Playwright tool reference
```

After `stow Agents` (or `./install.sh`), each skill is reachable at:

- `~/.agents/skills/<name>/SKILL.md` → `~/.dotfiles/Agents/.agents/skills/<name>/SKILL.md`
- (resolves via relative symlinks for `python`, `typescript`, `scalability`, `commenting`, `security`, `playwright-cli`)

The Claude side also gets in-repo relative symlinks back into the canonical content:

- `Claude/.claude/rules/<name>.md` → `Agents/.agents/skills/<name>/SKILL.md` (for path-conditional rules: python, typescript, scalability)
- `Claude/.claude/skills/<name>` → `Agents/.agents/skills/<name>` (for description-discovered skills: commenting, security, playwright-cli)

## How each agent picks them up

| Tool | Reads from | Loads as |
|---|---|---|
| **Claude Code** | `~/.claude/rules/python.md` (relative symlink to canonical) | path-conditional rule, auto-loads on matching files via `paths:` YAML frontmatter |
| **Codex** | `~/.agents/skills/python/SKILL.md` (this stow target) | skill, description-discovered when working with Python files |
| **OpenCode** | same as Codex | skill, description-discovered |

The Claude side is wired in `Claude/.claude/rules/<name>.md` as a **relative symlink** into `Agents/.agents/skills/<name>/SKILL.md`. Editing once at the canonical location updates all three tools simultaneously.

## Adding a new shared skill

1. Create `Agents/.agents/skills/<new-name>/SKILL.md` with the standard Agent Skills frontmatter (`name`, `description`, optional `paths:` for path-conditional loading).
2. If it should auto-load in Claude as a path-conditional rule, also add a relative symlink:
   ```bash
   cd ~/.dotfiles/Claude/.claude/rules
   ln -s ../../../Agents/.agents/skills/<new-name>/SKILL.md <new-name>.md
   ```
3. Re-run stow if needed: `cd ~/.dotfiles && ./install.sh` (or `stow --restow Agents Claude`).
4. Reference the skill in `Codex/.codex/AGENTS.md` and `Config/.config/opencode/AGENTS.md` if it should appear in their loading hints.

## Why a separate package

Keeping these in their own stow package (rather than nesting them under `Claude/`) means:

- **No tool-coupling**: the canonical content isn't owned by any single agent.
- **Stow-deterministic**: a fresh machine just runs `./install.sh` and gets the skills wired up the same way as the original.
- **Cross-machine portable**: relative symlinks survive a `~/.dotfiles` clone path change.
