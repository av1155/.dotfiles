---
name: commenting
description: Universal commenting and documentation conventions across all languages. Load when writing or reviewing substantial comments, docstrings, file headers, or migration documentation. Project-specific commenting standards in `docs/commenting-standard.md` (when present) extend or override this baseline.
---

# Commenting standard (universal)

Comments are part of the codebase. Write fewer; make them count.

## The core rule

Comments explain **why**, code explains **what**. If a comment just restates the code, delete it and rename the variable, function, component, or file. A good identifier eliminates the need for the comment.

## Write comments for

- **Intent and rationale.** Why this approach, not the obvious alternative.
- **Non-obvious constraints.** Rate limits, race conditions, API quirks, hidden invariants, regulatory requirements, expand-contract migration phases.
- **Warnings.** "Do not call without holding the lock," "mutates input," "raw body required for signature verification," "must run before any Sentry init."
- **Links.** Issue numbers, RFC / spec references, vendor docs, blueprint sections, CVE IDs.
- **TODO / FIXME / HACK / XXX tags** with an author and a tracking reference: `// TODO(av1155, BAI-247): restore jsx-a11y rules once v7 ships`. A bare `// TODO` is dead weight.
- **Citations** in compliance, financial, or legal code. Name the regulation, PPM section, treaty article, or blueprint section. These are part of the audit trail.

## Avoid

- **Restating code** (`const i = 0; // initialize i`).
- **Commented-out code.** Use git; delete it.
- **Changelog-style narration** (`// 2026-04-15: fixed bug`). That belongs in the commit message.
- **Discovery narration** (`// it took a live incident to find this`, `// after debugging we realized...`, `// we originally tried X but...`). State the constraint; reference the ticket. The story belongs in the PR description or postmortem, not the source.
- **Decorative banners** (`// ===== SECTION =====`). Module structure already does this. SQL migrations and `globals.css` are the documented exceptions where banners help readability.
- **Stale comments.** When you change code, update or remove the comment.
- **Apologetic comments** (`// this is hacky but...`). Either fix it or open a ticket.
- **Obvious type / name duplication** (`amountCents: number; // amount in cents`).
- **AI-edit narration** (`// Claude refactored this from useEffect to useReducer`). The diff already shows it.
- **Process-theater language** (`// verified`, `// post-fix verification`).
- **Long explanations or tutorials.** If it needs a tutorial, write a doc and link to it.

## Per-language doc style

- **TypeScript / JavaScript**: TSDoc on exported symbols (functions, types, components, hooks, schemas). Inline `//` for short notes. Two leading spaces before inline `//`. Never duplicate a TypeScript signature inside the doc; the signature is the source of truth. Forbidden tags: `@type`, inline `@param {type}` (TypeScript already owns types). See the `typescript` rule for full details.
- **Python**: PEP 257 + Google-style docstrings (Sphinx Napoleon). Imperative mood ("Return X", not "Returns X"). `Args:`, `Returns:`, `Raises:` sections. Don't repeat type hints in the docstring. See the `python` rule for full details.
- **CSS / Tailwind**: `/* ... */`. Comment the intent of token groups, not the value. Never comment individual utility classes; the class name is the doc. Long class strings (>10-12 utilities) signal an extraction, not a comment.
- **SQL migrations**: header comment block at the top (purpose, ticket, expand-contract phase if applicable). Inline `--` for non-obvious indexes, cascade choices, RLS predicates, partial-index predicates. Decorative section banners are tolerated in long migration files for readability.
- **YAML / TOML / Dockerfile**: `#` comments. Comment non-default settings only (a non-default `tracesSampleRate`, a `paths-ignore`, a `runner.environment` gate). Don't comment `image:`, `restart:`, `WORKDIR`.
- **HTML / Jinja**: `<!-- -->` for structural markers only. Use `{# ... #}` for developer notes in Jinja; `<!-- -->` ships to the browser. Never put secrets in HTML comments.
- **JSON**: no comments. Document the shape in the README or in a sibling `.md`. JSON-with-comments (`.jsonc`) is the exception.
- **Shell / bash**: `#!/usr/bin/env bash` then `set -euo pipefail` then a header comment block (purpose, required env vars, exit codes). Always comment any `|| true`, `2>/dev/null`, `trap`, or subshell construct. These are where bugs hide.
- **Markdown**: `<!-- -->` sparingly (TOC markers, `<!-- markdownlint-disable -->`). Don't hide prose in HTML comments. Front-matter (`---`) is acceptable for tooling that consumes it.

## TODO conventions

Format: `<TAG>(<author>, <tracker-ID>): <description>`.

- `TODO`: known work to do.
- `FIXME`: bug to fix.
- `HACK`: deliberate workaround; explain why and what would let it go.
- `XXX`: warning to future readers (uncommon, reserve for genuine landmines).

The tracker ID is a Linear / Jira / GitHub issue number, not a date or a vague "later". A TODO without a tracker is a comment that will rot.

## Disable / override directives

Always carry a reason:

- `// eslint-disable-next-line <rule>` — name the specific rule, never bare.
- `// @ts-expect-error <reason>` — one-line justification, never bare.
- `# type: ignore[code]` — specific error code, never bare.
- `# noqa: <rule>` — specific ruff rule, never bare.

A bare disable directive is a code smell; the next reader has no way to know if it is still needed.

## Smell test before committing a comment

1. Does the code already say this? If yes, delete the comment.
2. Could a better identifier eliminate the need? If yes, rename.
3. Will the comment still be true in 6 months? If unsure, link a Linear / Jira / GitHub issue instead.
4. Would a new contributor understand WHY from this comment alone? If yes, keep it.
5. Did the comment narrate edit history rather than design intent? If yes, rewrite or delete.
6. Does the comment cite a regulation, PPM section, treaty, or blueprint? If yes, verify the citation still applies before shipping.

If you cannot answer "yes" to question 4, the comment is probably dead weight.

## Project overrides

A project's `docs/commenting-standard.md` (or equivalent) extends or overrides this baseline. If the project has stack-specific rules (TSDoc tag policy, Sphinx domain choice, Rustdoc style), follow those. This skill is the floor, not the ceiling.
