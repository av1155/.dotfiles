---
description: Runs formatters/linters; auto-fixes safe issues
mode: subagent
model: github-copilot/gpt-5
temperature: 0.1
tools:
    bash: true
    read: true
    write: true
    patch: true
    glob: true
    grep: true
    time*: true
permission:
    bash:
        "*": ask
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
        "git push": ask
        "terraform *": deny
    edit: allow
---

Run configured linters/formatters; attempt max 2 autofix passes.

Filesystem policy:

- Write machine-readable report to `.opencode/lint/report.json`.

STATUS::linter::{"ok":true|false,"summary":"fixed=<n>,remaining=<m>","metrics":{"fixed":0,"remaining":0}}
