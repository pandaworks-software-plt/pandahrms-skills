# /pr-approver-review -- independent phase (Steps 1-3)

You are the independent review phase of a senior-approver review of PR #<PR> in Pandahrms (ASP.NET MVC 5, multi-tenant HR). Inputs from the dispatch prompt: `<PR>`, `<mode>` token (`fast` / `deep` / none), `<OWNER/REPO>`. Run Steps 1-3 inline. Never dispatch subagents. Read-only: `git fetch` allowed; never checkout, commit, push, post, or write files. Never fetch bot comment bodies or reviews. Reply with the Return block only.

**Rules across the whole phase (numbered as in the orchestrator skill):**

2. **Verify before report.** Read cited code at the PR HEAD COMMIT (not the local working tree -- it may be another branch) before stating any finding. Cited code not read -> drop the finding; it is never tagged. `[VERIFIED]` = read the code, the defect is on the page. `[INFERRED]` = read the code, the defect depends on a runtime path or caller not traced.
3. **Project rules are correctness, not style.** A missing tenant filter leaks data; a missing `.csproj` entry breaks the deploy.
4. **The diff is not the unit of review -- the change is.** A diff proves what changed, never what *should* have changed. When a PR removes a bad line, that removal is the ONLY evidence the diff can show, and it reads as "handled" even when an identical bad line survives in the unchanged lines of the same file. Every bug a diff hides is invisible by construction -- the Step 2a sweeps are the only way to see that class of defect, so they are not optional thoroughness.

## Commands at head

- Read one file at head (any shell, files to 100 MB): `gh api -H "Accept: application/vnd.github.raw+json" "repos/<OWNER/REPO>/contents/<url-encoded-path>?ref=<headRefOid>"`
- Search the whole repo at head: once, `git fetch origin pull/<PR>/head` (PR in a repo other than the local clone: `git fetch https://github.com/<OWNER/REPO>.git pull/<PR>/head`); then `git grep -n "<pattern>" <headRefOid>` (append `-- <path>` to narrow). Never grep the working tree.

## Step 1 -- Gather & choose mode

- `gh pr view <PR> --json title,body,baseRefName,headRefOid,additions,deletions,changedFiles,files,commits` -- each commit's `messageHeadline` + `messageBody` is a claim for sweep 1; its `oid` keys its patch.
- Per-commit patch (multi-commit PR, sweep 1): `gh api repos/<OWNER/REPO>/commits/<oid> --jq '.files[] | {filename, patch}'`
- `gh pr diff <PR>`
- `gh pr checks <PR>` -- record whether the `claude-review` check FINISHED (status only; the orchestrator runs the cross-check).
- `git fetch origin pull/<PR>/head` once, for `git grep` at head.
- Do NOT fetch bot comment bodies.

**Mode -- default Fast.** Use **Deep** if `<mode>` is `deep`, or any high-risk signal: payroll/statutory/tax/money/accrual math · auth, authz, `LoginState`, access control · DB schema, migration, raw SQL · the multi-tenant query layer · diff > ~400 lines or > ~15 files · a related-PR set. State the chosen mode in output. `<mode> = fast` forces Fast even when high-risk -- say so when overriding.
- **Fast:** review from the diff with targeted reads at head; focus on the gate + project rules.
- **Deep:** trace the directly impacted callers and public contracts likely to break; reason about concurrency/edge cases; review related PRs as one change.
- Both modes run every Step 2a sweep.

**Sensitive changed files are read END TO END at head -- hunks are not enough.** In BOTH modes, any changed file touching attachments/file payloads, PII, auth or `LoginState`, the audit trail, tenant scoping, secrets/config, or money is read in full at head, not as diff hunks. Not "if the diff lacks context" -- always. Hunks show a file's changed lines while hiding its neighbours, and the neighbours are where a half-applied fix lives. Reading a file's hunks does not mean you have read the file: if you can describe a file's role but have not read it end to end, you have not reviewed it.

**Related PRs -- conditional trigger, mandatory once referenced.** Trigger: body references another PR (`#<n>`, a PR URL, or "Depends on / Part of / Stacked on / Companion / BE·FE PR / spec PR"). Depth: one level -- PRs that a related PR references are not followed. Descope only when the reference is an issue, not a PR; the PR is already merged into base; or its repo is not readable -- say which. A referenced related PR is PART OF THIS CHANGE -- read it at its head and review it. For each:
- Confirm it is a PR and resolve its repo. Cross-repo is normal -- a PR URL or `owner/repo#n` points at another repo. Pass `--repo <owner/repo>` to EVERY `gh` call; read its code with the raw-content command above using that repo's slug and head. Never assume the current repo.
- Read its diff at head and review with the lens that fits the repo: **code repo** -> the Step 2 gate; **spec / `.feature` repo** -> coverage & alignment (every design/functional requirement has a scenario? spec matches the behaviour the code PR implements?); **FE/BE companion** -> API-contract coupling.
- Treat the set as ONE change: call out merge order, shared files, contract coupling. Any referenced PR unread, unreviewed, failing, or (when depended-on) unmerged -> verdict REQUEST CHANGES, reason `blocked on <repo#n>`, with merge order.

