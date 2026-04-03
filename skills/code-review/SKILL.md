---
name: code-review
description: Use when reviewing working tree changes against code standards - reads all changed files, reviews against checklist, fixes issues, and optionally runs /simplify. Does NOT commit. Run this before /commit.
---

# Code Review

## Overview

Review all git working tree changes against code quality standards, fix issues found, and optionally run /simplify. This skill changes code but never commits. Run /commit separately after testing.

## When to Use

- After finishing a chunk of implementation work, before testing and committing
- On explicit invocation to review current changes
- As the first step in the "review -> test -> commit" cycle

## Workflow

```dot
digraph code_review {
    "Changes ready to review" [shape=doublecircle];
    "Gather changes" [shape=box];
    "git diff and git status" [shape=plaintext];
    "Any changes?" [shape=diamond];
    "No changes to review" [shape=doublecircle];
    "Read all changed files" [shape=box];
    "Run linter" [shape=box];
    "Review against standards" [shape=box];
    "Issues found?" [shape=diamond];
    "Minor issues?" [shape=diamond];
    "Auto-fix minor issues" [shape=box];
    "Report major issues to user" [shape=box];
    "User approves fixes?" [shape=diamond];
    "Apply major fixes" [shape=box];
    "UI-only changes?" [shape=diamond, style=filled, fillcolor=lightblue];
    "Check spec discrepancy" [shape=box, style=filled, fillcolor=lightblue];
    "Spec covers changes?" [shape=diamond, style=filled, fillcolor=lightblue];
    "Ask: create/update spec?" [shape=diamond, style=filled, fillcolor=lightblue];
    "Run /spec-writing" [shape=box, style=filled, fillcolor=lightblue];
    "Ask: run /simplify?" [shape=diamond, style=filled, fillcolor=lightyellow];
    "Run /simplify" [shape=box, style=filled, fillcolor=lightyellow];
    "Show simplify changes" [shape=box];
    "Done - remind user to test" [shape=doublecircle];

    "Changes ready to review" -> "Gather changes";
    "Gather changes" -> "git diff and git status";
    "git diff and git status" -> "Any changes?";
    "Any changes?" -> "No changes to review" [label="no"];
    "Any changes?" -> "Read all changed files" [label="yes"];
    "Read all changed files" -> "Run linter";
    "Run linter" -> "Review against standards";
    "Review against standards" -> "Issues found?";
    "Issues found?" -> "UI-only changes?" [label="no"];
    "Issues found?" -> "Minor issues?" [label="yes"];
    "Minor issues?" -> "Auto-fix minor issues" [label="yes"];
    "Minor issues?" -> "Report major issues to user" [label="no, major"];
    "Auto-fix minor issues" -> "Report major issues to user";
    "Report major issues to user" -> "User approves fixes?";
    "User approves fixes?" -> "Apply major fixes" [label="yes"];
    "User approves fixes?" -> "UI-only changes?" [label="skip"];
    "Apply major fixes" -> "UI-only changes?";
    "UI-only changes?" -> "Ask: run /simplify?" [label="yes, skip spec check"];
    "UI-only changes?" -> "Check spec discrepancy" [label="no"];
    "Check spec discrepancy" -> "Spec covers changes?";
    "Spec covers changes?" -> "Ask: run /simplify?" [label="yes"];
    "Spec covers changes?" -> "Ask: create/update spec?" [label="no or missing"];
    "Ask: create/update spec?" -> "Run /spec-writing" [label="yes"];
    "Ask: create/update spec?" -> "Ask: run /simplify?" [label="skip"];
    "Run /spec-writing" -> "Ask: run /simplify?";
    "Ask: run /simplify?" -> "Run /simplify" [label="yes"];
    "Ask: run /simplify?" -> "Done - remind user to test" [label="skip"];
    "Run /simplify" -> "Show simplify changes";
    "Show simplify changes" -> "Done - remind user to test";
}
```

## Phase 1: Gather Changes

Run in parallel:
- `git status` - see all modified, added, untracked files
- `git diff` - see unstaged changes
- `git diff --cached` - see staged changes

Read the full content of every changed file. You need full context to review properly.

### Run Linter (if available)

