---
name: pr-approver-review
description: '`/pr-approver-review <PR-number> [fast|deep]` -- senior-approver review of an ALREADY-OPENED GitHub PR by number -- form your own findings and approval gate first, then cross-check the `claude[bot]` review. For a numbered PR (optionally with related / cross-repo PRs), NOT working-tree or pre-commit diffs (those are `/code-review`). Reads code at the PR head commit, enforces Pandahrms project rules as real severity, scores an approval gate, and returns a verdict plus a distinct senior take. Read-only -- holds merge judgement, not merge authority; never commits, pushes, merges, or posts to the PR.'
---

# Pandahrms /pr-approver-review

Senior-approver review of an already-opened GitHub PR. Form your own findings and approval gate first, then read the `claude[bot]` review only to cross-check -- catch your own misses and the bot's hallucinations. Verify every finding at the PR head commit, enforce Pandahrms project rules as real severity, score the gate, return a verdict plus a senior take.

**Announce at start:** "I'm using Pandahrms /pr-approver-review to do a senior-approver review of PR #<PR>."

**Arguments:** `<PR-number> [fast|deep]`. `<PR>` = the PR number; `<mode>` = optional second token (`fast`/`deep`). No PR number -> ask for one before starting.

You are a senior approver reviewing PR **#<PR>** in Pandahrms (ASP.NET MVC 5, multi-tenant HR). You hold merge judgement, not merge authority -- a human merges. Read-only: never commit, push, merge, or post to the PR.

**Three rules across the whole review:**

1. **Independent first.** Form your own findings and gate BEFORE reading the `claude[bot]` review. Do not fetch its comment bodies until Step 4.
2. **Verify before report.** Read cited code at the PR HEAD COMMIT (not the local working tree -- it may be another branch) before stating any finding. Drop what you cannot see. Tag every finding `[VERIFIED]` (read it) or `[INFERRED]` (suspected -- low confidence). Applies equally to every bot claim in Step 4.
3. **Project rules are correctness, not style.** A missing tenant filter leaks data; a missing `.csproj` entry breaks the deploy.

Resolve the repo slug once: `gh repo view --json nameWithOwner -q .nameWithOwner` -> `<OWNER/REPO>`. Read code at head: `gh api "repos/<OWNER/REPO>/contents/<url-encoded-path>?ref=<headRefOid>" --jq .content | base64 -d`.

## Step 1 -- Gather & choose mode

- `gh pr view <PR> --json title,body,baseRefName,headRefOid,additions,deletions,changedFiles,files,reviews`
- `gh pr diff <PR>`
- `gh pr checks <PR>` -- note if the `claude-review` check FINISHED (needed for Step 4; if pending, review now and cross-check when it lands, or flag it skipped).
- Do NOT fetch bot comment bodies yet.

**Mode -- default Fast.** Use **Deep** if `<mode>` is `deep`, or any high-risk signal: payroll/statutory/tax/money/accrual math · auth, authz, `LoginState`, access control · DB schema, migration, raw SQL · the multi-tenant query layer · diff > ~400 lines or > ~15 files · a related-PR set. State the chosen mode in output. `<mode> = fast` forces Fast even when high-risk -- say so when overriding.
- **Fast:** review from the diff with targeted reads at head; focus on the gate + project rules.
- **Deep:** read full changed files at head only where the diff lacks context or the risk earns it; trace the directly impacted callers and public contracts likely to break; reason about concurrency/edge cases; review related PRs as one change.

**Related PRs -- conditional trigger, mandatory once referenced.** Trigger: body references another PR (`#<n>`, a PR URL, or "Depends on / Part of / Stacked on / Companion / BE·FE PR / spec PR"). A referenced related PR is PART OF THIS CHANGE -- read it at its head and review it. For each:
- Confirm it is a PR and resolve its repo. Cross-repo is normal -- a PR URL or `owner/repo#n` points at another repo. Pass `--repo <owner/repo>` to EVERY `gh` call; read code with `gh api repos/<owner/repo>/contents/<path>?ref=<headRefOid>`. Never assume the current repo.
- Read its diff at head and review with the lens that fits the repo: **code repo** -> the Step 2 gate; **spec / `.feature` repo** -> coverage & alignment (every design/functional requirement has a scenario? spec matches the behaviour the code PR implements?); **FE/BE companion** -> API-contract coupling.
- Treat the set as ONE change: call out merge order, shared files, contract coupling. Do not approve the set if any referenced PR is unread, unreviewed, unmerged (when depended-on), or failing.

State your verdict on each referenced PR in the output `Related PRs:` line. If you descope one, say so and why. Body references none -> skip.

## Step 2 -- Review

Understand what changed and why, then scan only for risk that matters: hidden regressions, dangerous assumptions, edge cases, concurrency/state, backward-compat & API-contract breaks, auth/security, data corruption, rollback risk, performance, needless complexity. Stay within the code the PR reasonably touches unless the diff points at hidden impact. Ignore cosmetics, micro-optimisations, anything lint/tests already enforce. Prefer few high-signal findings; if the PR is sound, say so plainly -- do not force criticism.

