---
name: execute
description: Manually invoked as `/execute card-NN` to run that specific card's ordered sequence, or bare `/execute` to run the next available card (lowest-order active card not done). A guided run with stop-gates -- mechanical work auto-runs between gates; stops after each layer's code review, before deploy, and before commit/PR. Detects project architecture to include or skip the deploy + FE-regen bridge. Spec-first TDD with RED/GREEN/VERIFICATION markers, inlined SOLID + DDD. Orchestrates single-responsibility skills: per layer it runs scoped feature tests then invokes `/lint-gate` (deterministic guards) and `/code-review` (LLM judgment, fed the lint-gate result); at card pre-complete it invokes `/verify` ONCE on the final tree (full build + full test + coverage) and requires `VERIFY RESULT: PASS`; it commits the card with `/card-commit` (card scope, trusts the pre-complete /verify). The umbrella/branch commit is /commit or /pr. Moves the finished card to done and appends a Closed block. Append `--blast-mode` to run every available card back to back with no stop-gates: the agent resolves each decision point on its own and records it as a `DECISION` line, commit and PR are prohibited (no `/card-commit`, `/commit`, or `/pr`; deploy + FE regen still run), a card that cannot pass is marked BLOCKED and the run continues unless the block also blocks the remaining cards, and the run ends with a wrap-up of cards done, cards blocked, and every autonomous decision saved to the work `_overview.md` and printed to chat. Does NOT auto-trigger -- only on the slash command or an explicit "execute card" mention.
---

# Pandahrms Execute

Run ONE vertical-slice card by following its ordered sequence. Native, current context. No subagent dispatch, no batches. `/execute` orchestrates the single-responsibility leaf skills (`/lint-gate`, `/code-review`, `/verify`, `/card-commit`). The card ends after `/card-commit` runs, with the PR raised now or deferred to `/pr`.

**Announce at start:** "I'm using Pandahrms execute to run this card."

## Invocation

- `/execute card-NN` -- run that card.
- `/execute` (bare) -- run the next available card = lowest-order active card not yet done.
- Append `--approve` to either form (`/execute card-NN --approve`) for low-touch mode -- see Low-touch mode.
- `/execute --blast-mode` -- blast mode: run every available card back to back with no stop-gates; commit + PR prohibited. See Blast mode.

Read `work_folder` from the intake `_overview.md`. The card store is `<work-folder>/active/` and `<work-folder>/done/`. Pick by `order`.

## Resume

A half-done card continues from its first unchecked checklist step. Bare `/execute` skips fully-done cards in `<work-folder>/active/` and picks the next not-done one.

## Detect architecture

Inspect the project layout once at start:

- Separate BE-API + FE-SPA → INCLUDE the deploy BE + FE gen-api bridge.
- Monolith / MVC5 / monorepo (BE + FE build together) → SKIP deploy + regen.

If this detection conflicts with the sequence `/slice` wrote on the card, trust the card's sequence and note the mismatch to the user.

## Guided run with stop-gates

Mechanical work auto-runs between gates. STOP for a user check at:

- after each layer's code review,
- before deploy BE,
- before commit/PR.

Between those gates, run automatically -- no pause.

## Low-touch mode (`--approve`)

`/execute --approve` auto-proceeds the ROUTINE stop-gates so a clean card runs with no human pause. It auto-proceeds ONLY:

- the after-review continue gate,
- the commit gate.

HARD STOPS stay mandatory even under `--approve` -- never auto-proceed past:

- a test failure (scoped or full suite),
- a card/spec conflict or a scope conflict,
- any `/security-review` finding,
- any major `/code-review` finding the review skill could not auto-fix.

Flag forwarding: pass `--approve` narrowly to the leaf review (`/code-review --no-commit --approve`). Do NOT let it widen `/code-review`'s auto-apply beyond that skill's documented per-phase defaults. The commit runs `/card-commit` per the Commit section.

Announce the auto-pick on one line at each auto-proceeded gate (e.g. `--approve: proceeding past code review`). Under `--approve`, default the per-card PR to DEFER to `/pr` unless the user said otherwise.

