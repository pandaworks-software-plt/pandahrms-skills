---
name: spec-writing
description: Use when starting any work in a Pandahrms project - writing or updating Gherkin specs is a required first step before implementation for all changes including features, bug fixes, and refactors
---

# Spec Writing

## Overview

Specs come first. Before implementing any change in any Pandahrms project -- feature, bug fix, or refactor -- Gherkin specifications must be written or updated in the `pandahrms-spec` repository. This is a hard gate: no implementation begins until specs are in place.

**Announce at start with exactly one of these strings:**
- "I'm using the spec-writing skill to write specs before implementation." -- use when no relevant specs exist for the affected feature area.
- "I'm using the spec-writing skill to update specs before implementation." -- use when existing specs will be modified.

Do NOT emit the literal string "write/update". Choose one variant based on the situation.

## Skip Condition: Non-Pandahrms Project

**This skill only writes specs to `pandahrms-spec` for Pandahrms-related projects.** Before proceeding, check if the current working directory is a Pandahrms project.

**How to detect a Pandahrms project:**
- The project directory name starts with `pandahrms-` or `Pandahrms_` or `PandaHRMS_` (case-insensitive prefix match)
- OR the project is inside a workspace that contains `pandahrms-spec/` as a sibling
- OR the project's CLAUDE.md contains the literal string "Pandahrms project", "Pandahrms monorepo", or "Pandahrms workspace", OR sets a frontmatter/header field naming Pandahrms as the product (e.g. `product: Pandahrms`). A casual mention of the word "Pandahrms" in passing does NOT qualify.

**If the project is NOT Pandahrms-related:**
- Do NOT read, write, search, list, or otherwise reference `pandahrms-spec/` at any point during this skill. Treat it as if it does not exist on the filesystem.
- Instead, write specs within the project's own repository.
- Look for an existing spec directory by checking these paths in order:
  1. `.project/specs/` (preferred convention)
  2. `docs/specs/`
  3. `specs/`
  4. `features/`
- If none exist, create `.project/specs/` and use that.
- All Gherkin writing guidelines in this skill still apply -- only the spec location changes.
- Announce: "This is not a Pandahrms project -- specs will be written in this project's own repository instead of pandahrms-spec."

## Skip Condition: UI-Only Changes

**If the work is purely about UI/presentation** -- styling, layout, component design, theming, responsiveness, animations, dark mode, or visual polish -- **skip this skill entirely.** These changes don't alter business behavior and don't need Gherkin specs.

Announce: "Skipping spec-writing -- this is a UI-only change with no business behavior impact."

When skipping for UI-only work:
- Do NOT search for `pandahrms-spec/` (or any other spec directory).
- Do NOT read any `.feature` file.
- Do NOT create or modify any `.feature` file.
- Do NOT ask the user spec-related questions.
- After emitting the announce-string, return control to the calling skill (pandahrms:forge-pipeline-orchestrator or pandahrms:atlas-pipeline-orchestrator). If invoked directly, return control to the user and stop. Do NOT auto-invoke pandahrms:spec-review or any downstream skill in the diagram below.

**Examples of UI-only work (skip):**
- Redesigning a page layout or component appearance
- Adjusting spacing, colors, typography, or responsiveness
- Adding dark mode support
- Building a new UI component that renders existing data and calls only existing endpoints (no new state transitions, validations, persisted fields, or API contracts)
- Fixing visual bugs (alignment, overflow, z-index)

