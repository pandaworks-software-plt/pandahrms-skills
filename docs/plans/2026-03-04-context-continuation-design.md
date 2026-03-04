# Context Continuation Skill Design

## Overview

A user-invoked skill that generates a structured summary of the current conversation for handoff to a new chat session. Prevents context loss when conversations grow long.

## Trigger

User-invoked only via `/context-continuation` or phrases like "summarize this session", "context handoff".

## Approach

Structured template with fixed sections, capped at 15 bullet points total.

## Output Format

Printed to chat as a fenced markdown block for copy-paste:

```
## Context Continuation

**Project:** [project name]
**Task:** [one-line description]

### Decisions
- [decision 1]
- [decision 2]

### Code Changes
- [file-path]: [what was changed]
- [file-path]: [what was changed]

### Remaining Work
- [ ] [next step 1]
- [ ] [next step 2]
```

## Constraints

- Max 15 bullet points across all sections
- Each bullet is concrete and actionable
- File paths are relative from project root
- No fluff or filler

## What It Does NOT Do

- Write to any file
- Read or write the bridge
- Start a new session
- Commit or push anything

## Location

`pandahrms-skills/` repo as a skill file.
