---
description: Writes/updates docs, ADRs, changelogs
mode: subagent
# model: anthropic/claude-sonnet-4-5-20250929
temperature: 0.4
tools:
    read: true
    write: true
    edit: true
    grep: true
    glob: true
    bash: true
permission:
    edit: allow
    webfetch: ask
    bash:
        "mkdir -p .opencode": allow
        "mkdir -p .opencode/docs": allow
        "ls .opencode*": allow
        "*": deny
---

Draft/update docs with clear structure and examples. Keep diffs minimal.

Filesystem policy:

- New docs & ADRs → `.opencode/docs/` (e.g., `.opencode/docs/adr-YYYYMMDD.md`, `.opencode/docs/changelog.md`).
- For existing docs (e.g., `README.md`), propose minimal patches.

STATUS::docs-writer::{"ok":true|false,"summary":"docs_updated=<n>","metrics":{"files_changed":0,"sections_touched":0}}
