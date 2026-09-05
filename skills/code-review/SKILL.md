---
name: code-review
description: Triggers on mentions of code review of working-tree changes -- `/code-review`, "review my changes", "check my changes", "review the diff", "review before commit". A diff-scoped LLM-judgment review of the changed files in 3 named modes (standalone | orchestrated | autonomous) -- judgment checklist, fixes, optional Codex second opinion, /simplify. Consumes a /lint-gate result file and skips OWNED checks. Does NOT run the linter, build, tests, or deterministic guards -- those belong to /lint-gate and /verify -- and does NOT commit directly; only standalone mode may invoke /commit.
---

# Code Review

Diff-scoped LLM-judgment review over the git working-tree changes. Judges SOLID intent, naming meaning, semantic reuse, audit-pattern conformance, input-validation adequacy, PII/data-exposure, error-handling adequacy, readability, and spec meaning. Fixes issues and runs /simplify. Changes code, never commits directly; standalone mode may invoke `/commit` in Phase 7.

Scope boundary: this skill runs only `git status` / `git diff` / `git diff --cached`, file reads, and the phase-defined sub-skills (`/simplify`, `/security-review`, `/spec`, `/commit`). Linter, build, tests, coverage, and deterministic guards belong to `/lint-gate` and `/verify`. It never produces commit messages, PR descriptions, changelogs, migration plans, docs, branches, or PRs -- suggest in the Phase 7 summary instead.

Invoke sub-skills with the active host's skill mechanism. In Codex, when nested skill invocation is not exposed as a tool, read the sibling `../<skill-name>/SKILL.md` and execute it inline.

## Modes

Invocation: `/code-review [mode]`. Mode omitted -> `standalone`.

- `standalone` -- a dev runs the skill directly. Fully interactive; owns its own security phase and commit question.
- `orchestrated` -- a caller (e.g. `/execute`) drives the card and owns `/security-review` and the commit step. Fix approval stays interactive.
- `autonomous` -- unattended run (blast mode). No pauses; announces each auto-pick on one line (e.g. `autonomous: applying all major fixes`). Never commits.

| Phase | standalone | orchestrated | autonomous |
|-------|------------|--------------|------------|
| 0 Triage (trivial diff) | ask: full review or commit | skip question, full review | skip question, full review |
| 2 Security section | full shallow checklist | one-line deferral note (caller owns the deep pass) | full shallow checklist |
| 3 Fix approval (Major) | ask user | ask user | auto-apply all Major fixes |
| 4 /security-review | detect surface, ask user, may invoke | SKIP phase -- caller owns /security-review | SKIP phase -- caller owns /security-review |
| 5 Spec check | runs; ask user on gaps | runs; ask user on gaps | runs; skip the ask, record the gap, never invoke /spec |
| 7 Commit question | ask: /commit or test first | none -- emit summary, return to caller | none -- emit summary, return to caller |

Toggles (combine with any mode): `--codex` forces the Codex dispatch; `--no-codex` forces skip. These are the only flags.

## Lint-gate consumption

Callers pass the lint-gate result as a FILE PATH: `<work-folder>/.lint-gate-result.md` (written by `/lint-gate`). When a path is given, Read the file; it holds `### Findings` (`[tool:*]` tags) + an `OWNED: <categories>` line. An inline pasted result is consumed the same way. Code-review never runs `/lint-gate` itself.

**Binary OWNED rule:** a category listed in `OWNED:` -> SKIP its matching Phase-2 check row entirely -- do not re-detect, do not re-judge. Reason ONLY about the provided `[tool:*]` findings (their severity and fix implication). A category NOT in `OWNED:` -> the row runs in full. `traceability` has no Phase-2 row -- lint-gate owns it end to end.

**No lint-gate result provided:** every row runs. State `Lint-gate: not provided` in the Phase 7 summary.

## Phase 0: Triage

Run `git diff` and `git diff --cached` to assess the change. Trivial = a small mechanical diff with no new functions, classes, or exported symbols -- judgment call, never by file type alone.

