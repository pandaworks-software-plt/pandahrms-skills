---
name: aegis-security-review
description: Triggers when the user requests a security review of code or working-tree changes -- phrasings such as "/aegis-security-review", "run aegis", "do a security review", "audit this for vulnerabilities", "OWASP pass on this branch", "check this PR for security issues", "auth audit", "authz audit", "pen test this". Does NOT trigger on incidental mentions of security topics (CVE articles, threat-model discussion) without an action verb directed at the working tree. Audits auth, authz, input validation, injection, secrets, PII exposure, audit trails, and tenant isolation in working tree changes or a specified feature area. Reports findings and fixes approved issues. Does NOT commit, stage, push, or invoke any other skill except via an explicit user choice in Phase 8.
---

# Aegis Security Review

## Overview

Aegis Security Review is a focused security audit of the code under review. It scans working tree changes (or a specified feature area) for security vulnerabilities using the OWASP Top 10, Pandahrms-specific threat patterns (tenant isolation, audit trails, PII handling), and the standards in `~/.claude/rules/Security.md`. It reports findings grouped by severity, optionally fixes approved issues, and hands off to `/hermes-commit`. Aegis Security Review never commits on its own.

## Hard Prohibitions

Aegis Security Review MUST NOT do any of the following at any phase:

- Run `git commit`, `git commit --amend`, `git push`, `git rebase`, `git reset --hard`, `git stash`, `git add`, or any other history-altering, staging, or remote-publishing command. Fixes are written to the working tree only; staging is the user's responsibility (or `/hermes-commit`'s).
- Invoke `pandahrms:hermes-commit` or any other skill except through the explicit user choice in Phase 8.
- Send working-tree contents, diffs, file paths, or finding details to any external service (WebFetch, WebSearch, MCP servers, paste services, gists). The only allowed network calls are dependency-audit invocations of the project's own package-manager CLI (`dotnet`, `pnpm`, `npm`).
- Rotate, re-issue, or relocate secrets when fixing a leaked-credential finding. Aegis Security Review only removes the leaked value from the source file and reports the leak; rotation is a user responsibility.
- Modify `appsettings.Production.json`, KeyVault references, GitHub Actions secrets, or any production configuration store as a "fix."
- Apply a security fix without explicit user approval recorded in Phase 7.
- Write a `Where:` reference (file:line) for a line that has not been opened with the Read tool in this run.
- Cite CVE numbers from training-data memory. CVE knowledge comes only from package-manager audit output captured during Phase 3 (A06).
- Dispatch parallel subagents. All work happens in the main thread.

## When to Use

- Before merging a branch that touches authentication, authorization, API endpoints, or data persistence
- After adding or modifying any endpoint that accepts user input, handles secrets, or returns sensitive data
- When the user explicitly asks for a security review, pen-test pass, or OWASP audit
- As a follow-up to `/athena-code-review` when the change surface is security-sensitive (auth flows, payment, PII, file upload, cross-tenant operations)
- Before a release cut when changes include public-facing endpoints or schema migrations that touch sensitive columns

## When NOT to Use

Skip aegis-security-review ONLY when **every** condition below holds. If any one fails, run aegis-security-review in full.

- The diff contains no `dangerouslySetInnerHTML`, no `@Html.Raw`, no template/raw-HTML interpolation.
- The diff contains no `localStorage`, `sessionStorage`, or cookie writes.
- The diff contains no auth-route, middleware, filter, policy, or `[Authorize]` changes.
- The diff contains no new API call, new fetch, new HTTP client usage, or new server-action declarations.
- The diff contains no env-var reads (`process.env.*`, `IConfiguration[...]`, `appsettings.*`).
- The diff is documentation-only (`*.md`, `*.mdx`, `*.txt`), spec-only (`*.feature`), or tooling-only (lint config, formatter config) that does not ship to production.

Run `git diff` and grep for the tokens above before declaring a change out of scope. Pure styling/layout/dark-mode/responsiveness work that passes all six bullets above is the canonical skip case.

## Workflow

Phases run **strictly sequentially** in the order Phase 0 -> Phase 1 -> Phase 2 -> Phase 3 -> Phase 4 -> Phase 5 -> Phase 6 -> Phase 7 -> Phase 8. Do not begin a phase until the previous phase has emitted its required output. Aegis Security Review does not dispatch parallel subagents; all work happens in the main thread.

