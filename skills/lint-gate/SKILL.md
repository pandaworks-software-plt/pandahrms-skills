---
name: lint-gate
description: Manually invoked as `/lint-gate` (or by an explicit "run the lint gate" / "deterministic guard pass on my changes" mention). A diff-scoped DETERMINISTIC guard runner over the working-tree changes -- project linter on changed files, a Tool Gate (TODO/FIXME/XXX, secrets, leftover-debug, repo-conventions), an OPTIONAL structural analyzer/dup tier, and an L1->L2 `.feature` traceability check -- emitting findings tagged `[tool:<name>]` plus the set of OWNED categories. Does NOT auto-trigger (a pending diff alone is not enough), and does NOT commit, stage, push, run tests, or apply fixes.
---

# Lint Gate

Standalone deterministic guard runner over the working-tree diff. No LLM judgment. Runs the linter + Tool Gate + optional structural tier + L1->L2 traceability; emits findings tagged `[tool:<name>]` and returns the OWNED-category set.

**Announce at start:** "I'm using Pandahrms lint-gate to run the deterministic guards on your changes."

## Hard Prohibitions

MUST NOT at any phase:
- Run `git commit`, `git add`, `git push`, `git rebase`, `git reset`, `git stash`, or any staging / history-altering / remote command.
- Apply fixes, edit files, or modify the working tree. This skill DETECTS and REPORTS only.
- Run tests, migrations, builds, or dev servers.
- Make LLM judgment calls on a finding's correctness. Each guard is mechanical: a tool result (or its built-in fallback) is the finding. Do not re-reason whether a TODO "is fine" or a god-class "is acceptable" -- report it.
- Send diffs, file paths, or finding details to any external service. Only allowed external calls are the project's own linter/analyzer CLIs (`dotnet`, `pnpm`, `npm`, `npx --no-install`, `gitleaks`, `ast-grep`, `jscpd`).

## Scope resolution

Default scope = the working-tree change set. Gather it with, in parallel:
- `git status` -- modified, added, untracked files.
- `git diff` -- unstaged hunks.
- `git diff --cached` -- staged hunks.

If user passed a literal path or glob, use exactly that set instead.

**Empty tree halt.** If `git status`, `git diff`, and `git diff --cached` together produce no output AND no explicit scope was passed, emit one line -- "No changes in the working tree. Nothing to gate." -- and stop.