- **standalone + trivial:** ask the user -- run the full review, or commit directly? **commit** -> invoke `/commit`, end skill.
- **orchestrated / autonomous:** always full review, no question, no commit shortcut.

## Phase 1: Gather changes

Run in parallel: `git status`, `git diff`, `git diff --cached`.

**No changes:** if all three produce no output, respond "No changes detected in the working tree. Nothing to review." and exit.

Read the full content of every changed file -- review full files, not just hunks. Then consume the lint-gate result: mark OWNED rows skipped, stage the `[tool:*]` findings into the merged finding set as already-detected facts.

### Codex second opinion

Dispatch ONE external Codex review agent for the entire diff (never split per file/category/phase) when the Codex Rescue skill is installed AND the diff warrants it. When the active host is Codex, skip this external second opinion silently to avoid self-review.

**Detection.** Codex Rescue is installed if `codex:codex-rescue` appears in the available-skills block, or the user invoked it earlier this conversation. Not installed -> skip silently.

**Dispatch decision (by diff content, not size -- a small auth change still dispatches):** skip for test-only, verification-only (pure config / EF mapping / DTO projection), or pure structural refactor diffs; dispatch for security-sensitive or behavior-changing diffs, and when unsure. `--codex` / `--no-codex` override. Record the outcome for Phase 7.

**Dispatch pattern.** Use the host's subagent tool with `subagent_type: "codex:codex-rescue"` and description `"Codex second-opinion review"`. Prompt = verbatim content of `references/codex-review-prompt.md` (this skill's base directory) -- the reviewer has no conversation context. Dispatch in the same parallel batch as the first Phase 2 reads; never wait for it before starting the primary checklist, never block on failure or timeout (note "Codex unavailable" and continue).

**Handling Codex output:** parse JSON findings (parse failure -> one Major finding, category `other`, `[Codex - unparsed]`, raw text verbatim, never auto-fixed). Dedupe same file+line+category as `[Primary + Codex]`; otherwise tag `[Codex]` / `[Primary]`. External Codex is advisory -- on disagreement the higher severity wins.

## Phase 2: Review (LLM judgment)

Apply the checklist to every changed file. Skip each row whose `OWNED category` appears in the lint-gate `OWNED:` line. Finish each section across ALL changed files before the next -- 1 Architecture and Design, 2 Security, 3 Auditing and Observability, 4 Code Quality.

### Architecture and Design

| Check | OWNED category | What to look for |
|-------|----------------|------------------|
| God class / giant class | `god-class` | Oversized class/file, or three or more unrelated public methods. Judge whether the size signals mixed responsibilities. NEVER split during this skill -- report location, the mixed responsibilities, and a suggested split as a Major finding. |
| Single Responsibility | -- | One reason to change per class/function. Handlers orchestrate, not contain business logic. |
| Open/Closed | -- | New behavior via extension, not modification of working code. |
| Long switch / if-else chain | `long-switch` | A chain that should be polymorphic. |
| Liskov Substitution | -- | Subtypes behave correctly when substituted for base types. No surprising overrides. |
| Interface Segregation | -- | Small, focused interfaces. No fat interfaces forcing unused method implementations. |
| Dependency Inversion | -- | Dependencies injected via constructor. |
| `new` of a service | `new-of-service` | Direct `new` of a service or service-locator lookup inside domain code. |
| DI registration | -- | Only if project uses DI (`builder.Services.Add*`, `ConfigureServices`, a `ServiceCollectionExtensions` file, or a DI container package -- one grep; none -> note `DI registration: not applicable`). In use -> new interfaces, services, repositories, handlers must be registered. |

### Security

**orchestrated mode:** replace this whole section with one line -- `Security: deferred to caller (deep pass)`. standalone / autonomous run the full section; it is then the only shallow security pass -- never produce zero security review.

