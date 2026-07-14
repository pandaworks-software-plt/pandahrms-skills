# OWASP + Pandahrms Check Tables

Reference for `/security-review`. Holds the Phase 3 A01-A08 check tables and the Phase 4 Pandahrms-specific check table. Read this file before starting Phase 3.

## Phase 3 rows

### A01 - Broken Access Control

| Check | What to look for |
|-------|------------------|
| **Missing `[Authorize]` / auth guard** | New controller, action, route handler, or server action without auth enforcement. `AllowAnonymous` used intentionally? |
| **IDOR** | Endpoint takes id from client and loads by that id without verifying caller owns/has access. Always scope queries by `TenantId`, `OrgId`, or `UserId`. |
| **Role/policy bypass** | Role/policy strings typo'd, hardcoded `true`, or commented out. Policies registered in DI? |
| **Mass assignment** | Request DTO binds directly to entity with fields client should not set (`IsAdmin`, `TenantId`, `Status`). Use explicit mapping. |
| **Server-side enforcement** | UI hides button but endpoint does not re-check permission. Every check must exist on server. |
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
| **Verbose errors** | Stack traces, SQL errors, internal paths leaked to client in production. |
| **Default creds / sample data** | Demo users, `admin:admin`, seed credentials shipped to prod. |
| **Env vs appsettings** | Production secrets in committed `appsettings.json` instead of env/KeyVault. |

### A06 - Vulnerable and Outdated Components

Detect package manager from in-scope files and run matching command:

- If any `*.csproj` in scope, run `dotnet list package --vulnerable --include-transitive`.
- If `package.json` in scope and `pnpm-lock.yaml` exists at project root, run `pnpm audit --prod`.
- If `package.json` in scope and `package-lock.json` exists at project root, run `npm audit --production`.
- If `package.json` in scope and `yarn.lock` exists at project root, run `yarn npm audit --recursive --severity high`.

If relevant CLI not installed (command not found), report "dependency audit skipped: <command> not installed" in Phase 6 report. Do not silently skip.

CVE knowledge comes **only** from captured audit output. Do not cite CVE IDs from training-data memory. If audit output unavailable for any reason, report "lockfile changed; CVE check skipped" rather than inferring vulnerability status from prior knowledge.

Report any **High** or **Critical** advisories tied to changed `*.csproj` or `package.json`. If a lockfile changed, diff it and flag new packages the audit output reports as vulnerable.

### A07 - Identification and Authentication Failures

| Check | What to look for |
|-------|------------------|
| **Session handling** | Cookies `HttpOnly`, `Secure`, `SameSite=Lax` or `Strict`. Token refresh / revocation implemented. |
| **MFA / lockout** | Brute-force protections on login and OTP endpoints. Account lockout thresholds. |
| **Password policy** | Minimum length, complexity, breached-password check where applicable. |
| **Token storage (FE)** | Access tokens in `localStorage` is red flag -- prefer secure cookies or in-memory. |

### A08 - Software and Data Integrity Failures

| Check | What to look for |
|-------|------------------|
| **Deserialization** | `BinaryFormatter`, `JavaScriptSerializer` with type info, or `TypeNameHandling.All` in Newtonsoft. |
| **Unsigned updates** | Dynamic asset loads from unverified URLs. |
| **CI/CD supply chain** | New GitHub Actions pinned to SHA, not moving tags. |

## Phase 4 rows - Pandahrms-Specific Checks

| Check | What to look for |
|-------|------------------|
| **Tenant isolation** | Every DB query involving tenant-scoped tables filters by `TenantId`/`OrganisationId`. Global query filters in `DbContext.OnModelCreating` present and not bypassed with `IgnoreQueryFilters()` without justification. |
| **Audit fields** | Entities needing tracking have `CreatedBy`, `CreatedAt`, `ModifiedBy`, `ModifiedAt`. Populated via base entity or middleware, not hand-set. |
| **Audit trail on state-changing endpoints** | Every POST / PUT / PATCH / DELETE writes audit log record (who, what, when, which resource). New endpoints must use same audit mechanism as existing ones. Missing audit trail is **High** severity finding. |
| **PII in responses** | Response DTOs do not leak fields like `PasswordHash`, `SecurityStamp`, internal `Id` of other tenants' records, or salary/bank info not needed by caller. |
| **PII in logs** | No logging of passwords, tokens, full credit card, full NRIC/SSN. Redaction in place. |
| **Cross-project contract** | If FE change calling BE endpoint, verify BE actually enforces the authorization FE assumes. If BE change, verify downstream FE / mobile is not relying on removed checks. |
| **EF migrations** | New columns holding PII marked for encryption / masking. `DROP COLUMN` on sensitive columns reviewed for data retention policy. No unfiltered `UPDATE`/`DELETE` in migration SQL. |
| **Bridge / external keys** | No API keys, service account tokens, or bridge secrets committed. Check `.env*`, `appsettings.*.json`, `launchSettings.json`, `.github/workflows/*`. |
