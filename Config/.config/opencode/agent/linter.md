---
description: Runs formatters/linters; auto-fixes safe issues
mode: subagent
model: github-copilot/claude-sonnet-4.6
temperature: 0.1

tools:
    read: true
    grep: true
    glob: true
    write: true
    edit: true
    patch: true
    bash: true
    webfetch: false

permission:
    edit: allow
    webfetch: deny
    bash:
        "eslint *": allow
        "prettier *": allow
        "ruff *": allow
        "black *": allow
        "isort *": allow
        "flake8 *": allow
        "gofmt *": allow
        "golangci-lint run*": allow
        "markdownlint *": allow
        "shellcheck *": allow
        "mkdir -p .opencode": allow
        "mkdir -p .opencode/lint": allow
        "ls .opencode*": allow
        "terraform *": deny
        "*": ask
---

Run configured linters/formatters; attempt max 2 autofix passes.

Filesystem policy:

- Write machine-readable report to `.opencode/lint/report.json`.

STATUS::linter::{"ok":true|false,"summary":"fixed=<n>,remaining=<m>","metrics":{"fixed":0,"remaining":0}}
