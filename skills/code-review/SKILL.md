---
name: code-review
description: Triggers on mentions of code review of working-tree changes -- `/code-review`, "review my changes", "check my changes", "review the diff", "review before commit". A diff-scoped LLM-judgment review of the changed files in 3 named modes (standalone | orchestrated | autonomous) -- judgment checklist, fixes, optional Codex second opinion, /simplify. Consumes a /lint-gate result file and skips OWNED checks. Does NOT run the linter, build, tests, or deterministic guards -- those belong to /lint-gate and /verify -- and does NOT commit directly; only standalone mode may invoke /commit.
model: opus
---

# Code Review

Diff-scoped LLM-judgment review over the git working-tree changes. Judges SOLID intent, naming meaning, semantic reuse, audit-pattern conformance, input-validation adequacy, PII/data-exposure, error-handling adequacy, readability, and spec meaning. Fixes issues and runs /simplify. Changes code, never commits directly; standalone mode may invoke `/commit` in Phase 7.

## Modes

Invocation: `/code-review [mode]`. Mode omitted -> `standalone`.

- `standalone` -- a dev runs the skill directly. Fully interactive; owns its own security phase and commit question.
- `orchestrated` -- a caller (e.g. `/execute`) drives the card and owns `/security-review` and the commit step. Fix approval stays interactive.
- `autonomous` -- unattended run (blast mode). No pauses; announces each auto-pick on one line (e.g. `autonomous: applying all major fixes`). Never commits.

One table states every phase's behavior per mode:

| Phase | standalone | orchestrated | autonomous |
|-------|------------|--------------|------------|
| 0 Triage (trivial diff) | AskUserQuestion: full review or commit | skip question, full review | skip question, full review |
| 2 Security section | full shallow checklist | one-line deferral note (caller owns the deep pass) | full shallow checklist |
| 3 Fix approval (Major) | AskUserQuestion | AskUserQuestion | auto-apply all Major fixes |
| 4 /security-review | detect surface, AskUserQuestion, may invoke | SKIP phase -- caller owns /security-review | SKIP phase -- caller owns /security-review |
| 5 Spec check | runs; AskUserQuestion on gaps | runs; AskUserQuestion on gaps | runs; skip the ask, record the gap, never invoke /spec |
| 7 Commit question | AskUserQuestion: /commit or test first | none -- emit summary, return to caller | none -- emit summary, return to caller |

Toggles (combine with any mode): `--codex` forces the Codex dispatch; `--no-codex` forces skip. These are the only flags.

## Phase ledger

Announce each transition on one line: `Phase N/7 done -> Phase M`. A phase skipped by mode or skip-condition still emits its line, e.g. `Phase 4/7 skipped (orchestrated) -> Phase 5`.

## Lint-gate consumption

Callers pass the lint-gate result as a FILE PATH: `<work-folder>/.lint-gate-result.md` (written by `/lint-gate`). When a path is given, Read the file; it holds `### Findings` (`[tool:*]` tags) + an `OWNED: <categories>` line. An inline pasted result is consumed the same way. Code-review never runs `/lint-gate` itself.

**Binary OWNED rule:** a category listed in `OWNED:` -> SKIP its matching Phase-2 check row entirely -- do not re-detect, do not re-judge. Reason ONLY about the provided `[tool:*]` findings (their severity and fix implication). A category NOT in `OWNED:` -> the row runs in full. Each ownable row names its category in the checklist's `OWNED category` column. `traceability` has no Phase-2 row -- lint-gate owns it end to end.

**No lint-gate result provided:** every row runs. State `Lint-gate: not provided` in the Phase 7 summary.

## Phase 0: Triage

Run `git diff` and `git diff --cached` to assess change size.

**Trivial diff definition (literal):** diff has **<= 20 changed lines total across <= 2 files**, AND no `.cs` / `.ts` / `.tsx` / `.py` files contain new functions, classes, or exported symbols. Both hold -> trivial. Otherwise not. Never classify by file type alone.

**orchestrated / autonomous:** skip the triage question, proceed to Phase 1. Never offer the commit shortcut.

**standalone + trivial diff:** AskUserQuestion:

> "Trivial diff detected. Run a full code review, or commit directly?"

- **review** -> Phase 1.
- **commit** -> invoke `/commit`, end skill.
- Off-list answer -> re-ask once; still off-list -> stop skill, summarize state in one line.

**Not trivial:** proceed to Phase 1.

## Phase 1: Gather changes

Run in parallel: `git status`, `git diff`, `git diff --cached`.

