---
name: spec-writing
description: Use when a design or plan document is ready and needs to be converted into Gherkin feature specifications for the pandahrms-spec repository, or when writing new feature specs, updating existing specs, or reviewing spec coverage
---

# Spec Writing

## Overview

Convert design documents and plans into structured Gherkin feature specifications in the `pandahrms-spec` repository. This skill sits between planning and implementation in the development pipeline.

**Announce at start:** "I'm using the spec-writing skill to create Gherkin specifications."

```
superpowers:brainstorming --> superpowers:writing-plans --> pandahrms-skills:spec-writing
    --> superpowers:executing-plans (TDD) --> superpowers:code-review
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

### Step 1: Read the Source

1. Read the design/plan document that was produced by brainstorming or planning
2. Identify the module it belongs to: `performance`, `hr`, `leave`, `campaign`, or other
3. Identify all features, actors, and behaviors described

### Step 2: Study Existing Conventions

Before writing any spec, read at least one existing feature file from `pandahrms-spec/` to match the style. Key conventions:

- **Spec root:** `/Users/kyson/Developer/pandaworks/_pandahrms-workspace/pandahrms-spec/specs/`
- **Directory structure:** `specs/<module>/<feature-name>/<feature-file>.feature`
- **File naming:** `<entity>-<functional-area>.feature` (singular entity names)
- **Split by concern:** Separate files for template management vs. lifecycle vs. responses
- **Target:** Keep files under 200 lines where possible

### Step 3: Write the Gherkin

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

### Step 4: Review

1. Present the complete spec to the user for review
2. Highlight any assumptions made or gaps in the source document
3. Wait for approval before committing

### Step 5: Commit

After approval:
1. Write files to the correct location in `pandahrms-spec/`
2. Commit to the `pandahrms-spec` repository
3. Use commit message format: `feat(module): add spec for feature-name`

## Checklist

- [ ] Read source design/plan document
- [ ] Identified correct module and feature name
- [ ] Studied at least one existing .feature file for style
- [ ] Feature header has tags, description (As a/I want/So that), and Background
- [ ] Scenarios grouped with comment headers
- [ ] Tags applied at feature and scenario level
- [ ] Validation scenarios included with `@validation` tag
- [ ] Data tables used for structured input
- [ ] Files split by concern (under 200 lines each)
- [ ] Presented to user for review
- [ ] Committed to pandahrms-spec after approval
