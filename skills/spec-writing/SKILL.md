---
name: spec-writing
description: Use when starting any work in a Pandahrms project - writing or updating Gherkin specs is a required first step before implementation for all changes including features, bug fixes, and refactors
---

# Spec Writing

## Overview

Specs come first. Before implementing any change in any Pandahrms project -- feature, bug fix, or refactor -- Gherkin specs must be written or updated in `pandahrms-spec`. Hard gate: no implementation begins until specs are in place.

**Announce at start with exactly one of these strings:**
- "I'm using the spec-writing skill to write specs before implementation." -- use when no relevant specs exist for the affected feature area.
- "I'm using the spec-writing skill to update specs before implementation." -- use when existing specs will be modified.

Do NOT emit literal "write/update". Pick one variant.

## Skip Condition: Non-Pandahrms Project

**This skill only writes specs to `pandahrms-spec` for Pandahrms-related projects.** Check if the current working directory is a Pandahrms project.

**How to detect a Pandahrms project:**
- Project directory name starts with `pandahrms-` or `Pandahrms_` or `PandaHRMS_` (case-insensitive prefix match)
- OR project is inside a workspace containing `pandahrms-spec/` as a sibling
- OR project's CLAUDE.md contains literal "Pandahrms project", "Pandahrms monorepo", or "Pandahrms workspace", OR sets a frontmatter/header field naming Pandahrms as the product (e.g. `product: Pandahrms`). Casual mention of "Pandahrms" in passing does NOT qualify.

**If the project is NOT Pandahrms-related:**
- Do NOT read, write, search, list, or otherwise reference `pandahrms-spec/` at any point during this skill. Treat as if it does not exist on the filesystem.
- Write specs within the project's own repository.
- Look for an existing spec directory by checking these paths in order:
  1. `.project/specs/` (preferred convention)
  2. `docs/specs/`
  3. `specs/`
  4. `features/`
- If none exist, create `.project/specs/` and use that.
- All Gherkin writing guidelines still apply -- only spec location changes.
- Announce: "This is not a Pandahrms project -- specs will be written in this project's own repository instead of pandahrms-spec."

## Skip Condition: UI-Only Changes

**If work is purely UI/presentation** -- styling, layout, component design, theming, responsiveness, animations, dark mode, or visual polish -- **skip this skill entirely.** These don't alter business behavior and don't need Gherkin specs.

Announce: "Skipping spec-writing -- this is a UI-only change with no business behavior impact."

When skipping for UI-only work:
- Do NOT search for `pandahrms-spec/` (or any other spec directory).
- Do NOT read any `.feature` file.
- Do NOT create or modify any `.feature` file.
- Do NOT ask the user spec-related questions.
- After emitting the announce-string, return control to caller.

**Examples of UI-only work (skip):**
- Redesigning page layout or component appearance
- Adjusting spacing, colors, typography, or responsiveness
- Adding dark mode support
- Building new UI component that renders existing data and calls only existing endpoints (no new state transitions, validations, persisted fields, or API contracts)
- Fixing visual bugs (alignment, overflow, z-index)