## Blast mode (`--blast-mode`)

`/execute --blast-mode` runs EVERY available card in `<work-folder>/active/` back to back -- lowest-order not-done card first, then the next, until none remain. No human pause at any gate. Implies `--approve`'s auto-proceed and extends it across all cards.

**Commit + PR prohibited.** Never run `/card-commit`, `/commit`, or `/pr` in this mode. Deploy BE to local Docker and FE regen still run (they are not commit/PR). All cards' changes pile up uncommitted in the working tree for the user to review and commit later.

**Decision points instead of stop-gates.** The normal hard stops -- scoped/full test failure, `/verify` FAIL, card/spec conflict, `/security-review` finding, major `/code-review` finding -- do NOT pause the run. At each:

- Resolve it autonomously when safe (apply the fix, take the spec-backed reading). Announce one line `DECISION -- <point>: <choice> (<reason>)` and append the same to the card's Progress.
- When it cannot be safely resolved (a card that will not reach `/verify` PASS after fix attempts, an irreconcilable card/spec conflict), mark the card BLOCKED: leave it in `active/`, append a `BLOCKED -- <reason>` Progress entry, move to the next available card.

Never fake a pass, never commit broken code, never silently absorb a block. Every `DECISION` and every `BLOCKED` is recorded and surfaced in the wrap-up.

**End condition.** Stop when `active/` holds no runnable card (all done or blocked). If a blocker also blocks the remaining cards (they depend on the blocked card), END the run immediately and go to the wrap-up -- do not attempt the dependent cards.

**Card done in blast mode** = all work + `/verify` PASS, WITHOUT the commit step. Move the done card `active/` -> `done/` and append a `## Closed: <date>` block noting `commit skipped (blast mode)`.

**Diff scope.** With no commits between cards the working-tree diff accumulates. Scope each card's `/lint-gate` and `/code-review` to the files THAT card touched, not the whole accumulated diff. `/verify` stays project-scoped.

**Wrap-up (always, at the end).** Append a dated `## Blast run <date>` section to the work `_overview.md` AND print it to chat. Include:

- Cards done, each with its `## Closed` note.
- Cards blocked, each with its `BLOCKED -- <reason>`.
- Every `DECISION` the agent made during the run.
- A line stating nothing was committed: all changes sit uncommitted in the working tree.
- Next step: the user reviews the working tree, then runs `/commit` or `/pr` to ship.

## Boundary steps (inline leaf actions)

Run these inline as leaf actions, NOT a skill chain. `/execute` drives the whole slice and composes the leaf skills.

- Lint gate = invoke `/lint-gate` over the layer's `git diff` (deterministic guards: linter, Tool Gate, structural tier, L1->L2 traceability). It returns `### Findings` (`[tool:<name>]` tags) + a verbatim `OWNED: <categories>` line. `/execute` invokes it; `/code-review` does NOT auto-invoke it.
- Code review = invoke `/code-review --no-commit`, passing the `/lint-gate` result (the `OWNED:` line + `[tool:*]` findings) so code-review drops the OWNED judgment rows. LLM judgment only (review + fixes; the flag skips its commit phase). On a sensitive card, invoke `/code-review --no-commit --security-deferred` so its shallow Phase-2 security trims to a deferral note (the deep pass below covers it). `/execute` is the SINGLE owner of `/security-review`: run `/security-review --no-commit` ONCE when the card's sensitivity tag is set. `/code-review --no-commit` defers the deep security pass to its caller, so it runs exactly once per sensitive card (no double invocation, no double scan). The review skills never commit -- `/execute` owns the commit via `/card-commit`.
- Deploy = deploy BE to local Docker.
- Regen = regenerate FE API types from the deployed swagger (openapi).

Deploy + regen exist only for separate BE-API + FE-SPA. Skip them for monolith / MVC5 / monorepo.

## Order

