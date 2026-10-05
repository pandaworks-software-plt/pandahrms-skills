---
name: commit
description: 'Triggers when the user explicitly requests a git commit of the whole branch''s working-tree changes -- phrases like "commit my changes", "git commit", "ready to commit", "/commit", or "make atomic commits". Branch-scope commit gate -- invokes `/security-review --no-commit` for sensitive changes, auto-fixes format + lint inline, invokes `/verify` (the project-scoped build + test runner), then plans and executes atomic commits across the branch. Does NOT skip the security gate; `/commit --skip` bypasses only format, lint, and verify.'
---

# Commit

## Contents

- Overview
- Skip Mode
- Execution Order
  - Phase 0: Sensitive-change security gate
  - Phase 1: Hard Gate (Format + Lint + /verify)
  - Phase 1A: Format Auto-Fix
  - Phase 1B: Lint Auto-Fix
  - Phase 1C: /verify (Build + Test)
  - Phase 2: Gather Changes
  - Phase 3: Plan Atomic Commits
  - Phase 4: Execute Commits
  - Phase 5: Terminate
- Safety Rules (hard)

## Overview

Branch-scope commit step. Run final security gate for sensitive changes, verify whole branch's working tree, then plan and execute atomic commits.

**Phase 0 and Phase 1 are HARD GATES.** Before any commit, sensitive changes must clear `/security-review`; working tree must then have 0 format errors, 0 lint errors, and `VERIFY RESULT: PASS` from `/verify` (build + test) -- **even when failures are pre-existing or unrelated to current session changes**. `/commit --skip` bypasses Phase 1 only. The "Tool missing" branch in Failure Handling is Phase 1's other escape hatch.

Invoke `/verify` with the active host's skill mechanism. In Codex, when nested skill invocation is not exposed as a tool, read `../verify/SKILL.md` in full (to end of file) and execute it inline.

Phase 1A/1B auto-fix mechanical format/lint violations in write mode (`dotnet format`, `biome check --write`, `eslint --fix`, etc.); those fixes get pulled into the commit plan in Phase 3. Format and lint run BEFORE `/verify` so it sees the post-fix tree. For non-mechanical failures (a `/verify` FAIL, lint diagnostics that cannot be auto-fixed), STOP and tell the user what to fix -- never make judgment-call code edits, never hand-edit source to silence a diagnostic or pass a test.

## Skip Mode

`/commit --skip` (literal whitespace-delimited token in invocation) bypasses Phase 1 entirely: no formatter, linter, or `/verify` run. Phase 0 still runs. Before Phase 2, emit verbatim: `Skip mode: Phase 1 gate bypassed. Format, lint, and /verify (build + tests) will NOT run. Proceeding directly to commit planning.` All other phases and every safety rule still apply.

## Execution Order

Phases run strictly in order 0 -> 1 -> 2 -> 3 -> 4 -> 5. Within Phase 1: 1A (format auto-fix) -> 1B (lint auto-fix) -> 1C (`/verify`). Phase 2's four git commands run in parallel; that is the only parallelism.

Phase ledger: at every phase transition print `Phase N/5 done -> Phase N+1`. A phase that STOPS is never marked done.

**Phase 0: Sensitive-change security gate**

Classify entire uncommitted tree before any formatter or linter changes it. Mark sensitive when either:

- Any contributing work card has `sensitivity: sensitive`.
- Diff touches authentication, authorization, session, tenant boundary, money, billing, payment, database schema, migration, data rewrite, PII handling, audit logging, data retention, or risk named by design docs.

Standard tree -> announce `Security review skipped: no sensitive changes.` and continue.

Sensitive tree -> invoke `/security-review --no-commit` over whole uncommitted tree. Clean result or fully fixed findings -> continue. Unresolved Critical or High finding, review failure, or timeout -> STOP; never commit. Surface Medium, Low, and Info findings before continuing.

Security fixes land before Phase 1, so format, lint, build, and tests verify final tree.

**Phase 1: Hard Gate (Format + Lint + /verify)**

