---
name: card-commit
description: Manually invoked as `/card-commit` (or by an explicit mention of "card-commit" / "commit this card") to commit ONLY the current card's slice of changed files -- not the whole branch. Trusts the card's pre-complete `/verify` already returned `VERIFY RESULT: PASS` on this tree with no edits since: runs format + lint, but does NOT re-run the test suite or build. If any edit landed after that PASS (or the PASS cannot be confirmed), invokes `/verify` first and requires PASS before committing. Plans and executes atomic commits of the card's files with a conventional message and no AI attribution. Never pushes, never opens a PR, never amends or runs destructive git. Does NOT auto-trigger -- only on the `/card-commit` slash command or an explicit "card-commit"/"commit this card" mention; a finished card alone is not enough.
---

# Card-commit

Card-scoped commit. Commits only THIS card's slice of files, trusting the card's pre-complete `/verify` PASS.

**Announce at start:** "I'm using Pandahrms card-commit to commit this card's slice."

Phases run strictly in order: Phase 1 -> Phase 2 -> Phase 3 -> Phase 4 -> Phase 5. Do not begin a phase until the prior one finished.

## Phase 1: Trust gate (format + lint; trust the pre-complete /verify)

The card's pre-complete `/verify` returned `VERIFY RESULT: PASS` on this tree. Trust it -- run format + lint here, do NOT re-run tests or build.

**TRUST CONDITION.** The fast path holds only if BOTH are true:
1. `/verify` returned `VERIFY RESULT: PASS` (build not `failed` AND tests 0 failures) on this card's tree.
2. No file changed since that PASS.

If either is false, or the PASS cannot be confirmed, FALL BACK: invoke `/verify` now and require `VERIFY RESULT: PASS` before continuing. On `VERIFY RESULT: FAIL`, STOP and report the failing build/test output verbatim; do not commit.

### Phase 1A: Format auto-fix

Run the formatter in write mode, then verify.

- **.NET**: `dotnet format` (write), then `dotnet format --verify-no-changes`.
- **JS/TS** (detection precedence, first match wins):
  1. `biome.json` / `biome.jsonc` -> `pnpm biome check --write .` then `pnpm biome check .` (verify).
  2. `.prettierrc.*` or `prettier` key in `package.json` -> `pnpm prettier --write .` then `pnpm prettier --check .`.
  3. Otherwise: skip; Phase 1B's linter covers formatting.

If verify still reports issues, STOP and emit the diagnostic output verbatim, then: `Format errors remain after auto-fix. Inspect each failing file. Generated/vendored -> add to .editorconfig / biome.json / .prettierignore. Real source -> fix the syntax that defeated the formatter. Re-run /card-commit when verify passes.`

### Phase 1B: Lint auto-fix

Run the linter in fix mode, then verify.

- **.NET**: `dotnet format` (Phase 1A) covers analyzer lint; no separate step.
- **JS/TS** (detection precedence, first match wins):
  1. `biome.json` / `biome.jsonc` -> `pnpm biome check --write .` then `pnpm biome check .` (verify).
  2. `eslint.config.*` (flat) or `.eslintrc.*` (legacy) -> `pnpm lint --fix` then `pnpm lint`.
  3. `package.json` has `lint:fix` -> run it, then `pnpm lint`.
  4. `package.json` has `lint` only -> `pnpm lint` (verify, no auto-fix).
  5. None -> skip.

If verify still reports errors, STOP and emit violations verbatim, then: `Lint errors remain after auto-fix. Fix the offending code, or add a one-line "// reason" suppression when the rule does not apply. Re-run /card-commit when verify passes.`

### Trust-condition re-check after auto-fix

If Phase 1A or 1B MODIFIED any file, the pre-complete `/verify` PASS no longer covers the tree -- the TRUST CONDITION is void. FALL BACK: invoke `/verify` now and require `VERIFY RESULT: PASS` before Phase 2.

### Tool missing

Command not found / exit 127: emit `[tool name] is not installed. Install it or skip this sub-step?` and ask via `AskUserQuestion` with "Install and re-run" (STOP, await fix) or "Skip this sub-step" (continue past this one sub-step only). Do not auto-skip.

## Phase 2: Gather the card's slice

Identify the card's slice -- the specific files THIS card changed. Read the card's file list / Progress (the work-sequence and per-layer notes) to know which files belong to the card. The slice is those files only, never the whole branch.

Run in parallel:

- `git status` -- all modified, added, untracked files.
- `git diff` -- unstaged changes.
- `git diff --cached` -- staged changes.
- `git log --oneline -5` -- recent commits for message style.

Cross-reference: from the working-tree changes, keep ONLY the files in the card's slice. Files changed in the tree but outside the card's slice are left untouched -- do not stage or commit them.