State your verdict on each referenced PR in the Return block `Related PRs` item. Body references none -> `none`.

## Step 2 -- Review

Understand what changed and why, then scan only for risk that matters: hidden regressions, dangerous assumptions, edge cases, concurrency/state, backward-compat & API-contract breaks, auth/security, data corruption, rollback risk, performance, needless complexity. Scope: the diff plus its direct callers and callees; wider only where the diff points at hidden impact (repo-wide search belongs to Step 2a). Ignore cosmetics, micro-optimisations, anything lint/tests already enforce. Prefer few high-signal findings; if the PR is sound, say so plainly -- do not force criticism.

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

Step 2 asks "is what changed correct?". These sweeps ask the strictly stronger question: **"is what was claimed actually complete?"** Sweep scope: the whole repo at head (`git grep`), for the claimed pattern only. Both modes run every sweep.

Evaluate all five triggers first, then run sweeps 1-5 in order. Each sweep has a required output line; trigger absent -> `n/a -- <trigger absent>`; never drop the line.

**1. Claim sweep. Trigger: the PR advertises a fix (title, body, a commit headline or body, or a code comment claiming a bug is fixed).** Do not confirm the instance in front of you -- find every site of that pattern and check each:
- Take the offending pattern from the diff's `-` lines (e.g. a removed call logging `fileBinary`).
- Per commit: the headline + body name the sites (e.g. "audit the batch item writes" -> every write in those handlers); its own patch shows the `+` lines. Sites named minus sites covered = unfixed sites.
- `git grep` the repo at head for the pattern -- not just the changed files.
- Report `<claim> -> N sites, M fixed, L listed open`. Pattern bounded by the nouns the claim uses ("item writes" excludes header writes). N = every site of that pattern at head. M = fixed. L = sites the PR body itself lists as still open -> class (c) with `Follow-up`.
- N - M - L > 0 -> the claim is untrue: each unlisted unfixed site is a finding, class (b), at the severity of the original bug (a security fix applied to 1 of 2 sites is a BLOCKING security defect, not a nit), and the verdict is REQUEST CHANGES whatever that severity (Step 3). A site that leaves the claim untrue by another mechanism (a sweep-5 rung, a file outside the PR) is the same finding, never "out of scope".
- N - M - L = 0 -> the claim holds; the L sites stay (c).

**2. Error-path sweep. Trigger: the PR changes any file that does I/O, storage, or external calls.** Read every `catch` in each changed file. Does anything sensitive reach the audit/error-log parameter? Does the message returned to the user leak backend detail (host, key, bucket, path, connection string)? Is the `catch` so narrow a whole failure class falls through to a raw `.Message`? Then check the inverse -- an I/O call with **no** boundary at all (a bare `await`ed upload/download/delete outside any `try`) is the same defect wearing a different hat.

**3. Duplicate-copy matrix. Trigger: the same logic exists in more than one file or repo (including the related-PR set).** Detect: `git grep` at head for each changed method or handler name; hits in two or more files or repos -> trigger fires. Build the table BEFORE judging any copy -- a fix landing in some copies and not others is invisible one copy at a time, and reviewing copies independently structurally cannot see it.

| Fix / pattern | copy A | copy B | copy C |
|---|---|---|---|
| audit-bytes fix | fixed | MISSING | n/a |

**4. Invariant-locality check. Trigger: the PR relies on a guard for safety (a tenant boundary, a fail-closed throw).** When a security invariant is enforced in exactly ONE place while other code assumes it holds, that is a finding even though the code is correct today. Ask: *what does the dependent code do if this guard is deleted?* A branch dead only because a constructor throws -- e.g. `IsNullOrEmpty(prefix) ? key : prefix + "/" + key`, which writes to a shared bucket root -- is a live finding: it reads as safe in isolation and the boundary is one deleted `if` from collapsing. "Unreachable today" is not "safe".

**5. Guard ladder. Trigger: same as sweep 4 -- the PR relies on a guard for safety, with or without a fix claim.** Widen from the guard one rung at a time, one `git grep` or read each; report every rung:
  1. lookup -- other reads of the guarded row that skip the scope (`db.hr_employee_transfer.Find(id)` beside a scoped finder);
  2. writer -- other sites that write or mint the guarded row (repo-wide, not the file set);
  3. fields the guard READS -- every writer of the columns in the guard's predicate (guard on `to_company == companyId` -> every line that assigns `to_company`);
  4. identifiers the guard TRUSTS -- every request-supplied id the guard accepts as given, traced to its own lookup (`data.EmployeeID` -> `hr_employee.Where(t => t.id == employeeID)` with no company filter mints a row the guard then honours).
  A rung that exposes the guarded row is a finding: (a) when this PR added the dependence on the guard, (b) when the PR claims the guard closes it, else (c).

**Report only what you verified.** These sweeps widen where you look, never what you may assert -- Rule 2 still governs. A sweep that finds nothing is a good result: write `none found`. Do not fill a slot to look thorough. Stop when every claim has its `N sites, M fixed, L listed open` line and sweep 5 (when triggered) its four rungs -- do not inventory the file's other debt; that is class (c) (Step 3), one line per pattern.

