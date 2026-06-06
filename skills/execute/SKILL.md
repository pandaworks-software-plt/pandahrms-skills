---
name: execute
description: Manually invoked as `/execute card-NN` to run that specific card's ordered sequence, or bare `/execute` to run the next available card (lowest-order active card not done). A guided run with stop-gates -- mechanical work auto-runs between gates; stops after each layer's code review, before deploy, and before commit/PR. Detects project architecture to include or skip the deploy + FE-regen bridge. Spec-first TDD with RED/GREEN/VERIFICATION markers, inlined SOLID + DDD. Owns the commit (runs /commit; per repo for cross-repo cards); the PR is raised now or deferred to /pr. Moves the finished card to done and appends a Closed block. Does NOT auto-trigger -- only on the slash command or an explicit "execute card" mention.
---

# Pandahrms Execute

Run ONE vertical-slice card by following its ordered sequence. Native, current context. No subagent dispatch, no batches. `/execute` owns the commit; the card ends after `/commit` runs, with the PR raised now or deferred to `/pr`.

**Announce at start:** "I'm using Pandahrms execute to run this card."

## Invocation

- `/execute card-NN` -- run that card.
- `/execute` (bare) -- run the next available card = lowest-order active card not yet done.

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

## Boundary steps (inline leaf actions)

Run these inline as leaf actions, NOT a skill chain. `/execute` drives the whole slice.

- Code review = invoke `/code-review --no-commit` (review + fixes only; the flag skips its commit phase). Add `/security-review --no-commit` when the card's sensitivity tag is set. `/execute` owns the commit and runs `/commit` itself at the right point -- the review skills never commit.
- Deploy = deploy BE to local Docker.
- Regen = regenerate FE API types from the deployed swagger (openapi).

Deploy + regen exist only for separate BE-API + FE-SPA. Skip them for monolith / MVC5 / monorepo.

## Order

BE before FE inside the card. Finish BE → deploy BE to local Docker so swagger is live → regen FE types → FE work. Never hand-edit generated types to start FE early.

## Commit

`/execute` commits ONLY when the card is complete -- never mid-card. It owns the commit and runs `/commit` at the card's final commit step.

- Single-repo card: one `/commit` at the end of the sequence.
- Cross-repo card: at card completion, run `/commit` once in EACH touched repo (BE repo + FE repo). The earlier DEPLOY BE step runs from the working tree (local Docker) -- it needs no commit.

A PR is optional at this point: ask the user to raise the per-card PR now or defer it to the final `/pr`. Commit is required for the card to count as done; the PR may be deferred.

## TDD per layer

The spec→work→test sub-sequence per layer is TDD.

1. Write the L2 `.feature` FIRST → it is the failing acceptance test. Announce `RED -- <scenario> failing`. (Reqnroll BE / cucumber-vite FE.)
2. Implement the work → acceptance test green. Announce `GREEN -- <scenario> passing`.
3. Unit-level RED → GREEN → REFACTOR beneath the acceptance test. Read existing tests in the area first -- replace, extend, or add; never duplicate. Refactor only code you just wrote.

No production code before a failing test. RED/GREEN are required user-facing output for any behavior step.

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
- A card is DONE when every checklist step is ticked THROUGH the `/commit` step (the PR may be raised now or deferred to `/pr`).
- `/execute` OWNS the card move. The moment the card is done, move it `<work-folder>/active/` → `<work-folder>/done/` and APPEND a `## Closed: <date>` block at the END of the card file (append, never prepend). `/close` does NOT move cards.
- When that move leaves `<work-folder>/active/` empty (the last card is done), INVOKE `/status` as a leaf action to present the completion conclusion.

## Handoff

The card ends after `/commit` runs. The PR is raised now or deferred to `/pr`. A cross-repo slice raises 2 linked PRs.

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
| "The review skill will commit after its pass" | Review skills are review + fixes only. `/execute` owns the single commit gate and runs `/commit`. |
| "`/close` will move the finished card" | `/execute` owns the card move + `## Closed:` append. `/close` does not move cards. |

## Next step

End by telling the user their next skill: if active cards remain, run `/execute` for the next card; when the last card finishes, `/execute` invokes `/status` itself to present the conclusion.
