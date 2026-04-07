---
name: spec-review
description: Use after spec-writing to cross-check the design doc against feature spec files - ensures specs fully cover all requirements from the design and nothing is missed or misaligned
---

# Spec Review

## Overview

Cross-checks the approved design document against the written Gherkin spec files to ensure full alignment. Every requirement, behavior, rule, and edge case in the design must have corresponding spec coverage, and no spec should introduce behavior not described in the design.

**Announce at start:** "I'm using the spec-review skill to cross-check the design doc against the feature specs."

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

This skill runs after specs are written and approved, before proceeding to implementation planning. It can also be invoked independently whenever you need to verify design/spec alignment.

## Skip Condition: No Specs Written

If specs were skipped in the pipeline (user chose "Skip specs" in the development-workflow), or no `.feature` files exist for the current feature area in `pandahrms-spec/`, **skip this skill entirely**.

Announce: "Skipping spec-review -- no specs were written for this feature." Then proceed to the next step in the pipeline.

## Prerequisites

Before running this skill, you need:

1. **A design document** -- typically at `<project>/docs/plans/*-design.md`
2. **Written spec files** -- in `pandahrms-spec/specs/<module>/<feature>/`

If the design doc is missing, STOP and tell the user. If spec files are missing, skip (see skip condition above).

## The Process

### Step 1: Locate Artifacts

1. **Find the design doc** -- look in the current project's `docs/plans/` directory for the most recent `*-design.md` file relevant to the current work. If multiple exist, ask the user which one to use.
2. **Find the spec files** -- resolve the spec repo as a sibling directory: `$(dirname $PWD)/pandahrms-spec/`. Locate the feature files related to the design (same module/feature area).

### Step 2: Extract Design Requirements

Read the design document and extract a structured list of:

- **Features/capabilities** described
- **Business rules** and constraints
- **Validation rules** and error conditions
- **Edge cases** explicitly mentioned
- **Actor/role behaviors** (who can do what)
- **Status transitions** or workflow steps
- **Data requirements** (fields, formats, relationships)

Number each extracted requirement for reference (e.g., D1, D2, D3...).

### Step 3: Extract Spec Coverage

Read all related `.feature` files and extract:

- **Scenarios** and what behavior each covers
- **Validation scenarios** (`@validation` tagged)
- **Authorization scenarios** (`@authorization` tagged)
- **Edge case scenarios**

Number each extracted scenario for reference (e.g., S1, S2, S3...).

### Step 4: Cross-Check

Perform a two-way comparison:

#### 4a: Design -> Specs (completeness check)

For each design requirement (D1, D2, ...), identify which spec scenario(s) cover it.

Flag as **GAP** any design requirement that has no corresponding spec scenario. These are the most critical findings -- behavior described in the design that won't be verified.

#### 4b: Specs -> Design (consistency check)

For each spec scenario (S1, S2, ...), identify which design requirement it traces back to.

Flag as **EXTRA** any spec scenario that doesn't trace back to a design requirement. These may be valid additions (defensive specs, obvious edge cases) or may indicate spec drift.

### Step 5: Report

Present findings in this format:

```
## Spec Review: [Feature Name]

### Coverage Summary
- Design requirements: [count]
- Spec scenarios: [count]
- Fully covered: [count]
- Gaps (design not in specs): [count]
- Extras (specs not in design): [count]

### Gaps (design requirements missing from specs)
| # | Design Requirement | Section in Design |
|---|---|---|
| GAP-1 | [description] | [section reference] |
| GAP-2 | [description] | [section reference] |

### Extras (spec scenarios not in design)
| # | Spec Scenario | File |
|---|---|---|
| EXTRA-1 | [scenario name] | [file.feature] |

### Full Traceability Matrix
| Design Req | Description | Spec Scenario(s) | Status |
|---|---|---|---|
| D1 | [description] | S1, S5 | Covered |
| D2 | [description] | -- | GAP |
| D3 | [description] | S3 | Covered |
```

### Step 6: Resolve

Based on findings:

- **No gaps, no unexpected extras** -- announce "Design and specs are aligned." and pass the gate.
- **Gaps or extras found** -- present the report, then ask the user using AskUserQuestion: "Spec review found gaps between the design and specs. Would you like to fix them?" with options: "Yes, fix gaps" and "No, proceed anyway". If yes, loop back to spec-writing to fill the gaps. If no, proceed to the next pipeline step.

## Checklist

- [ ] Located design document and spec files
- [ ] Extracted all requirements from design doc (numbered D1, D2, ...)
- [ ] Extracted all scenarios from spec files (numbered S1, S2, ...)
- [ ] Performed design -> specs completeness check
- [ ] Performed specs -> design consistency check
- [ ] Presented coverage report with traceability matrix
- [ ] All gaps resolved (covered, descoped, or deferred)
- [ ] All extras resolved (kept or removed)
- [ ] Design and specs confirmed aligned
