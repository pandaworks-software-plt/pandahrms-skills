---
name: atlas-pipeline-orchestrator
description: Triggers on any mention of starting new work, building a feature, adding functionality, fixing a bug, refactoring, brainstorming, designing, writing a plan, or executing an existing plan. The single entry point for the full Pandahrms lifecycle: optimise-prompt -> design (gather/clarify/brainstorm/impact via pandahrms:design-refinement) -> spec routing -> plan -> execute -> spec<->code audit -> simplify -> Playwright e2e -> user test -> follow-up loop -> code review (athena + aegis) -> commit (hermes-commit). Also triggers on "atlas-pipeline-orchestrator", "atlas", "run the pipeline", or being handed a plan file.
---

# Pandahrms Atlas Pipeline Orchestrator

<SINGLE-INSTANCE>
Only one atlas-pipeline-orchestrator pipeline runs in a session at a time. Before starting, check whether a plan file exists with an `## Atlas Progress` section that has incomplete steps. If so, STOP and ask the user via AskUserQuestion: "An atlas-pipeline-orchestrator run is already in progress for plan '<path>'. How would you like to proceed?" with options: "Resume existing run", "Abort existing and start fresh", "Cancel this invocation". Do not silently start a parallel run.
</SINGLE-INSTANCE>

<STATE-FILES>
Atlas Pipeline Orchestrator state lives ONLY in:
- The design doc at `docs/pandahrms/designs/<...>.md`
- The plan file's `## Atlas Progress` section
- Updated `.feature` spec files in `pandahrms-spec`
- Staged code changes via implementer subagents (Steps 4 and 9)
- The commit history once Step 11 completes

Do NOT create any other state, log, tracking, scratch, or progress files. Do NOT create README.md, NOTES.md, CHANGELOG entries, summary docs, or any markdown file outside the design doc and plan file. The Development Summary at Step 8 (user-test handoff) is delivered in the chat response, not as a file. Do NOT write to `~/.claude/bridge/` unless the user explicitly instructs you to.
</STATE-FILES>

<CANONICAL-LABELS>
All AskUserQuestion option labels shown in this skill are CANONICAL. Use them verbatim -- do not paraphrase, shorten, expand, or reorder. All announcement strings shown in quoted form (e.g. "Skipping Aegis -- ...") are also canonical -- emit them verbatim with only the bracketed placeholders substituted.
</CANONICAL-LABELS>

## Overview

Atlas drives the full Pandahrms work lifecycle from user prompt to committed code, in a single orchestrated run. The 12 internal atlas steps map to the 16-step user-visible lifecycle as follows:

| Atlas Step | User lifecycle |
|------------|----------------|
| Pre-flight: optimise-prompt | 2 |
| 0. Setup (codex + time tracking + conditional branch reminder) | -- |
| 1. Design (gather/clarify/brainstorm/impact via pandahrms:design-refinement) | 3-6 |
| 2. Spec routing (ask if missing; always write if exists) | 7 |
| 3. Plan (pandahrms:plan-writing) | 8 |
| 4. Execute (pandahrms:execute-plan) | 9 |
| 5. Spec <-> Code audit | 10 |
| 6. Simplify (conditional) | 11 |
| 7. Playwright e2e (conditional) | 12 |
| 8. User test pause | 13 |
| 9. Follow-up loop (back to Step 1 if scope changes, Step 4 if code-only) | 14 |
| 10. Code review (athena + aegis) | 15 |
| 11. Commit (hermes-commit, pure) | 16 |

Atlas runs single-stage review by default for Step 4 (execute) and only opts into a second-stage spec-compliance reviewer for tasks the plan tags `**Risk:** high`.

