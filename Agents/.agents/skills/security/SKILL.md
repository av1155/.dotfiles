---
name: security
description: Security conventions for code that handles secrets, authentication, user input, external calls, cryptography, dependencies, or LLM/AI integrations. Load when working with auth flows, API endpoints, webhooks, file uploads, queue consumers, prompts to LLMs, or anything that touches untrusted data.
---

# Security standard (universal)

Security is layered. No single rule prevents every class of attack. Apply the principles below as defense-in-depth; the absence of any one of them is a finding.

For backend scale and rate limit specifics, defer to the `scalability` skill (overlap exists at boundaries: rate limits, timeouts, input validation).

## Secrets

- Never hardcode credentials, API keys, tokens, or PEM contents in source.
- Read from environment variables loaded from a secret manager (Vercel env vars, Doppler, 1Password Connect, AWS Secrets Manager, GCP Secret Manager). `.env` files are local-only; never commit them.
- `.env`, `.env.local`, `.env.*.local`, `secrets/`, `**/credentials*`, `**/*.pem`, `~/.ssh/`, `~/.aws/`, `~/.gnupg/`, `~/.docker/config.json`, `~/.npmrc`, `~/.config/gh/` should be in the project's deny-list and `.gitignore`.
- When committing, run a secret-scanner pre-commit hook (gitleaks, trufflehog, or the platform's equivalent).
- Rotate any credential that ever touched a commit, log file, screenshot, paste buffer, or chat — assume it is compromised.

## Input validation

- Validate at every boundary that touches untrusted data: HTTP handlers, server actions, route handlers, queue consumers, webhook receivers, file readers, message handlers.
- Use a parser, not a hand-rolled regex. zod for TypeScript, pydantic v2 for Python.
- Reject early; return a 4xx with a stable error shape rather than coercing.
- Length-limit every text input; the absence of a length cap is an availability bug.
- Internal functions trust their inputs. Validation belongs at the system perimeter, not on every call.

## Output encoding and injection

- **SQL injection**: use parameterized queries / prepared statements. Never f-string or template-literal user input into SQL. ORMs that build raw SQL still need parameters.
- **Cross-site scripting (XSS)**: escape on output, not on input. Frameworks escape text children, but raw HTML injection APIs, `href` URLs, and `style` strings are not auto-escaped. For HTML produced from user content, sanitize with DOMPurify (browser) or Bleach (Python) / Ammonia (Rust).
- **Cross-site request forgery (CSRF)**: framework token (Next.js Server Actions, Django CSRF middleware, Rails authenticity token, gorilla/csrf for Go). SameSite cookies are not enough on their own.
- **Command injection**: never build shell commands by string-concatenating user input. Use the language's `subprocess` / `child_process` API with the args array form.
- **Server-side request forgery (SSRF)**: any code that fetches a URL provided by the user must run through an SSRF filter (`ssrf-req-filter` for Node, `ssrf_filter` for Ruby) and a host allow-list. Block private CIDRs, link-local, and metadata endpoints by default.

## Authentication and session management

- Use a vetted auth library (Auth.js, Clerk, Auth0, Supabase Auth, better-auth, Keycloak). Do not roll your own session/JWT/password verification.
- Passwords: argon2id (preferred) or bcrypt with cost ≥ 12. Never SHA-anything for passwords.
- Sessions: rotate on privilege change, invalidate on logout, set short absolute lifetimes plus longer refresh windows.
- JWTs: short-lived access tokens (≤ 15 min), refresh tokens server-side, validate `iss` / `aud` / `exp` / `nbf` on every request.
- 2FA / MFA on admin paths and financially significant actions; TOTP via authenticator apps, not SMS.

## Authorization

- Default-deny. Every endpoint asks "is this caller allowed to do this on this resource?" before performing the action.
- For row-level access: enforce in the database (Supabase RLS, PostgreSQL row policies) so a buggy ORM call cannot leak.
- The `(SELECT auth.uid())` subselect pattern in Postgres RLS predicates is required for per-statement caching; bare `auth.uid()` re-executes per row and shows up in `pg_stat_statements`.
- Never trust client-supplied `userId` / `tenantId`; resolve from the verified session token.

## Cryptography

- Use vetted libraries: Google Tink (multi-language), libsodium / NaCl, Themis. Do not implement AES, RSA, ECDSA, or HMAC by hand.
- Never invent your own crypto protocol. If you find yourself xor-ing bytes or implementing a "key derivation function", stop.
- Use authenticated encryption (AES-GCM, ChaCha20-Poly1305). Don't use AES-CBC without a separate MAC.
- Random: `crypto.randomBytes` / `secrets.token_bytes` / `os.urandom`. Never `Math.random()` for security purposes.

## HTTP security headers

- Apply via Helmet (Node), `secure_headers` (Ruby), Django middleware, or framework default (Next.js / SvelteKit have built-in `headers()` config).
- Required: `Content-Security-Policy` with nonce or hash, `Strict-Transport-Security`, `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`, `Permissions-Policy` to deny unused features.
- CSP nonce: generate per-request, attach in middleware / proxy.ts, propagate to the renderer. A static `script-src 'unsafe-inline'` defeats the purpose.

## Cookies

- `Secure`, `HttpOnly`, `SameSite=Lax` (or `Strict` for most session cookies). `SameSite=None` only with `Secure` and a documented reason (cross-site embedding).
- Path-scope cookies to the route they serve. Don't set everything at `/`.
- Encrypted / signed cookies for any state worth tampering with.

## Dependency hygiene

- Pin versions in lockfiles. Run a CVE scan (Dependabot, Renovate, Snyk, GitHub's built-in alerts, `npm audit`, `pnpm audit --prod`, `pip-audit`) on every PR.
- Review the dependency graph before adopting a new direct dependency. A 50-byte utility with 14 transitive deps is a supply-chain risk.
- Verify package signatures where the registry supports it (npm provenance, PyPI Trusted Publishers, Cargo crates.io).

## Logging and observability

- Never log secrets, full credit card numbers, full SSNs, raw passwords, session tokens, or full bearer tokens. Log a hash or a prefix at most.
- Structured JSON logs with `request_id`, `trace_id`, `user_id`. Stack traces only in non-production logs unless a Sentry-style PII scrubber is in front.
- Audit-log security-relevant events (login, password reset, role change, admin action, financial action, data export) with actor, target, and timestamp.

## File uploads

- Limit MIME type, file size, and dimensions before processing.
- Strip EXIF / metadata from images.
- Store in object storage with a content-addressed key, not the user-supplied filename.
- Scan with ClamAV or a cloud scanner before any user can download what another user uploaded.

## LLM / AI integrations (prompt injection and adjacent threats)

The OWASP Top 10 for LLM Applications puts prompt injection at #1. AI agents amplify the impact. Apply these patterns when calling LLMs:

- **Trust boundary.** Treat anything that came from a user, a fetched web page, a document, an email, a search result, or another LLM as untrusted. Including the output of your own chain.
- **Structural separation.** In the prompt, mark the trust boundary explicitly (`<system_instructions>` vs `<user_data>` blocks, JSON envelope, or distinct messages). State that content inside `<user_data>` is data, not instructions.
- **Output filtering.** Validate LLM output against the action you intended to take. If the model returns a tool call, verify its arguments against an allow-list before executing.
- **Least privilege for tools.** Tools the LLM can call must have minimal scope. Read-only DB user, scoped API tokens, sandboxed code execution.
- **Human-in-the-loop** for high-impact actions: writes to production, money movement, deletions, sending external messages. The user authorizes the action, not the model.
- **Dual-LLM pattern** for content from untrusted sources: a quarantined model summarizes / extracts; a privileged model takes the action based only on the structured summary.
- **Caps and budgets.** Per-user rate limits, per-request token caps, max tool-call depth, max tool calls per turn. An agent with no caps is a DoS vector against itself.
- **Logging.** Persist every prompt and every tool call with `request_id`, model, version, prompt cache markers. Without these, post-incident forensics is impossible.
- **Secrets in context.** Prompts go into vendor logs, training corpora opt-outs notwithstanding. Never put a real secret into a prompt; reference an opaque handle and resolve it server-side.

## Defense-in-depth checklist before shipping

- [ ] No hardcoded secrets; secret-scanner pre-commit pass.
- [ ] Every untrusted boundary uses a parser, not regex.
- [ ] Every SQL query is parameterized.
- [ ] Every HTML output is escaped or explicitly sanitized.
- [ ] Auth uses a vetted library and verifies session on every request.
- [ ] Authorization checked on every endpoint; row-level in the DB where applicable.
- [ ] Crypto uses libraries (Tink / libsodium / Themis), not bespoke code.
- [ ] HTTP security headers configured (CSP with nonce, HSTS, nosniff, Referrer-Policy).
- [ ] Cookies are `Secure`, `HttpOnly`, sensible `SameSite`.
- [ ] Dependencies pinned; CVE scan on PRs.
- [ ] Logs do not include secrets, tokens, or full PII.
- [ ] LLM tool calls run through an output filter and respect a caps budget.
- [ ] LLM-facing prompts mark trust boundaries explicitly.

If any item is unchecked, the code is not ready for production data.
