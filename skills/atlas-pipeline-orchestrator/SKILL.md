---
name: atlas-pipeline-orchestrator
description: Triggers on any mention of starting new work, building a feature, adding functionality, fixing a bug, refactoring, or shipping a change end-to-end -- and on "atlas", "atlas-pipeline-orchestrator", or "run the pipeline". The single entry point for the Pandahrms work lifecycle: a fast lane for trivial changes, and a main flow that runs native understand -> conditional spec (spec-writing) -> decompose into vertical-slice cards (card-decompose) -> per card execute (card-execute) + review (athena, aegis when sensitive) -> per-card PR.
---

# Pandahrms Atlas Pipeline Orchestrator

Thin runner over the native flow. Most work happens natively; this skill sequences the steps and the gates.

**Announce at start:** "I'm using Pandahrms atlas-pipeline-orchestrator to drive this from understand to PR."

## Two modes

- **Fast lane** -- trivial change: 3 files or fewer, about 60 lines or fewer, no new public API, no new spec scenario, behavior obvious. One-line confirm, do it natively with TDD, done. No spec step, no decompose, no per-card review. Offer a PR when finished.
- **Main flow** -- everything else. Runs the steps below.

A change touching the sensitivity list (auth/authz, multi-tenant boundary, billing/payment, schema/migration, PII/audit, design-flagged) is never fast lane.

## Main flow

1. **Understand (native)** -- read the relevant specs, tests, and code; ask only what is unclear. No skill fires. Proportional to the request.
2. **Spec** -- check the project spec files for the area.
   - UI-only change with no business behavior (CSS/layout/copy, no validation/API/role/handler logic) -- skip with a one-line announcement.
   - Otherwise, when behavior changes and a spec exists or is needed, invoke `spec-writing` to create/update it. Show the user. **User agrees** before continuing. Design discussion is authoritative -- if it diverges from the spec, update the spec here.
3. **Decompose** -- invoke `card-decompose` to cut the work into vertical-slice cards, each tagged with its path and sensitivity. Show the card set. **User agrees** before any execution.
4. **Per card** -- run cards back to back; the user stops any time. Cards not run this session stay as a backlog.
   - **Execute** -- invoke `card-execute` (native TDD).
   - **Review** -- invoke `athena-code-review`. If the card is tagged sensitive, also invoke `aegis-security-review`. Fix findings.
   - **Raise PR?** -- invoke `card-pr`: it offers the PR, asks the user how to branch, commits via `hermes-commit`, and opens the PR. A card that spans BE + FE raises 2 linked PRs, one per repo.

## Optional: Codex

Off by default. If the user opts in and `codex` is installed (`command -v codex`), card execution may route through `codex:codex-rescue`; reviews always stay on Claude. A single on/off toggle -- no modes, no state machine, no per-task split.

## Authority

- **Understand / spec time** -- discussion and decisions are the source of truth. If they diverge from the spec, update the spec before decomposing.
- **Execution time** -- the card and the spec govern. On a spec/code conflict, STOP and report; never silently reconcile or pick a side.

## Branching and commits

- Branching is user-owned. Never auto-create or auto-switch a branch. The per-card PR step asks the user how to branch.
- No commits during execute or review. Commit a card only after its review passes, at the PR step.

## Red Flags

| Thought | Reality |
|---------|---------|
| "I'll decompose this typo into cards" | Fast lane. Trivial change -> confirm -> do it -> offer a PR. No decompose. |
| "I'll skip the spec because the user described the change" | When behavior changes, check the spec; create/update via spec-writing and get the user's agreement. UI-only with no behavior skips. |
| "I'll start executing the cards once I've drafted them" | Not until the user agrees to the card set. |
| "I'll run aegis on every card" | aegis runs only on cards tagged sensitive; standard cards get athena only. |
| "I'll dispatch subagent batches for the cards" | No. Cards execute natively via card-execute -- one at a time, in this context. |
| "I'll commit each card as I finish it" | Commit only after the card's review passes, at the PR step. |
| "I'll pick a branch and open the PR" | Branching is user-owned. Ask how they want to branch first. |
| "Discussion decided X but the spec says Y -- I'll just build X" | Update the spec first, then decompose. Never leave the spec stale. |

## When to use

- Any work request that needs understanding, specs, execution, review, or a PR -- atlas is the single entry point.
- Triggers: "start new work", "build a feature", "add functionality", "fix a bug", "refactor X", "ship this", "atlas", "run the pipeline".

## When not to use

- Writing specs for existing functionality with no change -- use `spec-writing` directly.
- Pure code review of working-tree changes -- use `athena-code-review` directly.
- Pure security audit -- use `aegis-security-review` directly.
- Committing already-reviewed changes -- use `hermes-commit` directly.