```dot
digraph aegis {
    "User triggers /aegis-security-review" [shape=doublecircle];
    "Scope provided?" [shape=diamond];
    "Use working tree diff" [shape=box];
    "Use specified scope" [shape=box];
    "Detect project type" [shape=box];
    "Gather context" [shape=box];
    "Any security-relevant changes?" [shape=diamond];
    "Report: no security surface, exit" [shape=doublecircle];
    "Run threat pass" [shape=box];
    "Run OWASP checklist" [shape=box];
    "Run Pandahrms-specific checks" [shape=box];
    "Run secret/credential scan" [shape=box];
    "Run dependency audit (if available)" [shape=box];
    "Findings?" [shape=diamond];
    "Report: clean, exit" [shape=doublecircle];
    "Categorize by severity" [shape=box];
    "Report findings to user" [shape=box];
    "Critical/High present?" [shape=diamond];
    "Ask: fix now?" [shape=diamond];
    "Apply approved fixes" [shape=box];
    "Re-verify fixes" [shape=box];
    "Ask: /hermes-commit or test first?" [shape=diamond, style=filled, fillcolor=lightgreen];
    "Run /hermes-commit" [shape=box, style=filled, fillcolor=lightgreen];
    "Done - user will test" [shape=doublecircle];

    "User triggers /aegis-security-review" -> "Scope provided?";
    "Scope provided?" -> "Use specified scope" [label="yes"];
    "Scope provided?" -> "Use working tree diff" [label="no"];
    "Use working tree diff" -> "Detect project type";
    "Use specified scope" -> "Detect project type";
    "Detect project type" -> "Gather context";
    "Gather context" -> "Any security-relevant changes?";
    "Any security-relevant changes?" -> "Report: no security surface, exit" [label="no"];
    "Any security-relevant changes?" -> "Run threat pass" [label="yes"];
    "Run threat pass" -> "Run OWASP checklist";
    "Run OWASP checklist" -> "Run Pandahrms-specific checks";
    "Run Pandahrms-specific checks" -> "Run secret/credential scan";
    "Run secret/credential scan" -> "Run dependency audit (if available)";
    "Run dependency audit (if available)" -> "Findings?";
    "Findings?" -> "Report: clean, exit" [label="no"];
    "Findings?" -> "Categorize by severity" [label="yes"];
    "Categorize by severity" -> "Report findings to user";
    "Report findings to user" -> "Critical/High present?";
    "Critical/High present?" -> "Ask: fix now?" [label="yes"];
    "Critical/High present?" -> "Ask: /hermes-commit or test first?" [label="no, low/info only"];
    "Ask: fix now?" -> "Apply approved fixes" [label="fix"];
    "Ask: fix now?" -> "Ask: /hermes-commit or test first?" [label="skip"];
    "Apply approved fixes" -> "Re-verify fixes";
    "Re-verify fixes" -> "Ask: /hermes-commit or test first?";
    "Ask: /hermes-commit or test first?" -> "Run /hermes-commit" [label="commit"];
    "Ask: /hermes-commit or test first?" -> "Done - user will test" [label="test first"];
}
```

## Phase 0: Scope

### 0.1 Resolve scope to a concrete file list

- If the user supplied a literal path or glob (e.g. `/aegis-security-review src/auth`, `aegis on Pandahrms.Performance.Api/Controllers/LoginController.cs`), use exactly that path set.
- If the user supplied a natural-language scope (e.g. "the new login endpoint", "the export feature"), resolve it to a concrete file list using `git status`, `grep`, and `find`. When more than 5 files match, or when zero files match, use `AskUserQuestion` to confirm the resolved list before proceeding.
- If no scope was supplied, default to the git working tree captured by:
  - `git status` (untracked and modified files)
  - `git diff` and `git diff --cached` (unstaged and staged changes)

### 0.2 Empty working tree halt

If no scope was supplied AND `git status` shows a clean tree (no staged, unstaged, or untracked changes), halt immediately with the single line: "No changes to audit. Pass an explicit scope (e.g. `/aegis-security-review src/auth`) to audit specific files." Do not audit the entire repository as a fallback.

### 0.3 Read every in-scope file end-to-end

Read the **full content** of every in-scope file using the Read tool. A diff alone is not enough for security analysis -- unchanged surrounding code (guards, middleware, filters) often determines whether a change is safe.

