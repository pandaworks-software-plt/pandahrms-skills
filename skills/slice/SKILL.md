---
name: slice
description: Manually invoked as `/slice` (or by an explicit "slice this" / "cut this into cards" mention) to cut agreed work into independently-shippable vertical-slice cards. One capability per slice (CRUD -> 4 slices), Collapse Rule for trivial ones. Each card carries the L1 scenarios it covers, its L2 spec file(s) (BE Reqnroll .feature + FE cucumber-vite .feature -- decided here, written later in /execute, one per layer the slice touches), an ordered work-sequence CHECKLIST templated by layer-span AND architecture, a sensitivity tag (auth/tenant/PII), and acceptance. Gates on user agreement before any execution. Cross-repo slice raises 2 linked PRs.
---

# Pandahrms Slice

Cut agreed work into independently-shippable vertical-slice cards. Each card = one capability through every layer it touches, carrying its own L2 spec file(s) and an ordered work-sequence checklist. Gate on user agreement before execution.

**Announce at start:** "I'm using Pandahrms slice to cut this into vertical-slice cards."

## Input

- Agreed L1 behaviour spec (the `.feature` scenarios).
- Intake output: objective, acceptance criteria, module.

## Vertical-slice heuristic

One capability per vertical slice. CRUD -> 4 slices (create, read, update, delete). A slice cuts through every layer it touches (e.g. DB column + API endpoint + FE form), NOT a horizontal layer ("all DB" then "all API"). Each slice:
- delivers working, testable behaviour on its own
- ships as one small PR, reviewable alone

Don't bundle unrelated capabilities into one card. Don't split what ships together (Collapse Rule).

## Collapse Rule

Collapse into one card the steps that are ALL of:
- causally chained (each finishes before the next starts), AND
- same logical concern (e.g. "persist X" = entity property + EF mapping + migration), AND
- cannot parallelise

Keep separate when concerns differ (validation vs persistence) even when sequential.

## Architecture detection

Determine the project shape before templating sequences:
- **separate BE-API + FE-SPA** (cross-repo: API repo + SPA repo) -> BE deploys, FE regenerates API types off the deployed swagger.
- **monolith / MVC5 / monorepo** (BE + FE build together) -> NO deploy, NO regen between layers.

## Each card

One vertical slice = one capability cut through all layers it touches. Each card holds:

- **Title** -- the capability (e.g. "Create appraisal").
- **Order** -- slice number.
- **Layers** -- BE / FE / both.
- **L1 covered** -- the behaviour-spec scenarios this slice satisfies (traceability to L1).
- **L2 spec file(s)** -- DECIDED here, written later. Before naming any path, INSPECT the real layout: find the BE Reqnroll `.feature` location (the `Features/` folder in the BE test project) and the FE cucumber-vite `.feature` location. Choose paths that match the existing layout. One L2 `.feature` per layer the slice touches:
  - BE -> BE test project `Features/` folder, Reqnroll `.feature`
  - FE -> FE cucumber-vite `.feature` location
  - cross-repo slice declares 2 spec files.
- **Sequence** -- ordered work steps as a CHECKLIST, templated by layer-span AND architecture (below).
- **Sensitivity** -- auth / tenant / PII flag.
- **Acceptance** -- from the L1 scenarios.

## Sequence templates

Render the card's Sequence as a markdown checklist (`- [ ]`), templated by layer-span and architecture:

**separate BE-API + FE-SPA, cross-repo slice:**
```
- [ ] BE spec (write L2 Reqnroll .feature + step defs)
- [ ] BE work
- [ ] BE test
- [ ] BE code review
- [ ] DEPLOY BE (from the working tree, local Docker -- no commit)
- [ ] FE generate API (openapi off deployed swagger)
- [ ] FE spec (write L2 cucumber-vite .feature)
- [ ] FE work
- [ ] FE test
- [ ] FE code review
- [ ] commit (BE repo + FE repo) + PR (ask user)
```
(Commit ONLY when the card is complete -- never mid-card. Cross-repo = one commit per repo, both at the end. Deploy uses the working tree, no commit.)

**monolith / MVC5 / monorepo, cross-layer slice (NO deploy, NO regen):**
```
- [ ] BE spec (write L2 .feature + step defs)
- [ ] BE work
- [ ] BE test
- [ ] BE code review
- [ ] FE spec (write L2 .feature)
- [ ] FE work
- [ ] FE test
- [ ] FE code review
- [ ] commit / PR (ask user)
```

**BE-only slice:** the BE half only (BE spec -> BE work -> BE test -> BE code review -> commit/PR ask).

**FE-only slice:** the FE half only (FE spec -> FE work -> FE test -> FE code review -> commit/PR ask).

Security review enters the sequence (after code review of the touched layer) when the card's sensitivity tag is set.

## Sensitivity tagging

Tag a card `sensitive` when it touches any of:
- authentication / authorization / session
- multi-tenant data boundary -- tenant_id filters, row-level security, cross-tenant checks
- money / billing / payment
- database schema / migration / data-rewrite script
- PII handling / audit logging / data retention
- anything a design doc flagged as risky

Sensitive cards add /security-review to the sequence; standard cards skip it.

## Card store

Read the `work_folder` field from the intake `_overview.md`. Write cards to `<work-folder>/active/`. Do not re-derive the location.

Cards are capability-named by order + capability: `01-create.md`, `02-read.md`, `03-update.md`, `04-delete.md`. The BE+FE split lives INSIDE the card's sequence, not in the filename.

## Card template

Emit each agreed card as its own file:

```markdown
---
title: <NN> <capability>
order: <NN>
created: <YYYY-MM-DD>
status: active
project: <slug or "ad-hoc">
layers: BE | FE | both
sensitivity: sensitive | standard
---

## Capability
<the one capability this slice delivers, in 1-2 sentences>

## L1 covered
- <behaviour-spec scenario(s) this slice satisfies>

## L2 spec files (decided here, written later -- paths inspected from the real layout)
- BE: <BE test project>/Features/<name>.feature   (Reqnroll)
- FE: <FE cucumber-vite path>/<name>.feature   (cucumber-vite)

## Sequence
- [ ] <templated steps per layer-span + architecture>

## Acceptance
- <from the L1 scenarios>

## Out of scope
- <adjacent capability deferred to another card>
```

## Cross-repo slice

A slice spanning BE + FE is one logical unit but raises 2 linked PRs (one per repo) at PR time. Each PR description cross-links the other. Flag it on the card.

## User-agreement gate

After drafting the card set, show the user the ordered list -- each line: order, title, layers, sensitivity, one-line capability. Ask via AskUserQuestion to agree before any execution. On requested changes, revise and re-show. Do NOT write card files, and do NOT begin execution, until the user agrees. After agreement, write the card files to the resolved store.

## Rules

- Cut vertically -- one capability through all the layers it needs. Never a horizontal "database" then "API" then "UI" card set.
- Collapse steps into one card when they are same concern + causally chained + can't parallelise.
- Always check the sensitivity list. Auth, tenant boundary, billing, schema, PII force `sensitive` + /security-review in the sequence.
- Cross-repo slice deploys BE then regenerates FE API types before FE work. Only monolith/MVC5/monorepo skips that bridge.
- Slice DECIDES the L2 spec paths; the writing happens later.
- Do not begin execution until the user agrees to the set. The gate is blocking.
- BE + FE slice raises two linked PRs, one per repo. Flag it on the card.
- Draft cards in chat, get agreement, then write files. Don't write rejected proposals to the store.