Detect the project's linter by checking for config files or `package.json` scripts:
- `biome.json` / `biome.jsonc` -> `pnpm biome check` or `npx biome check`
- `.eslintrc.*` / `eslint.config.*` -> `pnpm lint` or `npx eslint`
- `dotnet format` for .NET projects (check if `dotnet-format` tool is available)
- Any `lint` script in `package.json` -> `pnpm lint` or `yarn lint`

Run the linter on changed files only if possible. Include lint errors in the Phase 2 review findings.

## Phase 2: Review

Apply these checks to every changed file. Include any lint/format violations from Phase 1 in the findings.

### Review Checklist

**Architecture and Design:**

| Check | What to Look For |
|-------|-----------------|
| **God class / giant class** | Classes doing too much (100+ lines of logic, multiple unrelated methods). Split into focused classes. |
| **Single Responsibility** | Each class/function has one reason to change. Handlers should only orchestrate, not contain business logic. |
| **Open/Closed** | New behavior via extension, not modification. Check for long switch/if-else chains that should be polymorphic. |
| **Liskov Substitution** | Subtypes behave correctly when substituted for base types. No surprising overrides. |
| **Interface Segregation** | Interfaces are small and focused. No "fat" interfaces forcing unused method implementations. |
| **Dependency Inversion** | Dependencies injected via constructor, not instantiated with `new`. No service locator anti-pattern. |
| **DI registration** | *Only if project uses DI.* New interfaces/services are registered in DI container (e.g., `ServiceCollectionExtensions`, `Program.cs`, or relevant module registration). New repositories, services, and handlers must be wired up. |

**Security:**

| Check | What to Look For |
|-------|-----------------|
| **Injection** | SQL injection (raw string queries), command injection, XSS in responses. Use parameterized queries. |
| **Authentication/Authorization** | Endpoints have proper `[Authorize]` attributes. Role/policy checks enforced. No endpoints accidentally left open. |
| **Secrets** | No hardcoded API keys, connection strings, passwords, or tokens in code. Check for `.env` files staged. |
| **Input validation** | User inputs validated and sanitized. Request DTOs have proper validation attributes/rules. |
| **Data exposure** | Responses don't leak sensitive fields (passwords, internal IDs, PII). DTOs properly restrict what's returned. |

**Auditing and Observability:**

*Applies to backend projects (API, MVC5, monorepo with backend). If the project is frontend-only, skip this section.*

| Check | What to Look For |
|-------|-----------------|
| **Audit fields** | Entities that need tracking have `CreatedBy`, `CreatedAt`, `ModifiedBy`, `ModifiedAt` fields populated. |
| **Audit trail on all API endpoints** | Every state-changing API endpoint (POST, PUT, PATCH, DELETE) must have audit trail logging -- who did what, when, and on which resource. Check that new or modified endpoints follow the project's existing audit pattern (e.g., base entity audit, middleware audit, or explicit audit log calls). Endpoints without audit trail are a **major** issue. |
| **Audit trail consistency** | Verify the audit mechanism matches the project's existing pattern. Check for: base entity auto-population, audit middleware, or explicit audit service calls. New endpoints must use the same approach as existing ones. |
| **Logging** | Important operations have appropriate log levels. Errors are logged with context. No sensitive data in logs. |

**Code Quality:**

| Check | What to Look For |
|-------|-----------------|
| **Reuse before creating** | Before new code is added, check if an existing function, class, component, helper, or utility already does the same thing. Search the codebase for similar patterns. Flag duplicated logic that should reuse what already exists. |
| **Test coverage** | New/changed functionality has corresponding tests. Edge cases and error paths covered. |
| **Error handling** | Specific exceptions caught, meaningful messages, no swallowed errors. Consistent error response format. |
| **Readability** | Self-documenting code. No unnecessary complexity or over-engineering. Clear naming. |
| **Dead code** | No commented-out code, unused variables, unreachable branches, or leftover debugging code. |
| **Async correctness** | `async`/`await` used properly. No `async void` (except event handlers). No blocking on async (`.Result`, `.Wait()`). |

### Categorize Issues

- **Minor** (auto-fix): lint/format violations, naming inconsistencies, missing access modifiers, trivial formatting, simple null checks, obvious missing `readonly`, dead code removal, missing `async` keyword
- **Major** (ask first): SOLID violations, god classes, duplicated logic that should reuse existing code, missing DI registration, missing audit fields, missing audit trail on API endpoints, security vulnerabilities, missing test coverage, architectural concerns, missing authorization attributes