| Check | OWNED category | What to look for |
|-------|----------------|------------------|
| Injection | -- | SQL injection (raw string queries), command injection, XSS in responses. Use parameterized queries. |
| Authentication/Authorization | -- | Proper `[Authorize]` attributes, role/policy checks enforced, no endpoints accidentally left open. |
| Input validation | -- | User inputs validated and sanitized. Request DTOs carry proper validation attributes/rules. |
| Data exposure | -- | Responses don't leak sensitive fields (passwords, internal IDs, PII). DTOs restrict what's returned. |
| Secrets | `secrets` | Hardcoded credentials, API keys, connection strings, tokens in the diff. |

### Auditing and Observability

Backend projects only. Frontend-only -> skip this section.

| Check | What to look for |
|-------|------------------|
| Audit fields | Entities needing tracking have `CreatedBy`, `CreatedAt`, `ModifiedBy`, `ModifiedAt` populated. |
| Audit trail on all API endpoints | Every state-changing endpoint (POST, PUT, PATCH, DELETE) has audit trail logging -- who did what, when, on which resource -- following the project's existing audit pattern. Endpoints without audit trail are **Major**. |
| Audit trail consistency | The audit mechanism matches the project's existing pattern; new endpoints use the same approach. |
| Logging | Important operations log at appropriate levels. Errors logged with context. No sensitive data in logs. |

### Code Quality

| Check | OWNED category | What to look for |
|-------|----------------|------------------|
| Semantic reuse | -- | Before new code is added: does an existing function, class, component, helper, or utility already do this? Search the codebase; flag logic that should reuse what exists. |
| Exact duplication | `exact-dup` | Copy-paste blocks duplicating existing code. |
| Test coverage | -- | New/changed functionality has corresponding tests. Edge cases and error paths covered. |
| Error handling | -- | Specific exceptions caught, meaningful messages, consistent error response format, sound recovery-vs-rethrow choices. |
| Empty catch | `empty-catch` | Empty or exception-swallowing catch blocks. |
| Async correctness | `async` | Missing `await`, unawaited promises/tasks, `async void`. |
| Dead code | `dead-code` | Unused or unreachable code. Commented-out code is a finding. |
| Leftover debug | `debug-leftover` | `console.log` / `debugger` / `Console.WriteLine` left in the diff. |
| Silent TODOs | `todo` | TODO/FIXME/XXX added by the diff. |
| Repo conventions | `repo-conventions` | Mechanical rules from the active host's repo-root instruction file (`AGENTS.md` for Codex, `CLAUDE.md` for Claude Code): size limits, banned imports, required headers. |
| Readability | -- | Self-documenting code. No unnecessary complexity or over-engineering. Clear, meaningful naming. |

**End-of-phase merge (when Codex was dispatched):** wait for Codex (or its timeout), parse, dedupe, categorize the MERGED set -- higher severity wins.

### Categorize issues

**Minor (auto-fix without asking) is this closed list -- anything outside it is Major:**

(a) Missing access modifiers on private members
(b) Removal of unused imports
(c) Removal of unused private fields/locals
(d) Addition of `readonly` to private fields never reassigned outside constructor
(e) Addition of missing `async` keyword on methods that use `await`

**Major (needs approval):** everything else -- SOLID violations, god classes, duplication that should reuse existing code, missing DI registration, missing audit fields/trail, security vulnerabilities, missing test coverage, missing authorization attributes, architectural concerns.

## Phase 3: Fix

Work from the merged finding set (Primary + external Codex + lint-gate `[tool:*]`), preserving attribution in the user-facing report.

**Scope of edits:** apply fixes ONLY to files already in `git status` as modified/added, OR the single file required to wire up a finding (e.g. the DI registration file). Never refactor adjacent code, fix pre-existing unrelated issues, or tidy files opened for context only.

1. Auto-fix Minor issues silently; list what changed (with attribution) in the summary.
2. Report Major issues: what, why it matters, proposed fix, attribution.
3. **standalone / orchestrated:** ask the user -- apply the Major fixes, or skip? After emitting the question STOP: no edits until the user approves a specific finding.
4. Apply approved fixes (scope-of-edits rule still binds).

**autonomous:** skip the question, announce `autonomous: applying all major fixes`, apply every Major finding.

## Phase 4: Security review (/security-review)

**orchestrated / autonomous:** SKIP -- the caller owns `/security-review`. Record `Security review: deferred to caller`, go to Phase 5.

