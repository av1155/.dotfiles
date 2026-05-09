# Pi statusline handover

Current context: `~/.dotfiles`, package at `Pi/.pi/agent/packages/pi-statusline-footer`.

## Current status

The cleanup pass has been redone from a reset `index.ts` and `bash-mode/editor.ts`. The package is now slimmed down around the fixed-editor statusline, one-off shell prompt polish, and file-backed working vibes.

Current dirty files:

```text
D  Pi/.pi/agent/packages/pi-statusline-footer/CHANGELOG.md
M  Pi/.pi/agent/packages/pi-statusline-footer/README.md
D  Pi/.pi/agent/packages/pi-statusline-footer/banner.png
M  Pi/.pi/agent/packages/pi-statusline-footer/bash-mode/completion.ts
M  Pi/.pi/agent/packages/pi-statusline-footer/bash-mode/editor.ts
D  Pi/.pi/agent/packages/pi-statusline-footer/bash-mode/shell-session.ts
D  Pi/.pi/agent/packages/pi-statusline-footer/bash-mode/transcript.ts
M  Pi/.pi/agent/packages/pi-statusline-footer/bash-mode/types.ts
M  Pi/.pi/agent/packages/pi-statusline-footer/colors.ts
M  Pi/.pi/agent/packages/pi-statusline-footer/fixed-editor/terminal-split.ts
M  Pi/.pi/agent/packages/pi-statusline-footer/index.ts
M  Pi/.pi/agent/packages/pi-statusline-footer/package.json
M  Pi/.pi/agent/packages/pi-statusline-footer/presets.ts
D  Pi/.pi/agent/packages/pi-statusline-footer/segments.ts
D  Pi/.pi/agent/packages/pi-statusline-footer/separators.ts
M  Pi/.pi/agent/packages/pi-statusline-footer/types.ts
D  Pi/.pi/agent/packages/pi-statusline-footer/welcome-dismiss.ts
D  Pi/.pi/agent/packages/pi-statusline-footer/welcome.ts
M  Pi/.pi/agent/packages/pi-statusline-footer/working-vibes.ts
M  Pi/.pi/agent/settings.json
?? Pi/.pi/agent/keybindings.json
?? STATUSLINE-HANDOVER.md
```

## Completed in this pass

- Reset the previously broken partial `index.ts` and `bash-mode/editor.ts` edits before redoing the cleanup.
- Removed startup welcome overlay/header code and deleted `welcome.ts` / `welcome-dismiss.ts`.
- Removed sticky bash mode entry points:
    - `/bash-mode`
    - `/bash-reset`
    - `ctrl+shift+b`
    - managed shell session
    - embedded bash transcript
- Preserved Pi-native one-off shell prompts:
    - `!cmd` and `!!cmd` still go through Pi `user_bash`.
    - one-off prompts render with `$`.
    - `!` gets a red editor border.
    - `!!` gets a purple editor border.
    - successful one-off commands are appended to project shell history for ghost suggestions.
- Removed stash and prompt-history picker entry points:
    - `/stash-history`
    - `Alt+S`
    - `ctrl+alt+h`
    - stash status and persistence code
    - recent-project-prompt picker code
- Left fixed-editor mouse behavior intact.
- Left last-prompt display behavior intact.
- Added keyboard-only navigation updates without changing mouse handling:
    - `ctrl+alt+k` restores queued messages to the editor via Pi `app.message.dequeue` in `Pi/.pi/agent/keybindings.json`.
    - `ctrl+alt+m` jumps to the last user prompt.
    - `ctrl+alt+j` jumps back to the chat bottom.
- Reworked runtime working vibes to be file-backed only.
- Kept `/vibe generate <theme> [count]`, using the current configured Pi model through the command context.
- Removed `workingVibeModel` and `workingVibeMode` from `Pi/.pi/agent/settings.json`, leaving `workingVibe` intact.
- Collapsed presets to the baseline `default` plus `custom` alias.
- Removed public marketplace docs/assets/metadata and rewrote README as neutral project docs.
- Changed package author to `av1155` and removed name-specific wording.

## Caveats still binding

Do not touch these areas in follow-up cleanup unless explicitly asked:

- Mouse handling, mouse reporting, right-click passthrough, wheel behavior, terminal mouse modes.
- Recent-prompt or sticky-prompt implementation.

## Validation already run

```bash
node --experimental-strip-types --check Pi/.pi/agent/packages/pi-statusline-footer/index.ts
node --experimental-strip-types --check Pi/.pi/agent/packages/pi-statusline-footer/bash-mode/editor.ts
node --experimental-strip-types --check Pi/.pi/agent/packages/pi-statusline-footer/bash-mode/completion.ts
node --experimental-strip-types --check Pi/.pi/agent/packages/pi-statusline-footer/fixed-editor/terminal-split.ts
node --experimental-strip-types --check Pi/.pi/agent/packages/pi-statusline-footer/statusline-renderer.ts
node --experimental-strip-types --check Pi/.pi/agent/packages/pi-statusline-footer/working-vibes.ts
node --experimental-strip-types --check Pi/.pi/agent/packages/pi-statusline-footer/presets.ts
node --experimental-strip-types --check Pi/.pi/agent/packages/pi-statusline-footer/types.ts
python3 -m json.tool Pi/.pi/agent/packages/pi-statusline-footer/package.json >/dev/null
python3 -m json.tool Pi/.pi/agent/settings.json >/dev/null
python3 -m json.tool Pi/.pi/agent/keybindings.json >/dev/null
git diff --check -- Pi/.pi/agent/packages/pi-statusline-footer Pi/.pi/agent/settings.json Pi/.pi/agent/keybindings.json STATUSLINE-HANDOVER.md
PI_OFFLINE=1 pi --no-session --print 'Reply exactly OK'
```

## Interactive checks confirmed by user

- No welcome popup/header appears.
- `!` / `!!` prompts render with `$` and hide the literal bang prefix.
- `!` has a red editor border; `!!` has a purple editor border.
- Mouse behavior is unchanged.
- Fixed editor layout works.
- Earlier message jump shortcuts did not work reliably; replacement keyboard shortcuts are now `ctrl+alt+m` for the last user prompt and `ctrl+alt+j` for chat bottom.
