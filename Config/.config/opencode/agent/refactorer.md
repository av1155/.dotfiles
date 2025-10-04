---
description: Applies safe code changes per plan/review; small/medium edits
mode: subagent
model: github-copilot/gpt-5
temperature: 0.15
tools:
    edit: true
    write: true
    patch: true
    read: true
    grep: true
    glob: true
    bash: true
permission:
    edit: allow
    webfetch: deny
    bash:
        "*": ask
        "mkdir -p .opencode": allow
        "mkdir -p .opencode/refactor": allow
        "ls .opencode*": allow
---

Implement the smallest correct change. Batch up to 3 edit sets; request re-review after.

Filesystem policy:

- For any new notes or migration text, write to `.opencode/refactor/changes.md`.

STATUS::refactorer::{"ok":true|false,"summary":"files=<n>,loc=<m>","metrics":{"files_changed":0,"loc_changed":0}}
