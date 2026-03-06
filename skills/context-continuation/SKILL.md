---
name: context-continuation
description: Use when a conversation is getting long and the user wants to summarize decisions, code changes, and remaining work to continue in a fresh session
---

# Context Continuation

## Overview

Save and restore conversation context across sessions. When a session ends, this skill writes a structured summary to a local file. When a new session starts, invoking this skill again picks up where the previous session left off.

**Announce at start:** "I'm using the context-continuation skill to [save/resume] session context."

## Auto-Detect Mode

When the skill is triggered, determine the mode automatically:

1. Resolve the context file path (see [Step 1](#step-1-resolve-context-file-path))
2. Check if the context file already exists

| Context file exists? | Mode | Action |
|---------------------|------|--------|
| Yes | **Resume** | Go to [Resuming Context](#resuming-context) |
| No | **Save** | Go to [Saving Context](#saving-context) |

If the user explicitly states their intent (e.g., "save context", "pick up where we left off"), use that intent regardless of file state.

## Step 1: Resolve Context File Path

### Base Path

| Platform | Base Path |
|----------|-----------|
| macOS / Linux | `~/.claude/context/` |
| Windows | `%USERPROFILE%\.claude\context\` |

**Never hardcode absolute paths.** Always resolve the home directory at runtime.

### Project Name

Derive the project name from the current working directory name, converted to kebab-case.

Examples:
- `/Users/kyson/Developer/pandaworks/_pandahrms-workspace/Pandahrms-Performance` -> `pandahrms-performance`
- `/Users/kyson/Developer/pandaworks/_pandahrms-workspace/Pandahrms_PerformanceApi` -> `pandahrms-performanceapi`

### Full Path

`{base_path}/{project-name}.md`

Example: `~/.claude/context/pandahrms-performance.md`

## Saving Context

When ending a session and saving context:

1. Review the full conversation history
2. Identify key decisions, code changes, and incomplete work
3. Create the context directory if it does not exist: `mkdir -p ~/.claude/context/`
4. Write the context file using the template below
5. Tell the user: "Context saved to `{context_file_path}`. Open a new session in this project and invoke `/context-continuation` to resume."

### Template

Write the following to the context file:

```markdown
# Context Continuation

**Project:** [project name from cwd or conversation]
**Task:** [one-line description of what was being worked on]
**Saved:** [YYYY-MM-DD HH:MM]

## Decisions
- [key architecture/implementation decision and why]
- [trade-off that was chosen and why]

## Code Changes
- `[relative/file/path]`: [what was changed and why]
- `[relative/file/path]`: [what was changed and why]

## Current State
- [what is working now]
- [what is broken or incomplete]
- [any blockers or open questions]

## Remaining Work
- [ ] [concrete next step with enough detail to act on without re-reading the old conversation]
- [ ] [concrete next step]

## Key Context
- [anything a fresh session needs to know that isn't obvious from the code]
- [e.g., "the API returns X but we need Y", "user prefers approach A over B"]
```

### Constraints

- **Max 20 bullet points** across all sections combined
- Each bullet must be concrete and actionable - no fluff
- File paths are relative from the project root
- Decisions should capture the "why", not just the "what"
- Code changes should reference specific files, not vague descriptions
- Remaining work items should be actionable without re-reading the old conversation
- Include enough "Key Context" that a fresh session can make good decisions

## Resuming Context

When a context file is found:

1. Read the context file
2. Present a summary to the user:

```
Resuming from previous session:

**Task:** [task from the file]
**Saved:** [date from the file]

**Decisions made:**
- [list decisions]

**Remaining work:**
- [ ] [remaining items]

Ready to continue. What would you like to pick up first?
```

3. Ask the user if they want to continue with the remaining work or take a different direction
4. Once the user confirms, delete the context file to avoid stale state:
   - Tell the user: "Clearing the saved context since we're picking up the work now."
   - Delete the file
5. If the remaining work items are clear, create a TodoWrite checklist from them
6. Begin working on the task

## Rules

- One context file per project (new saves overwrite previous ones)
- Always auto-detect mode unless the user states explicit intent
- Delete the context file after resuming to prevent stale handoffs
- Never include code snippets in the context file - keep it summary-level
- If the project has uncommitted git changes, mention them in "Current State"
