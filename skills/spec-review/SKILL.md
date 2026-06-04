---
name: spec-review
description: Optional deep cross-check of the design doc against feature spec files - ensures specs fully cover all requirements from the design and nothing is missed or misaligned. spec-writing now runs an inline design-coverage cross-check at its Step 5, so this standalone pass is reserved for heavyweight scope or explicit request, not a required chain step after every spec-writing run.
---

# Spec Review

## Overview

Cross-checks approved design doc against written Gherkin spec files for full alignment. Every requirement, behavior, rule, and edge case in design must have spec coverage; no spec may introduce behavior not in design. Optional deep pass -- spec-writing Step 5 already runs an inline design-coverage cross-check. Use this skill for heavyweight scope or when the user explicitly asks for a second, independent coverage audit.

**Announce at start:** "I'm using the spec-review skill to cross-check the design doc against the feature specs."

Read-only with respect to design docs and `.feature` files. Do not edit, create, rename, or delete any design doc or `.feature` file from within this skill. Gap-filling is delegated to `pandahrms:spec-writing` via the Skill tool -- never edit specs inline from this skill.

## Prerequisites

Required:

1. **A design document** at `<project>/docs/pandahrms/designs/*-design.md`.
2. **Written spec files** in `pandahrms-spec/specs/<module>/<feature>/`.

If design doc is missing at expected path, do not proceed. Use AskUserQuestion to request absolute path to design doc. Resume Step 1 with provided path. If user declines, exit with message: "Spec review cannot run without a design document. Skill exited." and proceed to Skill Exit.

If spec files are missing, apply Skip Condition (evaluated after Step 1).

## The Process

**Step 1: Locate Artifacts (sequential)**

Step 1 is sequential. Do not parallelize the two sub-steps; sub-step 2 depends on module/feature path declared in document resolved in sub-step 1.

#### 1a. Resolve the design doc

- List all `*-design.md` files in `<project>/docs/pandahrms/designs/`.
- If exactly one exists, use it.
- If multiple exist, list every candidate by full path inline in chat and ask the user inline in plain text which file to use. Do not pick automatically based on mtime, file name keywords, or git status.
- Do not search outside `<project>/docs/pandahrms/designs/`.
- Read chosen design doc and capture its declared module and feature path (e.g. `specs/auth/onboarding-mobile`). If path is not stated in doc, ask the user inline in plain text so they can type the path.

#### 1b. Resolve the spec directory (runs only after 1a completes)

- Resolve spec repo as sibling: `$(dirname $PWD)/pandahrms-spec/`.
- Verify with `test -d $(dirname $PWD)/pandahrms-spec/`.
- If absent, use AskUserQuestion to request absolute `pandahrms-spec` path. Do not treat "sibling missing" as "no specs written".
- Glob exactly the declared module/feature path: `<pandahrms-spec>/<declared-path>/**/*.feature`. Do not search outside that directory.

### Skip Condition: No Specs Written (evaluated after Step 1)

Runs after Step 1 has resolved spec directory.

Skip this skill if EITHER condition holds, subject to listed verification:

- **Condition A -- User chose "Skip specs":** Most recent assistant message in this conversation contains literal string `Skip specs` as user's chosen option. If true, skip without further verification.
- **Condition B -- Zero spec files:** Resolved feature directory from Step 1 contains zero `.feature` files. Verify with `ls <resolved-path>/**/*.feature`. If directory does not exist, treat as zero files. Before applying skip on Condition B alone, confirm with user via AskUserQuestion that resolved spec directory (printed as absolute path) is correct. Do not skip on Condition B until user confirms there are intentionally no specs.

If skipped:

- Announce: "Skipping spec-review -- no specs were written for this feature."
- Return control to caller.

Then proceed to Skill Exit.

**Step 2: Extract Design Requirements**

Read design document and produce a single flat numbered list `D1..Dn`. Do not produce nested or category-grouped numbering.

Each entry has:

- Short requirement statement (one sentence).
- `Type:` tag from set `{Feature, BusinessRule, Validation, EdgeCase, ActorBehavior, StatusTransition, DataRequirement}`.
- `Section:` tag with design doc heading the requirement came from.

Extract only requirements explicitly stated in design doc text. Do not add inferred requirements, industry-standard expectations, or items implied by domain. If a requirement is not literally present in document, do not include it as `D`-numbered.

**Step 3: Extract Spec Coverage**

Read all `.feature` files resolved in Step 1 and produce a single flat numbered list `S1..Sm`. Each entry has:

- Literal scenario name as written in `.feature` file (text after `Scenario:` or `Scenario Outline:`). Do not paraphrase, shorten, or normalize casing.
- `File:` tag with file's relative path.
- `Tags:` tag listing any `@validation`, `@authorization`, or other Gherkin tags on scenario.

Steps 2 and 3 may run in parallel, but both must complete and emit fully-numbered lists (`D1..Dn` and `S1..Sm`) before Step 4 begins. Do not start cross-checking until both lists are fixed.

