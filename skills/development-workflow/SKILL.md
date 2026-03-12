---
name: development-workflow
description: Use INSTEAD of superpowers:brainstorming when starting any development work in a PandaHRMS project - features, bug fixes, refactors, or any change that needs design and specs before implementation
---

# PandaHRMS Development Workflow

## Overview

Orchestrates the correct development pipeline for PandaHRMS projects. This skill exists because `superpowers:brainstorming` hardcodes its terminal state to invoke `writing-plans` directly, which skips the required `pandahrms:spec-writing` step.

**Use this skill INSTEAD of invoking `superpowers:brainstorming` directly** in any PandaHRMS project.

**Announce at start:** "I'm using the development-workflow skill to orchestrate the PandaHRMS pipeline."

<HARD-GATE>
OVERRIDE: When the brainstorming skill completes and instructs you to "invoke writing-plans", do NOT invoke writing-plans. Instead, return to THIS pipeline and ask the user whether they want to write specs first.

The brainstorming skill says: "The ONLY skill you invoke after brainstorming is writing-plans." In PandaHRMS projects, this instruction is OVERRIDDEN by this pipeline. You MUST ask the user before proceeding.
</HARD-GATE>

## Pipeline

```dot
digraph pipeline {
    "Work request" [shape=doublecircle];
    "Invoke brainstorming" [shape=box];
    "Design approved + committed" [shape=diamond];
    "Write specs?" [shape=diamond];
    "Invoke spec-writing" [shape=box];
    "Specs approved + committed" [shape=diamond];
    "Invoke writing-plans" [shape=doublecircle];

    "Work request" -> "Invoke brainstorming";
    "Invoke brainstorming" -> "Design approved + committed";
    "Design approved + committed" -> "Invoke brainstorming" [label="no, revise"];
    "Design approved + committed" -> "Write specs?" [label="yes"];
    "Write specs?" -> "Invoke spec-writing" [label="yes"];
    "Write specs?" -> "Invoke writing-plans" [label="skip"];
    "Invoke spec-writing" -> "Specs approved + committed";
    "Specs approved + committed" -> "Invoke spec-writing" [label="no, revise"];
    "Specs approved + committed" -> "Invoke writing-plans" [label="yes"];
}
```

## Checklist

You MUST create a task for each of these items and complete them in order:

1. **Brainstorm the design** -- invoke `superpowers:brainstorming` to explore the idea, propose approaches, present design, and commit the design doc. When brainstorming tells you to "invoke writing-plans", STOP and return here instead.
2. **Ask: Write specs?** -- use AskUserQuestion to ask: "Would you like to write Gherkin specs before proceeding to the implementation plan?" with options: "Yes, write specs" and "Skip specs". Users may skip if the session is purely exploratory or an open discussion without concrete implementation targets.
3. **Write Gherkin specs** (if not skipped) -- invoke `pandahrms:spec-writing` to write or update specs in pandahrms-spec based on the approved design doc.
4. **Create implementation plan** -- invoke `superpowers:writing-plans` to plan the implementation based on the approved design and specs.

## Critical Override: Brainstorming Terminal State

The `superpowers:brainstorming` skill's step 6 says:

> "Transition to implementation -- invoke writing-plans skill to create implementation plan"

In PandaHRMS projects, this step is REPLACED by:

> "Ask the user whether to write specs -- if yes, invoke pandahrms:spec-writing to write Gherkin specs based on the approved design. If the user skips, proceed directly to writing-plans."

Only after the user has been asked (and specs are written if requested) should you invoke `superpowers:writing-plans`.

## Critical Override: Always Use Parallel Session

When `superpowers:writing-plans` completes and offers the execution choice between "Subagent-Driven (this session)" and "Parallel Session (separate)", you MUST always select **Parallel Session (separate)**.

Do NOT offer or use "Subagent-Driven (this session)" in PandaHRMS projects. After the plan is saved, guide the user to open a new session with `superpowers:executing-plans`.

## Critical Override: Executing Plans Behavior

When executing a plan via `superpowers:executing-plans` in PandaHRMS projects:

1. **Never commit during execution** -- Do NOT run `git commit` after individual tasks or batches. All changes remain uncommitted until the entire plan is complete. Committing is a separate step handled by `pandahrms:review-and-commit` after all work is done.
2. **Finish all tasks without stopping** -- Do NOT stop after batches of 3 for review. Execute ALL tasks in the plan continuously from start to finish. Only stop if you hit an actual blocker (missing dependency, test fails repeatedly, unclear instruction).

## Red Flags

| Thought | Reality |
|---------|---------|
| "Brainstorming said invoke writing-plans" | This pipeline overrides that for PandaHRMS projects |
| "I'll skip specs without asking" | Always ask the user. They decide whether specs are needed. |
| "The design doc is enough" | Design doc captures WHAT. Specs capture BEHAVIOR. Ask the user. |
| "This change is too small for specs" | Don't assume -- ask the user. They may still want specs. |
| "Let me use subagent-driven execution" | PandaHRMS always uses Parallel Session (separate). No exceptions. |
| "Let me commit after this task" | Never commit during plan execution. All commits happen after via review-and-commit. |
| "Let me stop for a batch review" | Finish all tasks without stopping. Only stop on actual blockers. |

## When to Use

- Any development work in a PandaHRMS project that would normally trigger brainstorming
- Features, bug fixes, refactors, or behavioral changes
- Any work where you'd invoke `superpowers:brainstorming`

## When NOT to Use

- Quick fixes that don't need brainstorming (typos, config changes)
- Non-PandaHRMS projects (use brainstorming directly)
- Writing specs for existing functionality without a new design (use `pandahrms:spec-writing` directly)
- Work that already has both a design doc and specs (go straight to `superpowers:writing-plans`)