Run every guard over the CHANGED files / the diff only, never the whole tree (the secret scan's untracked-file rule below is the one explicit widening).

## Guard contract

Every guard follows: **detect tool -> use if present -> fall back to a built-in.** Never a hard machine dependency; the built-in always runs when the tool is absent. For each guard emit findings tagged `[tool:<name>]` (name = the tool that ran, or the fallback, e.g. `[tool:gitleaks]` / `[tool:regex-fallback]`). Record per guard in the final summary which path ran.

`npx` invocations use `npx --no-install <tool>` so an absent tool fails fast to the built-in instead of silently fetching from the network.

## Phase 1: Linter

Linter precedence (run only the FIRST matching linter, never multiple), scoped to changed files:

1. `biome.json` / `biome.jsonc` -> `pnpm biome check` or `npx --no-install biome check`
2. `eslint.config.*` / `.eslintrc.*` -> `pnpm lint` or `npx --no-install eslint`
3. `lint` script in `package.json` -> `pnpm lint` or `yarn lint`
4. `*.csproj` files present -> `dotnet format --verify-no-changes`

Failure handling:
- **No matching linter detected:** record `Linter: not configured` in the summary.
- **Linter binary missing, OR linter exits non-zero on infrastructure errors (not lint findings):** record `Linter: failed (<exit code or reason>)`, continue.
- **Linter runs successfully:** emit each lint finding tagged `[tool:<linter>]`.

Never skip the linter silently when one matched but failed.

### Linter-owned categories (M1)

The linter OWNS the dead-code (unused/unreachable) and async-correctness categories ONLY when BOTH hold:
1. the specific rule is ENABLED in the project linter config (eslint `no-unused-vars` / `no-unreachable` / `no-floating-promises` / `require-await`; .NET AsyncFixer / VSTHRD / IDE0051), AND
2. the linter RAN CLEAN (ran successfully, did not fail on infrastructure errors).

When both hold, add that category to the OWNED-category set (the caller drops its LLM row). When the rule is NOT enabled, OR no linter is configured, OR the linter failed: do NOT claim ownership -- the category falls back to the caller's LLM, and record a `/tool-doctor` gap note in the summary (`Dead-code/async: LLM fallback (rule not enabled)` or `(no linter)`).

## Phase 2: Tool Gate

Cheap deterministic scans over the diff. Each row: tool -> built-in fallback. A row that runs adds its category to the OWNED set.

| Guard | Tool (preferred -> fallback) | Owned category |
|-------|------------------------------|----------------|
| TODO/FIXME/XXX | `rg -n 'TODO\|FIXME\|XXX'` over changed files -> `git grep -n 'TODO\|FIXME\|XXX'` | `todo` |
| Secrets / leaked credentials | `gitleaks` (see secret-scan surface below) -> regex over the diff + untracked files | `secrets` |
| Leftover debug | linter `no-console`/`no-debugger` (if enabled, ran clean) -> `grep -n 'console\.log\|debugger\|Console\.WriteLine'` | `debug-leftover` |
| Repo conventions | `wc -l` per changed file vs repo-root `CLAUDE.md` mechanical size limit; `grep` for a banned import / required header named in that `CLAUDE.md` | `repo-conventions` |

Rules:
- Every `TODO`/`FIXME`/`XXX` hit in the diff is a finding (Major severity).
- Repo-conventions reads ONLY mechanical rules from the repo-root `CLAUDE.md` -- a numeric file-size limit, a named banned import, a required-header string. Non-mechanical "judgment" conventions are NOT in scope here (they stay with the caller's LLM).
- A guard with no machine tool still runs its built-in -- never skipped.
- Record per guard which path ran: `TODO: rg` / `git grep`; `Secrets: gitleaks` / `regex fallback`; `Debug: linter` / `grep`; `Repo-conventions: checked`.

### Secret-scan surface (B2)

The secret scan covers the FULL change set, not only `git diff`:
1. `git diff` (unstaged hunks).
2. `git diff --cached` (staged hunks).
3. EVERY untracked file from `git status` (read each and scan its contents).

Tool path: `gitleaks protect --staged` plus `gitleaks detect --no-git` over untracked files (or `gitleaks protect` over the unstaged diff). Fallback path: regex over all three sources for `password\s*=`, `secret\s*=`, `api[_-]?key`, `Bearer `, `AKIA`, `-----BEGIN`, `ConnectionString`, `eyJ` (JWT prefix); plus flag any committed `.env`, `.pem`, `.pfx`, `.key`, `.p12`, `id_rsa`, `credentials.json`, `service-account*.json`. Any hit = Critical until proven false. Missing a staged-or-untracked source is a defect -- all three are mandatory.

## Phase 3: Structural analyzer / duplication tier (OPTIONAL)

Lower-priority tier. Where a tool is present it OWNS the mechanical DETECTION of the smell and that category joins the OWNED set; where absent, the category falls back to the caller's LLM (the LLM keeps the whole check) and a `/tool-doctor` gap note is recorded. This skill never makes the judgment half -- it only reports the tool's mechanical detection.

| Smell | Tool (mechanical detection) | Owned category |
|-------|-----------------------------|----------------|
| God class / giant class | `wc -l` size rule -- flag ONLY when the FILE is >= 300 lines, OR the diff ADDED >= 100 lines to that file (`git diff --numstat` added column) -- or an analyzer | `god-class` |
| Long switch / high cyclomatic chain | `complexity` / cyclomatic analyzer | `long-switch` |
| `new` of a service / service-locator lookup | `ast-grep` rule | `new-of-service` |
| Empty / swallowing catch | `no-empty-catch` lint or `ast-grep` rule | `empty-catch` |
| Exact duplication / copy-paste block | `jscpd` | `exact-dup` |

Rules:
- Run each tool scoped to changed files. `ast-grep` / `jscpd` via `npx --no-install` when not a project dep.
- Emit the tool's hit as a finding tagged `[tool:<name>]`; do NOT add judgment ("is this size really a problem") -- that is the caller's half.
- Record per smell which ran or fell back: `God-class: wc/analyzer` or `LLM fallback`; `Long-switch: complexity` or `LLM fallback`; `New-of-service: ast-grep` or `LLM fallback`; `Empty-catch: lint/ast-grep` or `LLM fallback`; `Exact-dup: jscpd` or `LLM fallback`. Note each `/tool-doctor` gap where a tool was absent.

## Phase 4: L1->L2 `.feature` traceability

Mechanical check that each card-claimed L1 scenario has a matching L2 `.feature` scenario. Run per card that names L2 `.feature` file(s).

### Inputs
- The card's `L1 covered` list -- capture each L1 scenario by its NAME (the exact `Scenario:` / `Scenario Outline:` line text).
- The card's declared L2 `.feature` file path(s).

### Pending outcome (M7)

L2 `.feature` files are written during execution and may not exist when this runs early. Before matching, check each declared L2 path on disk:
- If a declared L2 `.feature` file does NOT exist yet, mark that card's traceability `pending` (L2 not yet materialized) and emit a `pending` finding -- NOT a failure. Do not flag the L1 scenarios as uncovered.
- Only run the match below against L2 files that exist on disk.

### Match (M6 -- EXACT scenario name)

For each claimed L1 scenario, search the existing L2 `.feature` file(s) for a scenario whose NAME matches EXACTLY. A shared tag alone is NOT sufficient -- a tag match does not mark the L1 covered; only an exact scenario-name match does.

Use POSIX character classes, NOT `\s` (M5 -- BSD/macOS `grep` portable):

```
grep -nE '^[[:space:]]*Scenario([[:space:]]+Outline)?:[[:space:]]*<exact name>' <existing L2 .feature path(s)>
```

### Outcomes
- **covered** -- an exact scenario-name match found in an existing L2 file.
- **uncovered** -- L2 file exists but no exact-name match -> Major finding (list the unmatched L1 scenario).
- **pending** -- declared L2 file does not exist on disk yet (see M7) -> informational, not a failure.

`traceability` joins the OWNED set only for cards whose L2 files exist and were matched. Built-in only (`grep`); no machine-tool dependency.

## Output

Emit one report message:

### Findings
One block per finding, tagged with its guard tool:

> **[Severity] [tool:<name>] [Short title]**
> - **Where:** `path/to/file.ext:lineno`
> - **What:** the deterministic hit in one sentence

Severity bands: Critical (secret leak), Major (TODO/FIXME/XXX, repo-convention breach, uncovered L1->L2, structural smell), Minor (lint/format), Info (traceability `pending`). Emit `(none)` under Findings when empty.

### OWNED categories
A single explicit list of the categories this run OWNS -- the caller drops the matching LLM judgment rows. Categories are drawn from this fixed vocabulary:

```
todo, secrets, debug-leftover, repo-conventions,
dead-code, async,
god-class, long-switch, new-of-service, empty-catch, exact-dup,
traceability
```

A category appears ONLY when its tool actually ran (linter ran clean + rule enabled for `dead-code`/`async`; the tool present for each structural smell; L2 files existed for `traceability`). Emit the list verbatim, e.g.:

```
OWNED: todo, secrets, debug-leftover, repo-conventions, dead-code, async, exact-dup, traceability
```

When a category fell back to the caller's LLM, it is ABSENT from `OWNED` and listed under the gap notes instead.

### Guard summary
One line per guard: which path ran and any `/tool-doctor` gap:
- `Linter: <name> clean | failed | not configured`
- `Dead-code/async: linter-owned | LLM fallback (<reason>)`
- `TODO: rg | git grep`
- `Secrets: gitleaks | regex fallback` (staged + unstaged + untracked all scanned)
- `Debug: linter | grep`
- `Repo-conventions: checked | no CLAUDE.md`
- `God-class / Long-switch / New-of-service / Empty-catch / Exact-dup: <tool> | LLM fallback`
- `Traceability: <covered N / uncovered N / pending N>`

## Result file

After emitting the chat report, ALSO write the full report -- `### Findings` + the `OWNED:` line + `### Guard summary`, verbatim -- to `<work-folder>/.lint-gate-result.md`.

- Work folder = the `work_folder` value read from the per-work `_overview.md`.
- When no work folder is known: skip the file and add one line to the report -- `result file: skipped (no work folder)`.
- The chat report still stands; the file is IN ADDITION to it, never a replacement.

Consumer rule: callers pass this file's path to `/code-review` instead of relaying the report by prose.

## Rules

- DETERMINISTIC only -- tool result or built-in fallback IS the finding. No LLM judgment on correctness.
- Every guard: detect -> use -> fall back to built-in. Never a hard dependency, never silently skipped.
- Secret scan covers staged + unstaged + every untracked file (B2). All three mandatory.
- Linter owns dead-code/async ONLY when the rule is enabled AND the linter ran clean; else LLM fallback + gap note (M1).
- Traceability grep uses `[[:space:]]`, never `\s` (M5).
- Traceability matches by EXACT scenario name; a shared tag alone is NOT sufficient (M6).
- Traceability `pending` when an L2 `.feature` file does not exist on disk yet -- informational, not a failure (M7).
- Always emit the explicit `OWNED:` list -- a category appears only when its tool ran.
- Self-contained: built-ins (`rg`/`git grep`/`grep`/`wc`) carry every guard when its tool is absent.