**Examples that still need specs (don't skip):**
- New form creating/updating data (even if calls existing endpoint, if form introduces new validation or new persisted fields)
- Changing validation rules or error messages
- Adding filtering, sorting, or pagination behavior
- Changing workflow or status transitions
- Adding role-based visibility or permissions

## Skip Condition: No Behavior Change

**If the change has NO observable behavior change at any system boundary** (UI, API, DB, events, logs callers depend on), **skip this skill entirely.** Examples:
- Pure rename of a private symbol
- Code formatting or whitespace cleanup
- Type-only annotation changes that do not alter runtime behavior
- Comment edits or documentation-only changes
- Internal refactors preserving all observable outputs
- Dependency upgrades that do not change call sites

Announce: "Skipping spec-writing -- no observable behavior change."

Apply same return-to-caller rules as UI-only skip above (do not search, read, or write any `.feature` file).

<HARD-GATE>
Until relevant specs have been written or updated AND approved by user, do NOT:
- write or stage implementation code (in files OR as preview/example code blocks in chat)
- create, generate, or run any database migration
- modify ANY file outside `pandahrms-spec/` (or, for non-Pandahrms projects, outside the project's own spec directory determined by Skip Condition rules above)
- dispatch subagents that will modify files
- run build, deploy, or test commands
- create branches, commits, or pull requests in any repository other than the spec repository
- scaffold directories, stub files, or placeholder modules in the implementation project

Reading existing project code IS allowed (expected during Step 1 to understand the change).

Applies to ALL changes: features, bug fixes, refactors.
</HARD-GATE>

## Prerequisite: Verify pandahrms-spec Project (Pandahrms Projects Only)

**This section only applies to Pandahrms projects** (see "Skip Condition: Non-Pandahrms Project" above). For non-Pandahrms projects, skip this section and write specs within the project's own repository.

**All Pandahrms specs MUST be written into `pandahrms-spec`.** Before doing anything else, verify the project exists on the user's machine.

The spec repo is always a **sibling directory** to the current project. Go up one level from the current working directory to find the workspace, then look for `pandahrms-spec/` there:

```
<workspace>/              # parent of current project
├── pandahrms-web/        # current project (example)
├── pandahrms-app/
└── pandahrms-spec/       # <-- always here, same level
```

Resolve the path as: `$(dirname $PWD)/pandahrms-spec/`

**If not found, STOP and tell user:**

> The `pandahrms-spec` project was not found in your workspace. Please clone it first:
>
> ```bash
> cd <workspace-directory>
> git clone https://github.com/pandaworks-software-plt/pandahrms-spec.git
> ```
>
> Then re-run this skill.

Do NOT proceed with spec writing until project directory is confirmed to exist.

**Branch alignment check.** Before reading any `.feature` file, run `git -C $(dirname $PWD)/pandahrms-spec rev-parse --abbrev-ref HEAD` and compare with current implementation project's branch (`git rev-parse --abbrev-ref HEAD`). If they do not match, ask user (via AskUserQuestion) whether to:
1. Checkout matching branch in `pandahrms-spec`
2. Stay on current `pandahrms-spec` branch and proceed
3. Abort

Do NOT auto-checkout, auto-fetch, or auto-pull `pandahrms-spec`.

## The Process

### Step 1: Understand the Change

Identify what user is about to work on. Source can be:

- **Design/plan document** — read it and extract features, actors, behaviors.
- **Bug report or issue** — understand expected vs. actual behavior.
- **Verbal/informal request without a design doc** — ask focused clarifying questions one at a time via AskUserQuestion until you can answer all three items below. Stop once those three are resolved. Do NOT ask more than necessary; do NOT proceed without them.
- **Refactor** — understand what behavior must be preserved.

Determine:
1. **Module** it belongs to: `performance`, `hr`, `leave`, or `campaign`. If none, STOP and ask user (via AskUserQuestion) which module folder under `pandahrms-spec/specs/` to use. Do NOT create a new top-level module folder under `specs/` without explicit user approval.
2. **Feature area** affected.
3. **Behaviors** being added, changed, or preserved.

Do NOT advance to Step 2 until all three resolved.

### Step 2: Check for Existing Specs

Search `pandahrms-spec/specs/<module>/` (or, for non-Pandahrms projects, the project's own spec directory determined under "Skip Condition: Non-Pandahrms Project") for existing `.feature` files related to the affected feature area.

- **Specs exist and FULLY cover the change with no behavior modification** — announce: "Existing specs already cover this change. No updates required." Skip Step 3 and Step 4. Go to Step 5 and present existing relevant `.feature` files verbatim for user to confirm coverage. If user confirms, exit skill without committing (Step 6 skipped). If user reports a gap, return to Step 3.
- **Specs exist and cover the change but change modifies expected behavior** — proceed through Step 3, then update those scenarios in Step 4. Do NOT skip Step 3.
- **Specs exist but don't cover this feature area** — proceed through Step 3, then write additional scenarios for new/changed behavior in Step 4.
- **No specs exist** — proceed through Step 3, then write specs from scratch in Step 4.

### Step 3: Study Existing Conventions

Before writing any spec, read existing feature files to match style. Required selection rule:

1. Read the most recently modified `.feature` file in `pandahrms-spec/specs/<module>/` for target module (use `git -C <pandahrms-spec> log -1 --format=%H -- specs/<module>` or filesystem mtime).
2. If `pandahrms-spec/specs/<module>/<feature-name>/` already exists, also read one `.feature` file from that directory.
3. If no `.feature` file exists in target module, read one `.feature` file from any other module under `specs/` to capture cross-module conventions. State which file you used as style reference in your next message.

Use observed conventions (tags, section headers, role names, scenario phrasing, Background structure) verbatim in the new spec. Do NOT invent alternative conventions.

Key conventions to observe and follow:

- **Spec root:** `<workspace>/pandahrms-spec/specs/`
- **Directory structure:** `specs/<module>/<feature-name>/<feature-file>.feature`
- **File naming:** `<entity>-<functional-area>.feature` (singular entity names, no date prefix)
- **Split by concern:** Separate files for template management vs. lifecycle vs. responses
- **File length:** Each `.feature` file MUST NOT exceed 200 lines. If a draft would exceed 200 lines, split into multiple files using rules under "File Splitting Strategy" before writing to disk.

### Step 4: Write the Gherkin

#### Mandatory Sub-Step Order

Within Step 4, execute sub-steps in this exact order. Do NOT parallelize, reorder, or jump back to a prior sub-step once advanced:

1. Decide file split using "File Splitting Strategy" section below.
2. For each file, write Feature Header (with feature-level tags, `As a / I want / So that` block, and `Background` if needed).
3. Write Section Headers (comment banners) in required CRUD order: creation, listing, editing, deletion, special features.
4. Within each section, write scenarios in CRUD order.
5. Apply scenario-level tags as each scenario is written -- not afterward.
6. Validate naming conventions, role consistency, and BDD compliance on completed file.

#### BDD Principles (Mandatory)

Every scenario MUST describe **user behavior and business outcomes**, NOT UI implementation details. Scenarios must be **implementation-agnostic** -- same spec should be valid whether feature is built for web, mobile, or API.

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

A UI leak easy to miss: scenarios naming a literal validation message string ("must be between 1 and 24 months") or committing to a specific input behavior (auto-clamp vs reject). Both bake in implementation choices that a later UI redesign or input-component swap will invalidate.

**Prohibited:**

| Bad (hard-coded) | Why it leaks |
|-----------------|--------------|
| `Then I see "Months must be between 1 and 24"` | Couples spec to one error-message string. Localization or copy revision breaks spec. |
| `Then the system shows "Invalid input"` | Same -- couples to UI copy. |
| `When I enter 25 then the input becomes 24` | Commits to auto-clamping. If input swaps to one that throws an error, scenario is unsatisfiable. |
| `When I enter 0.5 then the value is rounded to 1` | Same -- commits to auto-rounding. |

**Required (behavior-focused):**

| Good (implementation-agnostic) | Why it survives changes |
|--------------------------------|-------------------------|
| `Then the request is rejected as out of range` | Asserts business outcome, not message. |
| `Then 25 is not accepted as a valid value` | Says nothing about how rejection surfaces (clamp, error, disabled submit). |
| `Then 0.5 is not accepted as a valid value` | Same -- outcome (not accepted) holds regardless of input control's coercion strategy. |

If a particular error message IS the business behavior (e.g., a compliance-required disclosure legal mandates), call it out in design and write scenario with the literal string PLUS a comment naming the requirement. Otherwise: outcome only.

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

- Write from user's perspective (first person: "I create", "I update")
- Use "When I try to..." for invalid actions in validation scenarios
- Include specific error messages: `Then I should receive an error "Template code already exists"`
- Use data tables for structured input
- Use triple quotes for multi-line text

#### Validation Scenarios

YOU MUST include validation scenarios for every feature. Tag with `@validation`:

```gherkin
@create @validation
Scenario: Cannot create with duplicate code
  Given a template with code "existing-code" already exists
  When I try to create another template with code "existing-code"
  Then I should receive an error "Code already exists"
```

#### Bug Fix Scenarios

When fixing a bug, write a scenario capturing the correct behavior:

```gherkin
@bugfix
Scenario: Salary calculation includes overtime for part-time employees
  Given a part-time employee with 10 hours of overtime this month
  When I calculate their monthly salary
  Then the overtime hours should be included in the calculation
```

#### Refactor Scenarios

When refactoring, write scenarios documenting behavior being preserved:

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
- Target 3 to 4 files per feature. Do NOT produce a single file longer than 200 lines. Do NOT produce more than 6 files per feature.
- Each file should be independently understandable.
- Group by: functional area, actor/role, or lifecycle phase.

**Naming convention:**
- Format: `[entity]-[functional-area].feature`
- Singular entity names: `adhoc-review` not `adhoc-reviews`
- Functional area describes concern: `template`, `response`, `lifecycle`
- Examples: `adhoc-review-template.feature`, `pip-tracking.feature`

#### Naming Conventions

- Feature names: clear capability description (e.g., "Ad-hoc Review Template Management")
- Scenario names: describe expected behavior (e.g., "HR creates a base ad-hoc review template")
- Consistent role names: "HR administrator", "Head of Department", "employee", "reviewer", "manager"

### Step 5: Review

1. Present complete spec (new or updated) to user for review.
2. Highlight any assumptions made or gaps in understanding.
3. Wait for explicit approval from user before advancing.
4. If user requests changes, return to Step 4 and apply ONLY requested changes -- do not rewrite unaffected scenarios, do not add new scenarios that were not requested, do not refactor unrelated specs. Re-present and wait for approval again. Loop this revise-and-re-present cycle until user explicitly approves.
5. Do NOT commit, write to disk in spec repository, or proceed to Step 6 without explicit approval.
6. **Only after approval:** proceed to Step 6 (commit). Step 5 ends at approval; "implementation planning/coding" is handled by downstream skills, not this one.

### Step 6: Commit

After approval:

**Always commit spec files only.** Stage ONLY the `.feature` files this skill produced. Never `git add .`, never `git add -A`, never stage any non-`.feature` path. Any other modified or untracked files in working tree (skill's repo or spec repo) are left exactly as is -- not staged, not stashed, not touched. Do NOT prompt user about unrelated files; do NOT list them; leave them alone.

**For Pandahrms projects:**
1. Write files to correct location in `pandahrms-spec/specs/<module>/<feature-name>/`.
2. Stage only `.feature` files this skill produced.
3. Commit to `pandahrms-spec` repository.
4. Commit message format:
   - New specs: `feat(module): add spec for feature-name`
   - Updated specs: `feat(module): update spec for feature-name`
   - Bug fix specs: `fix(module): add spec covering bug-name`

**For non-Pandahrms projects:**
1. Write files to project's own spec directory (e.g., `.project/specs/`, `docs/specs/`, `specs/`, or `features/`) as resolved by Skip Condition rules.
2. Stage only `.feature` files this skill produced.
3. Commit within current project repository.
4. Use same commit message format as above.

**Forbidden in Step 6:**
- Do NOT push, force-push, or fetch.
- Do NOT create or switch branches.
- Do NOT open pull requests.
- Do NOT amend prior commits.
- Do NOT run any git command beyond `status`, `add` (of specific `.feature` files), and `commit`.

### Exit

After Step 6 commit completes (or after an approved no-update exit per Step 2), STOP.

- Only files this skill writes are `.feature` files in spec repository (`pandahrms-spec` for Pandahrms projects, or project-local fallback for non-Pandahrms projects). It does NOT write code, tests, migrations, scaffolding, configuration, or documentation files anywhere else.
- Return control to caller. Skill's responsibility ends at spec commit (or at confirmed no-update exit).

## Pre-Exit Checklist

Before exiting skill, verify each item below is complete. If any item is unchecked, return to relevant step and resolve it. Do NOT exit with unchecked items.

- [ ] Understood the change (feature, bug fix, or refactor)
- [ ] Checked spec repository for existing specs in affected area (pandahrms-spec for Pandahrms projects; project-local spec dir otherwise)
- [ ] Identified correct module and feature name (or, if module is not in standard list, obtained explicit user approval for chosen module folder)
- [ ] Studied existing `.feature` files per Step 3 selection rule
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
- [ ] Only `.feature` files this skill produced were staged (no other paths)
- [ ] Committed to spec repository after approval (no push, no PR, no branch creation)
