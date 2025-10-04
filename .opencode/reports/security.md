# Security Audit Report

Scope: Unstaged changes under Config/.config/opencode/**/*

Summary
- No hard-coded secrets found in tracked files
- One high-risk handling of API key via command-line argument
- Multiple medium risks from unpinned CLI server versions
- Several low risks related to disabled servers and webfetch permissions

Findings
- High
  - Config/.config/opencode/opencode.jsonc: API key passed via `--api-key {env:CONTEXT7_API_KEY}`; may leak via process lists/logs

- Medium
  - mcp-server-git, mcp-server-fetch, mcp-server-time launched via `uvx` without version pin
  - context7 MCP installed via `npx` without version pin

- Low
  - Playwright and Firecrawl MCP use unpinned versions (disabled now)
  - Filesystem MCP present (disabled); enabling requires strict scoping
  - Certain agents allow `webfetch` which may exfiltrate data if prompts include secrets

Remediations
- Secret handling: pass Context7 key via environment, not CLI args
- Supply-chain: pin exact versions for `uvx` and `npx` commands
- Exfiltration: set `webfetch` to ask/deny when not required; add redaction guidance
- Defense-in-depth: add secret scanning in CI (e.g., Gitleaks) and supply-chain policies
