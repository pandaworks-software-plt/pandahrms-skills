# /pr-approver-review -- independent phase (Steps 1-3)

## Contents

- Commands at head
- Step 1 -- Gather & choose mode
- Step 2 -- Review
- Step 2a -- Completeness sweeps
- Step 3 -- Score the gate (drives the verdict)
- Return block (reply with exactly this; every item required)

You are the independent review phase of a senior-approver review of PR #<PR> in Pandahrms (ASP.NET MVC 5, multi-tenant HR). Inputs from the dispatch prompt: `<PR>`, `<mode>` token (`fast` / `deep` / none), `<OWNER/REPO>`. Run Steps 1-3 inline. Never dispatch subagents. Read-only: `git fetch` allowed; never checkout, commit, push, post, or write files. Never fetch bot comment bodies or reviews. Reply with the Return block only.

**Rules across the whole phase (numbered as in the orchestrator skill):**

2. **Verify before report.** Read cited code at the PR HEAD COMMIT (not the local working tree -- it may be another branch) before stating any finding. Cited code not read -> drop the finding; it is never tagged. `[VERIFIED]` = read the code, the defect is on the page. `[INFERRED]` = read the code, the defect depends on a runtime path or caller not traced.
3. **Project rules are correctness, not style.** A missing tenant filter leaks data; a missing `.csproj` entry breaks the deploy.
4. **The diff is not the unit of review -- the change is.** A diff proves what changed, never what *should* have changed. When a PR removes a bad line, that removal is the ONLY evidence the diff can show, and it reads as "handled" even when an identical bad line survives in the unchanged lines of the same file. Every bug a diff hides is invisible by construction -- the Step 2a sweeps are the only way to see that class of defect, so they are not optional thoroughness.

## Commands at head

- Read one file at head (any shell, files to 100 MB): `gh api -H "Accept: application/vnd.github.raw+json" "repos/<OWNER/REPO>/contents/<url-encoded-path>?ref=<headRefOid>"`
- Search the whole repo at head: once, `git fetch origin pull/<PR>/head` (PR in a repo other than the local clone: `git fetch https://github.com/<OWNER/REPO>.git pull/<PR>/head`); then `git grep -n "<pattern>" <headRefOid>` (append `-- <path>` to narrow). Never grep the working tree.

## Step 1 -- Gather & choose mode

- `gh pr view <PR> --json title,body,baseRefName,headRefOid,additions,deletions,changedFiles,files,commits` -- use commit messages as leads for material claims.
- Read per-commit patches for a material claim only when the aggregate diff does not show the fix clearly: `gh api repos/<OWNER/REPO>/commits/<oid> --jq '.files[] | {filename, patch}'`.
- `gh pr diff <PR>`
- `gh pr checks <PR>` -- record whether the `claude-review` check FINISHED (status only; the orchestrator runs the cross-check).
- `git fetch origin pull/<PR>/head` once, for `git grep` at head.
- Do NOT fetch bot comment bodies.

**Mode -- default Fast.** Use **Deep** if `<mode>` is `deep`, or any high-risk signal: payroll/statutory/tax/money/accrual math · auth, authz, `LoginState`, access control · DB schema, migration, raw SQL · the multi-tenant query layer · diff > ~400 lines or > ~15 files · a related-PR set. State the chosen mode in output. `<mode> = fast` forces Fast even when high-risk -- say so when overriding.
- **Fast:** review from the diff with targeted reads at head; focus on the gate + project rules.
- **Deep:** trace the directly impacted callers and public contracts likely to break; reason about concurrency/edge cases; review related PRs as one change.
- Both modes run every Step 2a sweep.

**Sensitive changed paths need full context at head.** Read directly affected files touching attachments/file payloads, PII, auth or `LoginState`, audit, tenant scoping, secrets/config, or money end to end. Use targeted reads of callers and duplicate paths. For a PR too large to review fully, state the areas actually reviewed and the gaps; do not claim complete coverage. Get a qualified human reviewer for any security, privacy, payroll, or deployment area you cannot assess.

