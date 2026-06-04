---
name: card-execute
description: Triggers when a single agreed vertical-slice card must be implemented natively with TDD -- phrasings like "execute this card", "build this card", "implement card NN", or when a caller hands over an agreed card to implement. Runs one card in the current context (no subagent dispatch, no batches): spec cross-check, Red-Green-Refactor with RED/GREEN/VERIFICATION markers, inlined SOLID + DDD standards, Auto/Manual gate running with BE-to-FE sequencing, ending ready-for-review then commit-after-review.
---

# Pandahrms Card Execute

## Overview

Implement one vertical-slice card natively in the current context with TDD. No subagent dispatch, no batches. End ready for review; commit after the per-card review passes.

**Announce at start:** "I'm using Pandahrms card-execute to implement this card with TDD."

## Standards

Apply to all work in the card.

1. **Card-driven** -- the card's Goal + Scope is the source of truth for what to build. Stay in Scope; defer Out-of-scope items to their own cards.
2. **Spec cross-check** -- before writing code, read the spec scenario(s) the card references. Verify the implementation will satisfy them. If card or spec and the code disagree, STOP and report the conflict; never silently pick one side.
3. **TDD** -- Red-Green-Refactor (below).
4. **SOLID** (inlined):
   - S -- one responsibility per class/module; one reason to change.
   - O -- open for extension, closed for modification; extend via abstractions, not edits to working code.
   - L -- subtypes substitutable for their base; a derived type must not break the base contract.
   - I -- small, focused interfaces; clients don't depend on methods they don't use.
   - D -- depend on abstractions; inject collaborators, never `new` them inside domain code.
5. **DDD** (inlined):
   - Use the spec's ubiquitous language in names (entities, value objects, aggregates, domain events).
   - Respect bounded contexts; don't leak infrastructure (DbContext, HTTP, file I/O) into domain logic.
   - Keep aggregates transactionally consistent.

## TDD with markers

For each behavior in the card:
1. Read every existing test in the affected area first -- replace, extend, or add; never duplicate.
2. Write the failing test. Run it. Announce `RED -- <test> failing with <reason>`.
3. Write minimal code to pass. Run it. Announce `GREEN -- <test> passing`.
4. Refactor only the code you just wrote; re-run the test. If none, note `no refactor needed`.

RED and GREEN are required user-facing output for any test-ref behavior. No production code before a failing test.

## No-test-pattern verification

A step in the closed No-Test-Pattern list -- EF mapping, EF migration, read DTO + projection, API regen, pure config -- has no test to write. Run the stated verification command and announce `VERIFICATION -- <category>: <output>`. RED/GREEN do not apply. Real logic in a mapping/DTO/config is NOT exempt -- it needs a real test.

## Gates

Honour BE-to-FE order inside the card: finish BE, deploy BE locally so swagger is live, regen FE types, then FE work. Never hand-edit generated types to start FE early.

- **Auto Gate** -- mechanical idempotent local commands (`pnpm openapi-ts`, `dotnet ef database update` on local DB, local docker rebuild). Announce one line, run automatically, no pause.
- **Manual Gate** -- operator action needing judgment or out-of-band steps (prod deploy, migration on shared/prod env, DBA review, anything destructive or cross-team). Pause and wait for the user's confirmation phrase.

Do NOT reclassify a gate at runtime.

## Commit-after-review

End state of execution is **ready for review**, NOT committed. After the per-card review passes and its findings are fixed, commit the card. Do NOT commit before review.

## Surface concerns

Never silently absorb a problem or a mid-run user correction. Surface concerns to the user; record what was wrong AND the corrected behavior. On a card/spec conflict, STOP and report -- don't work around it.

## Red Flags

| Thought | Reality |
|---------|---------|
| "I'll dispatch subagents for the card's steps" | No. card-execute runs natively in the current context -- no subagent dispatch, no batches. |
| "I'll commit as I finish each step" | No. End ready-for-review; commit after the per-card review passes. |
| "Card and spec disagree -- I'll pick the card" | STOP and report the conflict. Don't silently reconcile. |
| "This EF mapping has a HasConversion doing real work -- still just a mapping" | Real logic needs a real test. The verification slot is mechanical-only. |
| "I'll new up the repository inside the domain service" | Inject it. DIP -- domain depends on abstractions, not concretions. |
| "I'll pause on the openapi-ts gate to be safe" | Auto Gate runs automatically. Only Manual Gates pause. |
| "I'll follow the SOLID rules file" | Standards are inlined above. Self-contained -- no external per-member rule files. |
