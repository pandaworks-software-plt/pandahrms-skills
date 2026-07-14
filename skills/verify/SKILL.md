---
name: verify
description: Manually invoked as `/verify` (or by an explicit mention of "verify" / "run verify"). The single canonical project-scoped deterministic runner for a Pandahrms repo -- full whole-graph build / type-check + full test suite + changed-file coverage existence gate -- emitting one structured PASS/FAIL result with per-stage status (build, tests, coverage). Whole-codebase, never diff-scoped. Does NOT auto-trigger -- a finished card or a request to commit alone is not enough -- and does NOT run git, commit, push, or edit files.
---

# Verify

The single canonical project-scoped runner: full build + full test + changed-file coverage existence gate. Emits one structured result other skills consume.

**Announce at start:** "I'm using Pandahrms verify to run the project build, tests, and coverage."

Read-only on git. Runs build, tests, coverage. Never edits files, stages, commits, or pushes.

## Scope

- Whole-codebase, never diff-scoped. Build is inherently whole-graph -- a changed shared type can break an unchanged consumer.
- Coverage rides the test run -- no separate pass.
- Three stages run strictly in order: Stage 1 (build / type-check) -> Stage 2 (test suite) -> Stage 3 (changed-file coverage). Coverage is part of the Stage 2 invocation, not a fourth pass.

## Detection

Detect ALL project types present in the workspace (whole tree, not the changed-files set):

- `.csproj` / `.sln` anywhere -> .NET stages.
- `package.json` anywhere -> JS/TS stages.
- Mixed repo -> run BOTH for every stage, aggregate.
- Neither -> every stage records `not-configured`. Emit the result with overall `PASS` and continue. Do not invent commands.

## Stage 1: Build / Type-check

Whole-graph build to catch type-contract drift unreachable from the test graph.

JS/TS detection precedence (first match wins):

1. Root `package.json` has a `build` script -> run it (`pnpm build`, `yarn build`, or `npm run build` per the lockfile). Preferred -- recursive workspace builds rebuild shared `dist/` outputs in dependency order, catching source-vs-artifact drift.
2. Root `package.json` has a `type-check` script but no `build` script -> run it (`pnpm type-check` etc.). Weaker fallback: `tsc --noEmit` may still consult stale `dist/*.d.ts`, so it can miss source-vs-built-artifact drift. Tag the stage `clean (partial: type-check only)` in the result so callers know the build was not whole-graph.
3. Neither script exists -> stage records `not-configured`.

.NET:

- `dotnet build` on the solution/project (implicit restore).

Pass condition: 0 build errors. Warnings (chunk-size, deprecated-API notices) do not fail the stage.

Stage status values: `clean` | `clean (partial: type-check only)` | `failed` | `not-configured`.

On failure, capture the error output verbatim into the result and mark the stage `failed`. Continue to Stage 2 (run all stages, aggregate at the end) -- overall result is `FAIL`.

## Stage 2: Test suite

Full suite for every detected project type.

JS/TS detection precedence (first match wins):

1. `package.json` has a `test` script -> `pnpm test`.
2. Detect framework directly: `vitest` -> `pnpm vitest run`; `jest` -> `pnpm jest`. Playwright in this codebase means the Playwright MCP browser tools, NOT a CLI runner -- do NOT invoke `pnpm playwright test`.
3. No tests detected -> stage records `not-configured`.

Tests-exist tripwire: when test files exist on disk (any of `**/*.test.*`, `**/*.spec.*`, `**/*Tests.csproj`, `**/*.Tests.csproj`) and no runner was detected, the stage records `failed (tests exist but no runner detected)` and the overall result is `FAIL`.

.NET:

- `dotnet test` on the solution.

Mixed -> run both, aggregate counts.

Pass condition: 0 failures and 0 errors. Skipped/pending tests are allowed.

Stage status: `<N> pass / <M> fail` (with `<M> = 0` on a clean run), or `not-configured`.

On any test failure, capture failing test names into the result and mark `<N> pass / <M> fail` with `M > 0`. Overall result is `FAIL`.

## Stage 3: Changed-file coverage existence gate

