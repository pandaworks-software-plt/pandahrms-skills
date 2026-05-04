---
name: spec-review
description: Use after spec-writing to cross-check the design doc against feature spec files - ensures specs fully cover all requirements from the design and nothing is missed or misaligned
---

# Spec Review

## Overview

Cross-checks the approved design document against the written Gherkin spec files to ensure full alignment. Every requirement, behavior, rule, and edge case in the design must have corresponding spec coverage, and no spec should introduce behavior not described in the design.

**Announce at start:** "I'm using the spec-review skill to cross-check the design doc against the feature specs."

This skill is read-only with respect to design docs and `.feature` files. Do not edit, create, rename, or delete any design doc or `.feature` file from within this skill. Filling gaps is delegated to `pandahrms:spec-writing` via the Skill tool -- never edit specs inline from this skill.

### Where This Fits

```
superpowers:brainstorming (design doc)
    |
    v
pandahrms:spec-writing (write specs)
    |
    v
pandahrms:spec-review (THIS SKILL - cross-check)
    |
    v
superpowers:writing-plans (implementation plan)
```

This skill runs after specs are written and approved, before proceeding to implementation planning.

### Invocation Context Detection

Detect "invoked from forge-pipeline-orchestrator" by checking whether the current conversation already shows an active `pandahrms:forge-pipeline-orchestrator` Skill invocation. If present, treat as forge-pipeline-orchestrator-invoked. If not present, treat as standalone.

When standalone, every instruction in this skill that says "proceed to the next forge-pipeline-orchestrator step" or "return control to forge-pipeline-orchestrator" is replaced with "STOP and report status to the user". Do not invoke `pandahrms:forge-pipeline-orchestrator` to continue.

## Prerequisites

Before running this skill, you need:

1. **A design document** at `<project>/docs/plans/*-design.md`.
2. **Written spec files** in `pandahrms-spec/specs/<module>/<feature>/`.

If the design doc is missing at the expected path, do not proceed. Use AskUserQuestion to ask the user for the absolute path to the design doc. Resume Step 1 with the provided path. If the user declines, exit with the message: "Spec review cannot run without a design document. Skill exited." and proceed to Skill Exit.

If spec files are missing, apply the Skip Condition (evaluated after Step 1).

## The Process

### Step 1: Locate Artifacts (sequential)

Step 1 must be sequential. Do not parallelize the two sub-steps; sub-step 2 depends on the module/feature path declared in the document resolved in sub-step 1.

#### 1a. Resolve the design doc

- List all `*-design.md` files in `<project>/docs/plans/`.
- If exactly one exists, use it.
- If multiple exist, use AskUserQuestion to ask the user which file to use; list every candidate by full path. Do not pick automatically based on mtime, file name keywords, or git status.
- Do not search outside `<project>/docs/plans/`.
- Read the chosen design doc and capture its declared module and feature path (e.g. `specs/auth/onboarding-mobile`). If the path is not stated in the doc, use AskUserQuestion to ask the user for it.

#### 1b. Resolve the spec directory (runs only after 1a completes)

- Resolve the spec repo as the sibling: `$(dirname $PWD)/pandahrms-spec/`.
- Verify with `test -d $(dirname $PWD)/pandahrms-spec/`.
- If absent, use AskUserQuestion to ask for the absolute `pandahrms-spec` path. Do not treat "sibling missing" as "no specs written".
- Glob exactly the declared module/feature path: `<pandahrms-spec>/<declared-path>/**/*.feature`. Do not search outside that directory.

### Skip Condition: No Specs Written (evaluated after Step 1)

This check runs after Step 1 has resolved the spec directory.

Skip this skill if EITHER condition holds, subject to the listed verification:

- **Condition A -- User chose "Skip specs":** The most recent assistant message in this conversation contains the literal string `Skip specs` as the user's chosen forge-pipeline-orchestrator option. If true, skip without further verification.
- **Condition B -- Zero spec files:** The resolved feature directory from Step 1 contains zero `.feature` files. Verify with `ls <resolved-path>/**/*.feature`. If the directory does not exist, treat as zero files. Before applying skip on Condition B alone, confirm with the user via AskUserQuestion that the resolved spec directory (printed as an absolute path) is correct. Do not skip the skill on Condition B until the user confirms there are intentionally no specs.

If skipped:

- Announce: "Skipping spec-review -- no specs were written for this feature."
- If invoked from forge-pipeline-orchestrator: return control to forge-pipeline-orchestrator for the next step.
- If invoked standalone: STOP.

Then proceed to Skill Exit.

