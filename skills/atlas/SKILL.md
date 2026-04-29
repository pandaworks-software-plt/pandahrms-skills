---
name: atlas
description: MANUAL INVOCATION ONLY -- never auto-trigger. Atlas activates only when forge routes here from its Pipeline Selection question, or when the user explicitly invokes /atlas. Do NOT activate from phrases like "start new work", "build a feature", "design", "brainstorm", "plan", or "execute" -- those route through forge first, and forge decides whether to hand off to atlas. Atlas is the no-superpowers cousin of forge: same pipeline shape (design -> spec-writing -> QA review -> plan -> Plan-Spec cross-review -> execute -> simplify -> ask user to test), but uses pandahrms:design / pandahrms:plan / pandahrms:execute internally with single-stage review by default.
---

# Pandahrms Atlas

<MANUAL-ONLY>
This skill is invoked only by forge's Pipeline Selection step or by an explicit `/atlas` slash command. Do NOT auto-activate from work-start triggers, brainstorming triggers, planning triggers, or execution triggers -- forge owns the entry point for all such phrases. If the conversation does not show evidence of forge dispatching here (or an explicit /atlas), STOP and route the user to forge instead.
</MANUAL-ONLY>

## Overview

Unified Pandahrms-native pipeline: design, spec writing, QA review, implementation planning, Plan <-> Spec cross-review, and subagent-driven execution -- all in a single session, with no superpowers dependency.

Atlas is the no-superpowers cousin of `forge`. The pipeline shape is the same; the component skills swap from `superpowers:*` to `pandahrms:*`. The biggest practical difference is per-task throughput: atlas runs single-stage review by default and only opts into a second-stage spec-compliance reviewer for tasks the plan tags `**Risk:** high`. This was the v4->v5 superpowers change that produced the largest slowdown.

**Announce at start:** "I'm using Pandahrms atlas to orchestrate design through execution (no-superpowers mode). Routed here from forge."

## Fast Path (plan provided)

If invoked with a plan file path (e.g., `/atlas path/to/plan.md`), skip steps 1-4 and start directly at step 5 (Plan <-> Spec cross-review), then step 6 (Execute plan).

- Initialize time tracking as normal
- Announce: "Executing existing plan -- running Plan <-> Spec cross-review, then execution."
- Still run step 5 to catch drift between the pre-existing plan and current specs
- After execution, still run step 7 (simplify) and step 8 (ask user to test) with the Development Summary

## Resume Path

If invoked with `/atlas --resume`:

1. Read the plan file's `## Atlas Progress` section to determine which steps completed and their timing
2. Announce: "Resuming atlas from step N -- [step name]."
3. Continue from the next incomplete step with full time tracking
4. If no plan file exists or has no progress section, announce: "No atlas state found -- starting fresh." and begin from step 1

## Codex Availability

At the very start of every atlas run (before step 1, including Fast Path and Resume Path), detect whether Codex is available locally.

1. Run `command -v codex` via Bash. Empty stdout means unavailable.
2. Store the result in conversation context as `codex_available` (true/false). Persist it into the plan file's `## Atlas Progress` section once the plan exists, on a `Codex available: true|false` line, so resumed runs do not need to re-detect.

When `codex_available` is true, dispatch these review-only steps to the `codex:codex-rescue` subagent for a second-opinion pass:

- **Step 3** -- QA Review Agent
- **Step 5** -- Plan <-> Spec cross-review

These are analysis-only tasks. The dispatched prompt MUST begin with `READ-ONLY REVIEW. Do not modify files. Do not run --write. Return findings only.` so codex does not edit the working tree. Findings come back as the rescue subagent's stdout and are reconciled exactly as if the regular `Agent` tool had been used. The skip conditions for each step still apply -- detection only changes who runs the review, not whether it runs.

When `codex_available` is false, fall back to the regular `Agent` tool with the prompts shown in each section.

Announce at start: `"Codex detected -- routing QA review and Plan <-> Spec cross-review to codex:codex-rescue."` or `"Codex not detected -- using local agents for reviews."`

<HARD-GATE>
AUTHORITY HIERARCHY:

**Design time (steps 1-4):** Discussion/decisions are the source of truth. If a discussion or decision diverges from the existing spec, UPDATE the spec before writing the plan. Never write a plan that contradicts the spec -- update the spec first, then plan from the updated spec.

**Execution time (step 6):** The plan is the source of truth for each implementer subagent. But implementers MUST cross-check against the spec. If plan and spec disagree, STOP and report -- never silently pick one.

**Never silently reconcile.** Always ask the user or flag the conflict when authority sources disagree.
</HARD-GATE>

