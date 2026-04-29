---
name: spec-writing
description: Use when starting any work in a Pandahrms project - writing or updating Gherkin specs is a required first step before implementation for all changes including features, bug fixes, and refactors
---

# Spec Writing

## Overview

Specs come first. Before implementing any change in any Pandahrms project -- feature, bug fix, or refactor -- Gherkin specifications must be written or updated in the `pandahrms-spec` repository. This is a hard gate: no implementation begins until specs are in place.

**Announce at start:** "I'm using the spec-writing skill to write/update specs before implementation."

## Skip Condition: Non-Pandahrms Project

**This skill only writes specs to `pandahrms-spec` for Pandahrms-related projects.** Before proceeding, check if the current working directory is a Pandahrms project.

**How to detect a Pandahrms project:**
- The project directory name starts with `pandahrms-` or `Pandahrms_` or `PandaHRMS_` (case-insensitive prefix match)
- OR the project is inside a workspace that contains `pandahrms-spec/` as a sibling
- OR the project has a CLAUDE.md that references Pandahrms

**If the project is NOT Pandahrms-related:**
- Do NOT look for or write to `pandahrms-spec/`
- Instead, write specs within the project's own repository
- Look for an existing spec directory by checking these paths in order:
  1. `.project/specs/` (preferred convention)
  2. `docs/specs/`
  3. `specs/`
  4. `features/`
- If none exist, create `.project/specs/` and use that
- All Gherkin writing guidelines in this skill still apply -- only the spec location changes
- Announce: "This is not a Pandahrms project -- specs will be written in this project's own repository instead of pandahrms-spec."

## Skip Condition: UI-Only Changes

**If the work is purely about UI/presentation** -- styling, layout, component design, theming, responsiveness, animations, dark mode, or visual polish -- **skip this skill entirely.** These changes don't alter business behavior and don't need Gherkin specs.

Announce: "Skipping spec-writing -- this is a UI-only change with no business behavior impact." Then proceed directly to the next step in the workflow.

**Examples of UI-only work (skip):**
- Redesigning a page layout or component appearance
- Adjusting spacing, colors, typography, or responsiveness
- Adding dark mode support
- Building a new UI component with no new business logic
- Fixing visual bugs (alignment, overflow, z-index)