**Step 4: Cross-Check (sequential)**

Complete 4a fully (every `D` evaluated, GAP table finalized) before starting 4b. Do not interleave 4a and 4b findings.

#### 4a. Design -> Specs (completeness check)

For each design requirement `D1..Dn`, identify which spec scenario(s) cover it.

Flag as **GAP** any design requirement with no corresponding spec scenario.

#### 4b. Specs -> Design (consistency check)

For each spec scenario `S1..Sm`, identify which design requirement it traces back to.

Flag as **EXTRA** any spec scenario that does not trace back to a design requirement.

Classify each EXTRA as exactly one of:

- **Defensive** -- covers an obvious edge case implied by design (e.g. auth required, validation on a field declared required in design, 404 on missing entity).
- **Drift** -- adds behavior design does not mention.

Mark each EXTRA as `Defensive` or `Drift` in Extras table. Do not leave any EXTRA unclassified.

If more than 10 EXTRAs are found, stop classifying and present the count and EXTRA list inline in chat, then ask the user inline in plain text before continuing. Do not silently process a large extras set.

**Step 5: Report**

Present findings in this format:

```
## Spec Review: [Feature Name]

### Coverage Summary
- Design requirements: [count]
- Spec scenarios: [count]
- Fully covered: [count]
- Gaps (design not in specs): [count]
- Extras - Defensive: [count]
- Extras - Drift: [count]

### Gaps (design requirements missing from specs)
| # | Design Requirement | Section in Design |
|---|---|---|
| GAP-1 | [description] | [section reference] |
| GAP-2 | [description] | [section reference] |

### Extras (spec scenarios not in design)
| # | Spec Scenario | File | Classification |
|---|---|---|---|
| EXTRA-1 | [scenario name] | [file.feature] | Defensive |
| EXTRA-2 | [scenario name] | [file.feature] | Drift |

### Full Traceability Matrix
| Design Req | Description | Spec Scenario(s) | Status |
|---|---|---|---|
| D1 | [description] | S1, S5 | Covered |
| D2 | [description] | -- | GAP |
| D3 | [description] | S3 | Covered |
```

**Step 6: Resolve**

Branch on findings.

**Pass condition (zero GAPs AND zero Drift extras):** announce "Design and specs are aligned." Defensive EXTRAs do not block alignment. Proceed to Skill Exit.

**Any GAPs OR any Drift extras present:** ask inline in plain text `"Spec review found {N} gap(s) and {M} drift extra(s). How would you like to resolve?"` and list the options below for the user to type back. Apply matching action exactly:

- `Fix gaps and remove drift` -- re-invoke `pandahrms:spec-writing` via Skill tool, passing GAP table and Drift EXTRA table as input. Do not edit `.feature` files directly from this skill.
- `Fix gaps only` -- re-invoke `pandahrms:spec-writing` via Skill tool, passing GAP table only.
- `Update design to match specs` -- STOP and instruct user to revise design doc. Do not edit design doc from this skill.
- `Proceed anyway` -- record unresolved findings in conversation and proceed to Skill Exit.

A GAP is "resolved" when one of these states holds (recorded in conversation only, not in any file):

- **COVERED** -- `pandahrms:spec-writing` was re-run and a scenario now exists.
- **ACCEPTED** -- user explicitly chose `Proceed anyway`.

A Drift EXTRA is "resolved" when one of these states holds (recorded in conversation only):

- **REMOVED** -- `pandahrms:spec-writing` was re-run and drift scenario was removed.
- **ACCEPTED** -- user explicitly chose `Proceed anyway`.

This skill never modifies design doc, never creates a "deferred items" file, and never marks an item descoped on its own.

## Skill Exit

Complete when one of the following has happened:

- (a) Step 6 announced "Design and specs are aligned."
- (b) Step 6 routed back to `pandahrms:spec-writing` and that re-invocation was dispatched.
- (c) User chose `Proceed anyway` in Step 6.
- (d) User chose `Update design to match specs` in Step 6 (STOP after instructing user).
- (e) Early exit per Prerequisites or Skip Condition rules.

After exit, return control to caller.

## Checklist

- [ ] Located design document and spec files (Step 1 sub-steps run sequentially)
- [ ] Evaluated Skip Condition after Step 1; confirmed with user before applying Condition B
- [ ] Extracted all requirements from design doc as flat list `D1..Dn` with `Type:` and `Section:` tags
- [ ] Extracted all scenarios from spec files as flat list `S1..Sm` with literal scenario names, `File:`, and `Tags:`
- [ ] Performed design -> specs completeness check (4a complete before 4b)
- [ ] Performed specs -> design consistency check with every EXTRA classified `Defensive` or `Drift`
- [ ] Presented coverage report with traceability matrix
- [ ] All GAPs resolved (`COVERED` or `ACCEPTED`)
- [ ] All Drift extras resolved (`REMOVED` or `ACCEPTED`)
- [ ] Reached Skill Exit per documented branch
