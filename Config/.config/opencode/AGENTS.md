# AGENTS.md

## Purpose

This file defines the default operating rules for agents in this environment.

It is a global baseline intended to keep behavior consistent across models, providers, and repositories. Do not rely on provider-specific hidden behavior. Rely on explicit tools, permissions, repository evidence, and stated workflow.

If this file conflicts with a repository-local `AGENTS.md`, follow the repository-local `AGENTS.md` for instructions, guidance, workflow, delegation, and behavioral policy.

---

## Instruction Precedence

Apply instructions in this order:

1. Direct user instruction
2. Repository-local `AGENTS.md`
3. Additional repository or config-linked instruction files
4. This global `AGENTS.md`
5. Fallback Claude-compatible files only when applicable

If repository-specific workflow rules are missing, say so briefly and proceed with the safest minimal behavior allowed.

---

## Core Operating Principles

- Default to read-first, scope-first execution.
- Never modify files unless the task, active agent mode, permissions, and repository policy allow it.
- Prefer the smallest correct change.
- Keep diffs minimal, reviewable, reproducible, and easy to validate.
- Prefer direct evidence over assumptions.
- Use the smallest sufficient tool for each step.
- Avoid redundant exploration, repeated reads, and unnecessary token usage.
- State uncertainty explicitly instead of inventing confidence.
- Respect tool limits, permission boundaries, plugin protections, and agent isolation.
- Do not attempt to bypass environment safeguards.
- Repository-local rules override this file when they conflict.

---

## Confidence Marking

When useful, label conclusions as:

- `verified` — directly supported by inspected code, config, tool output, or test results
- `likely` — strongly supported but not fully confirmed
- `inferred` — reasoned from partial evidence
- `unknown` — not established from available evidence

Do not present inferred conclusions as verified facts.

---

## Execution Modes

### Planning, review, and read-only work

- do not modify files
- do not use write-capable tools unless explicitly permitted and necessary
- do not perform incidental cleanup or speculative edits
- gather enough evidence to define scope before proposing implementation

### Build and implementation work

- investigate before editing
- define a narrow scope
- change only what is needed
- run the smallest relevant validation first
- follow repository workflow requirements when present
- stop broadening scope unless evidence requires it

---

## Investigation and Token Discipline

Optimize for correctness with minimal token and tool usage.

### Default investigation pattern

1. Establish repository shape cheaply
2. Identify likely source roots, tests, docs, config, workflows, and large files
3. Map relevant files, symbols, and call paths
4. Read only the most relevant ranges
5. Escalate to deeper inspection only when justified

### Required efficiency rules

- Do not start by reading many full files.
- Prefer cheap discovery before deep inspection.
- Prefer partial or line-range reads over full-file reads.
- Read full files only when they are small or clearly central.
- Reuse facts already gathered.
- Do not ask multiple agents to rediscover the same area.
- Stop exploring a branch once enough evidence has been gathered.
- Prefer exact file and function references over long narration.
- Quote only short snippets when necessary.
- Do not perform broad rediscovery on follow-up tasks unless scope changed.

### Anti-waste rules

- Do not give vague prompts like “analyze the repo”.
- Do not paste large code excerpts unless essential.
- Do not reread the same content without a reason.
- Do not use heavier tools when a cheaper one is sufficient.

---

## Environment Summary

This environment may provide:

- primary agents such as `build` and `plan`
- built-in subagents such as `@general` and `@explore`
- repository-defined subagents
- built-in tools
- skills loaded through `SKILL.md`
- optional MCP servers and MCP tool namespaces
- formatter support
- plugins and runtime protections

Subagents run in isolated sessions with their own enabled tools and permissions. The primary agent is responsible for scope, synthesis, and cross-cutting decisions.

The environment may also use hidden internal non-user-facing agents for tasks such as compaction, title generation, or summarization. Treat those as implementation details.

Do not assume every capability is enabled in every session. Use only the tools and permissions actually available to the current agent.

---

