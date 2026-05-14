# AGENTS-PI.md — Pi agent-config reference

Pi-specific reference for agents working in `~/.dotfiles/Pi/.pi/`. Pi's runtime does NOT auto-load this document; it is read manually by agents doing housekeeping or refactor work on Pi config. The cross-harness wiring (skills, rules, AGENTS.md loading, plugins, MCP, Stow contract) is documented in `~/.dotfiles/docs/AGENTIC-CODING-HARNESSES.md`.

## Constitutional Invariants

Every Pi housekeeping or refactor batch must preserve these 12 invariants verbatim. Numbering matches `Pi/Housekeeping + Refactor/01-housekeeping-explore.md`.

1. Pi extension hook names (`session_start`, `turn_start`, `before_agent_start`, `session_shutdown`, etc.). Renaming a hook breaks Pi's extension dispatch.
2. `settings.json` schema keys Pi reads (`packages`, `extensions`, `theme`, `defaultProvider`, `defaultModel`, `defaultThinkingLevel`, `powerline`, `memory`, `workingVibe`, `quietStartup`, `startupScreen`, `showLastPrompt`, etc.). Removing a key or changing its value type breaks the corresponding feature.
3. Local package identifiers (`packages/pi-statusline-footer`, `packages/pi-claude-style-interop`). Both are referenced by directory path from `settings.json` `packages[]`.
4. MCP server names and `directTools` (`context-mode` with `[ctx_execute, ctx_execute_file]`). Defined in `agent/mcp.json`; consumed by the MCP discovery pipeline.
5. `APPEND_SYSTEM.md` MCP proxy discovery contract. The file is appended to the system prompt and lists active MCP servers so the model knows what tools are reachable via the proxy.
6. pi-lens cache layout (`.pi-lens/metrics-history.json`, `.pi-lens/worklog.jsonl`, `.pi-lens/cache/*`). Paths only; git tracking is orthogonal (the entire `.pi-lens/` tree is gitignored at `~/.gitignore_global:110`).
7. Plannotator contracts: `.plannotator/plans/<slug>.md` filename convention; the `[DONE:n]` marker inside each plan body; the `phases.planning` and `phases.executing` keys in `agent/plannotator.json`. The `.plannotator/` tree is gitignored at `~/.gitignore_global:109`; archived plans live in `.plannotator/plans/archive/` and are ignored by storage.ts's flat non-recursive scan.
8. AGENTS.md symlink target. `agent/AGENTS.md` is a symlink to `../../../Agents/.agents/AGENTS.md`, owned by the `Agents/` stow package. Out of scope for any Pi-local edit.
9. Two-runtime-name compatibility. Three loaders try `@mariozechner/pi-coding-agent` first, then `@earendil-works/pi-coding-agent`. The order must be preserved across the rename history.
10. Patch version monotonicity. Three constants gate prototype-patch reapply: `RENDER_PATCH_VERSION = 1` and `TOOL_RENDER_PATCH_VERSION = 7` in `packages/pi-claude-style-interop/index.ts:13-14`; `PATCH_VERSION = 8` in `extensions/user-message-style.ts:25`. Each increment must be matched in the corresponding reapply check (`pi-claude-style-interop/index.ts:376`, `pi-claude-style-interop/index.ts:1141`, `user-message-style.ts:579`).
11. Catppuccin theme path. The active theme file is `agent/themes/catppuccin-macchiato.json`; selected via `theme: "catppuccin-macchiato"` in `settings.json`.
12. Stow contract. Source lives at `~/.dotfiles/Pi/.pi/`; runtime at `~/.pi/` (symlinked by GNU Stow). After adding or removing a top-level path under `.pi/agent/`, the commit body must include a `stow --restow Pi` reminder so the user knows to refresh `~/.pi/` symlinks. The agent never runs Stow autonomously.

## Extension auto-discovery

Pi auto-loads every `.ts` file under `~/.pi/agent/extensions/`. The `extensions[]` array in `settings.json` is for ADDITIONAL paths beyond auto-discovery, not the activation list. Setting `extensions: []` is the correct posture when all on-disk extensions should remain active (as of session 2, `extensions` is `[]` and all 5 files load via auto-discovery: `all-core-tools.ts`, `inline-skill-invocations.ts`, `startup-screen.ts`, `user-message-style.ts`, `workmux-status.ts`).

See `pi.dev/docs/latest/extensions` for the documented contract.

## Patch version monotonicity

Three prototype patches install themselves at session start and gate reapply on a stored version number. Bumping a patch's version is REQUIRED when its semantics change so a stale wrapper from a prior pi session does not silently survive.

| Constant | File | Reapply check | Patch installer |
|---|---|---|---|
| `RENDER_PATCH_VERSION = 1` | `packages/pi-claude-style-interop/index.ts:13` | `index.ts:376` | `installFinalDurationRowPatch` |
| `TOOL_RENDER_PATCH_VERSION = 7` | `packages/pi-claude-style-interop/index.ts:14` | `index.ts:1141` | `installDirectMcpToolRendererPatch` |
| `PATCH_VERSION = 8` | `extensions/user-message-style.ts:25` | `user-message-style.ts:579` | `installPatch` |

When changing patch behavior, increment the constant AND verify the reapply check still compares against the constant (not a hardcoded number). The check pattern is `meta.version === <CONSTANT>`. Refactor Track J extracts these into a tested patch-system module.

