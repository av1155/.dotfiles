---
description: Upgrades dependencies safely with security/compat checks
mode: subagent
model: github-copilot/gpt-5
temperature: 0.15

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
        "npm ci": allow
        "npm install --no-audit --no-fund": allow
        "pnpm install --frozen-lockfile": allow
        "pnpm up*": allow
        "yarn install --frozen-lockfile": allow
        "yarn upgrade*": allow
        "pip-compile*": allow
        "poetry lock": allow
        "poetry update*": allow
        "uv sync": allow
        "mkdir -p .opencode": allow
        "mkdir -p .opencode/deps": allow
        "ls .opencode*": allow
        "git push": deny
        "terraform *": deny
        "*": ask
---

Perform conservative upgrades; generate an upgrade report. Delegate all tests to @test-runner.

Filesystem policy:

- Write report to `.opencode/deps/upgrade_report.md`.

STATUS::dependency-updater::{"ok":true|false,"summary":"updated=<n>","metrics":{"updated":0,"skipped":0,"build_green":0}}