If a file exceeds 2000 lines, page through it with explicit `offset`/`limit` calls until you reach EOF. Maintain a per-file ledger:

| Path | Total lines | Fully read |
|------|-------------|------------|

Do not begin Phase 1 until every in-scope file shows "Fully read: yes".

## Phase 1: Detect Project Type

Detect every project-type signal that appears in the in-scope file list. Run the checklist rows for **every** matching project type (a change that touches both `*.csproj` and `package.json` runs both checklists). Multiple matches are common and expected.

| Signal | Project type | Emphasis |
|--------|--------------|----------|
| `*.csproj`, `Program.cs`, `Startup.cs` | .NET backend (Performance API, Recruitment API, main API) | Controllers, `[Authorize]`, EF queries, DI, audit entity base, tenant filter |
| `next.config.*`, `app/` with route handlers | Next.js frontend / BFF | API routes, server actions, session cookies, CSRF, CSP, env var leakage |
| `package.json` + React only, no server routes | React frontend | XSS, `dangerouslySetInnerHTML`, auth token storage, dependency CVEs |
| `*.sql`, EF `Migrations/` | Schema change | Column-level PII, default values, NOT NULL on sensitive cols, down-migration safety |
| Docker, CI configs | Infra | Secret injection, image base CVEs, privilege, exposed ports |

### No-signal fallback

If **no** project-type signal matches in scope, halt and use `AskUserQuestion` to confirm whether to (a) abort aegis-security-review as out-of-scope, or (b) proceed using a user-specified checklist set. Do not infer a checklist from the absence of signals, and do not silently default to .NET.

## Phase 2: Threat Pass

Before checklist work, produce a written **Trust Boundary Map** that will be emitted into the final report under "Phase 2: Trust Boundaries". The map is a required input to Phase 3.

The map has exactly five labelled rows. Each row lists `file:line` references drawn from files actually opened in Phase 0 (do not invent line numbers):

1. **Entry points** -- where does untrusted input enter? (HTTP body, query string, headers, cookies, file upload, message queue, webhook)
2. **Validation / parameterization** -- what does the code do with it before trusting it? (validate, parameterize, escape, authorize)
3. **Exit points** -- where does it leave the system? (response body, log, DB, external API, email, file)
4. **Authorization gates** -- what gate protects the operation? Is it enforced on the server, or only the UI?
5. **Ownership verification** -- what tenant/user/org owns the data? Is that ownership verified before read/write?

Append a "weak spots" list at the end of the map -- specific concerns to feed into Phase 3 checklist findings. Do not begin Phase 3 until the map is written.

## Phase 3: OWASP Checklist

Work the rows in **strict numeric order**: A01, A02, A03, A04, A05, A06, A07, A08. A09 and A10 are covered downstream as noted but must still be acknowledged in the report ("A09: see Phase 4 audit-trail row", "A10: see A03 SSRF row"). Do not skip a row because earlier rows produced findings.

For each row, do **one of two things explicitly**:

- (a) Execute the check and report findings under that row, OR
- (b) Mark the row "N/A" with a one-line reason (e.g. "A02 N/A: no crypto, password storage, token signing, or TLS code in scope").

A row qualifies as N/A only when none of the file types or APIs it inspects appear in scope. Do not silently omit a row -- every row gets either findings or an N/A reason in the report.

### A01 - Broken Access Control

| Check | What to look for |
|-------|------------------|
| **Missing `[Authorize]` / auth guard** | New controller, action, route handler, or server action without auth enforcement. `AllowAnonymous` used intentionally? |
| **IDOR** | Endpoint takes an id from the client and loads by that id without verifying the caller owns/has access to the resource. Always scope queries by `TenantId`, `OrgId`, or `UserId`. |
| **Role/policy bypass** | Role/policy strings typo'd, hardcoded `true`, or commented out. Policies registered in DI? |
| **Mass assignment** | Request DTO binds directly to entity with fields the client should not set (`IsAdmin`, `TenantId`, `Status`). Use explicit mapping. |
| **Server-side enforcement** | UI hides a button but the endpoint does not re-check permission. Every check must exist on the server. |
| **Path traversal** | File/blob paths built from user input without sanitization (`..`, absolute paths). |

### A02 - Cryptographic Failures