**Examples that still need specs (don't skip):**
- Adding a new form that creates/updates data
- Changing validation rules or error messages
- Adding filtering, sorting, or pagination behavior
- Changing workflow or status transitions
- Adding role-based visibility or permissions

<HARD-GATE>
Do NOT write any implementation code, create any migration, or modify any project files until the relevant specs have been written or updated and approved by the user. This applies to ALL changes: features, bug fixes, and refactors.
</HARD-GATE>

### Where This Fits

```
Any work request in any Pandahrms project
    |
    v
pandahrms:forge (orchestrator: design through execution)
    |
    v
superpowers:brainstorming (design doc)
    |
    v
pandahrms:spec-writing (THIS SKILL - hard gate)
    |
    v
pandahrms:spec-review (cross-check design vs specs)
    |
    v
superpowers:writing-plans (implementation plan)
    |
    v
superpowers:executing-plans --> pandahrms:athena-review --> spec cross-check
    --> pandahrms:hermes-commit --> superpowers:finish-branch
```

**Note:** When invoked via `pandahrms:forge`, brainstorming runs first and this skill runs after the design doc is approved. When invoked directly, this skill runs standalone.

## Prerequisite: Verify pandahrms-spec Project (Pandahrms Projects Only)

**This section only applies to Pandahrms projects** (see "Skip Condition: Non-Pandahrms Project" above). For non-Pandahrms projects, skip this section and write specs within the project's own repository.

**All Pandahrms specs MUST be written into the `pandahrms-spec` repository.** Before doing anything else, verify the project exists on the user's machine.

The spec repo is always a **sibling directory** to the current project. Go up one level from the current working directory to find the workspace, then look for `pandahrms-spec/` there:

```
<workspace>/              # parent of current project
├── pandahrms-web/        # current project (example)
├── pandahrms-app/
└── pandahrms-spec/       # <-- always here, same level
```

Resolve the path as: `$(dirname $PWD)/pandahrms-spec/`

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

- **Spec root:** `<workspace>/pandahrms-spec/specs/`
- **Directory structure:** `specs/<module>/<feature-name>/<feature-file>.feature`
- **File naming:** `<entity>-<functional-area>.feature` (singular entity names, no date prefix)
- **Split by concern:** Separate files for template management vs. lifecycle vs. responses
- **Target:** Keep files under 200 lines where possible

### Step 4: Write the Gherkin

#### BDD Principles (Mandatory)

Every scenario MUST describe **user behavior and business outcomes**, NOT UI implementation details. Scenarios must be **implementation-agnostic** -- the same spec should be valid whether the feature is built for web, mobile, or API.

**Prohibited (UI-focused language) -- NEVER use these:**
- UI controls: "click button", "tap", "select from dropdown", "fill in textbox", "pick from date picker", "toggle switch"
- UI feedback: "see a toast notification", "modal appears", "spinner shows", "page redirects to"
- UI layout: "in the sidebar", "on the top right", "in the header", "below the table"
- CSS/styling: "highlighted in red", "greyed out", "bold text"

**Required (Behavior-focused language) -- use these instead:**

| Instead of (UI) | Write (Behavior) |
|---|---|
| "I click the Apply Leave button" | "I apply for leave" |
| "I select Annual Leave from the dropdown" | "I choose leave type Annual Leave" |
| "I pick 2026-03-10 in the date picker" | "from 2026-03-10 to 2026-03-12" |
| "I click Submit" | (omit -- implied by the action) |
| "I see a green toast Success" | "the application should be submitted successfully" |
| "a modal appears asking for confirmation" | "I am asked to confirm the action" |
| "the row is highlighted in red" | "the leave request should be flagged as conflicting" |
| "I see a spinner" | (omit -- implementation detail) |
| "the page redirects to dashboard" | "I should see my leave summary" |

**`Then` steps must assert business outcomes**, not visual feedback:
- Balance changes, status transitions, notifications sent, records created
- Permission checks, rule enforcement, data consistency
- NOT: toasts, modals, colors, redirects, spinners

#### Don't Hard-Code Validation Messages or Input Behavior

A specific class of UI leak that's easy to miss: scenarios that name a literal validation message string ("must be between 1 and 24 months") or commit to a specific input behavior (auto-clamp vs reject). Both bake in implementation choices that a later UI redesign or input-component swap will invalidate -- forcing spec rewrites mid-pipeline.

**Prohibited:**

| Bad (hard-coded) | Why it leaks |
|-----------------|--------------|
| `Then I see "Months must be between 1 and 24"` | Couples the spec to one error-message string. Localization or copy revision breaks the spec. |
| `Then the system shows "Invalid input"` | Same issue -- couples to UI copy. |
| `When I enter 25 then the input becomes 24` | Commits to auto-clamping behavior. If the input swaps to one that throws an error instead, the scenario is unsatisfiable. |
| `When I enter 0.5 then the value is rounded to 1` | Same -- commits to auto-rounding. |

**Required (behavior-focused):**

| Good (implementation-agnostic) | Why it survives changes |
|--------------------------------|-------------------------|
| `Then the request is rejected as out of range` | Asserts the business outcome, not the message. |
| `Then 25 is not accepted as a valid value` | Says nothing about how rejection surfaces (clamp, error, disabled submit). |
| `Then 0.5 is not accepted as a valid value` | Same -- the outcome (not accepted) holds regardless of the input control's coercion strategy. |

If a particular error message IS the business behavior (e.g., a specific compliance-required disclosure that legal mandates), call it out in the design and write the scenario with the literal string PLUS a comment naming the requirement. Otherwise: outcome only.

**Bad -- UI-focused:**
```gherkin
Scenario: Apply for leave
  When I click the "Apply Leave" button
  And I select "Annual Leave" from the dropdown
  And I click "Submit"
  Then I should see a green toast notification "Leave applied successfully"
```

**Good -- Behavior-focused:**
```gherkin
Scenario: Employee applies for annual leave
  When I apply for annual leave from "2026-03-10" to "2026-03-12"
  Then my leave application should be submitted successfully
  And my remaining annual leave balance should be reduced by 3 days
```

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

Always apply tags at **both** feature and scenario level.

**Feature-level tags** (on the Feature line):
- Module/feature identifier: `@performance`, `@recruitment`, `@hr`, `@leave`, `@campaign`
- Sub-feature identifier: `@template`, `@response`, `@review-lifecycle`, `@pip`

**Scenario-level tags:**

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
| `@hierarchy` | Hierarchical relationships |
| `@employee`, `@reviewer`, `@manager` | Role-specific scenarios |
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

#### Common Patterns

**Status Transitions:**
```gherkin
@status
Scenario: Status transition description
  Given [entity] with status "[current_status]"
  When [action]
  Then the status should change to "[new_status]"
  And [side effects]
```

**Permissions:**
```gherkin
@validation @authorization
Scenario: Cannot perform action without permission
  Given [context]
  When I try to [restricted action]
  Then I should receive an error "[permission error]"
```

**CRUD Operations** -- group in this order:
1. Creation (`@create`)
2. Listing/Retrieval (`@list`)
3. Editing (`@edit`)
4. Deletion/Archival (`@delete`)

#### File Splitting Strategy

Split features by **functional concerns/bounded contexts**, not by CRUD operations.

**When to split into separate files:**
- Different actors/user journeys (admin setup vs. end-user interaction)
- Different lifecycle phases (configuration vs. execution)
- Different concerns (template management vs. instance management vs. data entry)
- File approaching 200 lines

**When to keep in same file:**
- CRUD operations on the same entity (unless file gets too large)
- Variations of the same user flow
- Related validation scenarios

**Guidelines:**
- Keep files under 200 lines
- Prefer 3-4 files per feature over 1 large file or 10+ small files
- Each file should be independently understandable
- Group by: functional area, actor/role, or lifecycle phase

**Naming convention:**
- Format: `[entity]-[functional-area].feature`
- Singular entity names: `adhoc-review` not `adhoc-reviews`
- Functional area describes the concern: `template`, `response`, `lifecycle`
- Examples: `adhoc-review-template.feature`, `pip-tracking.feature`

#### Naming Conventions

- Feature names: clear capability description (e.g., "Ad-hoc Review Template Management")
- Scenario names: describe expected behavior (e.g., "HR creates a base ad-hoc review template")
- Consistent role names: "HR administrator", "Head of Department", "employee", "reviewer", "manager"

### Step 5: Review

1. Present the complete spec (new or updated) to the user for review
2. Highlight any assumptions made or gaps in understanding
3. Wait for approval before committing
4. **Only after approval:** proceed to implementation planning/coding

### Step 6: Commit

After approval:

**For Pandahrms projects:**
1. Write files to the correct location in `pandahrms-spec/`
2. Commit to the `pandahrms-spec` repository
3. Use commit message format:
   - New specs: `feat(module): add spec for feature-name`
   - Updated specs: `feat(module): update spec for feature-name`
   - Bug fix specs: `fix(module): add spec covering bug-name`

**For non-Pandahrms projects:**
1. Write files to the project's own spec directory (e.g., `specs/` or `features/`)
2. Commit within the current project repository
3. Use the same commit message format as above

## Checklist

- [ ] Understood the change (feature, bug fix, or refactor)
- [ ] Checked pandahrms-spec for existing specs in the affected area
- [ ] Identified correct module and feature name
- [ ] Studied at least one existing .feature file for style
- [ ] Feature header has tags, description (As a/I want/So that), and Background
- [ ] Scenarios grouped with comment headers
- [ ] Tags applied at feature and scenario level
- [ ] Validation scenarios included with `@validation` tag
- [ ] BDD compliant: no UI language, behavior-focused, business outcomes in Then steps
- [ ] Data tables used for structured input
- [ ] Files split by concern (under 200 lines each)
- [ ] Consistent role names used (HR administrator, employee, reviewer, manager)
- [ ] Presented to user for review and approved
- [ ] Committed to pandahrms-spec after approval