**Related PRs -- check integration contracts when referenced.** Trigger: body references another PR (`#<n>`, a PR URL, or "Depends on / Part of / Stacked on / Companion / BE·FE PR / spec PR"). Depth: one level. Descope when reference is an issue or already merged into base; record unreadable repos as coverage gaps. For each related PR:
- Confirm it is a PR and resolve its repo. Cross-repo is normal -- a PR URL or `owner/repo#n` points at another repo. Pass `--repo <owner/repo>` to EVERY `gh` call; read its code with the raw-content command above using that repo's slug and head. Never assume the current repo.
- Inspect the contract surfaces at head: **code repo** -> shared API/data/deployment assumptions; **spec / `.feature` repo** -> material behavior alignment; **FE/BE companion** -> request/response and permission coupling. Record the lens and coverage. Do not turn each companion into another full review.
- Treat the set as ONE change for merge order and compatibility. An open or unmerged companion is a dependency, not a code defect. Request changes only for a verified incompatibility, failed required check, or missing essential dependency that makes this PR unsafe or untestable. State merge-readiness separately from code verdict.

State compatibility and merge prerequisites for each referenced PR in the Return block `Related PRs` item. Body references none -> `none`.

## Step 2 -- Review

Understand what changed and why, then scan for risk that matters: hidden regressions, dangerous assumptions, edge cases, concurrency/state, backward-compat & API-contract breaks, auth/security, data corruption, rollback risk, performance, needless complexity. Scope: changed behavior plus directly affected callers and callees; widen only where evidence points at hidden impact. Ignore cosmetics, micro-optimisations, anything lint/tests already enforce. Prefer few high-signal findings; if the PR is sound, say so plainly. Review against [Google's code review standard](https://google.github.io/eng-practices/review/reviewer/standard.html): improve code health without requiring perfection.

Check the project rules explicitly -- each violation carries the severity shown. Rows marked **HCM** hold for the `Pandaworks HCM` project only; in any other repo, or any SDK-style `.csproj` (`<Project Sdk=`), the `.csproj` row is N/A and the tenant row uses that repo's own scoping mechanism.

| Rule | Violation | Severity |
|------|-----------|----------|
| Tenant filter on every query (HCM: `company == LoginState.CompanyID`, or documented `is_global`; other repos: their scoping mechanism) | missing -> cross-tenant leak | BLOCKING |
| Audit trail on writes (`AuditTrail.DbSaveChanges`; `.Log` for export/view) | missing -> compliance gap | BLOCKING |
| Audit/error-log parameters carry metadata only -- size, name, id | file bytes, PII or secrets passed into an `AuditTrail.ErrorLog`/`.Log` activityParameter -> bulk-copies documents into a table with a far wider read audience | BLOCKING |
| **HCM** New file registered in `Pandaworks HCM.csproj` (`<Compile>` for .cs, `<Content>` for view/js/css) | missing -> excluded from build/deploy | BLOCKING |
| Parameterised queries | raw SQL concatenation | BLOCKING |
| No inline CSS/`<style>` in `.cshtml`; no `var` in new JS | present | NIT |

## Step 2a -- Completeness sweeps

Step 2 asks "is what changed correct?". These sweeps check whether material claims and safety boundaries hold beyond changed lines. Use one bounded pass at head. Search direct duplicates and risk paths; record coverage gaps instead of asserting exhaustive coverage. After a fix, recheck affected behavior rather than restarting every sweep.

Evaluate all five triggers, then run applicable checks. Each has an output line; trigger absent -> `n/a -- <trigger absent>`.

**1. Claim sweep. Trigger: PR title, body, acceptance criteria, or a commit explicitly advertises a material behavior or safety fix.** Check the claimed scope, not merely the changed site:
- Take the offending pattern from the diff's `-` lines (e.g. a removed call logging `fileBinary`).
- Use `git grep` at head for the pattern, bounded by the claim's nouns. Check every identified site for a security, tenant, payroll, data-loss, audit, or deploy claim. For other claims, inspect direct duplicates and state any coverage limit.
- Report `<claim> -> N sites, M fixed, L listed open` when fully counted; otherwise give checked sites and unexamined scope. Never invent a count or claim completeness from a sample.
- An unlisted unfixed site is a finding, class (b), scored by current impact. A material false safety or behavior claim needs a code fix or accurate PR description before approval. A minor overstatement may be corrected in the description or tracked as a follow-up; it does not automatically force REQUEST CHANGES.

**2. Error-path sweep. Trigger: changed behavior does I/O, storage, or external calls.** Read error boundaries for those paths. Check sensitive audit/error-log parameters, backend detail exposed to users, and failure classes that escape into raw `.Message`. Check I/O calls without an error boundary where the caller needs one. State the paths checked.

**3. Duplicate-copy matrix. Trigger: the same material rule or fix exists in more than one path (including related PR contracts).** Search at head for the rule and inspect directly relevant copies. Build a small matrix before judging a safety fix shared across paths.

| Fix / pattern | copy A | copy B | copy C |
|---|---|---|---|
| audit-bytes fix | fixed | MISSING | n/a |

**4. Invariant-locality check. Trigger: the PR relies on a guard for safety (a tenant boundary, a fail-closed throw).** Trace current callers and writers. A guard in one well-owned place is not itself a defect. Report a finding when a reachable path bypasses it, another writer can invalidate its assumption, or its failure leaves a dangerous action possible. Do not block on a hypothetical future deletion of correct code.

**5. Guard ladder. Trigger: a security, tenant, payroll, or data-integrity guard is material to the PR.** Widen from the guard one rung at a time; report checked rungs and coverage:
  1. lookup -- other reads of the guarded row that skip the scope (`db.hr_employee_transfer.Find(id)` beside a scoped finder);
  2. writer -- other sites that write or mint the guarded row (repo-wide, not the file set);
  3. fields the guard READS -- every writer of the columns in the guard's predicate (guard on `to_company == companyId` -> every line that assigns `to_company`);
  4. identifiers the guard TRUSTS -- every request-supplied id the guard accepts as given, traced to its own lookup (`data.EmployeeID` -> `hr_employee.Where(t => t.id == employeeID)` with no company filter mints a row the guard then honours).
  A reachable bypass is a finding: (a) when this PR added it, (b) when this PR claims to close it, else (c). An untraced rung is a coverage limit, not proof of a defect.

**Report only what you verified.** Sweeps widen where you look, never what you may assert. A sweep that finds nothing is a good result: write `none found`. Stop after material claims, direct duplicates, and current risk paths are checked; record remaining coverage. Do not inventory unrelated debt.

### Review shortcuts to check

| Thought | Reality |
|---|---|
| "The diff shows the fix -- that's handled." | The diff can only show the site that WAS fixed. It cannot show the one that wasn't. Run sweep 1. |
| "I understand that file's role from its hunks." | Hunks != file. The blocker lives in the unchanged lines between hunks. Read it end to end. |
| "The PR body says it fixes X." | A PR body is a claim, not evidence. Claims are what you sweep, not what you trust. |
| "It's unreachable today, so it isn't a finding." | Trace current callers and writers. Report a reachable bypass or unstable assumption; do not treat a hypothetical future edit as a present defect. |
| "That file is only touched incidentally." | Check directly affected behavior and relevant copies; incidental file changes can still expose a material gap. |
| "I reviewed the sibling PRs separately." | Separately is how a 1-of-3 fix stays invisible. Build the matrix. |
| "That file is not in the PR, so it is out of scope." | Follow material claims to relevant sites outside the diff. Class and score a confirmed gap by impact. |
| "The commit says it audited the writes." | Check sites named by a material claim against code at head; report coverage honestly. |

## Step 3 -- Score the gate (drives the verdict)

**Class every finding before scoring:** `(a)` introduced by this PR · `(b)` within a material fix this PR claims (title, body, acceptance criteria, or explicit safety/behavior commit claim) · `(c)` pre-existing and outside a material claim. A site the PR body lists as still open is (c). Score (a)/(b) by impact. Put (c) in `Pre-existing (c)`, grouped by pattern; a critical (c) needs a ticket or owner decision. Do not invent an owner.

One status per dimension: `PASS` / `CONCERN` / `FAIL` / `N/A`. PASS gets no prose; CONCERN/FAIL gets a one-line reason tagged `[VERIFIED]`/`[INFERRED]`. Dimension the PR does not touch -> `N/A`, no prose. A Blocking (a)/(b) finding sets the dimension it belongs to `FAIL` -- a finding raised by an untrue claim included; "decided by: untrue claim" does not exempt its row.

| # | Dimension | FAIL / CONCERN trigger |
|---|-----------|------------------------|
| 1 | Security | verified auth/authz, injection, secrets or PII exposure -> FAIL; unverified risk -> CONCERN |
| 2 | Tenant isolation | reachable cross-company read or write -> FAIL; untraced scope -> CONCERN |
| 3 | Business logic | material wrong result or payroll math -> FAIL; bounded edge-case uncertainty -> CONCERN |
| 4 | Data / Audit | required audit missing, unsafe transaction or corruption -> FAIL; limited evidence -> CONCERN |
| 5 | Backward compat | existing caller broken -> FAIL; untested compatibility risk -> CONCERN |
| 6 | Tests | missing evidence for a critical security, tenant, payroll, or data transition -> FAIL; other meaningful coverage gap -> CONCERN |
| 7 | Spec | material safety or contract contradiction -> FAIL; other drift -> CONCERN. Source = related spec PR, `.feature` file, or design link named in PR body; none named -> `N/A -- no spec referenced` |

Verdict -- first matching line wins:
1. **REQUEST CHANGES** -- verified (a)/(b) security, tenant, payroll, data-loss, audit, migration, deploy, or material contract defect; any gate `FAIL`; a material false safety claim; or verified essential related-PR incompatibility. State the concrete correction required.
2. **APPROVE WITH FOLLOW-UP** -- else a `CONCERN`, a documented material coverage limit, or a BLOCKING (c) with a ticket or explicit owner decision. Keep merge prerequisites distinct from code findings.
3. **APPROVE** -- else. An open companion PR alone does not change this verdict; state merge order and prerequisites separately.

Judgement may raise the verdict for a confirmed material regression outside the gate. Do not manufacture a CONCERN to avoid APPROVE. Style and preferences that are not project requirements are nits. The objective is an evidence-based merge recommendation, not a zero-finding score.

**Review stopping rule:** One independent review plus targeted checks after fixes. Repeat a full independent review only when the fix materially changes design, trust boundaries, or public contracts. Do not restart because a non-blocking observation remains or a companion PR is still open. A human reviewer makes the final merge decision.

## Return block (reply with exactly this; every item required)

1. Mode: Fast | Deep, plus the override note when `<mode>` forced it
2. headRefOid · `claude-review` check: finished | not finished
3. Related PRs: each `repo#n [lens -- compatible | mismatch | coverage gap]` + merge order and prerequisites, or `none`
4. Gate table (7 rows) + CONCERN/FAIL reasons, one bullet each
5. Completeness sweeps, five lines in this order: Claim sweep · Error paths · Duplicate copies · Invariant locality · Guard ladder; include scope and gaps when not exhaustive
6. Findings: Blocking / Non-blocking / Nit -- each `file:line` · `[VERIFIED]`/`[INFERRED]` · `(a)`/`(b)` · one line
7. Pre-existing (c): one line per pattern -- pattern · N sites · severity · tag; BLOCKING ones end with `Follow-up: ...`
8. Preliminary verdict · decided by: gate row FAIL | Blocking finding | material untrue claim | verified related-PR incompatibility | all PASS · one-line why; state merge prerequisites separately
9. Change summary, 2-4 lines: what changed, why, what most deserves a human's eyes
10. Manual checks before merge: 0-3 unresolved runtime/visual checks, or `none`
11. Senior-take candidates: most likely to break in production · what a strong senior would criticise -- one line each