### Detection

Detect ALL project types present in the workspace (the gate covers the whole working tree):

- `.csproj` / `.sln` anywhere -> run .NET format/lint.
- `package.json` anywhere -> run JS/TS format/lint.
- Mixed repos: run BOTH, aggregate, STOP if any sub-step fails.
- Neither -> emit `No format/lint configuration recognized for this repo; proceeding to the /verify sub-step.` Do not invent commands.

`/verify` owns build/test detection -- this skill never detects or runs build/test commands itself.

### Write-Pass Scope (Changed Files Only)

The 1A/1B **write** passes run scoped to the changed files; the **verify** passes stay whole-tree. Compute the changed set once:

```bash
{ git diff --name-only; git diff --cached --name-only; git status --porcelain | grep '^??' | cut -c4-; } | sort -u
```

Filter to the file types each tool handles; pass the filtered paths to the write command. Empty list for a tool -> run its verify pass only.

**When a whole-tree verify pass fails ONLY on files outside the changed set**, STOP and ask the user:

- **"Fix tree-wide now (the fixes land as a separate chore commit in the plan)"** -> re-run the write pass whole-tree, re-verify, group the out-of-set files as their own `chore` commit in Phase 3.
- **"Skip this sub-step (gate on changed files only this run)"** -> continue; the changed files are clean.

Never silently reformat the whole repo into feature commits.

**Phase 1A: Format Auto-Fix**

Write pass (scoped):

- **.NET**: `dotnet format --include <changed .cs paths>`
- **JS/TS** (first match wins): `biome.json`/`biome.jsonc` -> `pnpm biome format --write <paths>`; `.prettierrc.*` or `prettier` key -> `pnpm prettier --write <paths>`; otherwise rely on Phase 1B's linter.

Verify pass (whole-tree): `dotnet format --verify-no-changes` / `pnpm biome format .` / `pnpm prettier --check .`. Remaining issues -> STOP, emit the diagnostics verbatim, and point the user at the likely cause (generated/vendored file to ignore, or a syntax error that broke the parser). Re-run `/commit` when verify passes.

**Phase 1B: Lint Auto-Fix**

Fix pass scoped, verify pass whole-tree:

- **.NET**: covered by `dotnet format`; no separate step.
- **JS/TS** (first match wins): biome -> `pnpm biome check --write <paths>` then `pnpm biome check .`; eslint (flat or legacy config) -> `pnpm exec eslint --fix <paths>` then `pnpm lint`; `lint:fix` script -> scoped linter binary, bare script only as fallback, then `pnpm lint`; `lint` script only -> verify mode only; none -> skip.

Errors the linter could not auto-fix -> STOP, emit violations verbatim, tell the user to fix each or add a one-line `// reason` suppression, and re-run `/commit`.

**Phase 1C: /verify (Build + Test)**

BEFORE invoking `/verify`, check for a prior PASS on an unchanged tree:

1. Read `work_folder` from the per-work `_overview.md` (none -> skip this check).
2. Run `bash <skill-dir>/../verify/scripts/check-result.sh <work-folder>` (`<skill-dir>` = directory containing this `SKILL.md`, `${CLAUDE_SKILL_DIR}` on Claude Code). Never re-derive the hash by hand.
3. Exit 0 with `VALID <timestamp>` -> SKIP the run, announce `verify skipped: tree unchanged since last PASS (<timestamp>)`, continue to Phase 2.
4. Anything else (`MISSING`, `FAIL`, `STALE`, script error) -> invoke `/verify` (no args) over the whole branch's working tree, after 1A/1B so it sees the post-fix tree.

Read the returned result block:

- `VERIFY RESULT: PASS` -> gate met, continue to Phase 2. The coverage line is advisory -- surface a non-empty uncovered list but proceed.
- `VERIFY RESULT: FAIL` -> STOP. Emit the result block and failing output verbatim; the user decides regression vs flake and fixes the cause. Re-run `/commit` when `/verify` returns PASS.

### Failure Handling