**No changes:** if all three produce no output, respond exactly: "No changes detected in the working tree. Nothing to review." and exit the skill. No Phase 2, no Codex dispatch.

Read the full content of every changed file. Full context required.

Then consume the lint-gate result (section above): read the result file, mark the OWNED rows skipped, stage the `[tool:*]` findings into the merged finding set as already-detected facts.

### Codex second opinion

Dispatch ONE parallel Codex review when Codex is installed AND the decision table says dispatch.

**Detection.** Codex is installed if EITHER: (1) a `codex:`-prefixed skill appears in the available-skills block, OR (2) the user invoked a `codex:*` skill earlier in this conversation. Neither -> not installed: skip silently, no announcement.

**Dispatch decision table (closed -- classify by diff content, not size):**

| Diff type | Dispatch? |
|-----------|-----------|
| Test-only (every changed file is a test file) | skip |
| Verification-only (pure config / EF mapping / DTO projection, no logic) | skip |
| Pure structural refactor (rename / move / extract, no behavior change) | skip |
| Security-sensitive (auth, tenant, PII surface) | dispatch |
| Behavior-changing logic | dispatch |
| Not sure which row fits | dispatch (default) |

A small diff is NOT a skip reason -- a small auth change still dispatches. Overrides: `--codex` forces dispatch; `--no-codex` forces skip. Record the outcome for Phase 7 (`Codex: ran` / `skipped (<table row>)` / `skipped (--no-codex)` / `not installed`).

**Dispatch pattern.** Exactly ONE Codex agent for the entire diff, via the Agent tool with `subagent_type: "codex:codex-rescue"` and description `"Codex second-opinion review"`. Never split per file, per category, or per phase.