| Check | What to look for |
|-------|------------------|
| **Passwords** | Never stored plain or with weak hash (MD5, SHA1, unsalted SHA256). Use `PasswordHasher<TUser>`, bcrypt, or argon2. |
| **Token signing** | JWT secrets not hardcoded, algorithms not `none` or `HS256` with weak key, issuer/audience validated. |
| **TLS** | Cookies marked `Secure`. External HTTP calls use HTTPS. No `ServicePointManager.ServerCertificateValidationCallback = (_, _, _, _) => true`. |
| **Encryption at rest** | Sensitive columns (SSN, salary, bank info) encrypted or isolated. EF value converters in place. |
| **Insecure randomness** | Security-sensitive randomness (tokens, nonces) uses `RandomNumberGenerator` / `crypto.randomUUID`, not `Random` or `Math.random`. |

### A03 - Injection

| Check | What to look for |
|-------|------------------|
| **SQL injection** | Raw `FromSqlRaw`, `ExecuteSqlRaw`, string-concatenated SQL, or Dapper with interpolation. Use parameters. |
| **NoSQL / LINQ dynamic** | Dynamic LINQ strings built from user input. |
| **Command injection** | `Process.Start`, shell exec, `child_process` built from user input. |
| **LDAP / XPath / ORM** | User input in LDAP filters, XPath queries, or ORM string predicates without escaping. |
| **XSS** | React: `dangerouslySetInnerHTML`. Razor: `@Html.Raw`. Response templates echoing unescaped user input. |
| **Log injection** | User input written to logs without sanitization of CR/LF. |
| **SSRF** | Server makes outbound HTTP to a URL taken from client input without allowlist. |

### A04 - Insecure Design

| Check | What to look for |
|-------|------------------|
| **Missing rate limiting** | Login, password reset, OTP, export endpoints without throttling. |
| **Predictable IDs** | Sequential public identifiers for sensitive resources. Use GUIDs for externally-exposed keys. |
| **Business logic abuse** | Negative quantities, zero prices, status transitions not enforced, workflow steps skippable. |

### A05 - Security Misconfiguration

| Check | What to look for |
|-------|------------------|
| **CORS** | `AllowAnyOrigin` with credentials. Origin allowlist explicit. |
| **CSP / security headers** | Missing `Content-Security-Policy`, `X-Content-Type-Options`, `X-Frame-Options`, `Strict-Transport-Security`. |
| **Verbose errors** | Stack traces, SQL errors, internal paths leaked to the client in production. |
| **Default creds / sample data** | Demo users, `admin:admin`, seed credentials shipped to prod. |
| **Env vs appsettings** | Production secrets in committed `appsettings.json` instead of env/KeyVault. |

### A06 - Vulnerable and Outdated Components

Detect the package manager from the in-scope files and run the matching command:

- If any `*.csproj` is in scope, run `dotnet list package --vulnerable --include-transitive`.
- If `package.json` is in scope and `pnpm-lock.yaml` exists at the project root, run `pnpm audit --prod`.
- If `package.json` is in scope and `package-lock.json` exists at the project root, run `npm audit --production`.
- If `package.json` is in scope and `yarn.lock` exists at the project root, run `yarn npm audit --recursive --severity high`.

If the relevant CLI is not installed (command not found), report "dependency audit skipped: <command> not installed" in the Phase 6 report. Do not silently skip.

CVE knowledge comes **only** from the captured audit output. Do not cite CVE IDs from training-data memory. If audit output is unavailable for any reason, report "lockfile changed; CVE check skipped" rather than inferring vulnerability status from prior knowledge.

Report any **High** or **Critical** advisories tied to changed `*.csproj` or `package.json`. If a lockfile changed, diff it and flag new packages that the audit output reports as vulnerable.

### A07 - Identification and Authentication Failures

| Check | What to look for |
|-------|------------------|
| **Session handling** | Cookies `HttpOnly`, `Secure`, `SameSite=Lax` or `Strict`. Token refresh / revocation implemented. |
| **MFA / lockout** | Brute-force protections on login and OTP endpoints. Account lockout thresholds. |
| **Password policy** | Minimum length, complexity, breached-password check where applicable. |
| **Token storage (FE)** | Access tokens in `localStorage` is a red flag -- prefer secure cookies or in-memory. |

### A08 - Software and Data Integrity Failures

| Check | What to look for |
|-------|------------------|
| **Deserialization** | `BinaryFormatter`, `JavaScriptSerializer` with type info, or `TypeNameHandling.All` in Newtonsoft. |
| **Unsigned updates** | Dynamic asset loads from unverified URLs. |
| **CI/CD supply chain** | New GitHub Actions pinned to SHA, not moving tags. |

