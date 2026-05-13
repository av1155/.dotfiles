# pi-claude-style-interop

Local Pi package that patches presentation gaps between Pi, `pi-claude-style-tools`, and the user-installed extension set without editing installed npm packages.

## What it does

- Keeps `pi-claude-style-tools` final visual duration rows while removing embedded `✻ Worked for ...` lines from final assistant text blocks.
- Suppresses the live-updating duration row while the final assistant message is still streaming, so the row appears once with the final duration.
- Fixes direct MCP tool rendering, such as `context_mode_ctx_execute`, where the generic Claude-style fallback can duplicate the title and summary.
- Adds a conditional fallback for unaccounted non-core tools. Known Claude-style tools stay delegated to `pi-claude-style-tools`; tools with their own extension renderers keep those renderers; direct MCP tools get an MCP-aware row; remaining custom tools get a compact metadata-driven row.

## Why this shim exists

Pi supports per-tool renderers through `renderCall(args, theme, context)` and `renderResult(result, options, theme, context)`. `pi-claude-style-tools` provides strong renderers for built-in tools and many common extension tools, plus a generic fallback for other non-core tools.

The fallback cannot always infer direct MCP identity. `pi-mcp-adapter` registers direct MCP tools with names like `context_mode_ctx_execute`, labels like `MCP: ctx_execute`, and result details like `{ server: "context-mode", tool: "ctx_execute" }`. The generic renderer sees only the prefixed tool name, so it can display `Context Mode Ctx Execute Context Mode Ctx Execute`.

This local package loads after `npm:pi-claude-style-tools` in `agent/settings.json`, so it can wrap the already-installed `ToolExecutionComponent` methods and narrowly override only the gaps.

## What is already configurable elsewhere

`pi-claude-style-tools` settings in Pi settings can tune presentation:

- `toolBackground`
- `mcpOutputMode`
- `previewLines`
- `expandedPreviewMaxLines`
- `readOutputMode`
- `searchOutputMode`
- `bashOutputMode`
- diff and theme-adaptive settings

`pi-mcp-adapter` settings can tune MCP exposure:

- `directTools`
- `disableProxyTool`
- `toolPrefix`
- per-server `directTools` and `excludeTools`

Those settings decide which tools exist and how much output to show. They do not currently let direct MCP labels and result details override `pi-claude-style-tools` generic label selection, so this code patch is needed for that part.

## Current renderer strategy

The patch is conditional and maintainable when packages are added or removed:

1. Built-in tools and known `pi-claude-style-tools` targets are delegated to the existing renderer.
2. Direct MCP tools are detected from `toolDefinition.label`, `toolName`, `result.details.server`, and `result.details.tool`.
3. Non-core tool call rows are normalized even when an extension has its own call renderer, so subagents, todo, processes, memory, Pi Lens, and direct MCP share the same call-row color grammar.
4. Custom tools use a generic label from `toolDefinition.label` plus an argument summary from common keys such as `operation`, `action`, `query`, `pattern`, `filePath`, `path`, `url`, `name`, `subject`, `key`, `intent`, and `prompt`.
5. Tool call rows use a three-part color grammar from the active theme: tool label = `toolTitle` (`#B7BDF8` in Catppuccin Macchiato), primary context = `accent` (`#C6A0F6`), and trailing detail = `muted` (`#A5ADCB` in the current theme file).
6. Pending normalized call rows blink between muted hollow and green solid dots, matching the pending-dot rhythm from `pi-claude-style-tools`.
7. Render context is normalized for completed tool rows so delegated renderers can show final success or error dots instead of stale pending dots on replayed or restored rows.
8. Result toggle hints say `Ctrl+O to expand` when collapsed and `Ctrl+O to collapse` when expanded.
9. Result rendering preserves extension-specific result renderers, partial, error, collapsed, and expanded states. Direct MCP results honor `mcpOutputMode`, `previewLines`, and `expandedPreviewMaxLines`.

This covers current user packages including `pi-subagents`, `pi-web-access`, `pi-lens`, `rpiv-todo`, `rpiv-ask-user-question`, `pi-mcp-adapter`, `pi-processes`, `pi-memory`, and Plannotator while staying resilient to uninstalling or adding tools.
