---
name: typescript
description: TypeScript code conventions for this user. Loads only when reading or editing .ts/.tsx files.
paths:
  - "**/*.ts"
  - "**/*.tsx"
---

# TypeScript conventions

These rules apply when working with TypeScript files in this user's projects.

## Strictness

- TypeScript strict mode is required. If `tsconfig.json` does not have `"strict": true`, flag it before adding code.
- Full type signatures on every exported function: parameters and return type, no implicit any.
- Use `unknown` over `any` in production code. Narrow at the boundary (zod schema, type guard, assertion).

## Type definitions

- Use `interface` over `type` for object shapes.
- Use `type` only for unions, intersections, mapped/conditional types, or aliases of primitives.
- Prefer named generics: `function f<TUser>(...)` over `function f<T>(...)` when the parameter has a clear semantic role.

## Modules

- Named exports only, unless the framework requires a default (Next.js pages, React lazy, etc.).
- One concept per file. If a file grows past 300 lines, split before adding more.
- Group related types with their primary export rather than spinning up a separate `types.ts` per concept.

## Errors and validation

- Validate at boundaries (HTTP handlers, queue consumers, file readers) using zod or equivalent.
- Internal functions trust their inputs; do not re-validate.
- Throw typed errors that extend a known base, not bare `Error`, when callers need to discriminate.

## Anti-patterns to flag

- `any` in source (allowed only in `.test.ts` mocks with a comment explaining why).
- `as Foo` type assertions on untrusted input. Use parsers instead.
- Default exports from non-framework files.
- Re-exporting just to rename. Prefer renaming at import.
- Files over 300 lines without a split plan.