**Role split between Codex and Claude** (active when the user opts in to Codex at Step 0): when `codex_enabled` is `true`, **Codex implements** (Step 4 dispatches, follow-up re-dispatches in Step 9, review-driven fixes in Step 10) and **Claude plans and audits** (Steps 1, 2, 3 planning; Steps 5, 6, 10 review; Step 7 exploration; second-stage reviewer for `Risk: high`). Codex never reviews its own output. When the user picks "No" at Step 0, the split collapses and Claude handles every step including implementation. See [Codex Usage](#codex-usage) for the full policy and announcement strings.

**Announce at start:** "I'm using Pandahrms atlas-pipeline-orchestrator to drive design through commit."

## Pre-Flight: Optimise the prompt (mandatory before any other step)

Before the start announcement above and before any other action in this skill, invoke `pandahrms:optimise-prompt` via the Skill tool with no arguments. It will either echo a one-line restatement (CLEAR) or ask the user to confirm intent (AMBIGUOUS / UNDER-SPECIFIED). Wait for it to return, then emit the start announcement and continue using the confirmed intent as the canonical request for the rest of the pipeline.

Skip this pre-flight only when:
- The current message is a direct reply to an AskUserQuestion the assistant just sent.
- The current message is a one-word ack ("yes", "ok", "no", "go", "continue").
- optimise-prompt is already running in the current call stack.
- Atlas is on the Fast Path or Resume Path AND the plan file already contains a confirmed intent line (no re-confirmation needed).

**Re-invoke on mid-pipeline fresh directives.** After the pre-flight, every user message received between Atlas steps MUST be classified per the [Follow-up Directives](../optimise-prompt/SKILL.md#follow-up-directives) section of optimise-prompt. Continuation replies, control acks, and in-flight clarifications are absorbed by the current step. Fresh directives (new verb, new top-level object, scope expansion, contradiction of the locked intent, mid-pipeline redirect) MUST pause the current step and re-invoke `pandahrms:optimise-prompt` before Atlas acts on them. Announce in B2 English which path Atlas took: replace-and-restart, add-and-continue, or switch-skill.

See [optimise-prompt](../optimise-prompt/SKILL.md) for the full algorithm.

## Fast Path (plan provided)

When `/atlas-pipeline-orchestrator` is invoked with a positional argument that is NOT `--resume` or `--skip-e2e`, treat it as a plan file path. Before skipping any steps:

1. Verify the path exists and is readable via the Read tool.
2. If the path is missing, unreadable, or does not contain a recognizable plan structure, STOP and respond verbatim: "Plan file '<path>' not found or unreadable. Provide a valid path or run /atlas-pipeline-orchestrator with no arguments to start fresh." Do not auto-create the file.

If validation passes, run Step 0 (Setup) FIRST, THEN announce "Executing existing plan -- skipping Steps 1-3, starting at Execute.", THEN skip directly to Step 4 (Execute). After Step 4, atlas continues through the remaining steps in order (5 audit, 6 simplify, 7 e2e, 8 user test, 9 follow-up if needed, 10 review, 11 commit).

- Step 0 runs in full -- codex detection and time tracking init still happen, even on Fast Path.
- On Fast Path entry, before Step 4 invokes pandahrms:execute-plan, atlas reconciles the `Codex execution mode:` line in the existing plan against the user's Step 0 choice:
  - If `codex_enabled` is true and the line is missing or set to `none`, overwrite it to `full` (the policy default). Announce: `"Codex enabled -- setting execution mode to 'full' (atlas policy default)."`
  - If `codex_enabled` is true and the line is already `full`, leave it alone.
  - If `codex_enabled` is false, force the line to `none` regardless of its previous value.

  Do NOT prompt the user with AskUserQuestion to confirm. The user can override by editing the line manually before Step 4 starts.

Fast Path still runs Step 5 (Spec<->Code audit) post-execute to catch drift between the pre-existing plan/spec and the freshly-implemented code.

## Resume Path

If invoked with `/atlas-pipeline-orchestrator --resume`:

1. Read the plan file's `## Atlas Progress` section to determine which steps completed and their timing.
2. Validate the section: it MUST have a parseable step table AND `Atlas started:` AND `Codex enabled:` lines. If any are missing or malformed, STOP and ask the user via AskUserQuestion: "Plan file's Atlas Progress section is malformed or unparseable. How would you like to proceed?" with options: "Start fresh (overwrite progress section)", "Abort so I can fix it manually". Do not auto-recover.
3. Announce: "Resuming atlas-pipeline-orchestrator from step N -- [step name]."
4. Continue from the next incomplete step with full time tracking.
5. If no plan file exists, announce: "No atlas-pipeline-orchestrator state found -- starting fresh." and begin from Step 0 (Setup), then Step 1.
6. If a plan file exists but has no `## Atlas Progress` section, STOP and prompt via AskUserQuestion: "Plan file exists but has no atlas-pipeline-orchestrator state. How would you like to proceed?" with canonical options: "Treat as Fast Path (start at Step 4)", "Start fresh (overwrite plan)", "Cancel". Do not silently fall through to Step 1.
7. After resuming, run all remaining incomplete steps in order through Step 11 inclusive. Resume mode does NOT change which steps run -- only which step the run starts at. The Step 11 termination rules apply identically to resumed runs.

## Scope Profile

After the design is approved (end of Step 1), classify the work into a **Scope Profile** so downstream steps can scale ceremony to feature size.

Two profiles. Apply in order, first match wins.

| Profile | Triggers (ALL must match for `small`) | What scales down |
|---------|---------------------------------------|------------------|
| **small** | • Touches <3 production source files (see [Production Source File](#production-source-file)), AND<br>• No schema migration / EF migration, AND<br>• No auth, multi-tenant boundary, billing, payment, or PII change, AND<br>• No breaking API change (additive endpoints/fields are fine), AND<br>• Plan estimate <8 tasks | • design-refinement skips the forced second-clarify (user lifecycle Step 4) and uses a single-question approve flow<br>• Spec<->Code audit (Step 5) runs sample-based instead of full sweep<br>• Simplify (Step 6) auto-skips unless Execute reported `DONE_WITH_CONCERNS` for any task<br>• Plan tightening: target 5-7 tasks, collapse strictly-sequential wiring, mechanical commands become Auto Gates (or Manual Gates if operator action is required) not tasks<br>• Design clarifying questions MUST batch into a single AskUserQuestion call when 2-4 are causally independent<br>• Aegis security review at Step 10 auto-skips (athena still runs) unless the design touched validation, permission, or data-state code |
| **normal** | Anything that doesn't match `small`. Includes auth, multi-tenant data, billing, payment, PII, schema migrations, breaking API changes, or >=3 production files. | Default ceremony: every step runs as documented. Tasks touching auth, multi-tenant, billing, schema, or PII get `Risk: high` tagging at plan-writing time. |

### How to set it

1. After Step 1 approval, before invoking spec routing, estimate file count and check the trigger criteria. Announce verbatim: `"Scope Profile: <profile> (<rationale>)."` -- always include the rationale.
2. Persist to the plan's Atlas Progress section once the plan is created (Step 3): `Scope Profile: small|normal`. Resumed runs read it back; do not re-classify on resume.
3. Do NOT proactively offer override via AskUserQuestion. Only re-classify if the user explicitly objects to the announced profile in their next message.

### Production Source File

For Scope Profile classification (the `small` criterion above), "production source file" means any file under the project's source tree (`src/`, `Pandahrms.*/` for BE) EXCLUDING:

- Generated types (`*.d.ts`, OpenAPI client output)
- Test files (`*.test.*`, `*.spec.*`, `*Tests.cs`)
- `.feature` spec files
- Storybook stories (`*.stories.*`)
- Config-only files (`.editorconfig`, `tsconfig.json`, `appsettings.*.json`, `*.csproj`)

EF migration files COUNT as production source files for this rule. CSS/Tailwind class changes inside an existing component file count as one file modification, not zero.

### Display in Development Summary

Step 8 displays the profile in the summary header so the user can see why ceremony was tightened or expanded:

```
Development Summary [Scope: small] (active work time, ...)
```

## Codex Usage

At Step 0 (Setup, including Fast Path and Resume Path), decide whether to use Codex for code implementation in this run. Two-step gate:

1. **Detect installation.** Run `command -v codex` via Bash. Treat as installed ONLY if exit code is 0 AND stdout is non-empty AND the resolved path exists.
2. **If installed, ask the user.** Call AskUserQuestion: `"Use Codex for code implementation in this run? (Codex implements, Claude reviews. Pick 'No' to keep Claude for everything.)"` with canonical options:
   - `"Yes, use Codex"` -- set `codex_enabled=true` in conversation context.
   - `"No, Claude does everything"` -- set `codex_enabled=false`.
3. **If not installed, skip the prompt.** Set `codex_enabled=false` automatically and continue silently.

Persist the result into the plan file's `## Atlas Progress` section once the plan exists, on a `Codex enabled: true|false` line, so resumed runs do not re-detect or re-prompt.

### Role split (active ONLY when `codex_enabled` is true)

| Layer | Owner | Steps |
|-------|-------|-------|
| **Implementation / fix** | Codex (`codex:codex-rescue`) | Step 4 implementer dispatch, Subagent Failure Handling re-dispatch on `insufficient reasoning`, code-fix follow-up triggered by Step 6 Simplify findings, Step 9 code-only follow-up iterations, Step 10 review-driven fixes |
| **Planning** | Claude (local `Agent` tool) | Step 1 design, Step 2 spec routing (delegates to spec-writing), Step 3 plan-writing |
| **Auditing / review of Codex output** | Claude (local `Agent` tool) | Step 5 Spec<->Code audit, Step 6 Simplify review pass, Step 10 athena + aegis review, second-stage spec-compliance reviewer for `Risk: high` tasks |
| **Exploration** | Claude (local `Agent` tool) | Step 7 Playwright e2e, ad-hoc codebase exploration during design/plan |

When `codex_enabled` is `false`, the split collapses -- Claude does both planning/audit AND implementation across all steps.

### Step 4 codex execution mode

Codex execution mode is binary: `full` (every implementer dispatches via `codex:codex-rescue`) or `none` (every implementer dispatches via the regular Agent tool). There is no in-between.

When `codex_enabled` is `true`, atlas sets the Step 4 [Codex Execution Mode](../execute-plan/SKILL.md#codex-execution-mode) to **`full`** and writes `Codex execution mode: full` into the plan file's `## Atlas Progress` section at plan creation (Step 3). The user can override to `none` by editing the line before Step 4 starts.

When `codex_enabled` is `false`, atlas writes `Codex execution mode: none`.

### Reviews never route to codex

When `codex_enabled` is `true`:

- Step 5 (Spec<->Code audit), Step 6 Simplify's review pass, and Step 10 (athena + aegis) all run via the local `Agent` tool -- not `codex:codex-rescue`. These are auditing tasks; Claude is the auditor.
- The second-stage spec-compliance reviewer dispatched by `pandahrms:execute-plan` for `Risk: high` tasks also runs via Agent, even when codex implemented the task. Codex output is reviewed by Claude; see `pandahrms:execute-plan` Reviewer Verdict Handling.
- Do NOT use the `READ-ONLY REVIEW` prefix in atlas. Atlas does not dispatch reviews to codex.

### Codex failure mid-run

If a `codex:codex-rescue` dispatch fails (timeout, runtime error, quota exhausted, non-zero exit): pause execution and ask the user via AskUserQuestion: `"Codex dispatch failed: [one-line error]. How would you like to proceed?"` with options:

- `"Switch to Claude for the rest of this run"` -- flip `codex_enabled` to `false`, persist `Codex enabled: true (switched to false at step N)` in the Atlas Progress section, flip the `Codex execution mode:` line to `none`, and re-dispatch the failing task via the regular `Agent` tool.
- `"Retry the same dispatch"` -- re-issue the codex dispatch once; if it fails again, this option is not offered.

### Start announcements

- `codex_enabled=true`: `"Codex on -- implementations via codex, reviews on Claude."`
- `codex_enabled=false` (either user chose No or codex not installed): silent. No announcement; proceed to Step 1 directly.

<HARD-GATE>
AUTHORITY HIERARCHY:

**Design time (Steps 1-3):** Discussion/decisions are the source of truth. If a discussion or decision diverges from the existing spec, UPDATE the spec before writing the plan. Never write a plan that contradicts the spec -- update the spec first, then plan from the updated spec.

**Execution time (Step 4):** The plan is the source of truth for each implementer subagent. But implementers MUST cross-check against the spec. If plan and spec disagree, STOP and report -- never silently pick one.

**Post-execution audit (Step 5):** The spec is the source of truth for what behavior must exist. The code is audited against the spec, not against the plan. If code and spec diverge, fix the code (loop back to Step 4) or update the spec (loop back to Step 2) per the rules in [Spec<->Code Audit](#spec-code-audit).

**Never silently reconcile.** When authority sources disagree and the loop-back rules cannot resolve them, STOP and prompt via AskUserQuestion: "Authority sources disagree -- [describe the conflict]. How would you like to resolve?" with canonical options: "Update spec to match implementation", "Fix code to match spec", "Abort atlas". Never silently pick a side; never just print a warning and continue.
</HARD-GATE>

<HARD-GATE>
NO COMMITS DURING EXECUTION OR REVIEW. Implementer subagents (Step 4, Step 9 follow-up code-only) and review agents (Step 10 athena + aegis) stage changes (`git add`) but never run `git commit`. Commits happen ONLY at Step 11 via `pandahrms:hermes-commit`.

GIT COMMAND ALLOWLIST. Implementer subagents, atlas itself, and audit/review agents may ONLY run these git verbs without user approval: `add`, `diff`, `status`, `log`, `show`, `ls-files`, `rev-parse`, `blame`. Any other git verb (`commit`, `push`, `checkout`, `restore`, `reset`, `stash`, `rebase`, `merge`, `branch`, `tag`, `clean`, `rm`, `mv`, `cherry-pick`, `revert`) requires explicit user approval via AskUserQuestion before invocation. The exception is Step 11 (`pandahrms:hermes-commit`) which is authorized to run `git commit` as its core operation. Read-only inspections of git state are always permitted.
</HARD-GATE>

## Pipeline

```dot
digraph atlas_pipeline {
    "Work request" [shape=doublecircle];
    "Plan file provided?" [shape=diamond];
    "Setup (codex + time + branch?)" [shape=box];
    "Design\n(design-refinement:\ngather -> clarify -> brainstorm -> impact)" [shape=box];
    "Design approved?" [shape=diamond];
    "Spec routing\n(ask if missing,\nalways write if exists)" [shape=box];
    "Plan\n(plan-writing)" [shape=box];
    "Execute\n(execute-plan)" [shape=box, style=filled, fillcolor=lightgreen];
    "Subagent failed?" [shape=diamond, style=filled, fillcolor=lightyellow];
    "Handle failure" [shape=box, style=filled, fillcolor=orange];
    "Spec <-> Code audit" [shape=box, style=filled, fillcolor=lightblue];
    "Audit gaps?" [shape=diamond];
    "Simplify\n(/simplify)" [shape=box, style=filled, fillcolor=lightblue];
    "Playwright e2e" [shape=box, style=filled, fillcolor=lightblue];
    "User test pause" [shape=diamond];
    "Follow-up scope?" [shape=diamond];
    "Code review\n(athena + aegis)" [shape=box, style=filled, fillcolor=lightblue];
    "Review pass?" [shape=diamond];
    "Commit\n(hermes-commit)" [shape=box, style=filled, fillcolor=lightgreen];
    "Done" [shape=doublecircle];

    "Work request" -> "Plan file provided?";
    "Plan file provided?" -> "Setup (codex + time + branch?)";
    "Setup (codex + time + branch?)" -> "Execute\n(execute-plan)" [label="yes (fast path)"];
    "Setup (codex + time + branch?)" -> "Design\n(design-refinement:\ngather -> clarify -> brainstorm -> impact)" [label="no"];
    "Design\n(design-refinement:\ngather -> clarify -> brainstorm -> impact)" -> "Design approved?";
    "Design approved?" -> "Design\n(design-refinement:\ngather -> clarify -> brainstorm -> impact)" [label="no, revise"];
    "Design approved?" -> "Spec routing\n(ask if missing,\nalways write if exists)" [label="yes"];
    "Spec routing\n(ask if missing,\nalways write if exists)" -> "Plan\n(plan-writing)";
    "Plan\n(plan-writing)" -> "Execute\n(execute-plan)";
    "Execute\n(execute-plan)" -> "Subagent failed?";
    "Subagent failed?" -> "Handle failure" [label="yes"];
    "Handle failure" -> "Execute\n(execute-plan)" [label="retry/skip"];
    "Handle failure" -> "Done" [label="abort, no changes"];
    "Subagent failed?" -> "Spec <-> Code audit" [label="no, all passed"];
    "Spec <-> Code audit" -> "Audit gaps?";
    "Audit gaps?" -> "Execute\n(execute-plan)" [label="fix code"];
    "Audit gaps?" -> "Spec routing\n(ask if missing,\nalways write if exists)" [label="update spec"];
    "Audit gaps?" -> "Simplify\n(/simplify)" [label="aligned"];
    "Simplify\n(/simplify)" -> "Playwright e2e";
    "Playwright e2e" -> "User test pause";
    "User test pause" -> "Follow-up scope?" [label="issues found"];
    "Follow-up scope?" -> "Design\n(design-refinement:\ngather -> clarify -> brainstorm -> impact)" [label="scope changes"];
    "Follow-up scope?" -> "Execute\n(execute-plan)" [label="code-only"];
    "User test pause" -> "Code review\n(athena + aegis)" [label="satisfied"];
    "User test pause" -> "Done" [label="abort"];
    "Code review\n(athena + aegis)" -> "Review pass?";
    "Review pass?" -> "Code review\n(athena + aegis)" [label="fixes needed"];
    "Review pass?" -> "Commit\n(hermes-commit)" [label="clean"];
    "Commit\n(hermes-commit)" -> "Done";
}
```

## Checklist

You MUST create a task for each of these items and complete them in order. Apply [Time Tracking](#time-tracking) to every step -- record start/end times and pause during user prompts.

0. **Setup** -- run [Codex Usage](#codex-usage) prompt and Time Tracking initialization (see [Time Tracking > On atlas start](#time-tracking)). This MUST complete before Step 1 begins. Persist results to conversation context until the plan file is created.

   **Branch reminder (conditional, pre-design).** Before invoking Step 1, check the working project's current branch with `git rev-parse --abbrev-ref HEAD`. If the branch matches one of `main`, `master`, `development`, `develop`, emit ONE short reminder via AskUserQuestion: `"You're on the <branch> branch -- this is usually protected. Atlas does not manage branches. Switch now (e.g. via pandahrms:branching) before Step 1 begins, or continue if this is intentional. How would you like to proceed?"` with options `"Continue on <branch>"` and `"Pause -- I'll switch branches first"`. On `Continue`, proceed to Step 1 immediately. On `Pause`, stop and wait for the user to switch and then say to resume. On any branch NOT in the protected list, skip the reminder silently and proceed directly to Step 1. Do NOT auto-create or auto-switch branches; do NOT re-prompt later in the pipeline; do NOT emit branch-related Manual Gates in any plan downstream.

1. **Design** -- invoke `pandahrms:design-refinement`. The skill runs an internal four-phase flow that maps to user lifecycle Steps 3-6:
   - (a) **Gather** -- read spec files, test files, and code files relevant to the request.
   - (b) **Forced repeat-back clarify** -- after context is loaded, repeat the user's intent in B2 English and ask the user to confirm or correct.
   - (c) **Brainstorm** -- propose 2-3 approaches with trade-offs and let the user pick.
   - (d) **Impact section** -- list before/after for code paths, DB schema/migrations, and business logic / business rules. The user must understand what changes in business rules. The impact section also folds in coverage thinking: list any spec scenarios the design implies but does not yet write, so spec-writing in Step 2 can pick them up.

   The skill saves an uncommitted design doc to `docs/pandahrms/designs/<...>.md` covering spec impact, test impact, implementation approach, and the impact section above. **Immediately after Step 1 approval, in this exact order:** (a) classify the work using [Scope Profile](#scope-profile), (b) announce the result verbatim per the format in Scope Profile > How to set it, (c) persist Scope Profile to conversation context (the plan file write happens at Step 3), (d) THEN proceed to Step 2.

2. **Spec routing** -- determine whether to write/update specs:
   - **UI-only auto-skip**: if the work changes ONLY: CSS/Tailwind classes, color tokens, layout primitives (flex/grid props), animation timings, breakpoint behavior, dark-mode tokens, or static copy in components -- AND does NOT change form validation logic, API calls, conditional rendering driven by data, role/permission checks, route guards, or any handler/effect logic -- announce `"Skipping spec-writing -- UI-only change with no business behavior impact"` and proceed to Step 3.
   - **Otherwise**: detect whether a relevant `.feature` file exists for the feature area in `pandahrms-spec` (use the file paths surfaced by design-refinement's gather phase in Step 1). Two sub-cases:
     - **Spec exists** -- always invoke `pandahrms:spec-writing` to update it. Do NOT ask the user; the design discussion is authoritative and the spec must reflect it. Announce: `"Updating existing spec at <path> with design decisions."`
     - **Spec missing** -- use AskUserQuestion: `"No spec exists for this feature. Would you like to write one before proceeding to the plan?"` with options `"Yes, write a spec"` and `"Skip specs"`. If yes, invoke `pandahrms:spec-writing`; if no, proceed to Step 3 with no spec.
   - When specs are written or updated, present them to the user for review before proceeding to Step 3.

3. **Plan** -- invoke `pandahrms:plan-writing`. The skill produces a plan with:
   - **Spec ref** on every business-behavior task (when specs exist)
   - **Test ref** on every production-code task with Red-before-Green ordering
   - **Depends on:** marker on every task (atlas reads this in Step 4 to parallel-dispatch)
   - **Risk:** tag on tasks that need second-stage review (auth, multi-tenant, billing, schema, PII)
   - **No commit steps** -- plans stage changes only; Step 11 owns commits

   At plan creation, atlas appends the `## Atlas Progress` section (see [On plan creation](#on-plan-creation-step-3)) with all 12 steps initialised.

4. **Execute plan** -- invoke `pandahrms:execute-plan`. The skill reads the plan, reads the `Codex execution mode:` line from the Atlas Progress section (atlas pre-set this at plan creation), groups tasks by `Depends on:`, parallel-dispatches independent batches (cap 5 per batch, Agent + codex counted together), runs single-stage review by default, and opts into second-stage spec-compliance review only for tasks tagged `**Risk:** high`. Implementer subagents stage changes but never commit. Time tracking records the step as a whole (wall-clock from first dispatch to last return). If a subagent fails, follow [Subagent Failure Handling](#subagent-failure-handling).

   **Step 4 completion is reached when one of:** (a) all dispatched tasks return success or skipped status, OR (b) the user chooses "Abort atlas" in the failure-handling flow. Time tracking ends at that moment regardless of outcome.

   **Plan-file mutations allowed during Step 4:** (i) checking off completed tasks (`[ ]` -> `[x]`), (ii) updating the Atlas Progress table, (iii) appending the Step 4 Task Timing block, (iv) annotating individual failed task entries with their final status (`failed-skipped`, `failed-aborted`, `succeeded-after-retry-N`). Do NOT modify task definitions, dependencies, risk tags, spec refs, or test refs during execution. Any task-definition change requires looping back to `pandahrms:plan-writing` first.

5. **Spec <-> Code audit** -- after Step 4 completes successfully, audit the implementation against the spec. See [Spec<->Code Audit](#spec-code-audit) for full mechanics, skip conditions, and resolution paths. Auto-loops back to Step 4 (fix code) or Step 2 (update spec) on gaps; only prompts the user on irreconcilable conflicts.

6. **Simplify (conditional)** -- once Step 5 has passed, decide whether to run `simplify` using these conditions in this exact precedence order (first match wins):
   - **Auto-skip** when Step 4 was aborted with no completed tasks. Announce: `"Skipping Simplify -- Step 4 aborted with no completed tasks."`
   - **Auto-skip** when Scope Profile is `small` AND no implementer returned `Status: DONE_WITH_CONCERNS`. Announce: `"Skipping Simplify -- small scope with no concerns flagged."`
   - **Run with severity filter** when Scope Profile is `small` AND at least one task returned `DONE_WITH_CONCERNS`. Tell the simplify subagents to report only severity >= medium findings; ignore cosmetic-only suggestions (comment trims, helper extractions of <10 lines, file-level reorderings).
   - **Run normally** when Scope Profile is `normal`, regardless of `DONE_WITH_CONCERNS` status.

   All resulting changes remain uncommitted -- commits happen at Step 11.

7. **Playwright e2e (conditional)** -- if Playwright is configured for the working project, run an e2e pass on the changes from this session. See [Playwright E2E Step](#playwright-e2e-step) for the detection and execution rules. Skip silently when Playwright isn't installed.

8. **User test pause** -- present the Development Summary. If the plan file's `## Atlas Progress` section has an `### Acknowledged Gaps` block, surface each gap with: `"**Acknowledged gaps to verify manually:** [gap list]."` Then ask via AskUserQuestion: `"Please test your changes locally. What did you find?"` with canonical options: `"Looks good -- proceed to code review"`, `"Found issues -- I'll describe them"`, `"Abort -- discard this run"`.

   - On `"Looks good -- proceed to code review"`: proceed directly to Step 10 (Step 9 is bypassed).
   - On `"Found issues -- I'll describe them"`: wait for the user's next message describing the issue, then proceed to Step 9.
   - On `"Abort -- discard this run"`: announce `"Atlas aborted at user-test stage. Staged changes remain uncommitted. Use git restore --staged to discard or hermes-commit later to keep them."` and terminate.

9. **Follow-up loop** -- the user has described issues. Classify the scope of the change:
   - **Scope change** (the user's report implies a new feature, removed feature, changed business rule, or different approach) -- loop back to Step 1. Before re-invoking design-refinement, run a context-refresh: re-read the design doc and any spec/test/code files that may have changed since execute. If files have changed since the original Step 1 gather, re-run gather; otherwise jump straight to brainstorm. Announce: `"Looping back to design -- scope change detected: [one-line summary]."`
   - **Code-only change** (the user's report is a bug fix, typo, behavior mismatch with existing spec, or styling tweak with no new business rule) -- loop back to Step 4. Generate a minimal fix-plan (1-3 tasks) and dispatch via pandahrms:execute-plan. Announce: `"Looping back to execute -- code-only fix: [one-line summary]."`

   Classification is decided by atlas based on the user's described issue. If unsure, ask via AskUserQuestion: `"Is this a scope change or a code-only fix?"` with canonical options `"Scope change (re-design)"`, `"Code-only fix"`, `"Abort atlas"`. After the loop-back completes, atlas re-enters the audit -> simplify -> e2e -> user-test cycle. There is no cap on follow-up iterations; the user terminates the loop by choosing `"Looks good -- proceed to code review"` at Step 8.

10. **Code review (athena + aegis)** -- run code review explicitly before commit:
    - **athena-code-review** -- invoke `pandahrms:athena-code-review`. The skill reviews changed files against the standard checklist (TDD compliance, SOLID, quality, format/lint/tests). It can fix issues directly (no commits) and runs `/simplify` on its own findings.
    - **aegis-security-review** -- invoke `pandahrms:aegis-security-review` if EITHER:
      - Scope Profile is `normal`, OR
      - The design touched auth, multi-tenant, billing, payment, PII, validation, permission, or data-state code.

      Otherwise auto-skip with announcement: `"Skipping Aegis -- small scope with no security-sensitive touches."`

    Both reviewers stage their fixes but do not commit. If either reviewer reports unresolved findings the user must decide on, prompt via AskUserQuestion with the findings and canonical options: `"Apply the suggested fixes and re-run review"`, `"Accept findings as known limitations"`, `"Abort atlas"`. On `"Apply the suggested fixes and re-run review"`, re-dispatch the relevant reviewer; on accept, persist the findings to the plan's `### Acknowledged Gaps` block and proceed to Step 11. On abort, terminate with announcement: `"Atlas aborted at code-review stage. Staged changes remain uncommitted."`

11. **Commit** -- invoke `pandahrms:hermes-commit`. The skill verifies a clean working tree (0 test failures, 0 lint errors, 0 format errors), plans atomic commits across the staged changes, and executes them. hermes-commit only commits; review already ran at Step 10. Time tracking ends when hermes-commit returns.

    **Atlas terminates the moment hermes-commit reports successful commits.** Emit the final summary line: `"Atlas complete -- N commit(s) created on branch <branch>. Push when ready."` After this line is sent, atlas is fully terminated.

    After termination, do NOT: re-invoke any skill, offer to `/schedule` any agent, propose follow-up work, summarize what was done a second time, suggest next steps, comment on the diff, or continue producing analysis. The next user message restarts evaluation from the system prompt; treat it as unrelated unless it begins with `/atlas-pipeline-orchestrator`, `/atlas-pipeline-orchestrator <plan-path>`, or `/atlas-pipeline-orchestrator --resume`.

## Time Tracking

Track **active work time** across the full atlas run -- time spent by Claude doing work, excluding time waiting for user input or blocked on external factors. Display a summary at Step 8 (user-test handoff) and update it after Step 11 (commit).

### How to track

1. **On step start** -- record the current time (use `date +%s` via Bash)
2. **Before any user prompt** -- record a pause timestamp. This includes:
   - AskUserQuestion calls (design approval, spec routing decisions, audit conflict prompts, user-test response, follow-up classification, code-review findings prompts, subagent-failure prompts)
   - Any blocker requiring user action (e.g., environment issue, missing access)
   - Presenting results and waiting for user to respond
3. **After user responds** -- record a resume timestamp. Add the paused duration to the step's excluded time.
4. **On step completion** -- calculate: `duration = (end - start) - total_excluded_time`. Display: `"Step N completed in Xm Ys (active work)"`
5. **At Step 8 (user-test handoff)** -- display a summary:

```
Development Summary [Scope: small] (active work time, excludes user-wait)
===========================
Design                       --  12m 34s
Spec routing                 --   8m 21s
Plan                         --  15m 02s
Execute                      --  18m 14s
  Dispatch-prep              --     0m 21s (1.9%)
  Subagent-active            --  17m 53s (98.1%)
    Test runtime sum         --   3m 12s
    Risk:high tasks          --   0 of 7
    Idle-wait observed       --     1m 19s (Batch 2: T3 waited on T2)
Spec <-> Code audit          --   1m 30s
Simplify                     --     skipped (small, no concerns)
Playwright e2e               --   2m 06s
===========================
Through user-test (active)   --     58m 47s
Total wall-clock so far      --  1h 32m 11s
User-wait time so far        --     33m 24s
```

6. **At Step 11 termination** -- append the post-test segment (Code review, Commit) to the summary and report the grand total.

### What counts as paused time

| Paused (exclude from timing) | Active (include in timing) |
|------------------------------|---------------------------|
| Waiting for user to answer AskUserQuestion | Claude processing after user responds |
| User reviewing a design doc or spec | Designing, writing specs, planning |
| User testing the staged changes (between Step 8 and the user's reply) | Subagent execution |
| User fixing an environment issue | Reading files, running commands |
| Blocked on external dependency | -- |

### Implementation

Use the plan file as the single source of truth for both progress tracking and timing. Before the plan file exists (Steps 1-2), hold timestamps in conversation context. Once the plan is created (Step 3), persist everything into the plan file.

Use the Read and Write tools for all plan file I/O. Only use Bash for `date +%s`.

**On atlas start:**

1. Run `date +%s` in Bash to get the epoch
2. Hold the atlas start time and step timestamps in conversation context until the plan file is created

### On plan creation (Step 3)

Append a `## Atlas Progress` section to the plan file. Backfill timing for whichever of Steps 1-2 actually ran in this session. For Fast Path entries (Steps 1-3 skipped), mark those rows as `skipped (Fast Path)` with no duration. Use the canonical skip-reason strings in the [Skipped duration format](#skipped-duration-format) section below.

**Compose the full block first (step table + all metadata lines + empty Acknowledged Gaps block) and write it in a SINGLE Write tool call.** Do not split into multiple writes -- a single write avoids interleaving with concurrent reads and keeps the Atlas Progress section atomic.

```markdown
## Atlas Progress

| Step | Status | Duration |
|------|--------|----------|
| 1. Design | done | 12m 34s |
| 2. Spec routing | done | 8m 21s |
| 3. Plan | done | 15m 02s |
| 4. Execute | pending | -- |
| 5. Spec <-> Code audit | pending | -- |
| 6. Simplify | pending | -- |
| 7. Playwright e2e | pending | -- |
| 8. User test pause | pending | -- |
| 9. Follow-up loop | pending | -- |
| 10. Code review | pending | -- |
| 11. Commit | pending | -- |

Atlas started: 1718000000
Codex enabled: true
Codex execution mode: full
Playwright e2e: auto-detect
Scope Profile: small

### Acknowledged Gaps

(Populated only when the user chose "Accept findings as known limitations" during Step 10, or "Proceed anyway -- mark as known gap" during Step 5. One bullet per gap. Step 8 surfaces this list to the user.)
```

**On each step completion:**

1. Run `date +%s` in Bash to get the timestamp
2. Use the **Read** tool to load the plan file. **If the plan file is missing or unreadable, STOP and respond verbatim: "Plan file '<path>' is missing or unreadable. atlas cannot continue without state. Restore the file or abort." Do NOT auto-recreate the plan file.**
3. Update the step's row in the Atlas Progress table (status and duration)
4. Use the **Write** tool to save the plan file back

### Skipped duration format

For skipped steps, the Duration column shows exactly one of these canonical strings (substitute the bracketed value where indicated):

- `skipped (small)` -- Scope Profile is small and the step's small-skip rule applied
- `skipped (no specs)` -- no specs exist or were created in this session
- `skipped (BE-only)` -- session changes have no FE-visible surface (Step 7 only)
- `skipped (Playwright not configured)` -- Step 7 only
- `skipped (--skip-e2e)` -- user requested e2e skip via flag or progress section
- `skipped (Fast Path)` -- step bypassed because /atlas-pipeline-orchestrator was invoked with a plan-file path
- `skipped (aborted - nothing to test)` -- Step 4 ended with no completed tasks
- `skipped (UI-only)` -- Step 2 only, when the UI-only auto-skip applied
- `skipped (bypassed - user satisfied)` -- Step 9 only, when user picked "Looks good" at Step 8

Do not paraphrase these strings. If a new skip reason appears, add it to this list before using it.

**On task completion (Step 4):**

When a subagent completes a plan task, update the task's checkbox in the plan file from `- [ ]` to `- [x]`, then update the Atlas Progress table for Step 4's running duration.

Active duration = `(end - start) - sum(resume - pause for each pause)`

Format durations by computing in your reasoning: `Xm YYs`. Skipped steps use the canonical strings from [Skipped duration format](#skipped-duration-format) -- never the bare `-- skipped` placeholder.

### Execution step timing

Step 4 (execute plan) is tracked as a single step at the orchestrator level (wall-clock from first subagent dispatch to last subagent completion), AND with per-task / per-batch breakdown for benchmarking.

**Roll-up duration** -- the headline number shown in the Development Summary header for Step 4 is wall-clock from first dispatch to last return.

**Breakdown** -- pandahrms:execute-plan populates a `### Step 4 Task Timing` block beneath the Atlas Progress table as each batch completes. See [pandahrms:execute-plan Step 6 Timing Breakdown](../execute-plan/SKILL.md#step-6-timing-breakdown) for the exact schema (per-task: dispatcher, type, wall-clock, test runtime, risk, status; per-batch: prep time, wall-clock, idle-wait notes).

**Surfacing in the Development Summary** -- after the Execute row, append a sub-block summarizing the breakdown so the user gets benchmarking data without opening the plan file. (Note: the execute-plan skill uses its own internal "Step 6" naming for the breakdown block name; atlas treats that as the breakdown of atlas Step 4.)

```
Execute                      --  18m 14s
  Dispatch-prep              --     0m 21s (1.9%)
  Subagent-active            --  17m 53s (98.1%)
    Test runtime sum         --   3m 12s
    Risk:high tasks          --   1 of 8 (T4 -- 3m 22s incl. 0m 41s review)
    Idle-wait observed       --   2m 03s (Batch 4: T5 waited on T4)
```

If a field can't be measured (e.g. a single-task batch has no idle-wait), omit the line rather than show `0`.

## Subagent Failure Handling

When a subagent returns `Status: BLOCKED`, `Status: NEEDS_CONTEXT`, or any non-success exit (build error, test failure, merge conflict):

1. **Pause execution** -- wait for all in-flight subagents in the current parallel batch to return, then do not dispatch any further batches until the user decides how to proceed.
2. **Check the retry counter** -- a single task may be re-dispatched at MOST 3 times across all classifications, counted in conversation context per task name. If the failing task has already been re-dispatched 3 times, do NOT offer the "Re-dispatch with added context" or "Re-dispatch with stronger model" options. Only offer "Send back to plan/spec", "Skip and continue", and "Abort atlas".
3. **Classify the failure** -- before offering retry, identify the failure mode. This avoids blind retries that waste time:
   - **Missing context** (typically `Status: NEEDS_CONTEXT`) -- the implementer prompt was missing a file, type, scenario, or env var the task requires. Resolution: re-dispatch with the missing context added.
   - **Insufficient reasoning** -- the subagent attempted the task but produced incorrect or incomplete code (e.g. failed verification it should have passed). Resolution: re-dispatch via `codex:codex-rescue` if `codex_enabled` is true. If `codex_enabled` is false, re-dispatch via the regular Agent tool with explicit user-supplied guidance.
   - **Task too large** -- the subagent partially completed work but the scope exceeds what fits in one dispatch. Resolution: return to `pandahrms:plan-writing` to split the task; do not retry as-is.
   - **Plan or spec error** (typically `Status: BLOCKED` with conflict details) -- the plan and spec disagree, the spec is internally contradictory, or the plan references something that doesn't exist. Resolution: escalate to the user; loop back to `pandahrms:spec-writing` or `pandahrms:plan-writing` as appropriate.
4. **Present the error and classification** -- show the failing subagent's name, task description, returned status, error output, your classification, and the current retry count for that task.
5. **Ask the user** via AskUserQuestion: "Subagent '[task name]' returned [status] -- classified as [missing context / insufficient reasoning / task too large / plan or spec error]. How would you like to proceed?" with options matched to the classification (omit retry options if the 3-retry cap has been hit):
   - **"Re-dispatch with added context"** (missing context) -- you provide the missing piece, atlas re-dispatches the same task and increments the retry counter.
   - **"Re-dispatch with stronger model"** (insufficient reasoning) -- atlas re-dispatches via codex per the resolution rule above and increments the retry counter.
   - **"Send back to plan/spec"** (task too large or plan/spec error) -- atlas pauses execute, loops back to the relevant skill, then resumes; this resets the retry counter for that task.
   - **"Skip and continue"** -- note the failed task in the conversation and proceed with remaining tasks.
   - **"Abort atlas"** -- stop execution, display the Development Summary with the Execute step marked failed, and end with: "Atlas aborted. Completed tasks remain uncommitted. Run /hermes-commit when ready or discard with git restore."

When the implementer returns `Status: DONE_WITH_CONCERNS`, do NOT silently mark the task complete. Surface the concerns via AskUserQuestion using these canonical option labels: "Accept (mark complete)", "Re-dispatch with guidance", "Escalate to design/plan".

Failures do not alter the step-level Development Summary other than annotating the Execute step's outcome (e.g. `Execute -- 18m 14s (1 task failed, skipped)`).

## Spec <-> Code Audit

Step 5 runs an audit that compares the spec against the freshly-implemented code. The audit catches gaps that only show up once code exists -- incomplete handlers, missed conditional branches, dropped validation rules.

### Skip Condition

Skip only when there are NO specs in the affected area. Detect this by:
- No `.feature` files were created or updated in this session, AND
- No in-scope `.feature` files exist for the feature area in `pandahrms-spec`

This covers UI-only work and the "skip specs" path. Announce: `"Skipping Spec <-> Code audit -- no specs for this feature."`

### Sample mode (small scope)

When [Scope Profile](#scope-profile) is `small`, run the audit in sample mode:

- Read every in-scope `.feature` file.
- Sample up to 5 scenarios per file (the first 3 + any 2 tagged `validation`, `permission`, or `boundary`).
- For each sampled scenario, locate the code path that should implement it and verify the implementation covers the Given/When/Then.

Announce when sample mode is in effect: `"Spec <-> Code audit running in sample mode (small scope) -- sampling up to 5 scenarios per file."`

For `normal` profile, run the full sweep (every scenario in every in-scope file).

### How to audit

Spec <-> Code audit is an audit task -- ALWAYS run inline via the local `Agent` tool, regardless of `codex_enabled` or Scope Profile. Reviews stay on Claude in this pipeline. Do NOT route to `codex:codex-rescue`; do NOT use the `READ-ONLY REVIEW` prefix.

Inline review steps:

1. Read every in-scope `.feature` file (full content for `normal`; sampled per the rule above for `small`).
2. For each scenario, identify the production code path it covers. Use the test file names from the plan's Test refs as a starting point; the spec scenario -> test -> code chain is the audit trail.
3. Read the relevant code files (via Read) and verify the implementation matches the Given/When/Then steps. Look specifically for:
   - **Missing branches** -- scenario covers an error path that the code never enters.
   - **Wrong outcomes** -- scenario expects "request rejected" but code returns success.
   - **Validation drift** -- scenario specifies a range/format/constraint the code doesn't enforce.
   - **Authorization drift** -- scenario specifies a role check the code skipped.
   - **Cascade misses** -- scenario implies a side-effect (audit log, notification, related-record update) that the code doesn't trigger.
4. Generate a findings report partitioned by scenario. Do NOT prompt the user with AskUserQuestion at this point. Use the report internally to drive automatic loop-backs per Handling Results below. Surface findings to the user only via the announcement strings specified in Handling Results.

### Handling Results

- **All scenarios covered correctly** -- announce `"Spec <-> Code audit: code matches all scenarios. Proceeding to Simplify."` Go to Step 6.
- **Gaps found** -- auto-resolve where possible; only ask the user on irreconcilable conflicts.
  - **Code missing a scenario** -- loop back to Step 4. Generate a minimal fix-task list (1-3 tasks) and dispatch via `pandahrms:execute-plan`. Announce: `"Spec <-> Code audit found N missing scenarios in code -- looping back to Execute with fix tasks."`
  - **Code implements behavior the spec doesn't describe** -- this is usually fine (the spec is intentionally minimal) BUT if the behavior is user-visible and load-bearing, loop back to Step 2 (Spec routing) to add a scenario. Announce: `"Spec <-> Code audit found N undocumented behaviors -- updating spec."` On unclear cases, fall through to the irreconcilable-conflict branch.
  - **Scenario and code disagree on outcome** -- this is an authority conflict (per the [Authority Hierarchy](#hard-gate) HARD-GATE). Prompt via AskUserQuestion: `"Spec <-> Code conflict: scenario '[name]' expects [X], code does [Y]. How would you like to resolve?"` with canonical options: `"Fix code to match spec"` (loops back to Step 4), `"Update spec to match code"` (loops back to Step 2), `"Proceed anyway -- mark as known gap"` (appends to `### Acknowledged Gaps` and continues to Step 6), `"Abort atlas"`.

When the user selects `"Proceed anyway -- mark as known gap"`, append a single bullet to the `### Acknowledged Gaps` block of the plan file's Atlas Progress section: `- [Step 5 conflict description] -- acknowledged at [ISO 8601 timestamp].`

After any loop-back resolution (fix code OR update spec), atlas re-runs Step 5 on the freshly-changed state. There is no iteration cap on Step 5; the loop terminates when the audit returns zero gaps OR the user picks `"Proceed anyway"` / `"Abort atlas"` on an irreconcilable conflict.

Do not proceed to Step 6 while real gaps remain unresolved.

## Playwright E2E Step

Step 7 runs an end-to-end pass with Playwright after `simplify` and before handing the run to the user for testing, but only when Playwright is actually configured for the project. Catches UI-level regressions on this session's changes before the user takes over.

### Detection

Check for Playwright in this order. The first match wins; stop checking once one is found.

1. `playwright.config.ts`, `playwright.config.js`, or `playwright.config.mjs` exists at the working project's root.
2. The project's `package.json` has `@playwright/test` (or `playwright`) under `dependencies` or `devDependencies`.
3. At least one `mcp__playwright__*` tool call has succeeded (returned a non-error result) earlier in the CURRENT atlas conversation. Authorization in a prior session does not count.

If none match, announce `"Skipping Playwright e2e -- not configured for this project."` and proceed to Step 8. Do not install Playwright on the user's behalf.

### Scope: changes made this session

Run e2e only against the user-visible flows touched in this session, not the entire project's e2e suite. Identify scope from the staged diff:

1. Run `git diff --name-only --cached` (and `git diff --name-only` for unstaged) to list files changed in this session.
2. Map FE files to user-visible routes/components. Examples:
   - `src/routes/admin/appraisals/**` -> the appraisals admin pages.
   - `src/lib/components/forms/<Form>.svelte` -> any page that mounts that form.
3. Map BE files via the consuming endpoints, then to the FE pages that call them.
4. If no FE-visible change is detected (BE-only refactor, EF migration, internal helper), announce `"Skipping Playwright e2e -- session changes have no FE-visible surface."` and proceed.

### Execution

Use the `mcp__playwright__*` MCP tools (browser automation) -- not the project's offline `playwright test` runner -- so the user can watch the pass. Load the toolset via `ToolSearch` with this exact query string (do NOT shorten, paraphrase, or use ellipses):

```
select:mcp__playwright__browser_navigate,mcp__playwright__browser_click,mcp__playwright__browser_snapshot,mcp__playwright__browser_fill_form,mcp__playwright__browser_type,mcp__playwright__browser_press_key,mcp__playwright__browser_console_messages,mcp__playwright__browser_network_requests,mcp__playwright__browser_wait_for,mcp__playwright__browser_take_screenshot
```

For each scoped flow:
1. Navigate to the route the changed code controls (`browser_navigate`).
2. Execute the golden-path interaction (click, fill, submit) per the design doc's "happy path" description.
3. Take a snapshot (`browser_snapshot`) so the result is visible to the user.
4. Test exactly one failure mode that the design's "unhappy path" section or any spec scenario tagged `validation`, `permission`, or `error` explicitly defines. If no such failure mode is documented, run only the golden path and note `no documented failure mode -- only golden path tested` in the report.
5. Capture console errors (`browser_console_messages`) and network failures (`browser_network_requests`).

### Reporting

After the e2e pass, append a `### Playwright E2E` block to the Development Summary in Step 8:

```
### Playwright E2E

| Flow | Result | Notes |
|------|--------|-------|
| <route or page> | pass | golden path + 1 failure-mode |
| <route or page> | fail | <one-line failure summary> |
```

If any flow failed, surface the failures in plain language to the user as part of the Step 8 user-test prompt -- they decide whether the failure is real (loop back via Step 9) or a flaky test (proceed). Do NOT auto-rerun failed flows. Report each failure once; if the user asks for a rerun, run it exactly once and report the second result. Never run a flow more than twice without explicit user direction.

### Skip conditions

Skip Step 7 entirely (with announcement) when any of these hold:
- Playwright is not configured (per Detection).
- This session's changes have no FE-visible surface.
- The user types `/atlas-pipeline-orchestrator --skip-e2e` or has set `Playwright e2e: skip` in the plan's `## Atlas Progress` section.
- Step 4 was aborted with no completed tasks (nothing to test).

## Red Flags

| Thought | Reality |
|---------|---------|
| "I'll skip the design step since the user described what they want" | Step 1 is mandatory. pandahrms:design-refinement enforces approval before implementation. |
| "I'll just invoke pandahrms:execute-plan on a plan that has no Depends on: markers" | Reject the plan and loop back to pandahrms:plan-writing. Missing markers serialize the run -- atlas can't parallel-dispatch. |
| "I'll mark every task Risk: high to be safe" | Atlas defaults to single-stage review. Tag `Risk: high` only on auth, multi-tenant, billing, schema, PII, or design-flagged risky tasks. |
| "I'll skip the Scope Profile classification -- it's obvious" | No. Always announce the profile after Step 1 with the rationale. The profile gates design's forced second-clarify, Spec<->Code audit sample mode, Simplify, and aegis-at-Step-10 -- silent classification means downstream behavior changes without an audit trail. |
| "Plan has 12 numbered tasks for a 1-property feature -- looks thorough" | Over-decomposition. Use the Collapse Rule in pandahrms:plan-writing: strictly-sequential wiring tasks merge into one. For small scope, target 5-7 tasks. |
| "I'll number `pnpm openapi-ts` as Task 9" | Mechanical commands are Gates, not tasks. They don't run through implementer subagents. Use Auto Gate for local mechanical commands (regen, local EF migrate, local docker rebuild) and Manual Gate only for genuine operator actions (prod deploy, DBA-led migration). |
| "I'll mark `pnpm openapi-ts` as Manual Gate so the user can confirm the regen finished" | No. Local mechanical commands are Auto Gates -- the orchestrator runs them automatically with a one-line announcement. The user's BE-then-deploy-then-FE rule is a sequencing rule, not a pause rule. |
| "Discussion decided X but spec still says Y, I'll implement X" | Stop. Update the spec to reflect the decision FIRST (Step 2 spec routing), then plan. Never leave the spec outdated. |
| "Spec exists -- I'll ask the user whether to update it" | No. When the spec exists, Step 2 ALWAYS updates it from the design decisions. Only ask the user when the spec is missing. |
| "Spec <-> Code audit found a missing scenario -- I'll AskUserQuestion how to resolve" | Don't ask. Code-missing-scenario auto-loops back to Step 4 with a fix-task list. Only ask the user when the spec and code disagree on outcome (irreconcilable conflict). |
| "User said the feature works -- I'll skip code review and commit directly" | No. Step 10 runs athena (and aegis when applicable) regardless of user satisfaction. The user-test pass at Step 8 covers behavior; Step 10 covers code quality and security. |
| "I'll silently invoke aegis at Step 10 even on small scope" | No. Aegis at Step 10 auto-skips on `small` scope UNLESS the design touched validation, permission, or data-state code. Announce the skip with the canonical string. |
| "hermes-commit will re-run athena on the diff, so Step 10 is optional" | No. hermes-commit only commits. Step 10 is the only place athena runs in the pipeline. Skipping it commits unreviewed code. |
| "I'll let an implementer commit since the plan says to commit" | Plans should not contain `git commit` steps. pandahrms:execute-plan strips them on dispatch. Step 11 owns commits. |
| "Codex is installed -- I'll route the Spec<->Code audit through codex too, for second-opinion depth" | No. Reviews always run on Claude (per Codex Usage role split). Codex never reviews its own output. |
| "I'll prefix the Spec<->Code audit dispatch with READ-ONLY REVIEW" | No. Atlas does not dispatch reviews to codex, so the read-only prefix has no purpose here. |
| "Codex is enabled but I'll ask the user which mode they want before Step 4" | No -- atlas pre-sets `Codex execution mode: full` when `codex_enabled` is true. The user can edit the line manually to override; do not prompt. |
| "I'll let Claude implement Step 4 tasks even though codex is enabled" | No. When `codex_enabled` is true, Step 4 implementations route to codex per the role split. Claude reviews codex's output, not produces production code. |
| "User said 'looks good' to the user-test prompt -- I'll terminate atlas and let them commit manually" | No. Atlas drives the full lifecycle through commit. On `"Looks good -- proceed to code review"`, atlas continues to Step 10 (review) and Step 11 (commit). Termination is at the end of Step 11, not Step 8. |
| "User reported a styling tweak -- I'll loop back to design (Step 1)" | No. Styling tweaks with no business-rule change are code-only fixes. Loop back to Step 4 with a minimal fix-plan. Only loop to Step 1 when the report implies a scope change (new feature, removed feature, changed business rule, different approach). |
| "Branch is `feature/foo` -- I'll show the branch reminder anyway" | No. Branch reminder only fires on `main`, `master`, `development`, `develop`. Any other branch skips the reminder silently. |

## When to Use

- Any work request that needs design, specs, plan, execution, review, OR commit -- atlas is the single entry point.
- Natural-language triggers: "start new work", "build a feature", "add functionality", "fix a bug", "refactor X", "brainstorm", "design", "write a plan", "execute the plan", "ship this", "do the whole flow".
- Slash invocations: `/atlas-pipeline-orchestrator`, `/atlas-pipeline-orchestrator <plan-path>` (Fast Path), `/atlas-pipeline-orchestrator --resume`, `/atlas-pipeline-orchestrator --skip-e2e`.

## When NOT to Use

- Quick fixes that don't need design (typos, config-only changes, dependency bumps, formatting fixes) -- handle directly without the orchestrator.
- Writing specs for existing functionality without a new design -- use `pandahrms:spec-writing` directly.
- Pure code review of working-tree changes -- use `pandahrms:athena-code-review` directly.
- Pure security audit -- use `pandahrms:aegis-security-review` directly.
- Committing already-reviewed changes that did NOT go through atlas -- use `pandahrms:hermes-commit` directly.