If the card's slice has no changes in the tree, STOP and emit: `No changes for this card's slice. Nothing to commit.` Do not enter Phase 3.

If `git diff --cached` shows pre-existing staged changes, unstage with `git reset` (no flags). File edits stay intact. Announce: `Unstaging N pre-existing staged file(s) so the commit plan can group from scratch.` Then re-run the gather commands.

Read every card-slice file in the diff with `Read`, except:

- Skip generated-content patterns (lock files, `*.min.*`, build artifacts, `dist/`, `node_modules/`).
- Files over 1000 lines -> read only diff hunks via `git diff <file>`.
- Binary files -> note presence, do not read.

## Phase 3: Plan atomic commits

Group the card's slice into logical commits. Each commit MUST be:

- **Self-contained** -- builds independently.
- **Single purpose** -- one logical change.
- **Properly ordered** -- dependencies committed first.

Reject any candidate that fails a rule; re-plan instead of relaxing.

### Grouping

1. Identify logical units (feature, bugfix, refactor, test addition).
2. Order by dependency layer: Domain/Core first; business logic / use cases second; infrastructure / persistence third; API / presentation fourth; tests last or alongside their layer.
3. Keep in one commit when ALL hold: total diff under 150 lines added+removed; all files share one logical purpose; splitting by layer would yield a commit that does not build on its own. Otherwise split by layer.

### Message format

Conventional commits: `type(scope): description`

| Type | When |
|------|------|
| `feat` | New feature / wholly new functionality |
| `fix` | Bug fix |
| `refactor` | Code restructuring, no behavior change |
| `test` | Adding or updating tests only |
| `docs` | Documentation only |
| `chore` | Maintenance, dependency updates |

Read `git log --oneline -5` to match the repo's existing commit style.

Do NOT add: `Generated with Claude Code`, `Co-Authored-By: Claude`, any AI attribution trailer, or any signature line. The message is the conventional commit body only.

### Present the plan

Show a numbered table:

```
| # | Type | Files | Message |
|---|------|-------|---------|
| 1 | feat(core) | Entity.cs, IRepo.cs | add Widget entity and repository interface |
| 2 | feat(usecase) | Handler.cs, Dto.cs | implement CreateWidget command handler |
| 3 | feat(api) | Endpoint.cs | expose CreateWidget endpoint |
| 4 | test(widget) | HandlerTests.cs | add CreateWidget handler unit tests |
```

Then ask inline in plain text: "Proceed with this commit plan?" with the two options:

- **"Approve -- execute the commits"** -> Phase 4.
- **"Abort -- leave the working tree untouched"** -> STOP. Do not commit.

## Phase 4: Execute commits

For each commit N in order:

1. `git add <specific files for commit N>`.
2. `git commit -m "<message N>"` using a HEREDOC for the message body.
3. `git status` immediately after.
4. If commit N failed (non-zero exit, hook rejection, or `git status` shows files still staged), STOP. Do not proceed to N+1. Report verbatim and wait.

Run the per-commit `git status` after every commit; do not batch to the end.

**NEVER** `git add -A` or `git add .` -- stage the card's specific files only.

## Phase 5: Terminate

After the last commit's `git status`, emit one line:

`Committed N atomic commits for this card's slice. Working tree clean for the slice.`

Then STOP. Do not push, do not offer to push, do not propose follow-up work, do not run further commands.

## Red Flags - STOP

Each item is a HARD rule. Hitting any means STOP in the current response.

- About to commit files outside the card's slice -> STOP. Stage only the card's files.
- About to make a logic / judgment-call code edit during commit -> STOP. Mechanical auto-fix via formatter or linter (`dotnet format`, `biome check --write`, `eslint --fix`) is allowed; hand-editing source to silence a lint diagnostic or pass a test is NOT.
- About to commit when the TRUST CONDITION is void (an edit landed after the pre-complete `/verify` PASS, or the PASS cannot be confirmed) without first running `/verify` to a fresh `VERIFY RESULT: PASS` -> STOP and run `/verify`.
- About to `git add -A` or `git add .` -> stage specific files only.
- Committing `.env`, credentials, or secrets -> warn the user and STOP.
- Committing `settings.json`, `appsettings.*.json`, `config.json`, `application.yml`, `.npmrc`, or similar config files -> scan file content for API keys, tokens, passwords, connection strings, OAuth client secrets, or other sensitive values BEFORE staging. If any are found, STOP and surface the exact line(s) to the user to redact (move to env var, secret manager, or local-only file ignored by git). Do not commit "I'll redact it later" placeholders.
- Commit message describes "what" instead of "why" (e.g. `add if statement` instead of `support widget filtering`) -> rewrite it. The message explains purpose, not mechanics.
- Commit message doesn't match the actual changes -> rewrite it.
- Format or lint errors remain after Phase 1 auto-fix -> STOP. Tell the user to fix and re-invoke `/card-commit`.
- NEVER push, force-push, tag, create branches, or open PRs. This skill commits only. Stop after Phase 5's `git status` verification.
- NEVER use `--amend`, `--no-verify`, `--no-gpg-sign`, or any flag that bypasses hooks/signing. If a hook fails, STOP and report; do not retry with bypass flags.
- NEVER run `git reset --hard`, `git checkout --`, `git restore`, `git clean`, or any destructive command. The only `git reset` permitted is the no-flag form in Phase 2 to auto-unstage pre-existing staged changes (file edits preserved).

## Next step

Card committed. Run `/execute` for the next card, or `/status` to review remaining cards.
