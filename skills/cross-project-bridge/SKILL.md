---
name: cross-project-bridge
description: Use whenever reading or writing any file under ~/.claude/bridge/ (issues, notes, specs, decisions), or when the user asks to communicate between separate Claude sessions across projects (FE/BE, mobile/BE). Auto-detects project pairs and works cross-platform (Mac/Windows). Any task derived from a bridge message must update the same file when complete.
---

# Cross-Project Bridge

## Overview

Structured protocol for communicating between separate Claude sessions using shared bridge directories stored in `~/.claude/bridge/`. Each session operates in its own project - the bridge provides a file-based channel to pass context.

Supports multiple message types: issues, notes, specs, and decisions.

**Announce at start:** "I'm using the cross-project-bridge skill to handle cross-project communication."

## When This Skill Triggers

This skill MUST be invoked in any of the following cases:

1. **Any read of a file under `~/.claude/bridge/`** (including listing the directory)
2. **Any write, append, or edit of a file under `~/.claude/bridge/`**
3. **User explicitly mentions the bridge** ("check the bridge", "write to the bridge", etc.)
4. **Completing a task that originated from a bridge message** - the same file must be updated with the outcome before the task is considered done

If you are about to touch a bridge file via Read/Edit/Write/Bash and this skill has not been invoked yet, stop and invoke it first.

## Critical Rules

1. **NEVER write to the bridge unless the user explicitly instructs you to.** Reading is allowed when this skill is triggered by bridge-file access; writing requires explicit user intent such as:
   - "write this to the bridge"
   - "document this in the bridge"
   - "respond on the bridge"

2. **Every task that was initiated by a bridge message MUST update that same bridge file with the outcome when the task completes.** This is non-negotiable. Do not mark such a task done until the response has been appended (see [Closing the Loop](#closing-the-loop)).

3. **Append, never overwrite.** Bridge files accumulate a conversation between two sides - preserve history.

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
   - **Track the originating bridge file path** for every such task - it must be updated when work completes (see [Closing the Loop](#closing-the-loop))
   - **Immediately write an open-loop memory** so a future session can resume the obligation (see [Persisting Open Loops to Memory](#persisting-open-loops-to-memory))
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

## Closing the Loop

Any task that was initiated by a bridge message is not complete until the originating bridge file has been updated with the outcome.

Follow this checklist before marking such a task done:

1. Identify the bridge file that triggered the task (path recorded when the message was first read, or recalled from the open-loop memory entry)
2. Append a `## Response` section (format shown in step 8 above) covering:
   - Findings
   - Actions taken (with file paths and commit refs if applicable)
   - Anything the other side still needs to do, or "Nothing"
3. Confirm the append succeeded (re-read the file) - do not rely on the Edit tool's success alone
4. Surface the copy-paste prompt so the user can notify the other session
5. **Delete the open-loop memory entry** for this bridge file (it is no longer in flight)
6. Only then mark the task complete in TodoWrite / report completion to the user

If the user explicitly asks you to skip the bridge update, record that instruction and proceed - but the default is always to update.

## Persisting Open Loops to Memory

The user can pause work and resume in a new session at any time. To ensure the close-the-loop obligation survives session boundaries, write a memory entry the moment an actionable bridge task is picked up.

### When to write

As soon as the user approves the execution plan for an actionable bridge message (step 8 above), and **before** starting implementation, write a `project`-type memory file at:

```
~/.claude/projects/{project-slug}/memory/project_bridge_openloop_{pair}_{shortname}.md
```

Where:
- `{project-slug}` is the current project's slug (the folder under `~/.claude/projects/` that matches the current working directory)
- `{pair}` is the bridge pair name (e.g. `performance`)
- `{shortname}` is a kebab-case short identifier derived from the bridge filename

### Memory file content

```markdown
---
name: Open bridge loop - {short description}
description: In-flight bridge task from {pair} - must append Response to {filename} before marking done
type: project
---

In-flight task from cross-project bridge.

**Bridge file:** `{absolute path to bridge file}`
**Pair:** {pair name}
**Originating side:** {the project that wrote the message}
**Current side:** {this project}
**Task summary:** {one-line description of what needs to be done}
**Started:** {YYYY-MM-DD}

**Why:** Bridge messages are the only shared channel between paired sessions. If this task is finished (in this session or a new one) without appending a `## Response` block to the bridge file, the other side has no visibility into the outcome.

**How to apply:**
- Before marking this task complete in any session, append a `## Response` block (see cross-project-bridge skill) to the bridge file above
- After the bridge file is updated, delete this memory entry
- If the user explicitly says "skip the bridge update", delete this memory entry with a note explaining why
```

Also add a one-line pointer to `MEMORY.md` so the entry loads into future-session context:

```
- [Open bridge loop: {short description}](project_bridge_openloop_{pair}_{shortname}.md) — must append Response to {filename}
```

### On session start

When a new conversation begins and any bridge-openloop memory is present, treat the referenced bridge file as an unfinished task. Remind the user there is an open loop before starting unrelated work.

### On completion or cancellation

- **Completed:** remove both the memory file and its `MEMORY.md` line after the `## Response` has been verified in the bridge file
- **Cancelled by user:** remove the memory file with a one-line explanation in the final user message

## Cleanup

- **Informational messages**: Delete after the receiving side has acknowledged them.
- **Actionable messages**: Delete when both sides confirm the topic is resolved.
- Always ask the user before deleting a bridge file.

## Rules

- One file per topic
- Both sides append to the same file - never overwrite
- Every bridge-initiated task closes the loop on the same file before being marked done
- Delete when resolved
- Always tell the user to switch sessions after writing
- Use platform-appropriate commands throughout