### Step 2: Extract Design Requirements

Read the design document and produce a single flat numbered list `D1..Dn`. Do not produce nested or category-grouped numbering.

Each entry has:

- A short requirement statement (one sentence).
- `Type:` tag from the set `{Feature, BusinessRule, Validation, EdgeCase, ActorBehavior, StatusTransition, DataRequirement}`.
- `Section:` tag with the design doc heading the requirement came from.

Extract only requirements explicitly stated in the design doc text. Do not add inferred requirements, industry-standard expectations, or items implied by the domain. If a requirement is not literally present in the document, do not include it as `D`-numbered.

### Step 3: Extract Spec Coverage

Read all `.feature` files resolved in Step 1 and produce a single flat numbered list `S1..Sm`. Each entry has:

- The literal scenario name as written in the `.feature` file (text after `Scenario:` or `Scenario Outline:`). Do not paraphrase, shorten, or normalize casing.
- `File:` tag with the file's relative path.
- `Tags:` tag listing any `@validation`, `@authorization`, or other Gherkin tags on the scenario.

Steps 2 and 3 may run in parallel, but both must complete and emit fully-numbered lists (`D1..Dn` and `S1..Sm`) before Step 4 begins. Do not start cross-checking until both lists are fixed.

### Step 4: Cross-Check (sequential)

Complete 4a in full (every `D` evaluated, GAP table finalized) before starting 4b. Do not interleave 4a and 4b findings.

#### 4a. Design -> Specs (completeness check)

For each design requirement `D1..Dn`, identify which spec scenario(s) cover it.

Flag as **GAP** any design requirement that has no corresponding spec scenario.

#### 4b. Specs -> Design (consistency check)

For each spec scenario `S1..Sm`, identify which design requirement it traces back to.

Flag as **EXTRA** any spec scenario that does not trace back to a design requirement.

For each EXTRA, classify as exactly one of:

- **Defensive** -- covers an obvious edge case implied by the design (e.g. auth required, validation on a field declared required in the design, 404 on missing entity).
- **Drift** -- adds behavior the design does not mention.

Mark each EXTRA as `Defensive` or `Drift` in the Extras table. Do not leave any EXTRA unclassified.

If more than 10 EXTRAs are found, stop classifying and present the count to the user via AskUserQuestion before continuing. Do not silently process a large extras set.

### Step 5: Report

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

### Step 6: Resolve

Branch on findings.

**Pass condition (zero GAPs AND zero Drift extras):** announce "Design and specs are aligned." Defensive EXTRAs do not block alignment. Proceed to Skill Exit.

**Any GAPs OR any Drift extras present:** use AskUserQuestion with the text `"Spec review found {N} gap(s) and {M} drift extra(s). How would you like to resolve?"` and the options below. Apply the matching action exactly:

- `Fix gaps and remove drift` -- re-invoke `pandahrms:spec-writing` via the Skill tool, passing the GAP table and the Drift EXTRA table as input. Do not edit `.feature` files directly from this skill.
- `Fix gaps only` -- re-invoke `pandahrms:spec-writing` via the Skill tool, passing the GAP table only.
- `Update design to match specs` -- STOP and instruct the user to revise the design doc. Do not edit the design doc from this skill.
- `Proceed anyway` -- record the unresolved findings in the conversation and proceed to Skill Exit.

A GAP is "resolved" when one of these states holds (recorded in the conversation only, not in any file):

- **COVERED** -- `pandahrms:spec-writing` was re-run and a scenario now exists.
- **ACCEPTED** -- the user explicitly chose `Proceed anyway`.

A Drift EXTRA is "resolved" when one of these states holds (recorded in the conversation only):

- **REMOVED** -- `pandahrms:spec-writing` was re-run and the drift scenario was removed.
- **ACCEPTED** -- the user explicitly chose `Proceed anyway`.

This skill never modifies the design doc, never creates a "deferred items" file, and never marks an item descoped on its own.

## Skill Exit

The skill is complete when one of the following has happened:

- (a) Step 6 announced "Design and specs are aligned."
- (b) Step 6 routed back to `pandahrms:spec-writing` and that re-invocation has been dispatched.
- (c) The user chose `Proceed anyway` in Step 6.
- (d) The user chose `Update design to match specs` in Step 6 (STOP after instructing the user).
- (e) An early exit per the Prerequisites or Skip Condition rules.

After exit, return control to the caller (forge-pipeline-orchestrator if invoked from forge-pipeline-orchestrator, otherwise the user). Do not invoke any other skill from within this skill.

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
- [ ] Reached Skill Exit per a documented branch
