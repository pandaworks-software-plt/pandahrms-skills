---
name: plan-writing
description: Triggers when an approved design and (optionally) Gherkin specs need to be turned into a bite-sized implementation plan in a Pandahrms project. Replaces superpowers:writing-plans. Each task carries exact file paths, complete code, a Red-before-Green TDD step pair, a spec scenario reference (when specs exist), a test file/case reference, and a dependency marker so atlas can parallel-dispatch. Drops superpowers' duplication mandate ("repeat the code in every task") and the inline-vs-subagent execution choice -- atlas always uses pandahrms:execute-plan.
---

# Pandahrms Plan

## Overview

Write a comprehensive implementation plan that an enthusiastic junior engineer with no project context could execute end-to-end. Each task has exact file paths, complete code, and verification steps. Plans are bite-sized (2-5 min per step), Red-Green-Refactor by default, and frequent-commit. DRY, YAGNI, TDD.

**Announce at start:** "I'm using Pandahrms plan to turn the design into an implementation plan."

**Save plans to:** `docs/pandahrms/plans/YYYY-MM-DD-<feature-name>.md` using today's date. Use a different path ONLY when the project's `CLAUDE.md` declares a different `plans/` location, in which case use that. Do not infer paths from any other source.

## Execution Order

Run these steps strictly in order. Do not parallelize, reorder, or skip any step.

1. Verify Prerequisites (next section). If any check fails, follow that section's remedy and stop.
2. Run the Scope Check.
3. Emit the Plan Document Header (see "Plan Document Header" section).
4. Emit the File Structure block (see "File Structure" section). You MUST emit this block before writing any `### Task N:` heading.
5. Emit every `### Task N:` block with required references and Red-Green steps. Insert Manual Gates between tasks per the placement rule in "Manual Gates".
6. Run the 8-item Self-Review checklist top to bottom; fix issues inline per its sequencing rule.
7. Save the plan to its path with the Write tool. Do NOT print the plan inline to the user. Do NOT skip the Write call.
8. Print the Hand Off announcement and end the turn. Do NOT begin implementing any task. Do NOT modify any source files. Do NOT run any tests.

## Prerequisites

Verify ALL of the following before emitting any plan content. If any check fails, STOP and follow the listed remedy.

1. **Design doc exists.** A design doc MUST live at `docs/pandahrms/designs/<feature-name>.md`. If it does not, output `No design doc found at docs/pandahrms/designs/. Run pandahrms:design-refinement first.` and stop.
2. **Design doc is approved.** Approval is signaled by either (a) the orchestrator (forge or atlas) routing this skill the design after its approval gate, or (b) a `Status: approved` line in the design doc's frontmatter or top section. If neither signal is present, output `Cannot confirm design approval. Confirm explicitly before continuing.` and wait for an explicit user reply before continuing.
3. **Design doc is complete.** The design doc MUST contain a Goal section, a Functional Requirements list, and a Tech Stack section. If any are missing, output `Design doc is incomplete. Missing sections: [list].` and stop. Do not invent content for missing sections.
4. **Specs exist OR skip-specs path is declared.** If business behavior is in scope, spec files MUST exist under `pandahrms-spec/features/<area>/`. If neither is true, output `No specs found and skip-specs path not declared. Run pandahrms:spec-writing first or confirm UI-only / skip-specs path explicitly.` and stop.
5. **Scope Profile is set.** The orchestrator sets `lightweight | standard | heavyweight` after design approval. If absent, default to `standard` and announce: `Scope Profile not set; defaulting to standard.`

## Scope Check

If the design covers multiple independent subsystems, STOP. Do not write any tasks. Output: `Design covers N subsystems: [list]. Cannot proceed -- ask the design author to split into separate plans, or reply confirming a single combined plan.` Wait for an explicit user reply before continuing. Each plan must produce working, testable software on its own.

## File Structure

Before defining tasks, map out which files will be created or modified and what each one is responsible for. This is where decomposition decisions get locked in.

