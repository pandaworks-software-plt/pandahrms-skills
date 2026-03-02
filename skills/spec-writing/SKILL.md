---
name: spec-writing
description: Use when starting any work in a Pandahrms project - writing or updating Gherkin specs is a required first step before implementation for all changes including features, bug fixes, and refactors
---

# Spec Writing

## Overview

Specs come first. Before implementing any change in any Pandahrms project -- feature, bug fix, or refactor -- Gherkin specifications must be written or updated in the `pandahrms-spec` repository. This is a hard gate: no implementation begins until specs are in place.

**Announce at start:** "I'm using the spec-writing skill to write/update specs before implementation."

<HARD-GATE>
Do NOT write any implementation code, create any migration, or modify any project files until the relevant specs have been written or updated and approved by the user. This applies to ALL changes: features, bug fixes, and refactors.
</HARD-GATE>

### Where This Fits

```
Any work request in any Pandahrms project
    |
    v
pandahrms:spec-writing (THIS SKILL - hard gate)
    |
    v
superpowers:writing-plans --> superpowers:executing-plans (TDD)
    --> superpowers:code-review --> superpowers:finish-branch
```

## Prerequisite: Verify pandahrms-spec Project

**All specs MUST be written into the `pandahrms-spec` repository.** Before doing anything else, verify the project exists on the user's machine.

Check for the directory at: `<workspace>/pandahrms-spec/` (where `<workspace>` is the pandahrms monorepo workspace, typically `_pandahrms-workspace/`).

**If not found, STOP and tell the user:**

> The `pandahrms-spec` project was not found in your workspace. Please clone it first:
>
> ```bash
> cd <workspace-directory>
> git clone https://github.com/pandaworks-software-plt/pandahrms-spec.git
> ```
>
> Then re-run this skill.

Do NOT proceed with spec writing until the project directory is confirmed to exist.

## The Process

### Step 1: Understand the Change

Identify what the user is about to work on. This could come from:

- **A design/plan document** — read it and extract features, actors, and behaviors
- **A bug report or issue** — understand the expected vs. actual behavior
- **A verbal request** — ask clarifying questions to understand the scope
- **A refactor** — understand what behavior must be preserved

Determine:
1. **What module** it belongs to: `performance`, `hr`, `leave`, `campaign`, or other
2. **What feature area** is affected
3. **What behaviors** are being added, changed, or must be preserved

### Step 2: Check for Existing Specs

Search `pandahrms-spec/specs/` for existing specs related to the affected feature area.

- **Specs exist and cover the change** — review them, update if the change modifies expected behavior. Move to Step 4.
- **Specs exist but don't cover this area** — write additional scenarios for the new/changed behavior
- **No specs exist** — write them from scratch

### Step 3: Study Existing Conventions

Before writing any spec, read at least one existing feature file from `pandahrms-spec/` to match the style. Key conventions:

- **Spec root:** `/Users/kyson/Developer/pandaworks/_pandahrms-workspace/pandahrms-spec/specs/`
- **Directory structure:** `specs/<module>/<feature-name>/<feature-file>.feature`
- **File naming:** `<entity>-<functional-area>.feature` (singular entity names)
- **Split by concern:** Separate files for template management vs. lifecycle vs. responses
- **Target:** Keep files under 200 lines where possible

### Step 4: Write the Gherkin

#### Feature Header

Every feature file starts with:

```gherkin
@module-tag @feature-tag
Feature: Clear Feature Name
  As a [role]
  I want to [action]
  So that [benefit]

  Background:
    Given [common preconditions]
```

#### Section Headers

Group scenarios logically with comment headers:

```gherkin
# =============================================================================
# Section Name
# =============================================================================
```

Order sections logically: creation -> listing -> editing -> deletion -> special features.

#### Tags

Apply tags at both feature and scenario level:

| Tag | Usage |
|-----|-------|
| `@create` | Creation scenarios |
| `@list` | Listing and filtering |
| `@update`, `@edit` | Modification scenarios |
| `@delete` | Deletion and archival |
| `@validation` | Error and validation cases |
| `@filter`, `@search` | Filtering and search |
| `@submit`, `@status` | Workflow and status transitions |
| `@authorization` | Permission checks |
| `@bulk`, `@batch` | Bulk operations |
| `@bugfix` | Scenarios added to cover a bug fix |
| `@refactor` | Scenarios documenting preserved behavior during refactor |

#### Scenario Structure

```gherkin
@tag
Scenario: Clear, specific description
  Given [initial context]
  When [action taken]
  Then [expected outcome]
  And [additional outcomes]
```

- Write from the user's perspective (first person: "I create", "I update")
- Use "When I try to..." for invalid actions in validation scenarios
- Include specific error messages: `Then I should receive an error "Template code already exists"`
- Use data tables for structured input
- Use triple quotes for multi-line text

#### Validation Scenarios

YOU MUST include validation scenarios for every feature. Tag them with `@validation`:

```gherkin
@create @validation
Scenario: Cannot create with duplicate code
  Given a template with code "existing-code" already exists
  When I try to create another template with code "existing-code"
  Then I should receive an error "Code already exists"
```

#### Bug Fix Scenarios

When fixing a bug, write a scenario that captures the correct behavior:

```gherkin
@bugfix
Scenario: Salary calculation includes overtime for part-time employees
  Given a part-time employee with 10 hours of overtime this month
  When I calculate their monthly salary
  Then the overtime hours should be included in the calculation
```

#### Refactor Scenarios

When refactoring, write scenarios that document the behavior being preserved:

```gherkin
@refactor
Scenario: Employee list still returns paginated results after repository refactor
  Given there are 50 employees in the system
  When I request page 1 with page size 10
  Then I should receive 10 employees
  And the total count should be 50
```

### Step 5: Review

1. Present the complete spec (new or updated) to the user for review
2. Highlight any assumptions made or gaps in understanding
3. Wait for approval before committing
4. **Only after approval:** proceed to implementation planning/coding

### Step 6: Commit

After approval:
1. Write files to the correct location in `pandahrms-spec/`
2. Commit to the `pandahrms-spec` repository
3. Use commit message format:
   - New specs: `feat(module): add spec for feature-name`
   - Updated specs: `feat(module): update spec for feature-name`
   - Bug fix specs: `fix(module): add spec covering bug-name`

## Checklist

- [ ] Understood the change (feature, bug fix, or refactor)
- [ ] Checked pandahrms-spec for existing specs in the affected area
- [ ] Identified correct module and feature name
- [ ] Studied at least one existing .feature file for style
- [ ] Feature header has tags, description (As a/I want/So that), and Background
- [ ] Scenarios grouped with comment headers
- [ ] Tags applied at feature and scenario level
- [ ] Validation scenarios included with `@validation` tag
- [ ] Data tables used for structured input
- [ ] Files split by concern (under 200 lines each)
- [ ] Presented to user for review and approved
- [ ] Committed to pandahrms-spec after approval