<HARD-GATE>
NO COMMITS DURING EXECUTION. Implementer subagents stage changes (`git add`) but never run `git commit`. The user tests first, then runs `/hermes-commit` to plan and execute atomic commits across the full set of changes. This rule lives in `pandahrms:execute` -- atlas just trusts the component skill to enforce it.
</HARD-GATE>

## Pipeline

```dot
digraph atlas_pipeline {
    "Work request" [shape=doublecircle];
    "Plan file provided?" [shape=diamond];
    "Invoke pandahrms:design\n(loads test + spec context,\ncovers spec + test impact)" [shape=box];
    "Design approved" [shape=diamond];
    "Write specs?\n(UI-only auto-skip\nor user choice)" [shape=diamond];
    "Invoke pandahrms:spec-writing" [shape=box];
    "Run QA review?\n(<3 new scenarios -> skip)" [shape=diamond];
    "Invoke QA review" [shape=box, style=filled, fillcolor=lightblue];
    "QA gaps or edge cases?" [shape=diamond];
    "Invoke pandahrms:plan" [shape=box];
    "Plan <-> Spec cross-review" [shape=box, style=filled, fillcolor=lightblue];
    "Plan aligned\n(spec + test refs)?" [shape=diamond];
    "Invoke pandahrms:execute" [shape=box, style=filled, fillcolor=lightgreen];
    "Subagent failed?" [shape=diamond, style=filled, fillcolor=lightyellow];
    "Handle failure" [shape=box, style=filled, fillcolor=orange];
    "Simplify\n(/simplify)" [shape=box, style=filled, fillcolor=lightblue];
    "Ask user to test" [shape=doublecircle];

    "Work request" -> "Plan file provided?";
    "Plan file provided?" -> "Plan <-> Spec cross-review" [label="yes (fast path)"];
    "Plan file provided?" -> "Invoke pandahrms:design\n(loads test + spec context,\ncovers spec + test impact)" [label="no"];
    "Invoke pandahrms:design\n(loads test + spec context,\ncovers spec + test impact)" -> "Design approved";
    "Design approved" -> "Invoke pandahrms:design\n(loads test + spec context,\ncovers spec + test impact)" [label="no, revise"];
    "Design approved" -> "Write specs?\n(UI-only auto-skip\nor user choice)" [label="yes"];
    "Write specs?\n(UI-only auto-skip\nor user choice)" -> "Invoke pandahrms:spec-writing" [label="yes"];
    "Write specs?\n(UI-only auto-skip\nor user choice)" -> "Invoke pandahrms:plan" [label="UI-only or skip"];
    "Invoke pandahrms:spec-writing" -> "Run QA review?\n(<3 new scenarios -> skip)";
    "Run QA review?\n(<3 new scenarios -> skip)" -> "Invoke QA review" [label=">=3 new scenarios"];
    "Run QA review?\n(<3 new scenarios -> skip)" -> "Invoke pandahrms:plan" [label="<3, skip"];
    "Invoke QA review" -> "QA gaps or edge cases?";
    "QA gaps or edge cases?" -> "Invoke pandahrms:spec-writing" [label="yes, fix specs"];
    "QA gaps or edge cases?" -> "Invoke pandahrms:plan" [label="no, reconciled"];
    "Invoke pandahrms:plan" -> "Plan <-> Spec cross-review";
    "Plan <-> Spec cross-review" -> "Plan aligned\n(spec + test refs)?";
    "Plan aligned\n(spec + test refs)?" -> "Invoke pandahrms:plan" [label="no, update plan"];
    "Plan aligned\n(spec + test refs)?" -> "Invoke pandahrms:spec-writing" [label="no, update spec"];
    "Plan aligned\n(spec + test refs)?" -> "Invoke pandahrms:execute" [label="yes"];
    "Invoke pandahrms:execute" -> "Subagent failed?";
    "Subagent failed?" -> "Handle failure" [label="yes"];
    "Handle failure" -> "Invoke pandahrms:execute" [label="retry/skip"];
    "Handle failure" -> "Ask user to test" [label="abort, no changes"];
    "Handle failure" -> "Simplify\n(/simplify)" [label="abort, partial done"];
    "Subagent failed?" -> "Simplify\n(/simplify)" [label="no, all passed"];
    "Simplify\n(/simplify)" -> "Ask user to test";
}
```

## Checklist

