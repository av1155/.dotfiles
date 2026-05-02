# AGENTS.md Cross-Tool Standard (May 2026 Reference)

Dense factual reference. Every claim cites the source URL it came from. Items the source does not state are marked "not documented".

---

## 1. Canonical spec at agents.md

Source: <https://agents.md>

- File shape: "AGENTS.md is just standard Markdown. Use any headings you like; the agent simply parses the text you provide." (<https://agents.md>)
- File location: place at "the root of the repository." For monorepos, "place another AGENTS.md inside each package." (<https://agents.md>)
- Subdirectory / nested rule: "Agents automatically read the nearest file in the directory tree, so the closest one takes precedence and every subproject can ship tailored instructions." (<https://agents.md>)
- Precedence: "The closest AGENTS.md to the edited file wins; explicit user chat prompts override everything." (<https://agents.md>)
- Adoption claim on canonical site: "over 60k open-source projects" use AGENTS.md, with 25+ tools listed as supporting it (<https://agents.md>).
- Frontmatter / schema: not required; the canonical spec deliberately specifies no schema, no required sections, and no YAML frontmatter (<https://www.morphllm.com/agents-md-guide>).
- Concatenation behavior at the spec layer: not documented at <https://agents.md>. The canonical page describes only hierarchical precedence ("nearest file wins"); merging semantics are left to each implementing tool.
- Encoding: not documented. Spec only says "standard Markdown" without naming a character encoding (<https://agents.md>).
- File extension: only `.md` is shown in the spec. Other extensions are not documented (<https://agents.md>).

Governance note (May 2026): AGENTS.md was placed under the Linux Foundation's Agentic AI Foundation (AAIF) in December 2025, alongside Anthropic's MCP and Block's Goose; founding members include OpenAI, Anthropic, Google, AWS, Bloomberg, and Cloudflare (<https://hivetrail.com/blog/agents-md-vs-claude-md-cross-tool-standard>).

---

## 2. Codex CLI (OpenAI)

Source: <https://developers.openai.com/codex/guides/agents-md>

Codex implements the most fully specified AGENTS.md loader of the major tools.

- Three-tier discovery, in order:
  1. Global scope: `~/.codex/AGENTS.override.md`, then `~/.codex/AGENTS.md`. Only the first non-empty file at this level is used.
  2. Project scope: starting from the Git root, walk down to the current working directory. At each directory, check `AGENTS.override.md`, then `AGENTS.md`, then any names listed in `project_doc_fallback_filenames`.
  3. Merge: "Codex concatenates files from the root down, joining them with blank lines." (<https://developers.openai.com/codex/guides/agents-md>)
- Per-directory limit: "Codex includes at most one file per directory." (<https://developers.openai.com/codex/guides/agents-md>)
- Override variant: `AGENTS.override.md` is checked before `AGENTS.md` at every level (<https://developers.openai.com/codex/guides/agents-md>).
- Effective precedence: "Files closer to your current directory override earlier guidance because they appear later in the combined prompt." (<https://developers.openai.com/codex/guides/agents-md>)
- Search bound: Codex does not search below the directory where the command was invoked (<https://developers.openai.com/codex/guides/agents-md>).
- Size cap: `project_doc_max_bytes`, default 32 KiB. "Codex skips empty files and stops adding files once the combined size reaches the limit." (<https://developers.openai.com/codex/guides/agents-md>)
- Configurable fallback names: `project_doc_fallback_filenames` array (e.g. `TEAM_GUIDE.md`, `.agents.md`) (<https://developers.openai.com/codex/guides/agents-md>).
- Demonstrated nesting at scale: Codex's own repo ships 88 AGENTS.md files across the tree (<https://www.morphllm.com/agents-md-guide>).

---

## 3. OpenCode

Source: <https://opencode.ai/docs/rules>

- Recognized files, in priority order:
  1. Project `AGENTS.md`
  2. `CLAUDE.md` (legacy fallback for Claude Code migration)
  3. Files referenced via the `instructions` field in `opencode.json`
- Locations searched:
  1. Project root (`AGENTS.md`)
  2. Global user config: `~/.config/opencode/AGENTS.md`
  3. Claude Code compatibility: `~/.claude/CLAUDE.md` (loaded unless disabled by an environment variable)
- Selection within a category: "The first matching file wins in each category. For example, if you have both `AGENTS.md` and `CLAUDE.md`, only `AGENTS.md` is used." (<https://opencode.ai/docs/rules>)
- Subdirectory traversal: rules are located "by traversing up from the current directory." OpenCode walks upward only; it does not walk downward into subdirectories (<https://opencode.ai/docs/rules>).
- Custom instructions: `opencode.json` `instructions` accepts file paths with glob patterns and remote URLs. "All instruction files are combined with your `AGENTS.md` files." (<https://opencode.ai/docs/rules>)
- File encoding / extension beyond `.md`: not documented at <https://opencode.ai/docs/rules>.

---

## 4. Claude Code (Anthropic)

Source: <https://code.claude.com/docs/en/memory> (the docs.claude.com URL redirects here)

- Native AGENTS.md support: explicitly NO. "Claude Code reads `CLAUDE.md`, not `AGENTS.md`." (<https://code.claude.com/docs/en/memory>)
- Recommended interop pattern: "If your repository already uses `AGENTS.md` for other coding agents, create a `CLAUDE.md` that imports it so both tools read the same instructions without duplicating them." Example shown: a `CLAUDE.md` whose first line is `@AGENTS.md` followed by Claude-specific sections (<https://code.claude.com/docs/en/memory>).
- Supported memory locations and precedence (more specific overrides broader) (<https://code.claude.com/docs/en/memory>):
  | Scope | Location |
  | --- | --- |
  | Managed policy | macOS `/Library/Application Support/ClaudeCode/CLAUDE.md`; Linux/WSL `/etc/claude-code/CLAUDE.md`; Windows `C:\Program Files\ClaudeCode\CLAUDE.md` |
  | Project | `./CLAUDE.md` or `./.claude/CLAUDE.md` |
  | User | `~/.claude/CLAUDE.md` |
  | Local (gitignored) | `./CLAUDE.local.md` |
- Lookup / concatenation: walks up the directory tree from CWD, checking each ancestor for `CLAUDE.md` and `CLAUDE.local.md`. "All discovered files are concatenated into context rather than overriding each other. Across the directory tree, content is ordered from the filesystem root down to your working directory." Within a directory, `CLAUDE.local.md` is appended after `CLAUDE.md` (<https://code.claude.com/docs/en/memory>).
- Subdirectory files (below CWD): discovered but not loaded at launch; "they are included when Claude reads files in those subdirectories." (<https://code.claude.com/docs/en/memory>)
- Imports (`@path/to/file` syntax):
  - Both relative and absolute paths allowed; relative paths resolve against the file containing the import, not the working directory.
  - Recursive imports allowed up to depth 5.
  - Imports from outside the project show an approval dialog the first time they are encountered.
  - Imported files are expanded and loaded into context at launch.
  - Source: <https://code.claude.com/docs/en/memory>.
- Path-scoped rules: live under `.claude/rules/*.md` with optional YAML frontmatter `paths:` glob patterns; rules without `paths` load unconditionally (<https://code.claude.com/docs/en/memory>).
- Exclusion: `claudeMdExcludes` setting (settings layers: user, project, local, managed) lets users skip ancestor `CLAUDE.md` files via glob patterns. Managed policy CLAUDE.md cannot be excluded (<https://code.claude.com/docs/en/memory>).
- HTML block comments (`<!-- ... -->`) in CLAUDE.md are stripped before injection; comments inside code blocks are preserved (<https://code.claude.com/docs/en/memory>).
- File extension and encoding: docs only show `.md`; encoding not documented (<https://code.claude.com/docs/en/memory>).
- Status of community request for native AGENTS.md: GitHub issue #6235 on the Claude Code repo, "thousands of upvotes," no Anthropic timeline (<https://hivetrail.com/blog/agents-md-vs-claude-md-cross-tool-standard>).

Conflict in third-party sources: <https://www.morphllm.com/agents-md-guide> lists Claude Code under "Native/Primary Support" for AGENTS.md. This contradicts Anthropic's own docs (<https://code.claude.com/docs/en/memory>), which are the authoritative source. Treat Anthropic's statement as canonical: Claude Code does NOT natively read AGENTS.md as of May 2026; AGENTS.md is consumed only via an explicit `@AGENTS.md` import inside a CLAUDE.md file.

---

## 5. Native vs fallback support summary

Sources: <https://agents.md>, <https://hivetrail.com/blog/agents-md-vs-claude-md-cross-tool-standard>, <https://www.morphllm.com/agents-md-guide>, <https://code.claude.com/docs/en/memory>, <https://opencode.ai/docs/rules>, <https://developers.openai.com/codex/guides/agents-md>.

| Tool | AGENTS.md status | Notes |
| --- | --- | --- |
| OpenAI Codex CLI | Native primary | Most detailed loader; supports `AGENTS.override.md`, configurable fallback names, 32 KiB cap |
| GitHub Copilot | Native | Per <https://hivetrail.com/blog/agents-md-vs-claude-md-cross-tool-standard> |
| Cursor | Native; also reads `.cursor/rules` | Per <https://hivetrail.com/blog/agents-md-vs-claude-md-cross-tool-standard> |
| Windsurf | Native | Per <https://hivetrail.com/blog/agents-md-vs-claude-md-cross-tool-standard> |
| Aider | Native | Per <https://hivetrail.com/blog/agents-md-vs-claude-md-cross-tool-standard> |
| Zed | Native | Per <https://hivetrail.com/blog/agents-md-vs-claude-md-cross-tool-standard> |
| Warp | Native | Per <https://hivetrail.com/blog/agents-md-vs-claude-md-cross-tool-standard> |
| Kilo Code | Native | Per <https://hivetrail.com/blog/agents-md-vs-claude-md-cross-tool-standard> |
| Google Jules / Gemini CLI | Native | Per <https://hivetrail.com/blog/agents-md-vs-claude-md-cross-tool-standard> |
| Factory (Droids) | Native | Per <https://hivetrail.com/blog/agents-md-vs-claude-md-cross-tool-standard> |
| Devin | Native | Per <https://hivetrail.com/blog/agents-md-vs-claude-md-cross-tool-standard> |
| OpenCode | Native primary; CLAUDE.md as legacy fallback | Per <https://opencode.ai/docs/rules> |
| Claude Code | NOT native; consumed only via `@AGENTS.md` import inside CLAUDE.md | Per <https://code.claude.com/docs/en/memory> |

---

## 6. Subdirectory and concatenation comparison

| Tool | Walk direction | Concatenation | Tie-break / precedence |
| --- | --- | --- | --- |
| Codex CLI | Git root → CWD (downward into the path) | Concatenates root-down, joined by blank lines; one file per directory; later (deeper) files override | `AGENTS.override.md` beats `AGENTS.md`; deeper overrides shallower (<https://developers.openai.com/codex/guides/agents-md>) |
| OpenCode | Upward from CWD | Project file plus `instructions` files combined; first match wins per category | `AGENTS.md` beats `CLAUDE.md`; project beats global (<https://opencode.ai/docs/rules>) |
| Claude Code | Walks up from CWD; subdir files load lazily on file read | All ancestor `CLAUDE.md` + `CLAUDE.local.md` concatenated, root → CWD; `CLAUDE.local.md` appended after `CLAUDE.md` per directory | Local > project > user > managed by ordering (specific overrides broader) (<https://code.claude.com/docs/en/memory>) |
| agents.md spec | "Nearest file wins" | Not documented at the spec level | Closest file overrides; chat prompt overrides everything (<https://agents.md>) |

---

## 7. Memory imports (`@path/to/file` syntax)

Only Claude Code documents this syntax in the sources reviewed.

- Triggered by `@path/to/import` anywhere in a `CLAUDE.md` (<https://code.claude.com/docs/en/memory>).
- Relative paths resolve against the importing file, not CWD (<https://code.claude.com/docs/en/memory>).
- Absolute paths and `~` paths are accepted (<https://code.claude.com/docs/en/memory>).
- Recursion permitted up to a maximum depth of 5 hops (<https://code.claude.com/docs/en/memory>).
- External imports trigger a one-time approval dialog; declining disables them silently for that project (<https://code.claude.com/docs/en/memory>).
- Imports load fully into context at session launch (no lazy-load) (<https://code.claude.com/docs/en/memory>).
- Equivalent import syntax for Codex, OpenCode, Cursor, etc.: not documented in the sources reviewed. OpenCode supports an `instructions` array in `opencode.json` (file paths, globs, and remote URLs) which is conceptually similar but uses configuration rather than inline `@` syntax (<https://opencode.ai/docs/rules>).

---

## 8. File extensions and encodings

- `agents.md` spec: only `.md` is shown; encoding not documented (<https://agents.md>).
- Codex: only `AGENTS.md` and `AGENTS.override.md` recognized by default; additional names allowed via `project_doc_fallback_filenames` (still expected to be Markdown). Encoding not documented (<https://developers.openai.com/codex/guides/agents-md>).
- OpenCode: `AGENTS.md` and `CLAUDE.md`; arbitrary files via `instructions` glob patterns. Encoding not documented (<https://opencode.ai/docs/rules>).
- Claude Code: `CLAUDE.md`, `CLAUDE.local.md`, plus any `.md` files under `.claude/rules/`. Encoding not documented (<https://code.claude.com/docs/en/memory>).

No source in this review specifies a required character encoding. UTF-8 is implicit because all examples use it but is not stated.

---

## 9. Comparison table

| Attribute | agents.md spec | Codex CLI | OpenCode | Claude Code |
| --- | --- | --- | --- | --- |
| Primary filename | `AGENTS.md` | `AGENTS.md` (+ `AGENTS.override.md`) | `AGENTS.md` (CLAUDE.md fallback) | `CLAUDE.md` (+ `CLAUDE.local.md`) |
| AGENTS.md native? | n/a (this is the spec) | Yes | Yes | No (interop via `@AGENTS.md` import) |
| Locations | Repo root + per-package | `~/.codex/`, then Git root → CWD | Project root, `~/.config/opencode/`, `~/.claude/CLAUDE.md` | Managed policy path, `./CLAUDE.md` or `./.claude/CLAUDE.md`, `~/.claude/CLAUDE.md`, `./CLAUDE.local.md` |
| Walk direction | Toward edited file (nearest wins) | Git root → CWD | Upward from CWD | Upward from CWD; subdir files lazy-loaded |
| Concatenation | Not specified | Root-down with blank-line joins | First match per category, plus `instructions` files | All ancestors concatenated root → CWD |
| One-file-per-dir limit | Not specified | Yes | Implicit (first match wins) | No: `CLAUDE.md` and `CLAUDE.local.md` both load |
| Size cap | Not specified | 32 KiB default (`project_doc_max_bytes`) | Not documented | Not documented (200 lines recommended; full file always loaded) |
| Override file variant | Not specified | `AGENTS.override.md` | Not documented | `CLAUDE.local.md` (gitignored) |
| Path-scoped rules | Not specified | Not documented | Not documented | `.claude/rules/*.md` with `paths:` frontmatter |
| Inline imports | Not specified | Not documented | Not documented (uses config `instructions`) | `@path/to/file`, depth 5 |
| Tie-break | Closest file > parent; user chat overrides all | Override > standard; deeper > shallower | First match per category; AGENTS.md > CLAUDE.md | More-specific scope > broader (managed > user > project > local concat order; concat means later wins) |
| File extensions | `.md` | `.md` (configurable names) | `.md` (plus globbed `instructions`) | `.md` |
| Encoding | Not documented | Not documented | Not documented | Not documented |
| HTML comment stripping | Not documented | Not documented | Not documented | Block-level HTML comments stripped before injection |
| Frontmatter required | None | None | None | None for `CLAUDE.md`; YAML `paths:` for `.claude/rules/*.md` |

---

## Sources

- <https://agents.md>
- <https://developers.openai.com/codex/guides/agents-md>
- <https://opencode.ai/docs/rules>
- <https://code.claude.com/docs/en/memory> (canonical; <https://docs.claude.com/en/docs/claude-code/memory> 301-redirects here)
- <https://hivetrail.com/blog/agents-md-vs-claude-md-cross-tool-standard>
- <https://www.morphllm.com/agents-md-guide>
- <https://github.com/openai/codex>
