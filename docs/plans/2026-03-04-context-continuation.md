# Context Continuation Skill Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a user-invoked skill that generates a structured conversation summary for handoff to a new chat session.

**Architecture:** Single SKILL.md file in `skills/context-continuation/` following existing pandahrms-skills conventions.

**Tech Stack:** Markdown skill file with YAML frontmatter.

---

### Task 1: Create the context-continuation skill

**Files:**
- Create: `skills/context-continuation/SKILL.md`

**Step 1: Create the skill directory**

```bash
mkdir -p skills/context-continuation
```

**Step 2: Write SKILL.md**

Create `skills/context-continuation/SKILL.md` with:

```markdown
---
name: context-continuation
description: Use when a conversation is getting long and the user wants to summarize decisions, code changes, and remaining work to continue in a fresh session
---

# Context Continuation

## Overview

Generate a structured summary of the current conversation for handoff to a new chat session. Caps output at 15 bullet points to keep it concise and copy-paste friendly.

## When to Use

- User says "summarize this session", "context handoff", "continuation summary"
- User invokes `/context-continuation`
- User asks to prepare a summary for a new chat

## Process

1. Review the full conversation history
2. Identify key decisions, code changes, and incomplete work
3. Output a structured summary as a fenced markdown block

## Output Template

Print the following as a fenced markdown block the user can copy-paste into a new session:

    ## Context Continuation

    **Project:** [project name from cwd or conversation]
    **Task:** [one-line description of what was being worked on]

    ### Decisions
    - [key architecture/implementation decision]
    - [trade-off that was chosen and why]

    ### Code Changes
    - `[relative/file/path]`: [what was changed and why]
    - `[relative/file/path]`: [what was changed and why]

    ### Remaining Work
    - [ ] [concrete next step]
    - [ ] [concrete next step]

## Constraints

- **Max 15 bullet points** across all three sections combined
- Each bullet must be concrete and actionable - no fluff
- File paths are relative from the project root
- Decisions should capture the "why", not just the "what"
- Code changes should reference specific files, not vague descriptions
- Remaining work items should be actionable without re-reading the old conversation

## What This Skill Does NOT Do

- Write to any file
- Read or write the cross-project bridge
- Start a new session automatically
- Commit or push anything
- Include code snippets (keep it summary-level)
```

**Step 3: Verify skill file renders correctly**

```bash
cat skills/context-continuation/SKILL.md
```

Expected: Valid markdown with YAML frontmatter, all sections present.

**Step 4: Commit**

```bash
git add skills/context-continuation/SKILL.md
git commit -m "feat: add context-continuation skill for session handoff summaries"
```
