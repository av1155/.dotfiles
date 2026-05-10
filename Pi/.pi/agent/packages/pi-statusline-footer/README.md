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
- File-backed working vibes from `~/.pi/agent/vibes/<theme>.txt`.
- `/vibe generate <theme> [count]` for creating new vibe files with the current Pi model.
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
    "workingVibe": "star-wars",
    "showLastPrompt": false,
    "powerline": {
        "fixedEditor": true,
        "mouseScroll": true,
        "widgetBudgets": {
            "widgets": {
                "pi-lens": { "maxLines": 8 },
                "rpiv-todos": { "maxLines": 5 },
                "plannotator-progress": { "maxLines": 4 }
            }
        }
    }
}
```

`powerline.widgetBudgets.widgets` maps Pi widget IDs to maximum rendered line counts. When a widget renders more lines than its budget, the final visible row becomes a compact `… +N more` summary, so `maxLines` is the total space the widget occupies. Omit `widgetBudgets` to preserve Pi's default widget rendering. Each widget entry may be `{ "maxLines": 8 }`, a positive number, or `true` to use the default of 4 lines. Use `false` or remove the entry to leave that widget uncapped.

The wrapper only sees registrations that happen after this package patches `ctx.ui.setWidget`. Load `packages/pi-statusline-footer` before widgets that register during `session_start`, such as `npm:pi-lens`. `/lens-widget-toggle` still fully hides or shows the Pi Lens widget.

Pi-native keybindings live in `~/.pi/agent/keybindings.json`. Queued-message editing uses `ctrl+alt+k` as the primary Ghostty/tmux-safe shortcut, with `alt+up` retained as a secondary binding.

Theme overrides can live in `~/.pi/agent/powerline-footer-theme.json`. See `theme.example.json` for the supported shape.
