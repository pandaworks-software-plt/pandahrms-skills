---
name: cross-project-bridge
description: Use when communicating between separate Claude sessions across projects (FE/BE, mobile/BE). Supports issues, notes, specs, and decisions. Auto-detects project pairs and works cross-platform (Mac/Windows).
---

# Cross-Project Bridge

## Overview

Structured protocol for communicating between separate Claude sessions using shared bridge directories stored in `~/.claude/bridge/`. Each session operates in its own project - the bridge provides a file-based channel to pass context.

Supports multiple message types: issues, notes, specs, and decisions.

**Announce at start:** "I'm using the cross-project-bridge skill to handle cross-project communication."

## Critical Rule

**NEVER write to the bridge unless the user explicitly instructs you to.**

Only act when the user says something like:
- "write this to the bridge"
- "document this in the bridge"
- "check the bridge"
- "read the bridge"

## Step 1: Resolve the Bridge Path

Determine the bridge base path based on the current platform. The platform is provided in your environment context.

| Platform | Command to Get Home | Bridge Base Path |
|----------|-------------------|------------------|
| macOS / Linux | Run: `echo $HOME` | `{HOME}/.claude/bridge/` |
| Windows (CMD) | Run: `echo %USERPROFILE%` | `{USERPROFILE}\.claude\bridge\` |
| Windows (PowerShell) | Run: `echo $env:USERPROFILE` | `{USERPROFILE}\.claude\bridge\` |

**Never hardcode absolute paths.** Always resolve the home directory at runtime.

## Step 2: Auto-Detect Project Pair

Determine which bridge directory to use:

1. **Identify the current project** from the working directory name
2. **Scan sibling directories** in the parent workspace folder (one level up)
3. **Classify projects by type:**
   - Has `package.json` with `next` dependency → Frontend (Next.js)
   - Has `app.json` or expo config → Mobile
   - Has `*.csproj` files → Backend (.NET)
4. **Match pairs** by shared domain name:
   - Strip common prefixes/suffixes: `Pandahrms-`, `Pandahrms_`, `_Api`, `Api`
   - Match projects that share the same domain (e.g., "Performance" in both `Pandahrms-Performance` and `Pandahrms_PerformanceApi`)
5. **Name the bridge directory** by the shared domain in kebab-case:
   - `performance/` for Performance FE + Performance API
   - `recruitment/` for Recruitment FE + Recruitment API
   - `mobile-app/` for Mobile App + Main API (special case: mobile projects)

**If detection fails**, ask the user which project they are bridging to.

## Step 3: Create the Bridge Directory

Create the bridge directory if it does not exist:

| Platform | Command |
|----------|---------|
| macOS / Linux | `mkdir -p {bridge_base_path}/{pair_name}` |
| Windows (CMD) | `if not exist "{bridge_base_path}\{pair_name}" mkdir "{bridge_base_path}\{pair_name}"` |
| Windows (PowerShell) | `New-Item -ItemType Directory -Force -Path "{bridge_base_path}\{pair_name}"` |

## Writing a Message

When the user instructs you to write to the bridge:

1. Complete Steps 1-3 above
2. Ask the user what type of message if not obvious from context:
   - **issue** - API/integration problem
   - **note** - General information sharing
   - **spec** - Feature or change specification
   - **decision** - Architectural or design decision

3. Create a file named `{type}-{descriptive-name}.md` in the bridge directory

4. Use the unified header:

```markdown
# [Type]: [Short Description]

**From:** [Current project name]
**To:** [Target project name]
**Date:** [YYYY-MM-DD]
**Type:** issue | note | spec | decision
```

5. Add type-specific sections:

**For issues:**
```markdown
## Endpoint
- **Method:** GET/POST/PUT/PATCH/DELETE
- **URL:** /api/v1/...

## Request Payload
[JSON or description of what was sent]

## Actual Response
[JSON or description of what came back]

## Expected Behavior
[What should have happened]

## Platform
[iOS / Android / Both - only for mobile projects]

## Relevant Code
[Code snippets or file paths from the current project]
```

**For notes:**
```markdown
## Context
[Why this is being shared]

## Details
[The information being communicated]

## Action Needed
[What the other side should do, if anything]
```

**For specs:**
```markdown
## Feature / Change
[What is being specified]

## Requirements
[Detailed requirements]

## Acceptance Criteria
[How to verify the work is done]
```

**For decisions:**
```markdown
## Context
[Why this decision was needed]

## Options Considered
[What alternatives were evaluated]

## Decision
[What was decided]

## Rationale
[Why this option was chosen]
```

6. Tell the user: "Message documented in bridge at `{bridge_path}/{filename}`. Switch to the [target project] session and ask Claude to check the bridge."

## Checking the Bridge

When the user instructs you to check the bridge:

1. Complete Steps 1-2 above
2. List all files in the bridge directory
3. Read each message file
4. Investigate the reported items in the current codebase
5. Append findings to the **same file** (never overwrite existing content):

```markdown
---

## Response

**From:** [Current project name]
**Date:** [YYYY-MM-DD]

### Findings
[What was discovered]

### Actions Taken
[Changes made, with file paths]

### Other Side Needs To
[Any changes the original side needs to make, or "Nothing"]
```

6. Tell the user: "Findings documented. Switch to the [other project] session to review."

## Cleanup

Delete the message file when both sides confirm the topic is resolved.

## Rules

- One file per topic
- Both sides append to the same file - never overwrite
- Delete when resolved
- Always tell the user to switch sessions after writing
- Use platform-appropriate commands throughout