**standalone:** the deeper pass (OWASP Top 10, tenant isolation, PII handling, audit-trail completeness, dependency scanning). Skip (announce "Skipping security review -- no security-relevant surface in these changes.") when the diff is UI-only, docs/spec/config-only, or has no security-relevant surface: no new/modified auth, authorization, endpoints, request handlers, persistence writes, file I/O, secrets, PII fields, cross-tenant operations, or dependency additions. Unsure -> not skippable.

**UI-only definition (shared with Phase 5):** every changed file is pure styling, or a component file whose hunks touch ONLY markup, className/style, UI-primitive imports, or copy. Any hunk touching a function body, hook, store, API call, or event handler -> NOT UI-only.

Security-relevant surface present -> ask the user:

> "Changes include security-sensitive surface ([summary]). Run /security-review for a deeper OWASP + Pandahrms security audit?"

- **Run** -> invoke `/security-review --no-commit`; it reports, may apply approved fixes, returns here. Do not re-ask about committing.
- **Skip** -> note in the summary.

Record the outcome for Phase 7: Skipped / Clean / Fixes applied / Findings acknowledged.

## Phase 5: Spec discrepancy check

Skip entirely if changes are UI-only (Phase 4 definition).

1. **Locate pandahrms-spec** (first that exists): `$(dirname $PWD)/pandahrms-spec`, `$PWD/../../pandahrms-spec`, `$HOME/Developer/pandaworks/_pandahrms/pandahrms-spec`. None -> report "Spec repo not found at any expected location", go to Phase 6 -- never block on a missing spec repo.
2. **Identify affected specs:** module, feature area, behaviors added/changed/removed. Search `pandahrms-spec/specs/` for the relevant `.feature` files.
3. **Compare MEANING** per behavioral change (new action -> scenario exists? validation/status/permission change -> matching `@validation`/`@status`/`@authorization` scenario? bug fix -> `@bugfix` scenario?). Categorize: **Covered** / **Outdated** / **Missing**.
4. All covered -> report "Specs are in sync with changes." Otherwise list each discrepancy, then (standalone / orchestrated) ask the user -- update specs now (invokes `/spec`) or skip and record the gap. **autonomous:** announce `autonomous: skipping spec update, recording gap`; NEVER invoke `/spec`.

**Never write `.feature` files in this skill** -- spec creation/update goes through `/spec` only.

## Phase 6: Simplify

Run `/simplify` against the current changes. Apply a finding ONLY if it does not contradict a Phase 3 fix AND is mechanical (rename, dead-code removal, single-helper extraction). Behavior-changing findings: surface in chat and wait for the user's decision. **autonomous:** invoke `/simplify --mechanical-only` instead -- behavior-changing findings are recorded in the summary, never applied.

`/simplify` errors or times out -> record `Simplify: failed - <reason>` and proceed; do not retry.

## Phase 7: Done

Summarize all changes made during review:

- Minor issues auto-fixed (with attribution)
- Major issues fixed (with attribution)
- Lint-gate: `consumed (OWNED: <list>)` or `not provided`
- Codex: ran / skipped (reason) / not installed
- Security review outcome (deferred to caller / skipped / clean / fixes applied / findings acknowledged)
- Spec status (in sync / updated / gap recorded)
- /simplify changes

**orchestrated / autonomous:** emit the summary and STOP -- no commit question, return control to the caller.

**standalone:** ask the user:

> "Code review complete. Proceed to /commit, or test first?"

- **commit** -> invoke `/commit`. When it returns, code-review is COMPLETE -- no further output.
- **test** -> end with: "Sounds good. Run /commit when you're ready."

## Sub-skill failure handling

Applies whenever code-review invokes `/simplify`, `/security-review`, `/spec`, or `/commit`:

- A sub-skill errors or times out -> record `<skill>: failed - <reason>` in the Phase 7 summary and continue. Do NOT retry in this run.
- A sub-skill returns control with its own pending question -> surface it verbatim; resume code-review once the user answered through the sub-skill.
