---
name: slice
description: '`/slice` -- cut agreed work into independently-completable cards. Group by capability where it helps (e.g. CRUD -> 4 cards), Collapse Rule for trivial ones; strict vertical slicing is not required. Each card carries the L1 scenarios it covers, its L2 spec file(s) (BE Reqnroll .feature + FE cucumber-vite .feature -- decided here, written later in /execute, one per layer the card touches), an ordered work-sequence CHECKLIST templated by layer-span AND architecture, a category tag (implementation/data-migration/deployment/testing/refactor/config), a sensitivity tag (auth/tenant/PII), and acceptance. Cards do NOT commit or raise a PR each -- the whole branch is committed and ONE PR raised at the end via /commit or /pr once every card is done (cross-repo work raises 2 linked PRs then). Shows the ordered card list and writes the card files immediately -- no confirmation gate; revises files in place when the user requests changes.'
---

# Pandahrms Slice

Cut agreed work into independently-completable cards. Group by capability where it helps; strict vertical slicing is not required. Each card carries its own L2 spec file(s) and an ordered work-sequence checklist. Show the card list, write the files, proceed -- no confirmation gate.

**Announce at start:** "I'm using Pandahrms slice to cut this into work cards."

## Input

- Agreed L1 behaviour spec (the `.feature` scenarios).
- Intake output: objective, acceptance criteria, module.

## Slicing heuristic

Cut into independently-completable cards. Group by capability where it helps -- e.g. CRUD -> 4 cards (create, read, update, delete). A vertical cut through every layer a capability touches (DB column + API endpoint + FE form) is preferred where natural, but not required; a card may span fewer layers. Each card delivers working, testable behaviour on its own. Don't bundle unrelated capabilities into one card. Don't split what belongs together (Collapse Rule).

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

Each card is one independently-completable unit of work. Each card holds:

- **Title** -- the capability (e.g. "Create appraisal").
- **Order** -- slice number.
- **Layers** -- BE / FE / both.
- **Category** -- the card's primary purpose: implementation / data-migration / deployment / testing / refactor / config (below).
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
```
(No per-card commit or PR. The card ends on `/verify` PASS; its changes stay in the working tree. The whole branch is committed and ONE PR raised at the end via `/commit` or `/pr`. Deploy uses the working tree, no commit.)

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
```
(No per-card commit or PR. Cards end on `/verify` PASS; the whole branch is committed and ONE PR raised at the end via `/commit` or `/pr`.)

**BE-only card:** the BE half only (BE spec -> BE work -> BE test -> BE code review).

**FE-only card:** the FE half only (FE spec -> FE work -> FE test -> FE code review).

Security review enters the sequence (after code review of the touched layer) when the card's sensitivity tag is set.

## Card category

Tag every card with one category naming its primary purpose. Pick by what the card mainly delivers (a card may include incidental other-type steps; tag by the dominant one):

| Category | Card's main purpose |
|----------|---------------------|
| `implementation` | Adds or changes product behaviour (default; most feature cards). |
| `data-migration` | Schema change, EF migration, or data backfill / rewrite script. |
| `deployment` | Release, pipeline, environment, or infra change. |
| `testing` | Test-only: add or expand coverage, no production code change. |
| `refactor` | Restructure existing code, no behaviour change. |
| `config` | Pure configuration change (appsettings, feature flag, settings) with no logic. |

Default to `implementation` when the card builds or changes feature behaviour. Use the others only when that IS the card's whole point.

**Group by category.** Default to ONE capability card that spans whatever categories the capability needs -- a feature card normally carries its implementation plus its incidental migration / config / test steps. Within that card, keep same-category tasks together; don't scatter the same kind of work across cards. Break a capability into separate same-category cards ONLY when a block of same-category work is BOTH substantial AND independently shippable on its own (a sizeable standalone data migration, a release / deployment task, a test-only coverage expansion) -- never split just because categories differ, and never create a card with no standalone value. When you do split, order by dependency (data-migration before the implementation that reads the new shape; deployment after the implementation it ships). The Collapse Rule still wins: same-concern, causally-chained, non-parallelisable steps stay in one card even when they cross categories (e.g. entity property + EF mapping + migration = one card, tagged by its dominant purpose).

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
category: implementation | data-migration | deployment | testing | refactor | config
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

## Cross-repo card

A card spanning BE + FE is one logical unit. No commit or PR per card; the 2 linked PRs (one per repo) are raised at the END for the whole work via `/pr`, each cross-linking the other. Flag the cross-repo span on the card.

## Card set output

After drafting the card set, show the user the ordered list -- each line: order, title, layers, category, sensitivity, one-line capability. Then write the card files to the resolved store in the same turn -- no confirmation gate. When the user requests changes after seeing the list, revise the affected card files in place and re-show the list.

## Rules

- Prefer capability-grouped cards; a vertical cut through the layers a capability needs is preferred but not mandatory. Avoid a pure horizontal "all database" then "all API" then "all UI" card set when a capability cut fits.
- Collapse steps into one card when they are same concern + causally chained + can't parallelise.
- Tag every card with one category (implementation/data-migration/deployment/testing/refactor/config). Default `implementation`; use another only when that is the card's whole point.
- Default to one capability card spanning categories; group same-category tasks together. Break out a same-category card ONLY when that block is BOTH substantial AND independently shippable -- never split on category difference alone, never make a card with no standalone value. Collapse Rule still overrides for same-concern causally-chained steps.
- Always check the sensitivity list. Auth, tenant boundary, billing, schema, PII force `sensitive` + /security-review in the sequence.
- Cross-repo slice deploys BE then regenerates FE API types before FE work. Only monolith/MVC5/monorepo skips that bridge.
- Slice DECIDES the L2 spec paths; the writing happens later.
- Show the ordered card list, write the files, proceed -- no confirmation gate. Revise card files in place on user-requested changes.
- Cross-repo card: the two linked PRs (one per repo) are raised at the end via `/pr`, not per card. Flag the cross-repo span on the card.
- Draft cards, show the list, write files in the same turn.

## Next step

End by telling the user to run `/execute` to build the first card (or `/execute card-01`).