BE before FE inside the card. Finish BE → deploy BE to local Docker so swagger is live → regen FE types → FE work. Never hand-edit generated types to start FE early.

## Pre-complete verify

Invoke `/verify` ONCE per card, placed LAST -- after every layer's `/code-review --no-commit` (+ `/simplify`) edits have landed, immediately before commit, on the final tree. This is the card pre-complete stage (see Check scope). `/verify` is the single project-scoped runner: full whole-graph build + full test suite + changed-file coverage existence gate.

- During work, only feature-scoped tests ran (see TDD per layer). Neither the full suite nor a full build has run yet on the final code -- `/verify` covers both now.
- Require `VERIFY RESULT: PASS`. On `VERIFY RESULT: FAIL`, STOP and surface the verbatim failing build/test output; do not commit. Coverage `uncovered:` is advisory -- it does not flip PASS/FAIL.
- If ANY edit lands after this `/verify` PASS (a fix, a simplify pass), the PASS is void -> re-invoke `/verify` and require PASS again before commit.
- Cross-repo card: run `/verify` in EACH touched repo, require PASS in both.

## Commit

`/execute` commits ONLY when the card is complete -- never mid-card. It owns the commit and runs `/card-commit` at the card's final commit step. `/card-commit` commits the card's slice of files and trusts the pre-complete `/verify` PASS (runs format + lint, skips the test/build re-run; re-invokes `/verify` itself if an edit landed after the PASS).

- Single-repo card: one `/card-commit` at the end of the sequence.
- Cross-repo card: at card completion, run `/card-commit` once in EACH touched repo (BE repo + FE repo), after that repo's `/verify` PASS. The earlier DEPLOY BE step runs from the working tree (local Docker) -- it needs no commit.

A PR is optional at this point: ask the user to raise the per-card PR now or defer it to the final `/pr`. Commit is required for the card to count as done; the PR may be deferred.

Under `--blast-mode` this whole section is skipped: no `/card-commit`, no PR. A card counts as done on `/verify` PASS without a commit. See Blast mode.

## Check scope

Per-layer checks during work target ONLY the `git diff` changed files. The project-scoped passes run ONCE at the card pre-complete stage (Pre-complete verify), not per layer.

- During layer work (diff-scoped): feature-scoped tests, `/lint-gate` (changed-file linter + guards), `/code-review --no-commit` (diff-only LLM judgment).
- Card pre-complete stage (project-scoped, once): `/verify` (full test suite + full build/type-check + coverage), then `/card-commit`.

Build/type-check is never a per-layer diff check -- it is inherently whole-graph (a changed shared type can break an unchanged consumer outside the diff), so it runs full, once, at pre-complete inside `/verify`.

## TDD per layer

The spec→work→test sub-sequence per layer is TDD.

1. Write the L2 `.feature` FIRST → it is the failing acceptance test. Announce `RED -- <scenario> failing`. (Reqnroll BE / cucumber-vite FE.)
2. Implement the work → acceptance test green. Announce `GREEN -- <scenario> passing`.
3. Unit-level RED → GREEN → REFACTOR beneath the acceptance test. Read existing tests in the area first -- replace, extend, or add; never duplicate. Refactor only code you just wrote.

No production code before a failing test. RED/GREEN are required user-facing output for any behavior step.

**Scope the in-work test runs.** During layer work, run only the FEATURE-SCOPED tests for RED/GREEN, not the whole suite:

- FE: `vitest run src/features/<x>` + the new integration file(s).
- BE: `dotnet test` filtered to the touched project or trait (`--filter`), not the whole solution.

The whole suite runs ONCE later, via `/verify` at the Pre-complete verify stage. Scoped runs keep the per-layer TDD loop fast; the full sweep still happens exactly once per card.

## Verification marker

Mechanical no-behaviour steps -- EF mapping, EF migration, read DTO + projection, API regen, pure config -- have no test to write. Run the stated verification command, announce `VERIFICATION -- <category>: <output>`. RED/GREEN do not apply. Real logic in a mapping/DTO/config is NOT exempt -- it needs a real test.