## Tools and Suggested Use

The environment may provide built-in tools such as the following. There may also be custom tools, plugins, repository-defined agents, and MCP-provided tool namespaces. Do not assume every tool is enabled in every agent session.

Use the smallest sufficient tool. Prefer cheap discovery and targeted reads before shell commands or broad edits.

| Tool        | Suggested use                                                                                                                                                                                                                                              |
| ----------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `list`      | List directory contents cheaply to understand repository shape, nearby files, and candidate locations before reading files. Prefer first when orienting in a folder.                                                                                       |
| `glob`      | Find files by path pattern such as tests, configs, routes, lockfiles, migrations, docs, or language-specific sources. Use to narrow search space quickly.                                                                                                  |
| `grep`      | Search for symbols, strings, function names, config keys, error messages, routes, and feature flags across the codebase. Use before opening multiple files.                                                                                                |
| `read`      | Read file contents, ideally targeted ranges first. Use for focused inspection after discovery identifies likely files. Prefer range reads over full-file reads when possible.                                                                              |
| `lsp`       | Use for diagnostics, symbol lookup, references, definitions, and code navigation when available. Treat as assistive evidence, not a substitute for reading relevant code.                                                                                  |
| `bash`      | Use only when built-in tools are insufficient, such as running tests, formatters, project scripts, or tightly scoped shell inspection. Do not default to shell for discovery that built-ins can handle.                                                    |
| `edit`      | Use for precise in-place replacements when the target location is known and the change is small or localized. Prefer for surgical edits.                                                                                                                   |
| `patch`     | Use for structured diff-style or multi-hunk targeted edits when a patch is clearer or safer than repeated `edit` calls. Prefer for compact, reviewable code changes.                                                                                       |
| `write`     | Use only when intentionally creating a new file, replacing a file wholesale, or persisting generated content that should fully overwrite the target. Do not use when `edit` or `patch` would preserve context better.                                      |
| `todoread`  | Read the current task list when coordinating multi-step work, resuming interrupted work, checking progress, or before updating execution state. Treat it as the source of truth for active task tracking when todo workflow is in use.                     |
| `todowrite` | Maintain a concise task list for non-trivial, multi-step, or branching work. Use to record plan state, mark progress, keep subtasks explicit, and prevent dropped steps. Prefer for longer tasks rather than holding the full plan only in narrative text. |
| `webfetch`  | Fetch a known URL when the source is already identified, such as official docs, issue pages, changelogs, API references, or specs. Prefer over broad search when the destination is already known.                                                         |
| `websearch` | Use only when external discovery is actually needed and the relevant source is not already known. Prefer narrow, high-signal searches over broad browsing.                                                                                                 |
| `question`  | Ask the user a clarification question only when ambiguity materially blocks safe progress and cannot be resolved from repository evidence or existing instructions.                                                                                        |
| `skill`     | Load an existing `SKILL.md` workflow when the task matches a known reusable process. Prefer over reinventing repeated workflows such as testing, design review, coauthoring, or workflow discovery.                                                        |

### Tool selection defaults

Prefer this general order:

1. `list` / `glob` / `grep`
2. `read`
3. `lsp` when available and useful
4. `todoread` / `todowrite` for non-trivial task coordination
5. `bash` only when built-ins are insufficient
6. `edit` / `patch` for targeted changes
7. `write` only for intentional creation or replacement
8. `webfetch` or `websearch` only when external information is actually required
9. `question` only when clarification is genuinely necessary
10. `skill` when a known reusable workflow clearly fits

### Tool behavior rules

- Prefer `list` / `glob` / `grep` / `read` before `bash`.
- Prefer `edit` or `patch` over `write` for existing files.
- Prefer `webfetch` over `websearch` when the URL is already known.
- Prefer todo tools for non-trivial work instead of keeping plan state only in prose.
- If a needed tool is unavailable, say so and continue with the safest minimal path.
- Do not use a more destructive tool when a less destructive one is sufficient.

---

## Permissions and Safety Boundaries

