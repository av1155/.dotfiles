# pi-statusline-footer

Pi statusline package with a fixed-editor layout, adaptive footer, one-off shell prompt styling, and file-backed working messages.

## What it keeps

- Adaptive statusline with context percentage/window, model, thinking level, git state, token usage, billing/subscription state, LSP, MCP, elapsed time, and Plannotator plan/auto mode.
- Fixed editor layout with the chat viewport above the editor, the statusline cluster sticky immediately below the prompt, and other below-editor widgets below the cluster.
- Existing fixed-editor mouse behavior and keyboard chat shortcuts:
    - `ctrl+alt+m`: jump to the last user prompt.
    - `ctrl+alt+j`: jump back to the chat bottom.
- Draft clipboard shortcuts:
    - `ctrl+alt+c`: copy full editor text.
    - `ctrl+alt+x`: cut full editor text.
- Pi-native one-off shell prompts:
    - `!cmd` and `!!cmd` stay handled by Pi.
    - One-off shell prompt chrome uses a `$` glyph.
    - `!` gets a red border, `!!` gets a purple border.
    - Successful one-off shell commands are saved to project shell history for ghost suggestions.
- Optional file-backed working vibes from `~/.pi/agent/vibes/<theme>.txt`.
- `/vibe generate <theme> [count]` for creating new vibe files with the current Pi model.
- Working vibes can stay off when another package, such as `pi-claude-style-tools`, owns the streaming loader text.
- Theme/icon override support.

## Removed from the original marketplace package

- Startup welcome overlay and header.
- Sticky bash mode, `/bash-mode`, `/bash-reset`, managed shell session, and embedded transcript.
- Editor stash, `/stash-history`, `Alt+S`, and the prompt-history picker.
- Public marketplace docs, changelog, banner, and package metadata.
- Runtime AI vibe generation and separate `workingVibeModel` / `workingVibeMode` settings.

## Commands

- `/powerline`: toggle this package on or off.
- `/powerline fixed-editor on|off|toggle`: control the fixed editor layout.
- `/powerline mouse-scroll on|off|toggle`: existing mouse-scroll setting. This package intentionally avoids changing lower-level mouse behavior.
- `/vibe`: show current vibe theme and backing file count.
- `/vibe <theme>`: use `~/.pi/agent/vibes/<theme>.txt` for working messages.
- `/vibe off`: disable themed working messages.
- `/vibe generate <theme> [count]`: generate a file of short themed loading messages using the current configured Pi model.

## Settings

Global settings live in `~/.pi/agent/settings.json`.

```json
{
    "workingVibe": "off",
    "showLastPrompt": false,
    "powerline": {
        "fixedEditor": true,
        "mouseScroll": true,
        "widgetBudgets": {
            "widgets": {
                "pi-lens": { "mode": "actionable", "maxLines": 8 },
                "rpiv-todos": { "mode": "native" },
                "plannotator-progress": { "mode": "remaining", "maxLines": 4 }
            }
        }
    }
}
```

`workingVibe` is optional. Use `"off"` or omit the key to leave this package's working messages disabled, which is the recommended setup when the Claude-style spinner is enabled. Set it to a theme name such as `"star-wars"` only when you want this package to replace the streaming loader text.

`powerline.widgetBudgets.widgets` maps Pi widget IDs to display policies. The default policy is still simple truncation (`mode: "truncate"`), where the final visible row becomes a compact `… +N more` summary and `maxLines` is the total space the widget occupies. Each widget entry may be `{ "maxLines": 8 }`, a positive number, or `true` to use the default of 4 lines. Use `false` or remove the entry to leave that widget uncapped.

Widget entries can also set `mode` for source-aware cleanup:

- `"actionable"`: hide non-actionable output, currently useful for `pi-lens` so an idle/ready LSP does not leave a bare `pi-lens` row.
- `"remaining"`: prefer remaining checklist rows and summarize completed rows, currently useful for `plannotator-progress`; all-done plans hide the live widget entirely.
- `"native"`: let the extension's own renderer decide; useful for `rpiv-todos`, which already hides completed tasks after the next turn and has its own overflow summary.
- `"todo"`: compact todo rows by priority if you want an additional cap on top of the todo renderer.

This package also registers a compact renderer for Plannotator's final `plannotator-complete` message, so the transcript shows a one-line completion summary instead of repeating the full checklist.

The wrapper only sees registrations that happen after this package patches `ctx.ui.setWidget`. Load `packages/pi-statusline-footer` before widgets that register during `session_start`, such as `npm:pi-lens`. `/lens-widget-toggle` still fully hides or shows the Pi Lens widget.

This package includes a local `tsconfig.json` plus `types/pi-runtime` shims so pi-lens/TypeScript diagnostics understand Pi runtime imports (`@mariozechner/*`, selected Node built-ins) without vendoring or modifying Pi itself.

Pi-native keybindings live in `~/.pi/agent/keybindings.json`. Queued-message editing uses `ctrl+alt+k` as the primary Ghostty/tmux-safe shortcut, with `alt+up` retained as a secondary binding.

Theme overrides can live in `~/.pi/agent/powerline-footer-theme.json`. See `theme.example.json` for the supported shape.