**Prompt.** Read `references/codex-review-prompt.md` (this skill's base directory) and use its content verbatim as the agent prompt. It is self-contained -- Codex has no conversation context.

**Timing (strict):**

1. Phase 1 file reads complete first.
2. Lint-gate consumption completes.
3. The single message that begins Phase 2 contains, in parallel: (a) the Codex Agent dispatch, AND (b) any grep/read calls needed for the Phase 2 checklist.

Never dispatch before the file reads complete. Never wait for Codex before starting the own checklist.

### Handling Codex output

- **Parse JSON findings.** Parse failure -> the entire Codex output becomes ONE Major finding, category `other`, attribution `[Codex - unparsed]`, raw text surfaced verbatim. Never auto-fix unparsed Codex output.
- **Dedupe:** same file+line+category flagged by both -> merge into one finding, credit `[Claude + Codex]`.
- **Codex-only** findings tagged `[Codex]`; **Claude-only** tagged `[Claude]`.
- **Severity:** Codex is advisory; on disagreement use the higher severity.
- **Failure/timeout:** note "Codex unavailable, proceeding with Claude-only review" and continue. Never block.

## Phase 2: Review (LLM judgment)

Apply the checklist to every changed file. Skip each row whose `OWNED category` appears in the lint-gate `OWNED:` line (binary rule). Merge `[tool:*]` findings as already-detected context.

**Evaluation order (strict):** finish each section across ALL changed files before the next -- 1 Architecture and Design, 2 Security, 3 Auditing and Observability, 4 Code Quality. Never parallelize sections or interleave per file.

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
| DI registration | -- | Only if project uses DI. Project "uses DI" if ANY of: `Program.cs` calls `builder.Services.Add*`; `Startup.cs` with `ConfigureServices`; a `ServiceCollectionExtensions` file; `package.json` / `*.csproj` references a DI container (`Microsoft.Extensions.DependencyInjection`, `tsyringe`, `inversify`, `awilix`). None detected after a single grep -> skip and note `DI registration: not applicable` in Phase 7. In use -> new interfaces, services, repositories, handlers must be registered. |

### Security

**orchestrated mode:** replace this whole section with one line -- `Security: deferred to caller (deep pass)` -- and run no row below. standalone / autonomous run the full section; it is then the only shallow security pass -- never produce zero security review.

| Check | OWNED category | What to look for |
|-------|----------------|------------------|
| Injection | -- | SQL injection (raw string queries), command injection, XSS in responses. Use parameterized queries. |
| Authentication/Authorization | -- | Proper `[Authorize]` attributes, role/policy checks enforced, no endpoints accidentally left open. |
| Input validation | -- | User inputs validated and sanitized. Request DTOs carry proper validation attributes/rules. |
| Data exposure | -- | Responses don't leak sensitive fields (passwords, internal IDs, PII). DTOs restrict what's returned. |
| Secrets | `secrets` | Hardcoded credentials, API keys, connection strings, tokens in the diff. |

### Auditing and Observability

Backend projects only (API, MVC5, monorepo with backend). Frontend-only -> skip this section.

| Check | What to look for |
|-------|------------------|
| Audit fields | Entities needing tracking have `CreatedBy`, `CreatedAt`, `ModifiedBy`, `ModifiedAt` populated. |
| Audit trail on all API endpoints | Every state-changing endpoint (POST, PUT, PATCH, DELETE) has audit trail logging -- who did what, when, on which resource -- following the project's existing audit pattern (base entity audit, middleware audit, or explicit audit log calls). Endpoints without audit trail are **Major**. |
| Audit trail consistency | The audit mechanism matches the project's existing pattern; new endpoints use the same approach. |
| Logging | Important operations log at appropriate levels. Errors logged with context. No sensitive data in logs. |

### Code Quality

| Check | OWNED category | What to look for |
|-------|----------------|------------------|
| Semantic reuse | -- | Before new code is added: does an existing function, class, component, helper, or utility already do this? Search the codebase for similar patterns; flag logic that should reuse what exists. |
| Exact duplication | `exact-dup` | Copy-paste blocks duplicating existing code. |
| Test coverage | -- | New/changed functionality has corresponding tests. Edge cases and error paths covered. |
| Error handling | -- | Specific exceptions caught, meaningful messages, consistent error response format, sound recovery-vs-rethrow choices. |
| Empty catch | `empty-catch` | Empty or exception-swallowing catch blocks. |
| Async correctness | `async` | Missing `await`, unawaited promises/tasks, `async void`. |
| Dead code | `dead-code` | Unused or unreachable code. Commented-out code is a finding. |
| Leftover debug | `debug-leftover` | `console.log` / `debugger` / `Console.WriteLine` left in the diff. |
| Silent TODOs | `todo` | TODO/FIXME/XXX added by the diff. |
| Repo conventions | `repo-conventions` | Mechanical rules from the repo-root CLAUDE.md (size limits, banned imports, required headers). |
| Readability | -- | Self-documenting code. No unnecessary complexity or over-engineering. Clear, meaningful naming. |

**End-of-phase merge (when Codex was dispatched):**

1. Wait for Codex to return (or its timeout).
2. Parse per "Handling Codex output".
3. Dedupe Claude + Codex findings.
4. Categorize the MERGED set (below), higher severity wins on disagreement.

### Categorize issues

**Minor (auto-fix without asking) is this closed list -- anything outside it is Major:**

(a) Missing access modifiers on private members
(b) Removal of unused imports
(c) Removal of unused private fields/locals
(d) Addition of `readonly` to private fields never reassigned outside constructor
(e) Addition of missing `async` keyword on methods that use `await`

**Major (needs approval):** SOLID violations, god classes, duplicated logic that should reuse existing code, missing DI registration, missing audit fields, missing audit trail on API endpoints, security vulnerabilities, missing test coverage, architectural concerns, missing authorization attributes, and anything not enumerated in the Minor list.

## Phase 3: Fix

Work from the merged finding set (Claude checklist + Codex if dispatched + lint-gate `[tool:*]`). Preserve `[Claude]` / `[Codex]` / `[Claude + Codex]` / `[tool:<name>]` attribution in the user-facing report.

**Scope of edits (literal):** apply fixes ONLY to files already in `git status` as modified/added, OR to the single file required to wire up a finding (e.g. the DI registration file). Never refactor adjacent code, fix pre-existing issues unrelated to the diff, or tidy files opened for context only.

1. Auto-fix Minor issues silently; list what changed (with attribution) in the summary.
2. Report Major issues clearly: what the issue is, why it matters, proposed fix, attribution.
3. **standalone / orchestrated:** AskUserQuestion -- apply the Major fixes, or skip? After emitting the question STOP: no staging, no edits, no pre-written fixes until the user approves a specific finding. Off-list answer -> re-ask once; still off-list -> stop skill.
4. Apply approved fixes (scope-of-edits rule still binds).

**autonomous:** skip the question, announce `autonomous: applying all major fixes`, apply every Major finding (scope-of-edits rule still binds).

## Phase 4: Security review (/security-review)

**orchestrated / autonomous:** SKIP this phase. The caller owns `/security-review`. Record `Security review: deferred to caller` and go to Phase 5.

**standalone:** Phase 2 catches the obvious; this is the deeper pass (OWASP Top 10, tenant isolation, PII handling, audit-trail completeness, dependency scanning).

Skip conditions (any -> skip the phase):

- **UI-only changes** -- definition below.
- **Docs/spec/config-only changes** -- README, markdown, `.feature` files, lint config, CI config with no production impact.
- **No security-relevant surface** -- no new or modified auth, authorization, endpoints, request handlers, persistence writes, file I/O, secrets, PII fields, or cross-tenant operations.

**UI-only definition (literal, shared with Phase 5):** every changed file matches `*.css` / `*.scss` / `*.tailwind.config.*`, OR is a `.tsx` / `.svelte` / `.vue` file whose hunks contain ONLY JSX/template markup changes, className/style changes, UI-primitive import additions, or text/copy changes. Any hunk touching a function body, hook, store, API call, or event handler -> NOT UI-only. Unsure -> not UI-only, run all phases.

When skipped announce: "Skipping security review -- no security-relevant surface in these changes." and go to Phase 5.

**Step 1 -- detect security-relevant surface** from the Phase 1 diff: new/modified routes/endpoints/controllers/handlers; `[Authorize]` / policy / middleware-order changes; request DTOs or user-input code; token/session/cookie/password handling; file upload/download or path construction from user input; cross-tenant persistence writes or queries missing tenant filters; PII added to responses/logs/exceptions; secrets/keys/connection-string/env additions; dependency additions (`package.json`, `.csproj`, `requirements.txt`). None apply -> skip per above.

**Step 2 -- AskUserQuestion:**

> "Changes include security-sensitive surface ([summary of what was detected]). Run /security-review for a deeper OWASP + Pandahrms security audit?"

- **Run /security-review** -> invoke `/security-review --no-commit` against the working tree; it reports findings, may apply approved fixes, returns control here. Treat approved fixes as applied; do not re-ask about committing.
- **Skip** -> note in the summary, go to Phase 5.
- Off-list -> re-ask once; still off-list -> stop skill.

**Step 3 -- record the outcome** for Phase 7: Skipped / Clean / Fixes applied / Findings acknowledged. If `/security-review` errors or times out -> Sub-skill failure handling.

## Phase 5: Spec discrepancy check

**Skip this phase entirely if changes are UI-only** (Phase 4 definition).

**Step 1 -- locate pandahrms-spec** (first path that exists):

1. `$(dirname $PWD)/pandahrms-spec`
2. `$PWD/../../pandahrms-spec`
3. `$HOME/Developer/pandaworks/_pandahrms/pandahrms-spec`

None exist -> report "Spec repo not found at any expected location", go to Phase 6. Never block on a missing spec repo.

**Step 2 -- identify affected specs:** module (performance, recruitment, hr, leave, campaign, ...), feature area, and the business behaviors added/changed/removed. Search `pandahrms-spec/specs/` with Glob/Grep for the relevant `.feature` files.

**Step 3 -- compare MEANING** per behavioral change: new endpoint/action -> scenario exists? validation rule changed -> `@validation` scenario reflects it? status transition modified -> `@status` scenario matches? permission changed -> `@authorization` scenario covers it? bug fix -> `@bugfix` scenario captures the correct behavior? Categorize each: **Covered** / **Outdated** / **Missing**.

**Step 4 -- report and ask.** All covered -> report "Specs are in sync with changes.", go to Phase 6. Outdated/missing -> list each discrepancy, then (standalone / orchestrated) AskUserQuestion:

> "Specs are out of sync with your changes. Create/update specs now? (This invokes /spec)"

- **yes** -> invoke `/spec`, then Phase 6.
- **skip** -> record the gap for the summary, Phase 6.
- Off-list -> re-ask once; still off-list -> stop skill.

**autonomous:** skip the ask, announce `autonomous: skipping spec update, recording gap`, go to Phase 6. NEVER invoke `/spec` in autonomous mode.

**Never write `.feature` files in this skill.** The only path to spec creation/update is `/spec`. User declines -> no spec drafting. `/spec` errors -> Sub-skill failure handling.

## Phase 6: Simplify

Run `/simplify` automatically (three parallel review agents: Code Reuse, Code Quality, Efficiency) against the current changes.

Accept and apply a `/simplify` finding ONLY if BOTH hold:

1. It does not contradict a fix already applied in Phase 3.
2. The fix is mechanical (rename, dead-code removal, single-helper extraction).

Behavior-changing findings: surface them in chat and wait for the user's decision before applying. Autonomous mode: invoke `/simplify --mechanical-only` instead -- behavior-changing findings are recorded in the Phase 7 summary, never applied and never asked about.

`/simplify` errors or times out -> record `Simplify: failed - <reason>` in the summary and proceed. Do not retry.

After completion, show a summary of what changed.

## Phase 7: Done

Summarize all changes made during review:

- Minor issues auto-fixed (with attribution)
- Major issues fixed (with attribution)
- Lint-gate: `consumed (OWNED: <list>)` or `not provided`
- Codex: ran / skipped (`<table row>` or `--no-codex`) / not installed
- Security review outcome (deferred to caller / skipped / clean / fixes applied / findings acknowledged)
- Spec status (in sync / updated / gap recorded)
- /simplify changes

**orchestrated / autonomous:** emit the summary and STOP. No commit question, no `/commit`. Return control to the caller.

**standalone:** AskUserQuestion:

> "Code review complete. Proceed to /commit, or test first?"

- **commit** -> invoke `/commit`. When `/commit` returns control, code-review is COMPLETE -- no further output, no re-summary, no next steps.
- **test** -> end with: "Sounds good. Run /commit when you're ready."
- Off-list -> re-ask once; still off-list -> stop skill.

## Red Flags -- STOP

| Mistake | Rule |
|---------|------|
| Reviewing only the diff, not the full file | Read every changed file in full. |
| Re-detecting an OWNED category | Binary rule: skip the row; reason only about the provided `[tool:*]` findings. |
| Running the linter, a build, tests, coverage, migrations, or dev servers | Out of scope -- `/lint-gate` and `/verify` own those. This skill runs only `git status` / `git diff` / `git diff --cached`, file reads, and the phase-defined sub-skills (`/simplify`, `/security-review`, `/spec`, `/commit`). |
| Auto-skipping review on a trivial diff | standalone ALWAYS asks via AskUserQuestion; orchestrated / autonomous run the full review. |
| Invoking `/security-review` without the Phase 4 question | standalone asks first; orchestrated / autonomous skip the phase -- the caller owns it. |
| Running Phase 4 or 5 on UI-only or docs-only changes | Apply the skip conditions and definitions. |
| Writing `.feature` files in Phase 5 | Spec writes go through `/spec` only -- never draft spec content as a courtesy. |
| Editing AND asking in the same turn (Phase 3) | After AskUserQuestion, STOP. No Edit calls until the user approves. |
| Fixing issues without telling the user | Summarize every auto-fix, with attribution. |
| Editing outside the `git status` changed set | Only changed files plus the single wiring file. Never tidy files opened for context. |
| Splitting / refactoring a god class during this skill | Major finding only -- splitting needs a separate plan. |
| Waiting for Codex before starting the own checklist | Dispatch in the same tool-call batch as the first Phase 2 read. |
| Blocking review when Codex fails or times out | Note failure, proceed Claude-only. |
| Announcing "Codex not installed" | Silent skip only. |
| Dispatching multiple Codex agents | Exactly ONE for the entire diff. |
| Treating Codex output as authoritative | Advisory only -- dedupe, merge attribution, higher severity wins. |
| Blocking when the spec repo is missing | Report it and move on. |
| Committing without the Phase 7 question | standalone asks; orchestrated / autonomous never commit. |
| Continuing after `/commit` returns | Skill ends. |
| Producing commit messages, PR descriptions, changelogs, plans, scaffolds, docs, branches, or PRs | See Out of Scope. |

## Out of Scope

Code Review does NOT produce or run any of the following. If one would be useful, mention it as a one-line suggestion in the Phase 7 summary and let the user decide:

- The project linter, a build / type-check, tests, coverage, or any deterministic guard (TODO/secrets/debug/repo-conventions/structural/traceability) -- those belong to `/lint-gate` and `/verify`
- Commit messages, PR descriptions, changelogs
- Migration plans, test scaffolds, new documentation files
- Design docs, memory entries
- Branch creation, PR creation, push operations
- Database migrations, dev-server starts, deployment builds

## Sub-skill failure handling

Applies whenever code-review invokes `/simplify`, `/security-review`, `/spec`, or `/commit`:

- A sub-skill errors or times out -> record `<skill>: failed - <reason>` in the Phase 7 summary and continue to the next phase. Do NOT retry in this run.
- A sub-skill returns control with its own pending question -> the question belongs to the sub-skill: surface it verbatim, resume code-review once the user answered through the sub-skill.