## Dual-runtime-name fallback

Pi was renamed across versions. Three loaders attempt both package names in order, with the new name first:

```typescript
for (const specifier of ["@mariozechner/pi-coding-agent", "@earendil-works/pi-coding-agent"]) {
    try {
        const module = await import(specifier);
        if (module.<Component>?.prototype) return module.<Component>;
    } catch {
        // Try the next package name. Pi has used both names across versions.
    }
}
console.warn("[<file-tag>] Could not load <Component> from any known Pi package name");
return null;
```

The 3 loader sites (session 4 added the `console.warn` fail-loud surface):

- `packages/pi-claude-style-interop/index.ts` `loadAssistantMessageComponent` (~line 1246).
- `packages/pi-claude-style-interop/index.ts` `loadToolExecutionComponent` (~line 1262).
- `extensions/user-message-style.ts` `loadUserMessageComponent` (~line 632).

Removing either package name without updating all 3 loaders disables the patches silently (for the missing name) or noisily (post-session-4, the warn surfaces on stderr).

## Stow contract

Source: `~/.dotfiles/Pi/.pi/`. Runtime: `~/.pi/`. GNU Stow symlinks the tree using tree-folding (a parent directory is symlinked when all its contents come from one source).

When the agent adds or removes a top-level path under `.pi/` or `.pi/agent/`, the commit body must include:

```
REMINDER: run `stow --restow Pi` from ~/.dotfiles/ to refresh
the ~/.pi/<path> symlink.
```

The user runs Stow manually. The agent never runs `stow` autonomously. After restow, verify with `ls -la ~/.pi/<path>` that the symlink points at `../../.dotfiles/Pi/.pi/<path>` (or the appropriate relative pattern).

For new files inside an already-symlinked tree-folded directory (e.g. `.plannotator/plans/archive/` when `.plannotator/` is folded), no restow is needed — the existing symlink picks up the new contents transparently. The restow rule applies only when a NEW symlink target appears at the runtime path.

Cross-harness wiring details live in `~/.dotfiles/docs/AGENTIC-CODING-HARNESSES.md`.

## Theme reference

The active theme file is `agent/themes/catppuccin-macchiato.json`. Pi's theme schema is documented at `pi.dev/docs/latest/themes`. The runtime selector is `theme: "catppuccin-macchiato"` in `agent/settings.json`. Theme reads happen across `packages/pi-statusline-footer/theme.ts`, `packages/pi-claude-style-interop/index.ts` (color helpers), and `extensions/user-message-style.ts`. Theme/color centralization is Refactor Track K.

## Tier 3 deferred-to-Refactor

Housekeeping intentionally defers larger structural work. The Refactor pass tracks these:

| Refactor Track | Scope |
|---|---|
| A | vitest setup + characterization tests for `pi-claude-style-interop` patch reapply and `user-message-style` collapse logic |
| B | `@ts-nocheck` removal across all 26 local TS files; install `@types/node`; add top-level `tsconfig.json` covering extensions + packages; replace inline `ExtensionAPI` redeclarations with imports from `@earendil-works/pi-coding-agent` |
| C | `packages/pi-statusline-footer/index.ts` decomposition (MI=0, 2,518 lines, maxCyc=538) |
| D | `packages/pi-claude-style-interop/index.ts` decomposition (MI=2, 1,340 lines, regressing) into settings module + tool detection + arg summarizer + call/result renderers + patch installers |
| E | `extensions/user-message-style.ts` decomposition (MI=10.6, 658 lines, regressing) |
| F | `packages/pi-statusline-footer/fixed-editor/terminal-split.ts` decomposition (MI=3.5, 1,204 lines) |
| G | `packages/pi-statusline-footer/statusline-renderer.ts` refactor (MI=11.9, 560 lines) |
| H | Tool registry centralization (consolidate `CORE_TOOL_NAMES`, `CLAUDE_STYLE_HANDLED_TOOL_NAMES`, `CORE_TOOLS`) into a single module imported by both `pi-claude-style-interop` and `all-core-tools` (Housekeeping A.2 only added `// SHARED:` cross-reference comments) |
| I | Extension wiring audit (verify each of the 5 extensions' hook subscriptions match Pi runtime expectations) |
| J | Patch system extraction (move `installFinalDurationRowPatch`, `installDirectMcpToolRendererPatch`, `installPatch` into a tested module with proper error surfaces) |
| K | Theme/color centralization across `pi-statusline-footer/theme.ts`, `pi-claude-style-interop` theme helpers, and `user-message-style.ts` theme reads |
| L | Config consolidation: author JSON schemas for `settings.json` / `web-search.json` / `mcp.json`; introduce a runtime validator; consolidate settings-cascade reads across `pi-claude-style-interop`, `startup-screen`, `working-vibes`, `theme` |
| M | ESLint flat config at `Pi/.pi/agent/eslint.config.mjs`; husky + lint-staged + pre-push hooks at the dotfiles root scoped to the `Pi/` subtree; Pi CI workflow at `.github/workflows/pi.yml` (root of dotfiles repo) |
| N | Comment hygiene deep pass (file headers, TSDoc on every exported symbol, audit every comment against `~/.agents/skills/commenting/SKILL.md`) — subsumes Housekeeping Track G which only handled the single pi-lens worklog finding |