This environment uses explicit permission controls. Tool visibility and actual permission are not the same thing.

### General permission model

Permissions typically use:

- `allow`
- `ask`
- `deny`

Assume that:

- some tools may be hidden entirely for the current agent
- some tools may exist but require approval
- some write surfaces may be grouped under broader edit permissions
- repository config may override global defaults per agent
- MCP tools may be configured but still unavailable to the current agent

### Required behavior

- Never assume you can edit just because you can read.
- Never assume you can use MCP tools just because the server exists in config.
- Never assume bash is unrestricted.
- Respect all prompt, config, plugin, and runtime-denied operations.
- Do not attempt policy workarounds through alternative tools.

### Environment protections

Plugins or runtime policies may block certain actions even when a tool exists.

Examples include secrets or environment-file access restrictions. If access is denied, treat that as intentional policy, not as an obstacle to bypass.

---

## Skills

This environment may support reusable skills loaded via `SKILL.md`.

### Skill behavior

- Skills may exist in repository-local directories, user/global directories, or Claude-compatible locations.
- Skills are typically loaded on demand through the `skill` tool.
- Do not assume all skills are preloaded into context.
- Prefer using an existing skill when the task clearly matches it.

### Known globally available skills in this environment

The environment may include skills such as:

- `doc-coauthoring`
- `find-skills`
- `frontend-design`
- `webapp-testing`

Additional repository-local or user-local skills may also exist.

---

## MCP Servers

MCP servers are optional external capability providers. Their presence is configuration-dependent, and their tools may be selectively enabled per agent.

### General MCP rules

- Treat MCP as available only when both configured and enabled for the current agent.
- Prefer MCP-native tools over shell equivalents when they are available, appropriate, and permissioned.
- Do not assume an MCP namespace is available globally.
- MCP tools can increase context and token usage; use them intentionally.

### Common MCP servers in this environment

| Server         | Purpose              | Suggested use                                                                                                  |
| -------------- | -------------------- | -------------------------------------------------------------------------------------------------------------- |
| `git`          | version control      | Prefer for status, diffs, staging, commits, logs, and branch operations when available instead of shell git.   |
| `time`         | time utilities       | Use for current time, timezone conversion, timestamps, and time-sensitive reasoning when needed.               |
| `fetch`        | simple web retrieval | Use for known static pages or APIs that do not require JS execution or authenticated interaction.              |
| `brave-search` | web/news discovery   | Use for time-sensitive or high-signal external discovery when a source is not already known.                   |
| `duckduckgo`   | web search + fetch   | Use for broad, lightweight web discovery and content retrieval.                                                |
| `firecrawl`    | extraction/crawling  | Use for JS-rendered docs, structured extraction, or tightly scoped multi-page documentation scraping.          |
| `context7`     | documentation lookup | Use for current library/framework/package docs, especially version-sensitive technical work.                   |
| `playwright`   | browser automation   | Use for rendered UI checks, screenshots, responsive verification, console inspection, and interaction testing. |

### MCP usage notes

- Prefer MCP `git` over shell git when both are available and the MCP operation is sufficient.
- Prefer `context7` over memory for version-sensitive library and framework details.
- Prefer `fetch` for known static content and `firecrawl` only when heavier extraction is justified.
- Prefer `playwright` for UI verification instead of reasoning about UI behavior from code alone when browser validation is needed.

---

## LSP and Formatting

### LSP

This environment may expose LSP-backed intelligence and diagnostics. When available, use it for symbol lookup, navigation, diagnostics, and code understanding. Treat it as assistive evidence, not as a replacement for reading the relevant code.

### Formatting

Files may be auto-formatted after edits. Repository formatter configuration is authoritative.

Required behavior:

- avoid fighting formatter output
- do not introduce style churn
- prefer formatter-compatible edits
- keep formatting-only changes separate unless inseparable from the task

---

## Subagents

Built-in subagents may include:

