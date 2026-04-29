---
name: plan
description: Triggers when an approved design and (optionally) Gherkin specs need to be turned into a bite-sized implementation plan in a Pandahrms project. Replaces superpowers:writing-plans. Each task carries exact file paths, complete code, a Red-before-Green TDD step pair, a spec scenario reference (when specs exist), a test file/case reference, and a dependency marker so atlas can parallel-dispatch. Drops superpowers' duplication mandate ("repeat the code in every task") and the inline-vs-subagent execution choice -- atlas always uses pandahrms:execute.
---

# Pandahrms Plan

## Overview

Write a comprehensive implementation plan that an enthusiastic junior engineer with no project context could execute end-to-end. Each task has exact file paths, complete code, and verification steps. Plans are bite-sized (2-5 min per step), Red-Green-Refactor by default, and frequent-commit. DRY, YAGNI, TDD.

**Announce at start:** "I'm using Pandahrms plan to turn the design into an implementation plan."

**Save plans to:** `docs/pandahrms/plans/YYYY-MM-DD-<feature-name>.md`
- User preferences for plan location override this default

**Context assumption:** This skill is invoked AFTER design (and usually spec-writing + QA review) has completed. The design doc lives at `docs/pandahrms/designs/<...>.md` and -- when business behavior is in scope -- spec scenarios live in `pandahrms-spec/features/<area>/*.feature`.

## Scope Check

If the spec or design covers multiple independent subsystems, it should have been broken down during design. If it wasn't, suggest splitting into separate plans -- one per subsystem. Each plan should produce working, testable software on its own.

## File Structure

Before defining tasks, map out which files will be created or modified and what each one is responsible for. This is where decomposition decisions get locked in.

- Design units with clear boundaries and well-defined interfaces. Each file should have one clear responsibility.
- You reason best about code you can hold in context at once, and your edits are more reliable when files are focused. Prefer smaller, focused files over large ones that do too much.
- Files that change together should live together. Split by responsibility, not by technical layer.
- In existing codebases, follow established patterns. If the codebase uses large files, don't unilaterally restructure -- but if a file you're modifying has grown unwieldy, including a split in the plan is reasonable.

This structure informs the task decomposition. Each task should produce self-contained changes that make sense independently.

## Bite-Sized Task Granularity

Each step is one action (2-5 minutes):
- "Write the failing test" -- step
- "Run it to make sure it fails" -- step
- "Implement the minimal code to make the test pass" -- step
- "Run the tests and make sure they pass" -- step
- "Commit" -- step

## Plan Document Header

Every plan MUST start with this header:

```markdown
# [Feature Name] Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use pandahrms:execute to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

**Design doc:** [path to docs/pandahrms/designs/<...>.md]

**Spec files:** [list of pandahrms-spec/features/<...>.feature paths, or "no specs (UI-only / skip-specs path)"]

---
```

## Task Structure

Each task carries four required references when business behavior is in scope:

- **Files** -- exact create/modify/test paths
- **Spec ref** -- the Gherkin scenario(s) the task implements (omit only when no specs exist)
- **Test ref** -- the test file and case names the task adds or modifies
- **Depends on** -- task IDs this one waits for, or `none` if independent (atlas uses this to parallel-dispatch)

````markdown
### Task N: [Component Name]

**Files:**
- Create: `exact/path/to/file.ts`
- Modify: `exact/path/to/existing.ts:123-145`
- Test: `tests/exact/path/to/file.test.ts`

**Spec ref:** `features/performance/goal-approval.feature:Scenario: approver revokes approval`

**Test ref:** `tests/services/goal-approval.test.ts::"approver revokes approval clears approved_at and notifies submitter"`

**Depends on:** none

- [ ] **Step 1: Write the failing test (Red)**

```ts
import { revokeApproval } from "../src/services/goal-approval";

test("approver revokes approval clears approved_at and notifies submitter", async () => {
  const goal = await seedGoal({ approvedAt: new Date("2026-01-01") });
  const result = await revokeApproval(goal.id, { approverId: "u1" });
  expect(result.approvedAt).toBeNull();
  expect(notifier.calls).toContainEqual({ to: goal.submitterId, kind: "approval-revoked" });
});
```