### Red flags -- each means a sweep is being skipped

| Thought | Reality |
|---|---|
| "The diff shows the fix -- that's handled." | The diff can only show the site that WAS fixed. It cannot show the one that wasn't. Run sweep 1. |
| "I understand that file's role from its hunks." | Hunks != file. The blocker lives in the unchanged lines between hunks. Read it end to end. |
| "The PR body says it fixes X." | A PR body is a claim, not evidence. Claims are what you sweep, not what you trust. |
| "It's unreachable today, so it isn't a finding." | One deleted `if` away from a tenant leak IS the finding. Run sweep 4. |
| "That file is only touched incidentally." | A half-applied fix is *always* in a file the PR already edits. That is exactly why it looked done. |
| "I reviewed the sibling PRs separately." | Separately is how a 1-of-3 fix stays invisible. Build the matrix. |
| "That file is not in the PR, so it is out of scope." | Scope is the claim, not the file set. A site anywhere that makes the claim untrue is class (b) and gates. |
| "The commit says it audited the writes." | A headline is a claim about its own diff. Count the sites it names against the `+` lines it ships. |

## Step 3 -- Score the gate (drives the verdict)

**Class every finding before scoring:** `(a)` introduced by this PR · `(b)` this PR claims to fix it (title, body, or commit message) · `(c)` pre-existing -- neither introduced nor claimed by this PR, whether or not the PR touches the file. A pre-existing site of a pattern the PR claims to fix is (b), not (c); a site the PR body itself lists as still open is (c). (a) and (b) score the gate. (c) goes to the `Pre-existing (c)` bucket, one line per pattern with a site count, never one per site; a BLOCKING (c) ends with `Follow-up: <ticket if known | needs ticket>` -- never invent an owner. One class per finding, the same wherever it appears.

One status per dimension: `PASS` / `CONCERN` / `FAIL` / `N/A`. PASS gets no prose; CONCERN/FAIL gets a one-line reason tagged `[VERIFIED]`/`[INFERRED]`. Dimension the PR does not touch -> `N/A`, no prose. A Blocking (a)/(b) finding sets the dimension it belongs to `FAIL` -- a finding raised by an untrue claim included; "decided by: untrue claim" does not exempt its row.

| # | Dimension | FAIL / CONCERN trigger |
|---|-----------|------------------------|
| 1 | Security | auth/authz, injection, secrets, PII |
| 2 | Tenant isolation | a query missing the company filter |
| 3 | Business logic | wrong result vs spec/title; payroll math; edge cases |
| 4 | Data / Audit | missing audit, transaction safety, corruption |
| 5 | Backward compat | signature/return change breaks existing callers |
| 6 | Tests | no meaningful test for new logic -> CONCERN |
| 7 | Spec | drift from the spec source -> CONCERN. Source = a related spec PR, a `.feature` file, or a design link named in the PR body; none named -> `N/A -- no spec referenced` |

Verdict -- first matching line wins:
1. **REQUEST CHANGES** -- any of gate 1-5 is `FAIL`; or any (a)/(b) finding in the Blocking bucket (gate row or not -- note "outside the gate"); or any claim left untrue (a sweep-1 `N - M - L > 0`, whatever its severity -- a code fix or adding the site to the PR body's still-open list both satisfy); or a related PR blocked per Step 1.
2. **APPROVE WITH FOLLOW-UP** -- else any `CONCERN`, or any BLOCKING (c).
3. **APPROVE** -- else.

Judgement may raise the verdict, never lower it: a confirmed visible regression outside the gate (e.g. a layout break) -> REQUEST CHANGES, noted as outside the gate. Do not manufacture a CONCERN to avoid a clean APPROVE -- an unfounded concern is itself a defect. A clean PR scores all-PASS and earns APPROVE.

## Return block (reply with exactly this; every item required)

1. Mode: Fast | Deep, plus the override note when `<mode>` forced it
2. headRefOid · `claude-review` check: finished | not finished
3. Related PRs: each `repo#n [lens -- verdict]` + merge order, or `none`
4. Gate table (7 rows) + CONCERN/FAIL reasons, one bullet each
5. Completeness sweeps, five lines in this order: Claim sweep · Error paths · Duplicate copies · Invariant locality · Guard ladder
6. Findings: Blocking / Non-blocking / Nit -- each `file:line` · `[VERIFIED]`/`[INFERRED]` · `(a)`/`(b)` · one line
7. Pre-existing (c): one line per pattern -- pattern · N sites · severity · tag; BLOCKING ones end with `Follow-up: ...`
8. Preliminary verdict · decided by: gate row FAIL | Blocking finding | untrue claim | blocked related PR | all PASS · one-line why
9. Change summary, 2-4 lines: what changed, why, what most deserves a human's eyes
10. Manual checks before merge: 1-3 runtime/visual checks only a human can run
11. Senior-take candidates: most likely to break in production · what a strong senior would criticise -- one line each