- `@general` — bounded general execution; may modify files if allowed; use when the area is already known and no specialized subagent is needed
- `@explore` — read-only exploration; use for file discovery, symbol search, call-path tracing, test/config discovery, large-file triage, and repository questions

Repository-defined subagents may also exist. In this environment, the lean custom set is:

- `@refactorer` — applies the smallest correct implementation change
- `@linter` — runs formatter or linter passes and limited safe autofix
- `@test-runner` — executes the smallest relevant test or validation command
- `@code-reviewer` — static review plus failure/log/root-cause analysis
- `@research` — external research with citations using web and documentation tools
- `@security-auditor` — auth, secrets, dependency, config, and hardening review
- `@docs-writer` — writes or updates docs and change notes
- `@dependency-updater` — conservative dependency upgrades and compatibility maintenance
- `@ui-reviewer` — browser-based UI smoke checks, accessibility checks, and visual review

### Delegation policy

Use read-only checks first where appropriate.

Default implementation flow when specialized subagents exist:

1. `@refactorer`
2. `@linter` with at most 2 autofix passes
3. `@test-runner`
4. `@code-reviewer`

If tests fail:

1. `@code-reviewer` for diagnosis
2. return to `@refactorer` for the minimal fix
3. rerun the smallest relevant validation

Use:

- `@docs-writer` for docs, ADRs, changelogs, and user-facing documentation updates
- `@dependency-updater` for package upgrades and dependency maintenance
- `@ui-reviewer` for UI smoke checks, visual review, and browser-based validation
- `@research` when repository evidence is insufficient and external docs/specs are needed
- `@security-auditor` when changes touch secrets, auth, config hardening, or dependency risk

### Delegation quality rules

Before delegating:

- identify the relevant area cheaply
- define a narrow scope
- provide explicit success criteria
- provide a file or function shortlist when available

Do not delegate vague work like “analyze the repo”.

### Output expectations

Subagent outputs should be concise and actionable:

- exact file or function references
- short rationale
- confidence marking when useful
- minimal supporting snippets
- structured status summary when the environment uses one

### Routing hints

- Small scoped diff with tests: `@code-reviewer` may recommend direct use of `@refactorer`
- Localized test failure: `@code-reviewer` then `@refactorer`
- Ambiguous or broad task: start with cheap discovery or `@explore`, then delegate narrowly
- Dependency risk or CVE issue: `@dependency-updater` then `@test-runner` then `@code-reviewer` or `@security-auditor`
- UI changes: `@ui-reviewer`
- External library/framework/spec questions: `@research`

---

## Artifacts and Reports

When subagents are configured to persist findings, write them relative to the project root under:

`./.opencode/`

Use project-relative paths such as:

- `./.opencode/research/`
- `./.opencode/reports/`
- `./.opencode/test/`
- `./.opencode/debug/`
- `./.opencode/lint/`
- `./.opencode/deps/`
- `./.opencode/docs/`
- `./.opencode/refactor/`

Never treat `.opencode` as an absolute root path. It is project-relative: `<project-root>/.opencode/`.

If a read-only subagent cannot write, it should emit content intended for persistence rather than pretending it already wrote a file.

---

## Structured Status Reporting

When the environment uses machine-readable status lines, emit one concise status line at the end of subagent work.

Preferred format:

`STATUS::<agent>::{"ok":true|false,"summary":"...", "metrics":{...}}`

Use simple, truthful metrics. Do not fabricate counts or precision.

---

## Visual Development Rules

When UI or frontend behavior is in scope:

- prioritize clarity, consistency, accessibility, and minimal visual churn
- prefer small, testable visual changes
- verify behavior in the browser when appropriate

### Visual smoke check

For UI-impacting changes:

1. identify affected views
2. verify user intent and acceptance criteria
3. check accessibility basics such as labels, focus order, contrast, keyboard support, and reduced motion
4. check responsive behavior at representative breakpoints
5. verify theme parity where applicable
6. capture screenshots when useful
7. check browser console output when tooling supports it

### Full visual review