- Design units with clear boundaries and well-defined interfaces. Each file should have one clear responsibility.
- You reason best about code you can hold in context at once, and your edits are more reliable when files are focused. Prefer smaller, focused files over large ones that do too much.
- Files that change together should live together. Split by responsibility, not by technical layer.
- In existing codebases, follow established patterns. If the codebase uses large files, don't unilaterally restructure. If a file you would modify exceeds 400 lines AND your changes touch a distinct responsibility from the rest of the file, add a `Split-File` task that extracts the new responsibility into its own file. Otherwise, do not propose a split.

This structure informs the task decomposition. Each task should produce self-contained changes that make sense independently.

## Bite-Sized Task Granularity

Each step is one action (2-5 minutes):
- "Write the failing test" -- step
- "Run it to make sure it fails" -- step
- "Implement the minimal code to make the test pass" -- step
- "Run the tests and make sure they pass" -- step
- "Stage changes (`git add ...`)" -- step. Do NOT include `git commit` -- see "No Commits in Plan Steps".

## Task Decomposition Heuristics

The orchestrator (atlas/forge) sets a Scope Profile after design approval. Use it to right-size the plan:

| Scope Profile | Target task count | Decomposition rule |
|---------------|-------------------|---------------------|
| `lightweight` | 5-7 tasks | Collapse strictly-sequential wiring tasks into a single task. See [Collapse Rule](#collapse-rule) below. |
| `standard` | 8-15 tasks | Default decomposition -- one task per logical concern. |
| `heavyweight` | 15+ tasks | Decompose aggressively to keep parallel-dispatch wide. |

If no Scope Profile is set (rare), default to `standard`.

### Collapse Rule

When the work is small enough that decomposition produces fake granularity, collapse strictly-sequential tasks that:

- Are causally chained (each must complete before the next starts), AND
- Touch the same logical concern (e.g. "persist X" = entity property + EF mapping + migration), AND
- Cannot run in parallel even with a `Depends on:` graph

...into a single task with all the steps inside it. The combined task still gets ONE `Spec ref:`, ONE `Test ref:` (or `Verification:` slot), and a single Red-Green-Refactor cycle covering the whole concern.

**Example -- collapse:**
- Task A: Add `PromotionProbation` property to `Appraisal` entity
- Task B: Add EF `OwnsOne` mapping for `PromotionProbation`
- Task C: Generate and apply migration `Add_PromotionProbation`

These are strictly sequential, all "persist promotion probation" -- collapse into:
- Task: **Persist promotion probation on Appraisal** -- entity property + EF mapping + migration as numbered sub-steps inside one task.

**Example -- do NOT collapse:**
- Task X: Validator rejects out-of-range values
- Task Y: Handler writes the value to the entity

These touch different concerns (validation vs persistence) even when sequential -- keep separate.

### Manual Gates (not tasks)

Some steps are not implementer work -- they are operator commands that the user (or the orchestrator) runs once:

- `pnpm openapi-ts` (or equivalent regen)
- `dotnet ef database update` against a local DB
- Deploying a service so swagger is live before FE work begins

These should NOT be numbered tasks in the plan. They appear as **Manual Gate** entries between tasks, marked with the command and a one-line "why this gate exists" note. Atlas reads gates and pauses execution to surface them to the user; once the user confirms completion, atlas resumes with the next task.

**Placement rule:** Place each Manual Gate immediately after the last task whose output the gate consumes, and immediately before the first task that depends on the gate. Example: the `pnpm openapi-ts` gate goes immediately after the BE endpoint task and immediately before the first FE task that imports the regenerated type. A Manual Gate MUST NOT appear before any task it does not gate, and MUST NOT be bunched at the top or bottom of the plan.

**Manual Gate format:**

```markdown
---

**Manual Gate: API regen**

Run: `cd apps/performance-fe && pnpm openapi-ts`

Why: Backend types must be regenerated before any FE task that imports the new endpoint.

User confirms: type "regen done" to resume.

---
```

## Plan Document Header

Every plan MUST start with this header:

```markdown
# [Feature Name] Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use pandahrms:execute-plan to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

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

The final step of every task MUST be `Stage changes` and MUST NOT include `git commit`, `git push`, `git tag`, `git rebase`, or any other history-mutating command. Self-Review item 8 enforces this.

## Required References

Each task that touches production code or specs MUST carry:

1. **Spec ref** -- one or more Gherkin scenarios the task satisfies. Omit only when no specs exist for the area (UI-only or skip-specs path). If specs exist for the area but you cannot link a task to one, the plan is incomplete -- update the spec or rewrite the task.
   - If an in-scope spec scenario describes a manual operator action with no production code (e.g. "Admin runs DB script", "DBA applies migration"), mark it as a Manual Gate, NOT a task. Do not create a task with placeholder code for manual procedures.
2. **Test ref** OR **Verification** -- TDD is the workflow default; one of the two MUST be present on every production-code task:
   - **Test ref** -- the test file path and the new/changed test case name(s). Required for any task that does NOT match a [No-Test-Pattern Category](#no-test-pattern-categories).
   - **Verification** -- only allowed for tasks in the No-Test-Pattern Categories below. The Verification slot accepts ONLY these category labels in parentheses: `(EF mapping)`, `(EF migration)`, `(read DTO + projection)`, `(API regen)`, `(pure config)`. Any other label is invalid and forces the task to use a Test ref. State the category in parens, then describe how the task is actually verified (e.g. `Verification: (EF mapping) -- no unit-test pattern in this codebase; verified via integration test of the consuming endpoint + runtime`). Tasks using a Verification slot do NOT run a Red-Green-Refactor cycle and skip the RED/GREEN markers in implementer reports.
3. **Red-before-Green ordering** -- when a Test ref is used, the failing-test step always precedes the implementation step. No production code without a failing test. (Verification-slot tasks are exempt -- they have no test to write.)
4. **Depends on** -- explicit task IDs, or `none`. Independent tasks let atlas parallel-dispatch and cut wall-clock time.

### No-Test-Pattern Categories

Tasks in these categories may use the `Verification:` slot in lieu of a `Test ref:`. The list is closed -- if a task does not match one of these categories, it needs a Test ref. Adding a new category is a discussion with the user, not a unilateral plan-writer call.

| Category | Why no test ref | Required verification |
|----------|-----------------|----------------------|
| **EF mapping** (configuring a property/relationship in `IEntityTypeConfiguration<T>`) | This codebase has no unit-test pattern for EF mappings. They are exercised by integration tests of the consuming endpoint and at runtime. | Name the integration test or endpoint that exercises the mapping; runtime smoke is acceptable when no integration test exists. |
| **EF migration** (an `Add-Migration` artifact) | This codebase has no automated migration test pattern. The convention is inspect the generated migration, apply locally, verify with `sqlcmd` or equivalent. | "Inspect generated migration + apply locally + verify schema with sqlcmd" -- name the verification command and the table/column to inspect. |
| **Read DTO + projection** (a DTO with a pure projection from an EF query, no business logic) | No unit-test pattern in this codebase for projections. They are verified through Swagger inspection + integration test of the consuming endpoint. | Name the integration test or Swagger endpoint that exercises the projection. |
| **API regen / generated types** (`pnpm openapi-ts`, swagger-typescript-api, etc.) | Purely mechanical -- the generator produces the file. | `pnpm tsc --noEmit` (or the equivalent type-check command) is the verification. |
| **Pure config change** (appsettings flag, tsconfig path alias, env var) with no behavior branch | No code path to test directly. | The build command and a runtime check that the config is honored. |

A task that combines a no-test-pattern category WITH custom logic (e.g. an EF mapping that has a `HasConversion` lambda doing real work) is NOT a no-test-pattern task -- it needs a real Test ref against the conversion logic.

## No Placeholders

Every step must contain the actual content an engineer needs. These are **plan failures** -- never write them:

- "TBD", "TODO", "implement later", "fill in details"
- "Add appropriate error handling" / "add validation" / "handle edge cases"
- "Write tests for the above" (without actual test code)
- Steps that describe what to do without showing how (code blocks required for code steps)
- References to types, functions, or methods not defined in any task

When two tasks share similar code, choose between repeating the code or referencing an earlier task using these concrete rules:

- **Repeat the code in full** when ANY of these is true:
  - The task's `Depends on:` is `none` (it can be parallel-dispatched).
  - The referenced task is more than 3 tasks earlier in the plan.
  - The two tasks live in different files.
- **Reference an earlier task** ONLY when ALL of these are true:
  - The dependent task is the immediately following task in the plan.
  - It lives in the same file as the referenced task.
  - The difference is a single named field, argument, or value, statable in one sentence.

Format for a valid reference: `"Same shape as Task 3 Step 3, but with field 'archivedAt' instead of 'approvedAt'."` Atlas dispatches independent tasks to fresh subagents that read the plan with no prior context, so repetition is safer than reference whenever the rules above don't unambiguously authorize a reference.

## No Commits in Plan Steps

The plan MUST NOT include a `git commit` step in any task. Atlas defers commits to `/hermes-commit` after the user has tested. Each task ends with:

- **Stage changes** -- `git add <files>` only

Never write `git commit -m "..."` into a plan. The user runs `/hermes-commit` after testing, which plans and executes atomic commits across the full set of changes.

## Self-Review

After writing the complete plan, re-read the design doc and every in-scope spec file in full. Do NOT rely on memory. Then run the 8-item checklist below in order, top to bottom. This is an inline checklist -- not a subagent dispatch.

**Sequencing rule.** For each item: (a) write the gap list to a scratch block at the bottom of the plan titled `<!-- Self-Review Scratch -->`; (b) fix every listed gap inline by editing the relevant task; (c) once all 8 items have been processed and every gap fixed, delete the scratch block. Do NOT save the plan with the scratch block still present.

**Boundary rule.** Self-Review may only edit the plan. Do NOT edit the design doc or any `.feature` file from this skill. If a gap exposes a defect in the design or spec that cannot be closed by editing the plan, see the unresolvable-gap rule below.

1. **Spec coverage** -- read each in-scope spec scenario in full. For each scenario, write the task ID that implements it. If no task implements a scenario, list it as a gap.
2. **Design coverage** -- read each functional requirement in the design doc in full. For each requirement, write the task ID that delivers it. If none, list it as a gap.
3. **Test ref or Verification completeness** -- every production-code task carries either a `Test ref:` or a `Verification:` (only when the task is in a [No-Test-Pattern Category](#no-test-pattern-categories)). List any tasks missing both. A task with `Verification:` whose category label is NOT one of `(EF mapping)`, `(EF migration)`, `(read DTO + projection)`, `(API regen)`, `(pure config)` is also a gap -- either move it to a real test ref or discuss adding the category with the user.
4. **Red-before-Green** -- every production-code task with a `Test ref:` has a failing-test step before any implementation step. Flag any task that puts implementation first. (Tasks using `Verification:` are exempt -- they do not run a TDD loop.)
5. **Placeholder scan** -- search the plan for the red-flag patterns from "No Placeholders" above. List every match.
6. **Type consistency** -- do the types, method signatures, and property names you used in later tasks match what you defined in earlier tasks? A function called `clearLayers()` in Task 3 but `clearFullLayers()` in Task 7 is a gap.
7. **Dependency markers** -- every task has a `Depends on:` line, even if it's `none`. List any task missing the line.
8. **No commit steps** -- search for `git commit`, `git push`, `git tag`, and `git rebase` in the plan. List every match.

**Closing the review.**
- If a Self-Review gap can be closed by editing the plan (adding a missing task, fixing a placeholder, renaming for consistency, adding a missing `Depends on:`, removing a forbidden git command), fix it inline.
- If a Self-Review gap cannot be closed because the design or spec is itself incomplete or contradictory, STOP. Do NOT save the plan. Output: `Self-Review found <N> unresolvable gap(s): [list]. Plan not saved.` and wait for the user.
- After every gap is fixed inline AND the scratch block is deleted, proceed to step 7 of the Execution Order (save the plan with the Write tool). Do NOT run Self-Review a second time. Do NOT begin implementation.

## Hand Off

The plan MUST already be saved to its path with the Write tool (Execution Order step 7) before this section runs. Do NOT print the plan inline as a chat response in lieu of saving.

After the plan is saved and Self-Review is complete, announce:

> "Plan complete and saved to `<path>`. Atlas will run Plan ↔ Spec cross-review next, then dispatch tasks to pandahrms:execute-plan."

Do NOT ask the user to choose between inline and subagent execution. Atlas always uses pandahrms:execute-plan with parallel dispatch.

When invoked outside atlas (rare), announce instead:

> "Plan complete and saved to `<path>`. Run pandahrms:execute-plan to implement, or hand the file to atlas via `/atlas-pipeline-orchestrator <path>` for the full pipeline."

**End of skill.** After printing the announcement, end your turn. Do NOT begin implementing any task. Do NOT modify any source files. Do NOT run any tests. Do NOT invoke pandahrms:execute-plan, /hermes-commit, or any follow-up skill from this skill.

## Red Flags

| Thought | Reality |
|---------|---------|
| "I'll write 'add validation here' to keep tasks short" | No placeholders. Show the actual validation code. |
| "Tasks 4 and 6 are nearly identical, I'll just say 'similar to Task 4'" | Default to repeating the code. Reference earlier tasks only when execution is strictly sequential. |
| "I'll add a `git commit` at the end of each task" | Never. Atlas + /hermes-commit own the commit step. Plans only stage changes. |
| "This task touches production code but the test is 'obvious'" | Every production-code task carries either a Test ref or, if it falls in a recognized No-Test-Pattern Category (EF mapping, migration, read DTO + projection, API regen, pure config), a Verification slot. "Obvious" is not a category. |
| "This EF mapping has a HasConversion lambda doing real work, but it's still 'just a mapping'" | No -- once there's behavior in the mapping, it needs a real Test ref against that behavior. The Verification slot is for mechanical mapping only. |
| "I'll invent a new no-test-pattern category since this task feels mechanical" | The category list is closed. If you think a new one belongs there, surface the discussion to the user before using a Verification slot. |
| "I'll skip the spec ref for this small task" | If specs exist for the area, every task has a spec ref. If no specs exist (UI-only / skip-specs), say so in the header. |
| "I'll let the engineer figure out task dependencies" | Mark dependencies explicitly. Atlas parallel-dispatches based on this -- missing markers serialize the run. |
| "I'll let writing-plans-style mandate decide whether to duplicate code" | Pandahrms plan picks pragmatically: reference earlier tasks when sequential, repeat code when parallel-dispatched. Default to repeating. |
| "I'll ask the user to choose inline vs subagent at the end" | No. Atlas always uses pandahrms:execute-plan. Don't add the choice. |

## Remember

- Exact file paths always
- Complete code in every code step
- Spec ref and test ref on every production-code task
- Red-before-Green ordering, no exceptions
- `Depends on:` line on every task (even if `none`)
- Stage changes only -- never commit
- DRY, YAGNI, TDD, frequent commits (committed by /hermes-commit, not by the plan)

## When to Use

- After `pandahrms:design-refinement` and (optionally) `pandahrms:spec-writing` have completed
- Invoked by atlas in step 4, or directly when the user hands you a design + spec set

## When NOT to Use

Refuse and abort with the listed message when ANY of the following are true:

- **Design not approved.** No design doc exists at `docs/pandahrms/designs/`, or the design's approval cannot be confirmed per Prerequisites item 2. Output: `Design not approved. Run pandahrms:design-refinement first.` and stop.
- **Trivial single-file fix.** The change touches a single file with at most 30 modified lines, no new public API, and no new spec scenarios. Output: `Change is too small for a full plan. Do the fix directly with TDD.` and stop.
- **Non-Pandahrms project.** No `pandahrms-spec/` directory exists in the workspace AND no `docs/pandahrms/designs/` directory exists. Output: `Plan skill is Pandahrms-only. Use superpowers:writing-plans for non-Pandahrms projects.` and stop.