- **Tool missing in 1A/1B** (exit 127): ask the user -- "Install and re-run" (STOP, await fix) or "Skip this sub-step" (that single sub-step only; the rest of the gate still applies). Never auto-skip. Tool-missing inside `/verify` is `/verify`'s own concern.
- **Auto-fix made changes**: expected -- note in the Phase 3 plan that pre-existing format/lint fixes are included.
- **Verify-pass errors after auto-fix**: STOP per the sub-step instructions. No retry, no manual edits, no bypass.

**Phase 2: Gather Changes**

Run in parallel: `git status`, `git diff`, `git diff --cached`, `git log --oneline -5` (message style reference).

- Clean tree, no untracked files -> STOP: `Working tree is clean. Nothing to commit.`
- Pre-existing staged changes -> `git reset` (no flags -- index only, edits intact), announce `Unstaging N pre-existing staged file(s) so the commit plan can group from scratch.`, re-run the gather commands.

Read every changed file with the `Read` tool, except: generated content (lock files, `*.min.*`, build artifacts, `dist/`, `node_modules/`); files over 1000 lines (read diff hunks only); binaries (note presence).

**Phase 3: Plan Atomic Commits**

Each commit MUST be **self-contained** (builds independently), **single purpose**, and **properly ordered** (dependencies first). Re-plan any candidate that fails these; never relax them.

### Grouping Strategy

1. Identify logical units of change (feature, bugfix, refactor, test addition).
2. Within each unit, order by dependency layer: domain/core -> business logic -> infrastructure/persistence -> API/presentation -> tests (or alongside their layer).
3. Keep one commit when the diff is under ~150 lines, all files share one logical purpose, and splitting by layer would break independent builds. Otherwise split by layer.

### Commit Message Format

Conventional commits: `type(scope): description` -- `feat` / `fix` / `refactor` / `test` / `docs` / `chore`. Match the style seen in `git log --oneline -5`. The message explains purpose ("why"), not mechanics, and must match the actual changes.

Do NOT add `Generated with Claude Code`, `Co-Authored-By: Claude`, `Generated by Codex`, `Co-Authored-By: Codex`, or any AI attribution/signature line.

### Present the Plan

Show a numbered table:

```
| # | Type | Files | Message |
|---|------|-------|---------|
| 1 | feat(core) | Entity.cs, IRepo.cs | add Widget entity and repository interface |
| 2 | feat(api)  | Endpoint.cs | expose CreateWidget endpoint |
```

Then ask the user "Proceed with this commit plan?": **"Approve -- execute the commits"** -> Phase 4; **"Abort -- leave the working tree untouched"** -> STOP.

**Phase 4: Execute Commits**

For each commit N in order:

1. `git add <specific files for commit N>` -- NEVER `git add -A` or `git add .`.
2. `git commit -m "<message N>"` (HEREDOC body).
3. `git status` immediately after -- per commit, not batched.
4. Failure (non-zero exit, hook rejection, files still staged) -> STOP, report verbatim, wait for the user. Never retry with bypass flags.

**Phase 5: Terminate**

After the last commit's `git status`, emit: `Committed N atomic commits. Working tree clean.` Then STOP -- no push, no offer to push, no follow-up commands.

## Safety Rules (hard)

- Secrets: committing `.env`, credentials, or keys -> warn and STOP. Before staging any config file (`settings.json`, `appsettings.*.json`, `config.json`, `application.yml`, `.npmrc`, ...), scan its content for API keys, tokens, passwords, connection strings, OAuth secrets; any hit -> STOP and surface the exact line(s) to redact. No "redact later" placeholders.
- NEVER push, force-push, tag, create branches, or open PRs. This skill commits only.
- NEVER use `--amend`, `--no-verify`, `--no-gpg-sign`, or any hook/signing bypass. A failing hook -> STOP and report.
- NEVER run `git reset --hard`, `git checkout --`, `git restore`, `git clean`, or any destructive command. The only permitted `git reset` is the no-flag form in Phase 2.