### A09 - Security Logging and Monitoring Failures

Covered in Pandahrms-specific checks below (audit trail).

### A10 - Server-Side Request Forgery (SSRF)

Covered in A03 above.

## Phase 4: Pandahrms-Specific Checks

| Check | What to look for |
|-------|------------------|
| **Tenant isolation** | Every DB query involving tenant-scoped tables filters by `TenantId`/`OrganisationId`. Global query filters in `DbContext.OnModelCreating` present and not bypassed with `IgnoreQueryFilters()` without justification. |
| **Audit fields** | Entities that need tracking have `CreatedBy`, `CreatedAt`, `ModifiedBy`, `ModifiedAt`. Populated via base entity or middleware, not hand-set. |
| **Audit trail on state-changing endpoints** | Every POST / PUT / PATCH / DELETE writes an audit log record (who, what, when, which resource). New endpoints must use the same audit mechanism as existing ones. Missing audit trail is a **High** severity finding. |
| **PII in responses** | Response DTOs do not leak fields like `PasswordHash`, `SecurityStamp`, internal `Id` of other tenants' records, or salary/bank info not needed by the caller. |
| **PII in logs** | No logging of passwords, tokens, full credit card, full NRIC/SSN. Redaction in place. |
| **Cross-project contract** | If this is a FE change calling a BE endpoint, verify the BE actually enforces the authorization the FE assumes. If this is a BE change, verify downstream FE / mobile is not relying on removed checks. |
| **EF migrations** | New columns holding PII are marked for encryption / masking. `DROP COLUMN` on sensitive columns reviewed for data retention policy. No unfiltered `UPDATE`/`DELETE` in migration SQL. |
| **Bridge / external keys** | No API keys, service account tokens, or bridge secrets committed. Check `.env*`, `appsettings.*.json`, `launchSettings.json`, `.github/workflows/*`. |

## Phase 5: Secret and Credential Scan

Phase 5 runs as a discrete pass after Phase 4 completes. Do not merge it into Phase 3 or Phase 4 even if those phases noticed potential secrets.

On the full set of changed files (including untracked):

1. Grep for common patterns: `password\s*=`, `secret\s*=`, `api[_-]?key`, `Bearer `, `AKIA`, `-----BEGIN`, `ConnectionString`, `eyJ` (JWT prefix).
2. Flag any committed `.env`, `.pem`, `.pfx`, `.key`, `.p12`, `id_rsa`, `credentials.json`, `service-account*.json`.
3. For any hit, treat as **Critical** until proven false, and emit a top-of-report warning block in this exact form:

   ```
   ## CRITICAL: POSSIBLE SECRET LEAKED
   - File: <path>
   - Line: <lineno>
   - Pattern matched: <pattern>
   - Matched substring (redacted): <first 4 chars>...<last 4 chars>
   ```

   This block appears at the very top of the Phase 6 report, above the Counts table, in addition to (not instead of) the regular Critical entry under Findings.

## Phase 6: Categorize and Report

Group findings into four buckets:

- **Critical** - exploitable now, data loss / account takeover / RCE class. Must fix before merge.
- **High** - clear vulnerability with plausible exploit path. Fix before merge unless explicitly accepted.
- **Medium** - weakness that raises risk (e.g., weak logging, missing rate limit on non-auth endpoint). Fix soon.
- **Low / Info** - hardening suggestion, defense-in-depth. Fix opportunistically.

### Mandatory report structure

The Phase 6 report is a single message containing, in this exact order:

1. Any `## CRITICAL: POSSIBLE SECRET LEAKED` blocks emitted by Phase 5 (zero or more, at the very top).
2. `## Aegis Report -- <scope summary>`
3. `### Counts` -- a table with one row per severity (Critical, High, Medium, Low, Info) and an integer count for each.
4. `### Phase 2: Trust Boundaries` -- the Trust Boundary Map produced in Phase 2.
5. `### Findings` -- one block per finding using **exactly** this four-bullet template:

   > **[Severity] [Short title]**
   > - **Where:** `path/to/file.cs:lineno`
   > - **What:** the vulnerability in one sentence
   > - **Why it matters:** concrete attacker scenario
   > - **Fix:** concrete remediation (code sketch if non-trivial)