## Spec cross-check

Before writing code, read the spec scenario(s) the card references. Verify the work will satisfy them. If card and spec disagree, STOP and report the conflict; never silently pick one side.

## SOLID (inlined)

- S -- one responsibility per class/module; one reason to change.
- O -- open for extension, closed for modification; extend via abstractions, not edits to working code.
- L -- subtypes substitutable for their base; a derived type must not break the base contract.
- I -- small, focused interfaces; clients don't depend on methods they don't use.
- D -- depend on abstractions; inject collaborators, never `new` them inside domain code.

## DDD (inlined)

- Use the spec's ubiquitous language in names (entities, value objects, aggregates, domain events).
- Respect bounded contexts; don't leak infrastructure (DbContext, HTTP, file I/O) into domain logic.
- Keep aggregates transactionally consistent.

## Progress tracking

The card carries its ordered sequence as a checklist.

- Tick each step as it passes.
- Append dated Progress entries, mirroring the docspace card convention (Goal/Scope/Acceptance/TDD/Progress).
- A card is DONE when every checklist step is ticked THROUGH the `/card-commit` step (the PR may be raised now or deferred to `/pr`).
- `/execute` OWNS the card move. The moment the card is done, move it `<work-folder>/active/` → `<work-folder>/done/` and APPEND a `## Closed: <date>` block at the END of the card file (append, never prepend). `/close` does NOT move cards.
- When that move leaves `<work-folder>/active/` empty (the last card is done), INVOKE `/status` as a leaf action to present the completion conclusion.

## Handoff

The card ends after `/card-commit` runs. The PR is raised now or deferred to `/pr`. A cross-repo slice raises 2 linked PRs.

## Surface concerns

Never silently absorb a problem or a mid-run user correction. Surface it; record what was wrong AND the corrected behavior. On a card/spec conflict, STOP and report -- don't work around it.

## Red Flags

| Thought | Reality |
|---------|---------|
| "I'll dispatch subagents for the card's steps" | Run natively in the current context -- no subagent dispatch, no batches. |
| "I'll auto-run straight through deploy and commit" | STOP after each layer's code review, before deploy, before commit/PR. |
| "Monolith, but I'll deploy + regen anyway" | Skip deploy + regen for monolith / MVC5 / monorepo. Run only for separate BE-API + FE-SPA. |
| "I'll write code, then add the test" | Write the L2 `.feature` (RED) first; no production code before a failing test. |
| "This EF mapping has a HasConversion doing real work -- still just a mapping" | Real logic needs a real test. VERIFICATION is mechanical-only. |
| "I'll new up the repository inside the domain service" | Inject it. DIP -- domain depends on abstractions. |
| "Card and spec disagree -- I'll pick the card" | STOP and report the conflict. |
| "I'll hand-edit the generated types to start FE early" | Deploy BE, regen from live swagger, then FE work. |
| "The review skill will commit after its pass" | Review skills are review + fixes only. `/execute` owns the single commit gate and runs `/card-commit`. |
| "`/close` will move the finished card" | `/execute` owns the card move + `## Closed:` append. `/close` does not move cards. |
| "Blast mode -- I'll commit each card as I go" | Commit + PR are prohibited in blast mode. No `/card-commit`, `/commit`, or `/pr`. Changes stay uncommitted. |
| "A card won't pass -- I'll stop the whole blast run" | Mark it BLOCKED, continue the next card. End the run only when the blocker also blocks the remaining cards. |
| "Card/spec conflict in blast mode -- I'll quietly pick a side" | Record every autonomous call as `DECISION --`; BLOCK on an irreconcilable conflict. Nothing silent. |

## Next step

End by telling the user their next skill: if active cards remain, run `/execute` for the next card; when the last card finishes, `/execute` invokes `/status` itself to present the conclusion.

Under `--blast-mode` the run ends with the Blast mode wrap-up (saved to `_overview.md` + chat); next step is the user reviews the uncommitted working tree, then runs `/commit` or `/pr`.