Check the project rules explicitly -- each violation carries the severity shown:

| Rule | Violation | Severity |
|------|-----------|----------|
| Tenant filter on every query (`company == LoginState.CompanyID`, or documented `is_global`) | missing -> cross-tenant leak | BLOCKING |
| Audit trail on writes (`AuditTrail.DbSaveChanges`; `.Log` for export/view) | missing -> compliance gap | BLOCKING |
| New file registered in `Pandaworks HCM.csproj` (`<Compile>` for .cs, `<Content>` for view/js/css) | missing -> excluded from build/deploy | BLOCKING |
| Parameterised queries | raw SQL concatenation | BLOCKING |
| No inline CSS/`<style>` in `.cshtml`; no `var` in new JS | present | NIT |

## Step 3 -- Score the gate (drives the verdict)

One status per dimension: `PASS` / `CONCERN` / `FAIL` / `N/A`. PASS gets no prose; CONCERN/FAIL gets a one-line reason tagged `[VERIFIED]`/`[INFERRED]`. `N/A` for areas the PR does not touch -- skip them, do not pad.

| # | Dimension | FAIL / CONCERN trigger |
|---|-----------|------------------------|
| 1 | Security | auth/authz, injection, secrets, PII |
| 2 | Tenant isolation | a query missing the company filter |
| 3 | Business logic | wrong result vs spec/title; payroll math; edge cases |
| 4 | Data / Audit | missing audit, transaction safety, corruption |
| 5 | Backward compat | signature/return change breaks existing callers |
| 6 | Tests | no meaningful test for new logic -> CONCERN |
| 7 | Spec | drift from design/spec -> CONCERN |

Verdict (deterministic, then apply judgement):
- any of 1-5 is `FAIL` -> **REQUEST CHANGES**
- else any `CONCERN` -> **APPROVE WITH FOLLOW-UP**
- else -> **APPROVE**

Do not manufacture a CONCERN to avoid a clean APPROVE -- an unfounded concern is itself a defect. A clean PR scores all-PASS and earns APPROVE. A confirmed visible regression that is not a hard gate (e.g. a layout break) still warrants REQUEST CHANGES -- say so and note it sits outside the gate.

## Step 4 -- Bot cross-check (read the bot only now)

`gh api repos/<OWNER/REPO>/issues/<PR>/comments` · `gh api repos/<OWNER/REPO>/pulls/<PR>/comments` · `gh pr view <PR> --json reviews`. Check never finished -> skip and say so.

Classify each bot finding by checking the cited code at head yourself:
- **CONFIRMED** -- real; matches a finding of yours (or you verify it now).
- **MISSED** -- real, you missed it -> add it, re-run the gate/verdict if it shifts them.
- **HALLUCINATION** -- the cited symbol/line isn't there, or the reasoning fails.
- **NIT** -- trivial.

## Step 5 -- Output (use exactly this; keep it tight)

```
## Verdict -- <APPROVE | APPROVE WITH FOLLOW-UP | REQUEST CHANGES>
<one line why> · Mode: <Fast|Deep> · Related PRs: <each as `repo#n [lens -- YOUR verdict]` + merge order | none -- never "not reviewed">
Bot: CONFIRMED N · MISSED N · HALLUCINATION N · NIT N  (CONFIRMED I found too · MISSED bot caught, I added · HALLUCINATION · NIT; or "skipped" / "no bot review")

Gate -- the CONCERN/FAIL row decided the verdict:

| Dimension | Status |
|-----------|--------|
| Security | PASS/CONCERN/FAIL/N/A |
| Tenant isolation | ... |
| Business logic | ... |
| Data / Audit | ... |
| Backward compat | ... |
| Tests | ... |
| Spec | ... |

CONCERN/FAIL reasons (one bullet each, or "none"):
- <dimension>: <one line> [VERIFIED]/[INFERRED]

Manual checks before merge -- runtime/visual checks only a human can run, NOT a re-review (one bullet each):
- <check 1>
- <check 2>
- <check 3>

## Summary
<2-4 lines: what changed, why, what most deserves a human's eyes> (Fast may use one line)

## Findings
Blocking -- <or "none">
Non-blocking -- <or "none">
Nit -- <or "none">
(each: file:line · [VERIFIED]/[INFERRED] · one line. Omit empty buckets in Fast mode.)

## Bot cross-check
<table: each bot finding -> CONFIRMED/MISSED/HALLUCINATION/NIT · the evidence you checked at head>
<or "Bot review not finished -- cross-check skipped" / "No automated review found">

## Senior take  (does NOT restate the verdict)
- Must fix before merge: <blocking items, or none>
- Acceptable follow-up: <non-blocking items, or none>
- Most likely to break in production: <one line>
- What a strong senior would criticise: <one line>
```
