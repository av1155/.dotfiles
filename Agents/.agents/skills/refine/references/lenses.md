# Refine lenses

Each lens reviews one shard of the staged diff (a `refine diff` patch file) and reports
findings. Lenses never edit files.

## Output contract

One finding per line:

`<path>:<line> | <scope> | <lens> | <change> | <why it is better>`

- `scope` is `hunk` (a line this change added or modified), `pre-existing` (an unchanged
  line in a file the change touches) or `report-only` (a test, config or existing
  migration file, a public or exported interface, or anything that needs edits in
  another file).
- At most 15 findings per shard, most valuable first; 8 for the `combined` lens.
- Skip what a formatter or linter already owns.
- If nothing is worth changing, print `NO-FINDINGS`.
- End with a line containing only `END-OF-FINDINGS`. Write nothing after it.

## Lenses

### reuse

Flag new code that re-implements something the repository already has. Search shared or
utility modules and files next to the change, and name the existing helper to call
instead. Flag duplication inside the change: blocks that differ slightly and should be
one, including twin code paths where a fix reached one copy but not the other.

### simplification

Flag complexity the change adds: redundant or derivable state, dead code it leaves
behind, nesting that early returns would flatten, single-use wrappers and needless
indirection, casts or `any` that only silence the type checker, and defensive checks for
states the types or the surrounding code already rule out (only when you can show they
are ruled out). Flag comments that restate the code, narrate the change, record edit
history or describe process. Name the simpler form.

### efficiency

Flag wasted work the change introduces: repeated computation or I/O, calls or queries
inside loops, independent operations run one after another, blocking work on hot or
startup paths, unbounded growth. Name the cheaper alternative. Skip micro-optimizations
that cost clarity.

### altitude

Check that each change fixes the cause at the right depth instead of patching a symptom:
special cases layered onto shared code, the same fix repeated at several call sites,
flags threaded through layers. Prefer the simpler, more general change to the underlying
mechanism and name it. A fix that needs edits outside the staged files is `report-only`.

### combined

All four lenses in one pass, for light reviews of small diffs.

## Constraints on every proposal

- Behavior stays identical: outputs, errors and their types, logging and telemetry, side
  effects, ordering, public API.
- Keep validation at system boundaries, security checks, timeouts, limits, retries, and
  error handling that changes outcomes.
- Keep comments that carry rationale, constraints, citations (a regulation, spec or
  ticket), `TODO(owner, ticket)` tags, reasons on lint or type-check suppressions, and
  the header blocks of shell scripts and SQL migrations.
- The repository's own rules win over this rubric: comment depth, protected files,
  required doc blocks, naming conventions.
- A new helper is allowed only when it is private to its file and replaces two or more
  duplicates in the staged files. No new files, dependencies, exports or abstractions.
- No renames for convention alone. Never rename an exported symbol.
- Tests are report-only. Never propose deleting a case, merging distinct cases, or
  changing an assertion.
- Fewer lines is not the goal; clearer code is. No clever one-liners or nested ternaries.
- Split or merge functions only to remove duplication or a real reading burden, never to
  hit a size.
