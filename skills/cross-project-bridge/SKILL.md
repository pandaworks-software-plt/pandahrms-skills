---
name: cross-project-bridge
description: Use when debugging issues that span frontend/backend or mobile/backend boundaries, when the user says to write to or check the bridge, or when documenting cross-project API issues between separate Claude sessions
---

# Cross-Project Bridge

## Overview

Structured protocol for communicating issues between frontend/mobile and backend Claude sessions using shared bridge directories. Each session operates in its own project - the bridge provides a file-based channel to pass context.

**Announce at start:** "I'm using the cross-project-bridge skill to handle cross-project communication."

## Critical Rule

**NEVER write to the bridge unless the user explicitly instructs you to.**

Only act when the user says something like:
- "write this to the bridge"
- "document this in the bridge"
- "check the bridge"
- "read the bridge"

## Bridge Locations

| Project Pair | Bridge Path |
|--------------|-------------|
| Performance FE + Performance API | `~/.claude/bridge/performance/` |
| Mobile App + Main API | `~/.claude/bridge/mobile-app/` |

Absolute paths:
- `/Users/kyson/.claude/bridge/performance/`
- `/Users/kyson/.claude/bridge/mobile-app/`

## Detecting the Project Pair

Determine which bridge to use based on the current working directory:

| Current Project | Bridge | Other Side |
|-----------------|--------|------------|
| `Pandahrms-Performance` | `~/.claude/bridge/performance/` | `Pandahrms_PerformanceApi` |
| `Pandahrms_PerformanceApi` | `~/.claude/bridge/performance/` | `Pandahrms-Performance` |
| `pandaworks-app` | `~/.claude/bridge/mobile-app/` | `PandaHRMS_Api` |
| `PandaHRMS_Api` | `~/.claude/bridge/mobile-app/` | `pandaworks-app` |

If unclear, ask the user which project pair is involved.

## Writing an Issue (Frontend/Mobile Side)

When the user instructs you to document an issue in the bridge:

1. Ensure the bridge directory exists (`mkdir -p <bridge-path>`)
2. Create a file in the appropriate bridge directory
3. Name it descriptively: `<issue-name>.md`
4. Use this format:

```markdown
# Issue: [Short Description]

**Reported by:** [Project name]
**Date:** [YYYY-MM-DD]

## Endpoint
- **Method:** GET/POST/PUT/PATCH/DELETE
- **URL:** /api/v1/...

## Request Payload
[JSON or description of what was sent]

## Actual Response
[JSON or description of what came back]

## Expected Behavior
[What should have happened]

## Relevant Code Context
[Relevant FE/mobile code snippets or file paths]
```

For mobile issues, add:
```markdown
## Platform
iOS / Android / Both
```

5. Tell the user: "Issue documented in bridge. Switch to the [other project] session and ask Claude to check the bridge."

## Checking the Bridge (Backend Side)

When the user instructs you to check the bridge:

1. List all files in the bridge directory
2. Read each issue file
3. Investigate the reported issue in the backend codebase
4. Append findings to the **same file**:

```markdown
---

## Backend Findings

**Investigated by:** [Project name]
**Date:** [YYYY-MM-DD]

### Root Cause
[What caused the issue]

### Fix Applied
[What was changed, with file paths]

### Frontend/Mobile Changes Needed
[Any changes the other side needs to make, or "None"]
```

5. Tell the user: "Findings documented. Switch to the [other project] session to review."

## Cleanup

Delete the issue file when both sides confirm the issue is resolved.

## Rules

- One file per issue
- Both sides append to the same file
- Never overwrite the other side's content
- Delete when resolved
- Always tell the user to switch sessions after writing