## Phase 3: Fix

1. **Auto-fix minor issues** silently - apply fixes, then list what was changed in a summary
2. **Report major issues** clearly - for each, explain: what the issue is, why it matters, proposed fix
3. **Ask user** whether to fix major issues or skip them
4. Apply approved fixes

## Phase 4: Spec Discrepancy Check

**Skip this phase entirely if the changes are UI-only** (styling, layout, theming, responsiveness, dark mode, visual polish with no business logic changes).

### Step 1: Locate pandahrms-spec

The spec repo is a **sibling directory** to the current project. Resolve the path as: `$(dirname $PWD)/pandahrms-spec/`

If the spec repo is not found, report it to the user and move on to Phase 5. Do not block the review.

### Step 2: Identify affected specs

From the git changes gathered in Phase 1, determine:
1. **What module** the changes belong to (performance, recruitment, hr, leave, campaign, etc.)
2. **What feature area** is affected (e.g., template management, review lifecycle, leave application)
3. **What business behaviors** were added, changed, or removed

Search `pandahrms-spec/specs/` for existing spec files that cover the affected feature area. Use Glob and Grep to find relevant `.feature` files by module directory and keyword matching.

### Step 3: Compare changes against specs

For each behavioral change in the git diff, check whether the spec covers it:

- **New endpoint/action added** -- is there a scenario for this behavior?
- **Validation rule changed** -- does a `@validation` scenario reflect the new rule?
- **Status transition modified** -- does a `@status` scenario match the new flow?
- **Permission/authorization changed** -- does an `@authorization` scenario cover it?
- **Bug fix** -- is there a `@bugfix` scenario capturing the correct behavior?

Categorize the findings:
- **Covered** -- spec exists and matches the implementation
- **Outdated** -- spec exists but describes old behavior that no longer matches
- **Missing** -- no spec covers the new/changed behavior

### Step 4: Report and ask

If all changes are covered, report: "Specs are in sync with changes." and move to Phase 5.

If there are **outdated or missing specs**, report the discrepancies clearly:

> **Spec discrepancy found:**
> - [Missing/Outdated]: [description of the behavior not covered or out of date]
> - ...

Then use `AskUserQuestion` to ask:

> "Specs are out of sync with your changes. Would you like to create/update specs now? (This will invoke /spec-writing)"

- If user says **yes** -> invoke the `/spec-writing` skill, then continue to Phase 5
- If user says **skip** -> move to Phase 5

## Phase 5: Simplify (interactive)

### Step 1: Ask before running

Use `AskUserQuestion` to ask the user whether they want to run `/simplify`:

> "Ready to run /simplify to check for reuse opportunities, code quality, and efficiency improvements. Run it?"

- If user says **yes** -> proceed to Step 2
- If user says **skip** -> go to Phase 6

### Step 2: Run /simplify

Invoke the `/simplify` skill. This launches three parallel review agents (Code Reuse, Code Quality, Efficiency) against the current changes. Apply any valid findings.

### Step 3: Show changes

After `/simplify` completes and fixes are applied, show the user a summary of what changed.

## Phase 6: Done

Summarize all changes made during the review:
- Minor issues auto-fixed
- Major issues fixed (if any)
- Spec discrepancy status (in sync, updated, or skipped)
- /simplify changes (if run)

End with this message:

> "Code review complete. Please test your changes, then run /commit when ready."

## Red Flags - STOP

- Running `/simplify` without asking the user first - always use AskUserQuestion
- Running `/spec-writing` without asking the user first - always use AskUserQuestion
- About to commit - this skill NEVER commits. That's /commit's job.
- Skipping review because "changes are small" - review everything
- Reviewing only the diff, not the full file - always read full files
- Running spec check on UI-only changes - skip Phase 4 for styling/layout/theming work

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Reviewing only the diff, not the full file | Always read full file for context |
| Fixing issues without telling the user | Always summarize what was auto-fixed |
| Committing after review | Never commit. Remind user to test then /commit |
| Blocking review when spec repo is missing | Report it and move on -- do not block the review |
| Running spec check on UI-only changes | Skip Phase 4 for styling, layout, theming, dark mode |