- [ ] **Step 2: Run test to verify it fails (Red confirmed)**

Run: `pnpm vitest run tests/services/goal-approval.test.ts`
Expected: FAIL with `revokeApproval is not defined`

- [ ] **Step 3: Write minimal implementation (Green)**

```ts
export async function revokeApproval(goalId: string, ctx: { approverId: string }) {
  const goal = await goalRepo.update(goalId, { approvedAt: null, revokedBy: ctx.approverId });
  await notifier.send({ to: goal.submitterId, kind: "approval-revoked" });
  return goal;
}
```

- [ ] **Step 4: Run test to verify it passes (Green confirmed)**

Run: `pnpm vitest run tests/services/goal-approval.test.ts`
Expected: PASS

- [ ] **Step 5: Refactor (if needed)**

If duplication appeared with `approveGoal`, extract a shared `mutateApprovalState(goalId, patch)` helper. Re-run the test after each refactor step. Skip this step if no refactor opportunity exists.

- [ ] **Step 6: Stage changes (do NOT commit -- atlas defers commits to /hermes-commit)**

Run: `git add tests/services/goal-approval.test.ts src/services/goal-approval.ts`
````

## Required References

Each task that touches production code or specs MUST carry:

1. **Spec ref** -- one or more Gherkin scenarios the task satisfies. Omit only when no specs exist for the area (UI-only or skip-specs path). If specs exist for the area but you cannot link a task to one, the plan is incomplete -- update the spec or rewrite the task.
2. **Test ref** -- the test file path and the new/changed test case name(s). Every production-code task names at least one test. Tasks that touch production code without a test reference are rejected. **TDD is universal in this workflow** -- there are no "mechanical" or "no-test-pattern" exemptions. EF mappings, migrations, read DTOs, generated types, and config changes all need a real test (typically an integration test against the consuming endpoint, or a structural assertion for migrations). If a task genuinely cannot be tested, that is a design problem -- escalate to the user, do not write a planless task.
3. **Red-before-Green ordering** -- the failing-test step always precedes the implementation step. No production code without a failing test.
4. **Depends on** -- explicit task IDs, or `none`. Independent tasks let atlas parallel-dispatch and cut wall-clock time.

## No Placeholders

Every step must contain the actual content an engineer needs. These are **plan failures** -- never write them:

- "TBD", "TODO", "implement later", "fill in details"
- "Add appropriate error handling" / "add validation" / "handle edge cases"
- "Write tests for the above" (without actual test code)
- Steps that describe what to do without showing how (code blocks required for code steps)
- References to types, functions, or methods not defined in any task

When two tasks share similar code, prefer one of these over verbatim duplication:

- **Reference an earlier task** when execution is sequential and the engineer reads top-to-bottom: `"Same shape as Task 3 Step 3, but with field 'archivedAt' instead of 'approvedAt'."`
- **Repeat the code** when the engineer (or subagent) may execute the task in isolation, when the differences are subtle, or when the file lives far from the referenced task.

Default to repeating the code when in doubt -- atlas dispatches independent tasks to fresh subagents that read the plan with no prior context.

## No Commits in Plan Steps

The plan MUST NOT include a `git commit` step in any task. Atlas defers commits to `/hermes-commit` after the user has tested. Each task ends with:

- **Stage changes** -- `git add <files>` only

Never write `git commit -m "..."` into a plan. The user runs `/hermes-commit` after testing, which plans and executes atomic commits across the full set of changes.

## Self-Review

After writing the complete plan, look at the design doc + spec files with fresh eyes and check the plan against them. This is a checklist you run inline -- not a subagent dispatch.

