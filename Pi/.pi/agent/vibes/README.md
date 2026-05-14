# Agent Vibes

Spinner messages Pi displays during agent work. Toggled by the `workingVibe` setting in `~/.pi/agent/settings.json`. The current value is `"off"`; set it to a vibe name (e.g. `"star-wars"`) to activate.

## File format

One phrase per line. Each phrase ends with three trailing dots (`...`). Lines without the trailing dots are filtered out at load time, as are blanks. See `agent/packages/pi-statusline-footer/working-vibes.ts:161-164` for the load-time filter.

## Filename resolution

The `workingVibe` value is slugified before lookup: lowercased, non-`[a-z0-9_-]` runs collapsed to `-`, leading/trailing separators stripped. So `workingVibe: "Star Wars"` and `workingVibe: "star-wars"` both resolve to `star-wars.txt`. Slug logic lives in `working-vibes.ts:139-148`.

The "off" sentinel is case-insensitive: any value whose lowercased form is `"off"` disables vibes entirely (`working-vibes.ts:103`).

## Commands

- `/vibe` toggles vibe display in the current session.
- `/vibe generate` asks the model to generate a new batch of phrases for the active vibe file.

## Current state

`star-wars.txt` is present with 222 phrases but dormant (`workingVibe: "off"` in the global settings). To activate, set `workingVibe: "star-wars"` in `~/.pi/agent/settings.json`.