Runs as part of the Stage 2 test invocation (same run, no extra pass). Flags any changed PRODUCTION file with ZERO covering test.

The TOOL owns the existence check ("is there a covering test"). The caller's LLM keeps the ADEQUACY judgment (edge cases, error paths) on files the tool reports as covered -- adequacy is NOT this stage's job.

Detect-tool -> use-if-present -> fallback:

1. JS/TS: `@vitest/coverage-v8` present -> run coverage with the Stage 2 test command (e.g. `pnpm vitest run --coverage`).
2. .NET: `coverlet` present -> collect coverage with `dotnet test` (e.g. `--collect:"XPlat Code Coverage"` or the configured coverlet collector).
3. No coverage tool configured -> fall back to LLM existence check: for each changed production file, confirm a covering test file exists. Record a gap note recommending `/tool-doctor` to add the coverage tool.

Scope the gate to changed production files: take `git diff --name-only` (plus untracked production files), exclude tests, generated/vendored files (lock files, `*.min.*`, `dist/`, `node_modules/`, `*.g.cs`, migrations), and non-code assets.

Stage status: list of changed production files with zero covering test (empty list = all covered), or `not-configured` when no tool and no changed production files apply. A non-empty uncovered list does NOT fail the overall result -- it is surfaced for the caller to act on.

## Result contract

Emit exactly one structured result block at the end. Shape:

```
VERIFY RESULT: <PASS|FAIL>
- build: <clean | clean (partial: type-check only) | failed | not-configured>
- tests: <N pass / M fail | not-configured>
- coverage: <all covered | uncovered: file1, file2, ... | not-configured>
```

Overall `PASS` <-> build is not `failed` AND tests have 0 failures. Build `not-configured` and tests `not-configured` do not fail the overall result. A non-empty `coverage` uncovered list does NOT change overall PASS/FAIL -- it rides as advisory.

Below the block, when a stage `failed` or tests failed, include the captured verbatim error output / failing test names so the caller can act. When coverage fell back to the LLM with no tool, include the `/tool-doctor` gap note.

## Result file

After emitting the chat result block, ALSO write the same result to `<work-folder>/.verify-result.json` when a work folder is known (read `work_folder` from the per-work `_overview.md`). When no work folder exists, skip the file write and add one line under the chat block:

```
result file: skipped (no work folder)
```

JSON shape (exact keys):

```json
{
  "result": "PASS|FAIL",
  "build": "<stage status>",
  "tests": "<stage status>",
  "coverage": "<stage status>",
  "timestamp": "<output of: date -u +%Y-%m-%dT%H:%M:%SZ>",
  "tree_hash": "<output of: { git diff; git diff --cached; git status --porcelain; } | shasum -a 256 | cut -d' ' -f1>"
}
```

Consumer rule: "A PASS in this file is valid for a caller ONLY while `tree_hash` matches the caller's freshly computed hash of the same command. A changed tree voids the PASS."

## Failure handling

- Tool missing (command not found, exit 127): mark that single stage `not-configured`, note the missing tool name in the result, and continue the other stages. Do not invent a substitute command.
- Never auto-fix, never edit source to make a stage pass. This runner reports; it does not mutate the tree.

## Red Flags

| Thought | Reality |
|---------|---------|
| "I'll only build the changed files" | Build is whole-graph, never diff-scoped. Run the full build. |
| "I'll run coverage as a separate pass after the tests" | Coverage rides the Stage 2 test run -- one invocation. |
| "`pnpm playwright test` covers the e2e tests" | Playwright here is the MCP browser tools, not a CLI runner. Do not invoke it. |
| "A changed file has no test -- I'll fail the result" | Uncovered files are advisory; they do not flip overall PASS/FAIL. Surface the list. |
| "I'll edit the test so the suite passes" | This runner never mutates the tree. Report the failure verbatim. |
| "No build script, but I'll guess a command" | No recognized script -> record `not-configured`. Never invent commands. |
| "No test script found, so I'll pass the stage" | Test files on disk with no detected runner = `failed` stage, not `not-configured`. |
| "Type-check passed, so the build is clean" | `type-check` is a weaker fallback -- tag it `clean (partial: type-check only)`. |