1. **Spec coverage** -- skim each in-scope spec scenario. Can you point to a task that implements it? List any gaps.
2. **Design coverage** -- skim each functional requirement in the design doc. Can you point to a task that delivers it? List any gaps.
3. **Test ref completeness** -- every production-code task names a test file and case. List any tasks missing this.
4. **Red-before-Green** -- every production-code task has a failing-test step before any implementation step. Flag any task that puts implementation first.
5. **Placeholder scan** -- search the plan for the red-flag patterns from "No Placeholders" above. Fix them.
6. **Type consistency** -- do the types, method signatures, and property names you used in later tasks match what you defined in earlier tasks? A function called `clearLayers()` in Task 3 but `clearFullLayers()` in Task 7 is a bug.
7. **Dependency markers** -- every task has a `Depends on:` line, even if it's `none`. Atlas reads these to parallel-dispatch.
8. **No commit steps** -- search for `git commit` in the plan. Remove any matches.

Fix issues inline. No need to re-review -- just fix and move on. If you find a spec requirement with no task, add the task.

## Hand Off

After the plan is saved and self-reviewed, announce:

> "Plan complete and saved to `<path>`. Atlas will run Plan ↔ Spec cross-review next, then dispatch tasks to pandahrms:execute."

Do NOT ask the user to choose between inline and subagent execution. Atlas always uses pandahrms:execute with parallel dispatch.

When invoked outside atlas (rare), announce:

> "Plan complete and saved to `<path>`. Run pandahrms:execute to implement, or hand the file to atlas via `/atlas <path>` for the full pipeline."

## Red Flags

| Thought | Reality |
|---------|---------|
| "I'll write 'add validation here' to keep tasks short" | No placeholders. Show the actual validation code. |
| "Tasks 4 and 6 are nearly identical, I'll just say 'similar to Task 4'" | Default to repeating the code. Reference earlier tasks only when execution is strictly sequential. |
| "I'll add a `git commit` at the end of each task" | Never. Atlas + /hermes-commit own the commit step. Plans only stage changes. |
| "This task touches production code but the test is 'obvious'" | Every production-code task names a test ref. No exceptions. TDD is universal in this workflow. |
| "This is just an EF mapping / migration / DTO projection / generated type -- no test pattern in this codebase" | Then write one. Pick the consuming endpoint's integration test (mappings, DTOs), a structural schema assertion (migrations), or a typecheck command turned into a test runner step (generated types). "We don't have a pattern" is not a license to skip TDD -- it's a signal that the pattern needs to exist. |
| "This task genuinely cannot be tested" | Stop and escalate to the user. Do not write a plan task without a Test ref. The user decides whether to (a) define a new test pattern, (b) restructure the task so it is testable, or (c) explicitly accept the gap with a written rationale. |
| "I'll skip the spec ref for this small task" | If specs exist for the area, every task has a spec ref. If no specs exist (UI-only / skip-specs), say so in the header. |
| "I'll let the engineer figure out task dependencies" | Mark dependencies explicitly. Atlas parallel-dispatches based on this -- missing markers serialize the run. |
| "I'll let writing-plans-style mandate decide whether to duplicate code" | Pandahrms plan picks pragmatically: reference earlier tasks when sequential, repeat code when parallel-dispatched. Default to repeating. |
| "I'll ask the user to choose inline vs subagent at the end" | No. Atlas always uses pandahrms:execute. Don't add the choice. |

## Remember

- Exact file paths always
- Complete code in every code step
- Spec ref and test ref on every production-code task
- Red-before-Green ordering, no exceptions
- `Depends on:` line on every task (even if `none`)
- Stage changes only -- never commit
- DRY, YAGNI, TDD, frequent commits (committed by /hermes-commit, not by the plan)

## When to Use

- After `pandahrms:design` and (optionally) `pandahrms:spec-writing` have completed
- Invoked by atlas in step 4, or directly when the user hands you a design + spec set

## When NOT to Use

- Before design is approved (use `pandahrms:design` first)
- For trivial single-file fixes that don't need a full plan (do the fix directly with TDD)
- Non-Pandahrms projects (use `superpowers:writing-plans` directly)
