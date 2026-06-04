---
name: card-decompose
description: Triggers when an understood change must be cut into independently-shippable vertical-slice cards before implementation -- phrasings like "decompose this", "break this into cards", "slice this into PRs", "split this work into cards", or when a caller hands over a clarified requirement to plan as cards. Produces vertical slices (one capability cut through all layers), applies the Collapse Rule, tags each card with a path (fast-lane vs main-flow) and sensitivity, and gates on user agreement before any execution.
---

# Pandahrms Card Decompose

## Overview

Turn an understood change into independently-shippable vertical-slice cards. Each card = one capability cut through all the layers it needs, shippable as one small PR. Tag each card with a path and sensitivity. Gate on user agreement before any execution.

**Announce at start:** "I'm using Pandahrms card-decompose to cut this into vertical-slice cards."

## Vertical-slice rule

A card is a vertical slice: one capability through every layer it touches (e.g. "appraisal comment" = DB column + API endpoint + FE form), NOT a horizontal layer ("all DB", then "all API"). Each slice:
- delivers working, testable behavior on its own
- ships as one small PR, reviewable alone

Don't bundle unrelated capabilities into one card. Don't split what ships together (see Collapse Rule).

## Collapse Rule

Collapse into one card the steps that are ALL of:
- causally chained (each must finish before the next starts), AND
- same logical concern (e.g. "persist X" = entity property + EF mapping + migration), AND
- cannot parallelise

Keep separate when concerns differ (validation vs persistence) even when sequential.

## Path detection

Assign each card a path:
- **fast-lane** -- trivial: 3 files or fewer, about 60 lines or fewer, no new public API, no new spec scenario, behavior obvious. Execute directly with TDD; no per-card review ceremony.
- **main-flow** -- everything else: execute (TDD), then review, then PR.

A card hitting the sensitivity list is never fast-lane.

## Sensitivity tagging

Tag a card `sensitive` when it touches any of:
- authentication / authorization / session
- multi-tenant data boundary -- tenant_id filters, row-level security, cross-tenant checks
- money / billing / payment
- database schema / migration / data-rewrite script
- PII handling / audit logging / data retention
- anything a design doc flagged as risky

Sensitive cards gate aegis-security-review at review time; standard cards skip it.

## Card store

- **Project work** (cwd under a registered project) -- write cards to that project's `cards/active/`.
- **Ad-hoc / non-project work** -- ask the user once where ad-hoc cards live, record the answer in global `~/.claude/CLAUDE.md` + memory, then reuse it.

## Card template

Emit each agreed card as its own file:

```markdown
---
title: <NN> <short title>
created: <YYYY-MM-DD>
status: active
project: <slug or "ad-hoc">
path: fast-lane | main-flow
sensitivity: sensitive | standard
---

## Goal
<the one capability this slice delivers, in 1-2 sentences>

## Scope (this card)
- <layers cut through: DB / API / FE -- the vertical slice>

## Out of scope
- <adjacent capability deferred to another card>

## Gates (blocking)
- TDD: RED/GREEN markers (or VERIFICATION for a no-test-pattern step)
- main-flow: athena-code-review; sensitive: also aegis-security-review
- <cross-repo? name the paired PR>
```

## Cross-repo slice

A slice spanning BE + FE is one logical unit but raises 2 linked PRs (one per repo) at PR time. Flag it on the card so each PR description cross-links the other.

## User-agreement gate

After drafting the card set, show the user the ordered list -- each line: number, title, path, sensitivity, one-line goal. Ask via AskUserQuestion to agree before any execution. On requested changes, revise and re-show. Do NOT write card files, and do NOT begin execution, until the user agrees. After agreement, write the card files to the resolved store.

## Red Flags

| Thought | Reality |
|---------|---------|
| "I'll make a 'database' card, then an 'API' card, then a 'UI' card" | Horizontal layers. Cut vertically -- one capability through all the layers it needs. |
| "These two sequential steps each deserve a card" | If same concern + causally chained + can't parallelise, collapse into one card. |
| "This card is tiny, skip the sensitivity check" | Always check the sensitivity list. Auth, tenant boundary, billing, schema, PII force main-flow + aegis. |
| "I'll start executing the cards now" | Not until the user agrees to the set. The agreement gate is blocking. |
| "BE + FE slice is one PR" | Two linked PRs, one per repo. Flag it on the card. |
| "Every card needs athena and aegis" | aegis runs only on `sensitive` cards; standard cards get athena only. |
| "I'll decompose this one-file change into a set of cards" | If it is fast-lane (3 files or fewer, ~60 lines or fewer, no new API/spec), it is a single fast-lane card -- don't over-decompose. |
| "I'll write the proposed cards to the store, then ask" | Draft in chat, get agreement, then write files. Don't litter the store with rejected proposals. |