**Examples that still need specs (don't skip):**
- Adding a new form that creates/updates data (even if it calls an existing endpoint, if the form introduces new validation or new persisted fields)
- Changing validation rules or error messages
- Adding filtering, sorting, or pagination behavior
- Changing workflow or status transitions
- Adding role-based visibility or permissions

## Skip Condition: No Behavior Change

**If the change has NO observable behavior change at any system boundary** (UI, API, DB, events, logs that callers depend on), **skip this skill entirely.** Examples:
- Pure rename of a private symbol
- Code formatting or whitespace cleanup
- Type-only annotation changes that do not alter runtime behavior
- Comment edits or documentation-only changes
- Internal refactors that preserve all observable outputs
- Dependency upgrades that do not change call sites

Announce: "Skipping spec-writing -- no observable behavior change."

Apply the same return-to-caller rules as the UI-only skip above (do not search, read, or write any `.feature` file; do not auto-invoke downstream skills).

<HARD-GATE>
Until the relevant specs have been written or updated AND approved by the user, do NOT:
- write or stage implementation code (in files OR as preview/example code blocks in chat)
- create, generate, or run any database migration
- modify ANY file outside `pandahrms-spec/` (or, for non-Pandahrms projects, outside the project's own spec directory determined by the Skip Condition rules above)
- dispatch subagents that will modify files
- run build, deploy, or test commands
- create branches, commits, or pull requests in any repository other than the spec repository
- scaffold directories, stub files, or placeholder modules in the implementation project

Reading existing project code IS allowed (and is expected during Step 1 to understand the change).

This applies to ALL changes: features, bug fixes, and refactors.
</HARD-GATE>

### Where This Fits

```
Any work request in any Pandahrms project
    |
    v
pandahrms:forge-pipeline-orchestrator (orchestrator: design through execution)
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
superpowers:executing-plans --> pandahrms:athena-code-review --> spec cross-check
    --> pandahrms:hermes-commit --> superpowers:finish-branch
```

**Note:** When invoked via `pandahrms:forge-pipeline-orchestrator`, brainstorming runs first and this skill runs after the design doc is approved. When invoked directly, this skill runs standalone.

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

**Branch alignment check.** Before reading any `.feature` file, run `git -C $(dirname $PWD)/pandahrms-spec rev-parse --abbrev-ref HEAD` and compare the result with the current implementation project's branch (`git rev-parse --abbrev-ref HEAD`). If they do not match, ask the user (via AskUserQuestion) whether to:
1. Checkout the matching branch in `pandahrms-spec`
2. Stay on the current `pandahrms-spec` branch and proceed
3. Abort

Do NOT auto-checkout, auto-fetch, or auto-pull `pandahrms-spec`.

## The Process

### Step 1: Understand the Change

Identify what the user is about to work on. This could come from:

- **A design/plan document** — read it and extract features, actors, and behaviors.
- **A bug report or issue** — understand the expected vs. actual behavior.
- **A verbal/informal request without a design doc** — ask focused clarifying questions one at a time using AskUserQuestion until you can answer all three of the items below. Stop asking once those three are resolved. Do NOT ask more than necessary; do NOT proceed without them.
- **A refactor** — understand what behavior must be preserved.

Determine:
1. **What module** it belongs to: `performance`, `hr`, `leave`, or `campaign`. If the answer is none of these, STOP and ask the user (via AskUserQuestion) which module folder under `pandahrms-spec/specs/` to use. Do NOT create a new top-level module folder under `specs/` without explicit user approval.
2. **What feature area** is affected.
3. **What behaviors** are being added, changed, or must be preserved.

Do NOT advance to Step 2 until all three items above are resolved.

### Step 2: Check for Existing Specs

Search `pandahrms-spec/specs/<module>/` (or, for non-Pandahrms projects, the project's own spec directory determined under "Skip Condition: Non-Pandahrms Project") for existing `.feature` files related to the affected feature area.

- **Specs exist and FULLY cover the change with no behavior modification** — announce: "Existing specs already cover this change. No updates required." Skip Step 3 and Step 4. Go directly to Step 5 and present the existing relevant `.feature` files verbatim for the user to confirm coverage. If the user confirms, exit the skill without committing (Step 6 is skipped). If the user reports a gap, return to Step 3.
- **Specs exist and cover the change but the change modifies expected behavior** — proceed through Step 3, then update those scenarios in Step 4. Do NOT skip Step 3.
- **Specs exist but don't cover this feature area** — proceed through Step 3, then write additional scenarios for the new/changed behavior in Step 4.
- **No specs exist** — proceed through Step 3, then write specs from scratch in Step 4.

### Step 3: Study Existing Conventions

Before writing any spec, read existing feature files to match the style. Required selection rule:

1. Read the most recently modified `.feature` file in `pandahrms-spec/specs/<module>/` for the target module (use `git -C <pandahrms-spec> log -1 --format=%H -- specs/<module>` or filesystem mtime to identify it).
2. If `pandahrms-spec/specs/<module>/<feature-name>/` already exists, also read one `.feature` file from that directory.
3. If no `.feature` file exists in the target module, read one `.feature` file from any other module under `specs/` to capture cross-module conventions. State which file you used as the style reference in your next message.

Use the conventions you observe (tags, section headers, role names, scenario phrasing, Background structure) verbatim in the new spec. Do NOT invent alternative conventions.

Key conventions to observe and follow:

- **Spec root:** `<workspace>/pandahrms-spec/specs/`
- **Directory structure:** `specs/<module>/<feature-name>/<feature-file>.feature`
- **File naming:** `<entity>-<functional-area>.feature` (singular entity names, no date prefix)
- **Split by concern:** Separate files for template management vs. lifecycle vs. responses
- **File length:** Each `.feature` file MUST NOT exceed 200 lines. If a draft would exceed 200 lines, split into multiple files using the rules under "File Splitting Strategy" before writing them to disk.

### Step 4: Write the Gherkin

#### Mandatory Sub-Step Order

Within Step 4, execute these sub-steps in this exact order. Do NOT parallelize, reorder, or jump back to a prior sub-step once advanced:

1. Decide the file split using the "File Splitting Strategy" section below.
2. For each file, write the Feature Header (with feature-level tags, the `As a / I want / So that` block, and the `Background` if needed).
3. Write Section Headers (comment banners) in the required CRUD order: creation, listing, editing, deletion, special features.
4. Within each section, write scenarios in CRUD order.
5. Apply scenario-level tags as each scenario is written -- not afterward.
6. Validate naming conventions, role consistency, and BDD compliance on the completed file.

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

Section order MUST be exactly: creation, listing, editing, deletion, then special features. Do not reorder.

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
- Each `.feature` file MUST NOT exceed 200 lines.
- Target 3 to 4 files per feature. Do NOT produce a single file longer than 200 lines. Do NOT produce more than 6 files for a single feature.
- Each file should be independently understandable.
- Group by: functional area, actor/role, or lifecycle phase.

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

1. Present the complete spec (new or updated) to the user for review.
2. Highlight any assumptions made or gaps in understanding.
3. Wait for explicit approval from the user before advancing.
4. If the user requests changes, return to Step 4 and apply ONLY the requested changes -- do not rewrite unaffected scenarios, do not add new scenarios that were not requested, do not refactor unrelated specs. Re-present and wait for approval again. Loop this revise-and-re-present cycle until the user explicitly approves.
5. Do NOT commit, write to disk in the spec repository, or proceed to Step 6 without explicit approval.
6. **Only after approval:** proceed to Step 6 (commit). Step 5 ends at approval; "implementation planning/coding" is handled by downstream skills, not this one.

### Step 6: Commit

After approval:

**Pre-commit safety check (both project types).** Before staging, run `git -C <spec-repo-path> status --porcelain`. If the working tree contains files unrelated to this skill's output, list them to the user via AskUserQuestion and ask whether to:
1. Proceed (stage only this skill's `.feature` files; leave the others untouched)
2. Stash the unrelated changes first
3. Abort and let the user clean up

Do NOT auto-stash and do NOT include unrelated files in the commit.

**For Pandahrms projects:**
1. Write files to the correct location in `pandahrms-spec/specs/<module>/<feature-name>/`.
2. Stage only the `.feature` files this skill produced.
3. Commit to the `pandahrms-spec` repository.
4. Use commit message format:
   - New specs: `feat(module): add spec for feature-name`
   - Updated specs: `feat(module): update spec for feature-name`
   - Bug fix specs: `fix(module): add spec covering bug-name`

**For non-Pandahrms projects:**
1. Write files to the project's own spec directory (e.g., `.project/specs/`, `docs/specs/`, `specs/`, or `features/`) as resolved by the Skip Condition rules.
2. Stage only the `.feature` files this skill produced.
3. Commit within the current project repository.
4. Use the same commit message format as above.

**Forbidden in Step 6:**
- Do NOT push, force-push, or fetch.
- Do NOT create or switch branches.
- Do NOT open pull requests.
- Do NOT amend prior commits.
- Do NOT run any git command beyond `status`, `add` (of the specific `.feature` files), `commit`, and (where used for the pre-commit safety check) `diff`.

### Exit

After Step 6 commit completes (or after an approved no-update exit per Step 2), STOP.

- The only files this skill writes are `.feature` files in the spec repository (`pandahrms-spec` for Pandahrms projects, or the project-local fallback for non-Pandahrms projects). It does NOT write code, tests, migrations, scaffolding, configuration, or documentation files anywhere else.
- Do NOT auto-invoke `pandahrms:spec-review`, `pandahrms:plan-writing`, `pandahrms:execute-plan`, `pandahrms:athena-code-review`, `pandahrms:hermes-commit`, or any other downstream skill in the diagram above.
- Return control to the calling skill (`pandahrms:forge-pipeline-orchestrator` or `pandahrms:atlas-pipeline-orchestrator`) if invoked from a pipeline. If invoked directly, return control to the user and stop. The skill's responsibility ends at the spec commit (or at confirmed no-update exit).

## Pre-Exit Checklist

Before exiting the skill, verify each item below is complete. If any item is unchecked, return to the relevant step and resolve it. Do NOT exit with unchecked items.

- [ ] Understood the change (feature, bug fix, or refactor)
- [ ] Checked the spec repository for existing specs in the affected area (pandahrms-spec for Pandahrms projects; project-local spec dir otherwise)
- [ ] Identified correct module and feature name (or, if module is not in the standard list, obtained explicit user approval for the chosen module folder)
- [ ] Studied existing `.feature` files per the Step 3 selection rule
- [ ] Feature header has tags, description (As a/I want/So that), and Background
- [ ] Scenarios grouped with comment headers
- [ ] Section order is creation, listing, editing, deletion, special features (no reordering)
- [ ] Tags applied at feature and scenario level
- [ ] Validation scenarios included with `@validation` tag
- [ ] BDD compliant: no UI language, behavior-focused, business outcomes in Then steps
- [ ] No hard-coded validation message strings or input-coercion behaviors
- [ ] Data tables used for structured input
- [ ] Each `.feature` file is at most 200 lines, with at most 6 files per feature
- [ ] Consistent role names used (HR administrator, employee, reviewer, manager)
- [ ] Presented to user for review and explicitly approved
- [ ] Pre-commit safety check ran on the spec repository working tree
- [ ] Committed to the spec repository after approval (no push, no PR, no branch creation)
