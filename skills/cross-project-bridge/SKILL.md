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
- "check the bridge" / "read the bridge" / "review the bridge"

## Determine Intent

When the skill is triggered, determine what the user wants:

| User says | Intent | Go to |
|-----------|--------|-------|
| "write to the bridge", "document in the bridge" | **Write** | [Writing a Message](#writing-a-message) |
| "check the bridge", "read the bridge", "review the bridge" | **Read** | [Checking the Bridge](#checking-the-bridge) |
| Ambiguous | **Ask** | Ask the user: "Do you want to write a message to the bridge, or check for incoming messages?" |

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
   - Has `package.json` with `next` dependency -> Frontend (Next.js)
   - Has `app.json` or expo config -> Mobile
   - Has `*.csproj` files -> Backend (.NET)
4. **Match pairs** by shared domain name:
   - Strip common prefixes/suffixes (e.g., `Pandahrms-`, `Pandahrms_`, `_Api`, `Api`, or similar project-specific naming patterns)
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

6. Tell the user the message was documented, then output a copy-paste-able prompt in a code block:

```
Bridge message documented at `{bridge_path}/{filename}`.

Paste this in your [{target project}] session:
```

```
Check the bridge for a {type} about {short description} at {bridge_path}/{filename}
```

## Checking the Bridge

When the user instructs you to check/read/review the bridge:

1. Complete Steps 1-2 above
2. List all files in the bridge directory
3. If the bridge is empty, tell the user: "No messages in the bridge." and stop.
4. Read each message file
5. **Classify each message** as one of:
   - **Informational** - no code changes needed in the current project (e.g., "No frontend code changes required")
   - **Actionable** - requires code changes, investigation, or a response in the current project

6. **Present a summary** to the user:

```
Bridge messages for [{pair_name}]:

  [Informational]
  - {filename}: {one-line summary} -- No action needed, acknowledge only.

  [Actionable]
  - {filename}: {one-line summary} -- Action: {brief description of what needs to be done}
```

7. **For informational messages**: Summarize the key points for the user's awareness. Ask the user if they want to acknowledge and delete the file.

8. **For actionable messages**: Investigate the items in the current codebase, then:
   - Present findings to the user
   - Propose an execution plan (use EnterPlanMode for non-trivial work)
   - After user approval, execute the plan
   - Once work is complete, append results to the bridge file (never overwrite existing content):

```markdown
---

## Response

**From:** [Current project name]
**Date:** [YYYY-MM-DD]

### Findings
[What was discovered in the codebase]

### Actions Taken
[Changes made, with file paths]

### Other Side Needs To
[Any changes the original side needs to make, or "Nothing"]
```

9. Tell the user work is complete, then output a copy-paste-able prompt in a code block:

```
Work complete and response appended to bridge.

Paste this in your [{other project}] session:
```

```
Check the bridge for a response about {short description} at {bridge_path}/{filename}
```

## Cleanup

- **Informational messages**: Delete after the receiving side has acknowledged them.
- **Actionable messages**: Delete when both sides confirm the topic is resolved.
- Always ask the user before deleting a bridge file.

## Rules

- One file per topic
- Both sides append to the same file - never overwrite
- Delete when resolved
- Always tell the user to switch sessions after writing
- Use platform-appropriate commands throughout