You MUST create a task for each of these items and complete them in order. Apply [Time Tracking](#time-tracking) to every step -- record start/end times and pause during user prompts.

1. **Design** -- invoke `pandahrms:design`. The skill loads test + spec context, asks one question at a time, proposes 2-3 approaches, presents the design in sections, and saves an uncommitted design doc to `docs/pandahrms/designs/<...>.md` covering spec impact, test impact, and implementation approach.
2. **Write or update specs?** -- two routing decisions in one place:
   - **UI-only auto-skip**: if the work is purely UI/presentation (styling, layout, component design, theming, responsiveness, animations, dark mode, visual polish), announce "Skipping spec-writing -- UI-only change with no business behavior impact" and proceed to step 4 (QA auto-skipped too).
   - **Otherwise**: use AskUserQuestion: "Would you like to write/update Gherkin specs before proceeding to the implementation plan?" with options "Yes, write/update specs" and "Skip specs". Users may skip if the session is purely exploratory or open discussion. If yes, invoke `pandahrms:spec-writing` to write or update specs in pandahrms-spec. **Discussion/decisions are authoritative** -- if the design produced decisions that diverge from existing specs, update the spec to reflect the new decisions BEFORE writing the plan. Never leave an outdated spec to be reconciled later. Present the written/updated specs to the user for review before proceeding.
3. **QA review (conditional)** -- skip when EITHER no specs exist OR fewer than 3 NEW scenarios were added in step 2 (modifications to existing scenarios do not count -- step 1's design already covered impact for small changes). Otherwise dispatch the QA-review sub-agent (two-pass: design<->spec coverage + edge cases) and wait for it to complete. See [QA Review Agent](#qa-review-agent) for dispatch prompt, skip-condition detection, and result handling. If QA surfaces coverage gaps or new scenarios, loop back to `pandahrms:spec-writing` to update the specs, then re-run QA. When QA returns zero blocking findings (or the user chooses to proceed), move on to step 4.
4. **Create implementation plan** -- invoke `pandahrms:plan`. The skill produces a plan with:
   - **Spec ref** on every business-behavior task (when specs exist)
   - **Test ref** on every production-code task with Red-before-Green ordering
   - **Depends on:** marker on every task (atlas reads this in step 6 to parallel-dispatch)
   - **Risk:** tag on tasks that need second-stage review (auth, multi-tenant, billing, schema, PII)
   - **No commit steps** -- plans stage changes only; /hermes-commit owns commits
5. **Plan <-> Spec cross-review** -- after the plan is written (or at Fast Path entry), verify three directions: (a) every plan task references a real spec scenario, (b) every in-scope spec scenario has at least one plan task, and (c) every plan task that touches production code names a test reference with Red-before-Green ordering. The (c) check is the only test-ref validator on Fast Path -- do not skip it. If gaps exist, fix them before execution. See [Plan-Spec Cross-Review](#plan-spec-cross-review) for skip conditions and resolution paths.
6. **Execute plan** -- invoke `pandahrms:execute`. The skill reads the plan, resolves the codex execution mode (asks the user once if `codex_available` is true and the mode isn't already set in the progress section), groups tasks by `Depends on:`, parallel-dispatches independent batches (cap 5 per batch, Agent + codex counted together), runs single-stage review by default, and opts into second-stage spec-compliance review only for tasks tagged `**Risk:** high` (reviewer routes through codex when available). Implementer subagents stage changes but never commit. Time tracking records the step as a whole (wall-clock from first dispatch to last return). If a subagent fails, follow [Subagent Failure Handling](#subagent-failure-handling).
7. **Simplify** -- once Step 6 has finished and at least one subagent reported success, invoke the `simplify` skill to review the changed files for reuse, quality, and efficiency, and to fix any issues it finds. Skip this step if Step 6 was aborted with no completed tasks (nothing to simplify). All resulting changes remain uncommitted -- the user still tests in Step 9 before /hermes-commit.
8. **Playwright e2e (conditional)** -- if Playwright is configured for the working project, run an e2e pass on the changes from this session. See [Playwright E2E Step](#playwright-e2e-step) for the detection and execution rules. Skip silently when Playwright isn't installed.
9. **Ask user to test** -- present the Development Summary. If the plan file's `## Atlas Progress` section has an `### Acknowledged Gaps` block (gaps the user chose to "Proceed anyway" past during Step 5), surface each gap with: "**Acknowledged gaps to verify manually:** [gap list]." Then end with: "Please test your changes, then run /hermes-commit when ready."

## Time Tracking

Track **active work time** across the full atlas run -- time spent by Claude doing work, excluding time waiting for user input or blocked on external factors. Display a summary when execution completes.

### How to track

1. **On step start** -- record the current time (use `date +%s` via Bash)
2. **Before any user prompt** -- record a pause timestamp. This includes:
   - AskUserQuestion calls (design approval, "write specs?", "add QA findings to specs?", "how to resolve Plan <-> Spec gaps?", subagent-failure prompts)
   - Any blocker requiring user action (e.g., environment issue, missing access)
   - Presenting results and waiting for user to respond
3. **After user responds** -- record a resume timestamp. Add the paused duration to the step's excluded time.
4. **On step completion** -- calculate: `duration = (end - start) - total_excluded_time`. Display: `"Step N completed in Xm Ys (active work)"`
5. **On final step completion** -- display a summary:

```
Development Summary (active work time, excludes user-wait)
===========================
Design                       --  12m 34s
Write specs                  --   8m 21s
QA review                    --   2m 45s
Create implementation plan   --  15m 02s
Plan <-> Spec cross-review   --   1m 30s
Execute plan                 --  18m 14s
Simplify                     --   3m 12s
Playwright e2e               --   2m 06s
===========================
Grand total (active)         --  1h 03m 44s
Total wall-clock time        --  1h 44m 17s
User-wait time               --     40m 33s
```

### What counts as paused time

| Paused (exclude from timing) | Active (include in timing) |
|------------------------------|---------------------------|
| Waiting for user to answer AskUserQuestion | Claude processing after user responds |
| User reviewing a design doc or spec | Designing, writing specs, planning |
| User fixing an environment issue | Subagent execution |
| Blocked on external dependency | Reading files, running commands |

### Implementation

Use the plan file as the single source of truth for both progress tracking and timing. Before the plan file exists (steps 1-3), hold timestamps in conversation context. Once the plan is created (step 4), persist everything into the plan file.

Use the Read and Write tools for all plan file I/O. Only use Bash for `date +%s`.

**On atlas start:**

1. Run `date +%s` in Bash to get the epoch
2. Hold the atlas start time and step timestamps in conversation context until the plan file is created

**On plan creation (step 4):**

Append a `## Atlas Progress` section to the plan file. Backfill steps 1-3 timing from conversation context:

```markdown
## Atlas Progress

| Step | Status | Duration |
|------|--------|----------|
| 1. Design | done | 12m 34s |
| 2. Write specs | done | 8m 21s |
| 3. QA review | skipped | -- |
| 4. Create implementation plan | done | 15m 02s |
| 5. Plan <-> Spec cross-review | pending | -- |
| 6. Execute plan | pending | -- |
| 7. Simplify | pending | -- |
| 8. Playwright e2e | pending | -- |
| 9. Ask user to test | pending | -- |

Atlas started: 1718000000
Codex available: true
Codex execution mode: none
Playwright e2e: auto-detect

### Acknowledged Gaps

(Populated only when the user chose "Proceed anyway" during Step 5. One bullet per gap. Step 9 surfaces this list to the user.)
```

**On each step completion:**

1. Run `date +%s` in Bash to get the timestamp
2. Use the **Read** tool to load the plan file
3. Update the step's row in the Atlas Progress table (status and duration)
4. Use the **Write** tool to save the plan file back

**On task completion (step 6):**

When a subagent completes a plan task, update the task's checkbox in the plan file from `- [ ]` to `- [x]`, then update the Atlas Progress table for step 6's running duration.

Active duration = `(end - start) - sum(resume - pause for each pause)`

Format durations by computing in your reasoning: `Xm YYs`. Skipped steps show `-- skipped`.

### Execution step timing

Step 6 (execute plan) is tracked as a single step:

- **Duration** = wall-clock time from first subagent dispatch to last subagent completion
- Per-subagent timing is NOT tracked. If multiple subagents run in parallel, they overlap inside this one duration.

## Subagent Failure Handling

When a subagent returns `Status: BLOCKED`, `Status: NEEDS_CONTEXT`, or any non-success exit (build error, test failure, merge conflict):

1. **Pause execution** -- wait for all in-flight subagents in the current parallel batch to return, then do not dispatch any further batches until the user decides how to proceed
2. **Classify the failure** -- before offering retry, identify the failure mode. This avoids blind retries that waste time:
   - **Missing context** (typically `Status: NEEDS_CONTEXT`) -- the implementer prompt was missing a file, type, scenario, or env var the task requires. Resolution: re-dispatch with the missing context added.
   - **Insufficient reasoning** -- the subagent attempted the task but produced incorrect or incomplete code (e.g. failed verification it should have passed). Resolution: re-dispatch using a stronger model or codex if available; consider switching the codex execution mode for this task.
   - **Task too large** -- the subagent partially completed work but the scope exceeds what fits in one dispatch. Resolution: return to `pandahrms:plan` to split the task; do not retry as-is.
   - **Plan or spec error** (typically `Status: BLOCKED` with conflict details) -- the plan and spec disagree, the spec is internally contradictory, or the plan references something that doesn't exist. Resolution: escalate to the user; loop back to `pandahrms:spec-writing` or `pandahrms:plan` as appropriate.
3. **Present the error and classification** -- show the failing subagent's name, task description, returned status, error output, and your classification.
4. **Ask the user** via AskUserQuestion: "Subagent '[task name]' returned [status] -- classified as [missing context / insufficient reasoning / task too large / plan or spec error]. How would you like to proceed?" with options matched to the classification:
   - **"Re-dispatch with added context"** (missing context) -- you provide the missing piece, atlas re-dispatches the same task
   - **"Re-dispatch with stronger model"** (insufficient reasoning) -- atlas re-dispatches via codex (or escalates the codex mode), if available
   - **"Send back to plan/spec"** (task too large or plan/spec error) -- atlas pauses execute, loops back to the relevant skill, then resumes
   - **"Skip and continue"** -- note the failed task in the conversation and proceed with remaining tasks
   - **"Abort atlas"** -- stop execution, display the Development Summary with the Execute step marked failed, and end with: "Atlas aborted. Completed tasks remain uncommitted. Run /hermes-commit when ready or discard with git restore."

When the implementer returns `Status: DONE_WITH_CONCERNS`, do NOT silently mark the task complete. Surface the concerns via AskUserQuestion: accept (mark complete), re-dispatch with guidance, or escalate to design/plan.

Failures do not alter the step-level Development Summary other than annotating the Execute step's outcome (e.g. `Execute plan -- 18m 14s (1 task failed, skipped)`).

## QA Review Agent

In step 3, after specs are written/updated, dispatch a sub-agent to audit the specs in two passes in a single run. The agent runs in the foreground -- wait for it to return and reconcile findings before moving on to plan-writing (step 4).

1. **Design<->Spec structural coverage** -- does every design requirement have a corresponding spec scenario? (replaces the standalone spec-review step)
2. **Edge-case hunt** -- what did both the design and spec miss? Unhappy paths, boundary conditions, implicit requirements.

### Skip Condition

Skip this step when EITHER condition holds:

**A. No specs to review** -- detect by:
- No `.feature` files were created or updated in this session, AND
- No in-scope `.feature` files exist for the feature area in `pandahrms-spec`

Covers UI-only work, "skip specs" path, and any invocation against a spec-less feature.

**B. Light spec changes** -- specs were edited but fewer than 3 NEW scenarios were added in step 2. Modifications to existing scenarios DO NOT count. Step 1's design already covered impact for small edits, so a fresh edge-case hunt isn't worth the cost.

To count new scenarios, run `git diff` on the spec files updated in this session and count `^+\s*Scenario:` and `^+\s*Scenario Outline:` lines (added scenario headers only). If the count is < 3, skip.

Announce the skip reason -- e.g. `"Skipping QA review -- no specs to review."` or `"Skipping QA review -- only N new scenario(s) added (threshold: 3)."`

### Agent Dispatch

If `codex_available` is true, dispatch via the `codex:codex-rescue` subagent. Otherwise dispatch via the regular `Agent` tool. In both cases, prefix the prompt with `READ-ONLY REVIEW. Do not modify files. Do not run --write. Return findings only.` followed by a blank line, then the body below.

Replace the placeholders:
- `{design_doc_path}` -- path to the approved design document
- `{spec_file_paths}` -- paths to all written spec files
- `{scope_notes}` -- brief "in scope / out of scope" summary extracted from the design doc, so the agent doesn't flag edge cases for deferred features

```
prompt: |
  You are a QA reviewer. Your job has TWO parts, completed in one pass:

  **Part A: Design<->Spec structural coverage** -- verify every design
  requirement has a corresponding Gherkin scenario.

  **Part B: Edge-case hunt** -- identify missed edge cases, unhappy paths,
  boundary conditions, and implicit requirements.

  ## Inputs

  Design document: {design_doc_path}
  Spec files: {spec_file_paths}
  Scope: {scope_notes}

  Read the design document and all spec files. The scope section defines
  what is in-scope and out-of-scope for this iteration. Only flag edge
  cases for in-scope functionality -- do not report findings for features
  explicitly marked as deferred or out-of-scope.

  ## Part A: Structural coverage

  For every functional requirement in the design doc, check whether at
  least one spec scenario covers it. Report any design requirement that
  has NO spec scenario as a "coverage gap".

  ## Part B: What to Look For

  1. **Unhappy paths** -- What happens when the user provides invalid input,
     cancels mid-flow, loses connectivity, or hits a timeout?
  2. **Boundary conditions** -- Empty lists, maximum lengths, zero values,
     exactly-at-limit values, off-by-one scenarios.
  3. **Concurrent/conflicting actions** -- Two users editing the same record,
     duplicate submissions, race conditions.
  4. **Permission edge cases** -- User's role changes mid-session, permission
     revoked after page load, cross-tenant access attempts.
  5. **Data state edge cases** -- Soft-deleted records, archived entities,
     null/missing optional fields, migrated legacy data.
  6. **Implicit requirements** -- Behavior the design assumes but never states
     (e.g., audit logging, notification triggers, cascade effects).

  ## Output Format

  Return a structured report:

  ### Coverage Gaps (Part A)

  For each design requirement without spec coverage:
  - **ID**: COV-1, COV-2, etc.
  - **Design requirement**: Quote or summary from the design doc
  - **Suggested scenario**: A Gherkin scenario outline that would cover it

  ### Edge Cases Found (Part B)

  For each finding:
  - **ID**: QA-1, QA-2, etc.
  - **Category**: (unhappy path | boundary | concurrency | permission | data state | implicit requirement)
  - **Description**: What the edge case is
  - **Suggested scenario**: A Gherkin scenario outline (Given/When/Then) that would cover it
  - **Severity**: (high | medium | low) -- high means likely to cause a bug in production

  ### Summary

  - Coverage gaps: [count]
  - Total edge-case findings: [count]
  - High severity: [count]
  - Medium severity: [count]
  - Low severity: [count]

  If you find zero edge cases, state that explicitly -- do not invent findings.
  Focus on quality over quantity. Only report genuine gaps, not theoretical
  scenarios that the feature's scope clearly excludes.

description: "QA review specs for edge cases"
```

### Handling Results

After the agent returns:

- **Zero findings (both parts)** -- announce "QA review complete -- coverage is complete and no additional edge cases found." Proceed to step 4.
- **Findings returned** -- present the agent's report to the user, then **automatically loop back to `pandahrms:spec-writing`** to incorporate coverage gaps AND high/medium severity edge-case findings as new scenarios. Do NOT ask the user whether to add them -- discrepancies found in spec review always go into the spec. Announce "QA review found [coverage_count] coverage gaps and [edge_count] edge cases ([high_count] high severity) -- adding to specs." Then re-run QA review on the updated specs. Low-severity findings may be deferred at the user's direction during the spec-writing step.

## Plan-Spec Cross-Review

After `pandahrms:plan` produces the plan file (or when entering Fast Path with an externally-authored plan), verify the plan's integrity against both specs and tests before executing anything.

This step is the only validator for fast-path plans -- since Fast Path skips Step 4's plan-requirements check, Step 5 must cover those guarantees too.

### Skip Condition

Skip only when there are NO specs AND NO existing tests in the affected area. Detect this by:
- The plan file contains zero spec references, AND
- No `.feature` files exist for the feature area in `pandahrms-spec`, AND
- No test files exist in the affected codebase

This covers UI-only work with no tests, "skip specs" path with a spec-less and test-less area, and fast-path invocations against truly content-less features.

Announce the applicable skip reason -- e.g. `"Skipping Plan <-> Spec cross-review -- no specs or tests for this feature."`

### How to Review

If `codex_available` is true, dispatch this review to the `codex:codex-rescue` subagent with a prompt that lists the plan file path, the in-scope `.feature` file paths, the test file inventory from step 1, and the three checks below. Prefix the prompt with `READ-ONLY REVIEW. Do not modify files. Do not run --write. Return findings only.`. Treat the subagent's output as the review report.

If `codex_available` is false, perform the review inline:

1. Read the plan file and extract every task's spec reference, test reference, and (where present) verification slot.
2. Read every in-scope `.feature` file for the feature.
3. Check three directions:
   - **Plan -> Spec** -- does every plan task that touches business behavior reference a real spec scenario? Flag tasks with no spec reference or broken references. (Skip this check if no specs exist.)
   - **Spec -> Plan** -- does every in-scope spec scenario have at least one plan task implementing it? Flag uncovered scenarios. (Skip this check if no specs exist.)
   - **Plan -> Test** -- does every plan task that touches production code carry EITHER a `Test ref:` (with explicit Red-before-Green ordering) OR a `Verification:` slot whose category appears in the [pandahrms:plan No-Test-Pattern Categories](../plan/SKILL.md#no-test-pattern-categories) table (EF mapping, EF migration, read DTO + projection, API regen, pure config)? **Do NOT flag tasks with a valid `Verification:` slot -- accept them silently as fulfilling the requirement.** Flag only tasks that have neither a Test ref nor a recognized Verification slot. (This check runs whenever any tests exist OR whenever the plan modifies production code.)
4. Present findings to the user, partitioned by direction so resolution can route automatically (see Handling Results below).

### Handling Results

- **All directions covered** -- announce "Plan, spec, and tests aligned. Proceeding to execution." Go to step 6.
- **Gaps found** -- the cross-review auto-resolves any gap that has real coverage value. It does NOT prompt the user. Resolution by direction:
  - **Plan -> Spec gap (plan task with no spec scenario)** -- discrepancy belongs in the spec. Loop back to `pandahrms:spec-writing` and add the missing scenario. Announce "Plan-Spec cross-review found N missing scenarios -- adding to specs."
  - **Spec -> Plan gap (spec scenario with no plan task)** -- plan completeness issue. Loop back to `pandahrms:plan` to add the missing task. For fast-path plans, edit the plan file directly. Announce "Plan-Spec cross-review found N uncovered scenarios -- adding plan tasks."
  - **Plan -> Test gap (production-code task missing both Test ref and Verification)** -- loop back to `pandahrms:plan` to add the missing reference. For fast-path plans, edit the plan file directly:
     - If the task fits a recognized No-Test-Pattern Category, write a `Verification:` slot with the category and the verification method.
     - Otherwise, add a real `Test ref:` with Red-before-Green ordering.
     Announce "Plan-Spec cross-review found N tasks missing test references -- resolving."
  - **Mixed gaps** -- handle each direction per the rules above; loop-backs can be sequential or parallel.

**Auto-accepted (do NOT loop back, do NOT report as gaps):**
- Tasks with a valid `Verification:` slot whose category appears in the [pandahrms:plan No-Test-Pattern Categories](../plan/SKILL.md#no-test-pattern-categories) table.
- Spec scenarios marked out-of-scope in the design doc's scope section.

Only fall back to AskUserQuestion when:
1. A loop-back surfaces an irreconcilable conflict (e.g. the design itself contradicts the new spec scenario the cross-review wants to add), OR
2. A `Verification:` slot uses a category NOT in the recognized table -- this requires a user decision on whether to add the category to `pandahrms:plan` or convert the task to a real Test ref.

Do not proceed to execution while real gaps remain unresolved.

## Playwright E2E Step

Step 8 runs an end-to-end pass with Playwright after `simplify` and before handing the run back to the user, but only when Playwright is actually configured for the project. The goal is to catch UI-level regressions on the changes made this session before the user takes over.

### Detection

Check for Playwright in this order. The first match wins; stop checking once one is found.

1. `playwright.config.ts`, `playwright.config.js`, or `playwright.config.mjs` exists at the working project's root.
2. The project's `package.json` has `@playwright/test` (or `playwright`) under `dependencies` or `devDependencies`.
3. The user has previously authorized Playwright access in this session (the `mcp__playwright__*` tools have already been used).

If none match, announce `"Skipping Playwright e2e -- not configured for this project."` and proceed to Step 9. Do not install Playwright on the user's behalf.

### Scope: changes made this session

Run e2e only against the user-visible flows touched in this session, not the entire project's e2e suite. Identify scope from the staged diff:

1. Run `git diff --name-only --cached` (and `git diff --name-only` for unstaged) to list files changed in this session.
2. Map FE files to user-visible routes/components. Examples:
   - `src/routes/admin/appraisals/**` -> the appraisals admin pages.
   - `src/lib/components/forms/<Form>.svelte` -> any page that mounts that form.
3. Map BE files via the consuming endpoints, then to the FE pages that call them.
4. If no FE-visible change is detected (BE-only refactor, EF migration, internal helper), announce `"Skipping Playwright e2e -- session changes have no FE-visible surface."` and proceed.

### Execution

Use the `mcp__playwright__*` MCP tools (browser automation) -- not the project's offline `playwright test` runner -- so the user can watch the pass. The full toolset is loaded via `ToolSearch` with `select:mcp__playwright__browser_navigate,mcp__playwright__browser_click,mcp__playwright__browser_snapshot,...`.

For each scoped flow:
1. Navigate to the route the changed code controls (`browser_navigate`).
2. Execute the golden-path interaction (click, fill, submit) per the design doc's "happy path" description.
3. Take a snapshot (`browser_snapshot`) so the result is visible to the user.
4. Test at least one obvious failure mode the spec covers (validation error, permission denied, etc.).
5. Capture console errors (`browser_console_messages`) and network failures (`browser_network_requests`).

### Reporting

After the e2e pass, append a `### Playwright E2E` block to the Development Summary in Step 9:

```
### Playwright E2E

| Flow | Result | Notes |
|------|--------|-------|
| <route or page> | pass | golden path + 1 failure-mode |
| <route or page> | fail | <one-line failure summary> |
```

If any flow failed, surface the failures in plain language to the user as part of "ask user to test" -- they decide whether the failure is real (block /hermes-commit) or a flaky test (proceed). Do not auto-rerun more than once.

### Skip conditions

Skip Step 8 entirely (with announcement) when any of these hold:
- Playwright is not configured (per Detection).
- This session's changes have no FE-visible surface.
- The user types `/atlas --skip-e2e` or has set `Playwright e2e: skip` in the plan's `## Atlas Progress` section.
- Step 6 was aborted with no completed tasks (nothing to test).

## Red Flags

| Thought | Reality |
|---------|---------|
| "I'll skip the design step since the user described what they want" | Step 1 is mandatory. pandahrms:design enforces approval before implementation. |
| "It's a bug fix, no need to discuss tests upfront" | Bug fixes especially need a failing test that would have caught the bug. The design proposes that test before the fix. |
| "I'll just invoke pandahrms:execute on a plan that has no Depends on: markers" | Reject the plan and loop back to pandahrms:plan. Missing markers serialize the run -- atlas can't parallel-dispatch. |
| "I'll mark every task Risk: high to be safe" | The default single-stage review is the point of atlas. Tag only auth, multi-tenant, billing, schema, PII, or design-flagged risky tasks. |
| "I'll skip the QA review since specs look fine" | QA is conditional. Run it whenever >=3 NEW scenarios were added in step 2; skip it for smaller edits. Don't skip a qualifying run on a hunch. |
| "Discussion decided X but spec still says Y, I'll implement X" | Stop. Update the spec to reflect the decision FIRST, then plan. Never leave the spec outdated. |
| "Plan has no spec refs, but I'll just execute it" | Plans without spec refs (when specs exist) must be rewritten before execution. No shortcuts. |
| "Spec scenario has no plan task, but the plan looks complete" | Bi-directional coverage required. Either add a task or remove the scenario -- don't execute around it. |
| "QA found edge cases -- I'll ask the user whether to add them to specs" | Don't ask. Spec-review discrepancies always go into the spec automatically. Loop back to pandahrms:spec-writing without prompting. |
| "Plan-Spec cross-review found a missing scenario -- I'll AskUserQuestion how to resolve" | Don't ask for Plan -> Spec gaps. Auto-add the scenario via pandahrms:spec-writing. Only ask when an irreconcilable conflict surfaces during the loop-back. |
| "Cross-review found a task missing a test ref -- I'll flag it" | Check first whether it fits a No-Test-Pattern Category (EF mapping, migration, read DTO + projection, API regen, pure config). If yes, the resolution is to add a `Verification:` slot, not a Test ref. Only flag tasks that have neither a Test ref nor a valid Verification slot. |
| "I'll list noisy 'no test by convention' findings in the cross-review report" | No. Tasks with a valid Verification slot are silently accepted. The cross-review report only contains real gaps that need fixing. |
| "Cross-review found gaps -- I'll ask the user whether to fix them" | No. Real gaps with coverage value are auto-resolved by looping back to spec-writing or plan. The user is only asked when an irreconcilable conflict surfaces or when a Verification category isn't in the recognized list. |
| "Codex is installed but I'll just dispatch the local agent" | If `codex_available` is true, route QA review and Plan <-> Spec cross-review through `codex:codex-rescue`. |
| "I'll send the codex review prompt without the read-only prefix" | Codex defaults to `--write`. Every review dispatch MUST start with `READ-ONLY REVIEW. Do not modify files. Do not run --write. Return findings only.` so codex doesn't edit the working tree. |
| "I'll let an implementer commit since the plan says to commit" | Plans should not contain `git commit` steps. pandahrms:execute strips them on dispatch. /hermes-commit owns commits. |

## When to Use

- **Only** when forge's Pipeline Selection routes here (user picked "Atlas")
- **Only** when the user explicitly invokes `/atlas`, `/atlas <plan-path>`, or `/atlas --resume`
- Otherwise: route the user to `forge` -- it owns the entry point for all design/plan/execute work in Pandahrms projects.

## When NOT to Use

- ANY auto-trigger from natural-language phrases ("start new work", "build feature", "brainstorm", "design", "write a plan", "execute"). Forge owns those triggers and decides whether to hand off here.
- Quick fixes that don't need design (typos, config changes) -- handle directly without any orchestrator.
- Non-Pandahrms projects (use `superpowers:brainstorming` directly).
- Writing specs for existing functionality without a new design (use `pandahrms:spec-writing` directly).
- When the user explicitly wants the superpowers-based pipeline (use `forge` instead).