6. `### Phase 3 row coverage` -- one line per OWASP row (A01-A08) marked either "executed" or "N/A: <reason>".
7. `### Phases / checks skipped` -- list any other check that was N/A or skipped (e.g. dependency audit, project-type checklist) with a one-line reason.

Deviation from this structure is a defect. Do not omit a section because it would be empty -- emit the heading with "(none)" instead.

### No invented references

Every `Where:` reference must come from a file actually opened by the Read tool in this run. Do not write a line number unless you have read that line. If a finding spans a concept rather than a single line, write `path/to/file.cs (whole file)` instead of guessing.

## Phase 7: Fix (Optional)

### When to run Phase 7

- If at least one Critical or High finding exists, run Phase 7 (ask before fixing).
- If only Medium / Low / Info findings exist, **skip Phase 7 entirely** and proceed directly to Phase 8.

### Approval prompt

If Critical or High findings exist, use `AskUserQuestion` to ask:

> "Aegis Security Review found [N Critical / M High] issues. Fix them now, or report and let you handle them?"

Options:
- **Fix now** -- apply remediations for approved findings.
- **Skip** -- report stays as-is, user decides what to do.

Never silently apply a security fix without user approval. Security fixes can change behavior.

### What "fix" means in Phase 7

A "fix" is the **minimum code change** that closes the specific finding. In Phase 7, Aegis Security Review MUST NOT:

- Refactor unrelated code or rename symbols.
- Add new tests or test files (the user owns test coverage decisions for security fixes).
- Restructure files or move code between files.
- Change formatting, indentation, or whitespace outside the touched lines.
- Modify dependency versions or lockfiles.

If the minimum fix is non-local (touches multiple files or requires architectural changes), do not auto-apply -- report it as a finding-with-recommendation and let the user decide.

### Re-verification

After applying fixes, re-verify each fix by:

1. Re-reading the **entire file** containing the fix end-to-end (not just the diff).
2. Re-running the OWASP rows that originally produced the finding.
3. **Plus** re-running A01 (access control) and the Phase 4 tenant-isolation row, even if those did not flag the original finding -- a fix can introduce new access-control or tenant-scoping defects.

Record re-verification results inline under each fixed finding in the report ("Re-verified: clean" or "Re-verified: new finding -- [details]").

## Phase 8: Handoff

Summarize:
- Counts by severity
- What was fixed (if any)
- Residual risk the user is accepting (if any)

Then use `AskUserQuestion` to ask:

> "Security review complete. Would you like to proceed to /hermes-commit, or test first?"

- **Commit** -- invoke `pandahrms:hermes-commit` via the Skill tool, then end the aegis-security-review turn immediately upon dispatch. Do not produce additional output, additional findings, or extra commentary after the dispatch.
- **Test first** -- emit exactly the single line "Sounds good. Run /hermes-commit when you're ready." and end the turn. Do not add any further text.

After Phase 8 ends, aegis-security-review is complete. Do not continue executing aegis-security-review behavior (no further audits, no follow-up advice, no additional checks) in the same turn.

## Red Flags - STOP

- Applying a security fix without explicit user approval
- Reporting "no issues" without actually reading the full changed files
- Skipping tenant-isolation checks on any DB query in a tenant-scoped project
- Declaring a hardcoded credential "probably fine" - always flag as Critical until disproven
- Using a narrow diff view to judge a security question - always read the full file to see the surrounding guards
- Running `/hermes-commit` automatically after fixes - always ask commit vs test first
- Treating a missing audit trail as Low - it is High severity in Pandahrms

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Judging auth from the route handler alone | Trace the middleware/filter pipeline too; the guard may be upstream -- or missing there. |
| Assuming the ORM prevents injection | LINQ is safe; raw SQL, dynamic LINQ, and string interpolation into `FromSqlRaw` are not. |
| Accepting "it's only reachable internally" | Internal-only endpoints still need authz -- insiders and compromised services exist. |
| Treating frontend validation as sufficient | FE validation is UX; the server must re-validate every input. |
| Ignoring a removed check | If a `[Authorize]` or tenant filter was deleted, treat it as a Critical finding until shown to be intentional. |
| Skipping dependency audit because "it's just a patch bump" | Run the audit anyway; transitive CVEs hide in minor bumps. |
| Not reading the full file | Security depends on context -- the vulnerability may live in the unchanged block next to the edit. |
