---
name: commit
description: 'Triggers when the user explicitly requests a git commit of the whole branch''s working-tree changes -- phrases like "commit my changes", "git commit", "ready to commit", "/commit", or "make atomic commits". Branch-scope commit gate -- auto-fixes format + lint inline, invokes `/verify` (the project-scoped build + test runner) and requires `VERIFY RESULT: PASS`, then plans and executes atomic commits across the branch. Does NOT skip the gate for pre-existing or unrelated failures unless `/commit --skip` is given.'
---

# Commit

## Overview

Branch-scope commit step. Verify the whole branch's working tree is clean, then plan and execute atomic commits across the branch.

**Phase 1 is a HARD GATE.** Before any commit, the working tree must have 0 format errors, 0 lint errors, and `VERIFY RESULT: PASS` from `/verify` (build + test) -- **even when the failures are pre-existing or unrelated to the current session's changes**. The only escape hatches: the explicit `/commit --skip` flag (Skip Mode) and the "Tool missing" branch in Failure Handling.

Phase 1A/1B auto-fix mechanical format/lint violations in write mode (`dotnet format`, `biome check --write`, `eslint --fix`, etc.); those fixes get pulled into the commit plan in Phase 3. Format and lint run BEFORE `/verify` so it sees the post-fix tree. For non-mechanical failures (a `/verify` FAIL, lint diagnostics that cannot be auto-fixed), STOP and tell the user what to fix -- never make judgment-call code edits, never hand-edit source to silence a diagnostic or pass a test.

## Skip Mode

`/commit --skip` (literal whitespace-delimited token in the invocation) bypasses Phase 1 entirely: no formatter, linter, or `/verify` run. Before Phase 2, emit verbatim: `Skip mode: Phase 1 gate bypassed. Format, lint, and /verify (build + tests) will NOT run. Proceeding directly to commit planning.` All other phases and every safety rule still apply.

## Execution Order

Phases run strictly in order 1 -> 2 -> 3 -> 4 -> 5. Within Phase 1: 1A (format auto-fix) -> 1B (lint auto-fix) -> 1C (`/verify`). Phase 2's four git commands run in parallel; that is the only parallelism.

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

**When a whole-tree verify pass fails ONLY on files outside the changed set**, STOP and ask via `AskUserQuestion`:

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
2. Read `<work-folder>/.verify-result.json`.
3. Compute the current tree hash:

   ```bash
   { git diff; git diff --cached; git status --porcelain; } | shasum -a 256 | cut -d' ' -f1
   ```

4. File exists AND `"result": "PASS"` AND `tree_hash` matches -> SKIP the run, announce `verify skipped: tree unchanged since last PASS (<timestamp>)`, continue to Phase 2.
5. Anything else -> invoke `/verify` (no args) over the whole branch's working tree, after 1A/1B so it sees the post-fix tree.

Read the returned result block:

- `VERIFY RESULT: PASS` -> gate met, continue to Phase 2. The coverage line is advisory -- surface a non-empty uncovered list but proceed.
- `VERIFY RESULT: FAIL` -> STOP. Emit the result block and failing output verbatim; the user decides regression vs flake and fixes the cause. Re-run `/commit` when `/verify` returns PASS.

### Failure Handling

- **Tool missing in 1A/1B** (exit 127): ask via `AskUserQuestion` -- "Install and re-run" (STOP, await fix) or "Skip this sub-step" (that single sub-step only; the rest of the gate still applies). Never auto-skip. Tool-missing inside `/verify` is `/verify`'s own concern.
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

Do NOT add `Generated with Claude Code`, `Co-Authored-By: Claude`, or any AI attribution/signature line.

### Present the Plan

Show a numbered table:

```
| # | Type | Files | Message |
|---|------|-------|---------|
| 1 | feat(core) | Entity.cs, IRepo.cs | add Widget entity and repository interface |
| 2 | feat(api)  | Endpoint.cs | expose CreateWidget endpoint |
```

Then ask "Proceed with this commit plan?" via `AskUserQuestion`: **"Approve -- execute the commits"** -> Phase 4; **"Abort -- leave the working tree untouched"** -> STOP.

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