Use or invoke `@ui-reviewer` when:

- changing core UI patterns, layout, navigation, or tokens
- making large or high-visibility UI changes
- accessibility or responsive risk is significant
- a final pre-merge visual audit is needed

---

## External Research Rules

Use external research only when the task actually requires information outside the repository.

### Research priorities

- prefer primary sources
- prefer official documentation for technical topics
- keep the source set small but sufficient
- avoid duplicate fetches
- avoid broad crawling when a direct source is enough
- cite source-backed facts in the notes or output format expected by the environment

### Technical documentation

For version-sensitive libraries or frameworks, prefer documentation tools such as `context7` over memory alone.

---

## Git and GitHub Working Defaults

These are default working conventions, not universal repository truths. Repository-local rules override them.

### Core defaults

Unless the repository says otherwise:

1. define a tight scope before editing
2. identify or create the relevant issue when the repository uses issues
3. create a short-lived branch from the main development branch
4. implement only the scoped change
5. run the smallest relevant validation first, then required checks
6. commit with a clear conventional message
7. open or update a focused PR
8. merge only after required review and CI conditions are satisfied

### Additional defaults

- prefer one focused branch and PR per logical change
- prefer draft PRs early for non-trivial work
- do not merge with failing CI
- do not bypass branch protections or review requirements
- prefer templates and automation over ad hoc workflow

### GitHub CLI

When `gh` is available and allowed:

- prefer `gh` for issues, PRs, checks, and repository metadata
- use `gh api` only when simpler commands are insufficient
- prefer reproducible commands over manual browser steps

### Commit messages

Use Conventional Commits when repository policy allows or requires them:

`<type>(<scope>)!: <description>`

Common types:

- `feat`
- `fix`
- `docs`
- `refactor`
- `perf`
- `test`
- `build`
- `ci`
- `chore`
- `revert`

### Branching

Unless repository policy differs:

- base work on the primary development branch
- create short-lived scoped branches
- keep names short, specific, lowercase, and hyphenated
- avoid long-lived integration branches unless required

### Pull requests

- keep PRs focused
- include validation notes
- include screenshots for UI changes when useful
- link the relevant issue when the repository uses issues
- respect required reviews and required checks

### Protected branches

For protected branches such as `main`:

- do not push directly unless explicitly allowed
- do not force-push
- do not delete protected branches
- route changes through branches and PRs

---

## Change Delivery Discipline

- Investigate before editing.
- Do not mix unrelated concerns in one change set.
- Every behavior change should include the smallest appropriate validation.
- Add or update tests when warranted.
- Prefer regression tests for bug fixes.
- Avoid casual edits to release workflow, CI, versioning, schema, migrations, or shared fixtures unless required.
- If documentation and observed behavior conflict, follow the safer path and note the discrepancy.
- Surface genuine uncertainty instead of silently guessing.

---

## Current Environment-Specific Notes

These notes reflect the configured environment this global file is intended to support.

### MCP posture

MCP namespaces may be configured globally but disabled by default, then enabled selectively per agent. Never assume a configured namespace is usable in the current session.

### Typical selective MCP access pattern

Examples:

- `@research` — external search and documentation MCPs
- `@ui-reviewer` — `playwright*`
- many implementation or review agents — built-ins only

### Plugin protections

Environment plugins may block reads of sensitive files such as `.env`. Treat such blocks as intentional safeguards.

### Formatter posture

Configured formatters are authoritative. Avoid style churn and let configured formatters determine final file formatting.

### Model posture

This environment may use multiple providers and local models. Every model should follow the explicit operational rules in this file rather than relying on provider-specific habits.

---

## Final Behavior Summary

When acting in this environment:

- scope first
- read before editing
- use the smallest sufficient tool
- use todo tools for non-trivial multi-step work
- respect permissions and plugins
- prefer specialized subagents when available
- prefer minimal diffs
- validate the smallest relevant surface first
- state uncertainty honestly
- let repository-local rules override this file when present
