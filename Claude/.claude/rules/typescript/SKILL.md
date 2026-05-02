---
name: typescript
description: TypeScript and Next.js conventions for this user. Loads only when reading or editing .ts/.tsx files. Reflects TypeScript 6 (strict-by-default), Next.js 16 (async APIs, proxy.ts, Cache Components), React 19.2.
paths:
  - "**/*.ts"
  - "**/*.tsx"
---

# TypeScript and Next.js conventions

Apply when working with TypeScript files. For backend scalability concerns (queries, caching, queues, observability) defer to the `scalability` skill. For comment authority defer to the `commenting` skill. For auth/secrets/input validation/LLM safety defer to the `security` skill.

## Strictness (TypeScript 6 defaults)

- TypeScript 6 ships `strict: true` as the default; assume it is on. Do not introduce code that would fail strict checks.
- Enable `noUncheckedIndexedAccess`. It adds `| undefined` to indexed access and catches roughly 40% of the runtime errors that bare `strict` misses.
- Use `unknown` over `any` in production code. Narrow at the boundary with a parser (zod), a type guard, or an exhaustive `switch`.
- Full type signatures on every exported function: parameters and return type, no implicit `any`.
- `tsconfig.json` defaults worth confirming: `module: "esnext"`, `target: "es2025"`, `moduleResolution: "bundler"` for Next.js / Vite. Pin `types: []` and add only what you use; the auto-load of all `@types/*` is gone.

## Type definitions

- `interface` for object shapes; `type` for unions, intersections, mapped/conditional types, or aliases of primitives.
- Lowercase built-in generics where applicable; prefer `Array<T>` only when the inline `T[]` is genuinely harder to read.
- Named generics over single-letter when the parameter has a semantic role: `function f<TUser>(...)` over `<T>`.

## Modules and files

- Named exports only, unless the framework requires a default (Next.js page/layout/route, React `lazy`, etc.).
- One concept per file. If a file grows past 300 lines, split before adding more.
- Group related types with their primary export rather than spinning up a separate `types.ts` per concept.

## Errors and validation

- Validate at boundaries (HTTP handlers, queue consumers, file readers, server actions) with zod or equivalent.
- Internal functions trust their inputs; do not re-validate.
- Throw typed errors that extend a known base when callers need to discriminate. Never throw bare strings or `Error` for control flow.

## Next.js 16 specifics

- **Async request APIs are mandatory.** `params`, `searchParams`, `cookies()`, `headers()`, `draftMode()` are now Promises; await before use. The synchronous compat shim from Next 15 is gone.
- **`proxy.ts` replaces `middleware.ts`** for request interception. Node.js runtime only; the `edge` runtime stays on `middleware.ts` (deprecated). Rename the function export to `proxy`.
- **Cache Components are opt-in via `cacheComponents: true` in `next.config.ts`** and the `"use cache"` directive. By default everything dynamic runs at request time. The old `experimental.ppr` and `experimental.dynamicIO` flags are gone.
- **Cache invalidation APIs:**
  - `revalidateTag(tag, profile)` requires a `cacheLife` profile (`'max'` for most cases). Single-arg form is deprecated.
  - `updateTag(tag)` in Server Actions for read-your-writes (immediate refresh).
  - `refresh()` in Server Actions for refreshing uncached data only.
- **Type helpers:** run `npx next typegen` to generate `PageProps<'/route'>`, `LayoutProps`, `RouteContext` for type-safe async params.
- **Image safety:** prefer `images.remotePatterns` over the deprecated `images.domains`. Local images with query strings need `images.localPatterns` to opt in (enumeration-attack defense).
- **Parallel routes** all need an explicit `default.js` (calls `notFound()` or returns `null`) or the build fails.
- **ESLint Flat Config** is the default; `next lint` is removed (run ESLint or Biome directly).
- **Min versions:** Node 20.9, TypeScript 5.1, Chrome/Edge/Firefox 111+, Safari 16.4+.

## React 19.2 patterns

- Server Components are the default; audit every `'use client'`. If a component renders data without interactivity, it should stay server-side.
- Wrap async data dependencies in `<Suspense>` with a layout-accurate skeleton, one boundary per data dependency.
- The React Compiler is stable but not on by default; opt in with `reactCompiler: true` when build-time cost is acceptable.
- Use `useEffectEvent` to extract non-reactive logic out of effects. Use `<Activity>` for hidden-but-stateful UI. Use `<ViewTransition>` for page/state transition animations.
- Prop interfaces document non-obvious props only; do not document `className`, `disabled`, or self-evident handlers.

## Anti-patterns to flag

- `any` in source (allowed only in `.test.ts` mocks with a one-line comment explaining why).
- `as Foo` type assertions on untrusted input. Use parsers instead.
- Default exports from non-framework files.
- Re-exporting just to rename. Prefer renaming at import.
- Files over 300 lines without a split plan.
- Synchronous access to `params` / `cookies()` / `headers()` (Next.js 16 will throw at request time).
- `middleware.ts` for new code (use `proxy.ts`).
- `revalidateTag(tag)` without a `cacheLife` profile (TypeScript will error).
- Implicit caching assumptions; default in Next.js 16 is uncached, opt in with `"use cache"`.

## Tooling

- Format with Prettier (project `.prettierrc.json`).
- Lint with ESLint Flat Config or Biome.
- Run `tsc --noEmit` (or the framework's equivalent) before declaring a task done; strict-mode regressions surface there first.
