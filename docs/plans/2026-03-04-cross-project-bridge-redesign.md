# Cross-Project Bridge Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Redesign the cross-project-bridge skill to be cross-platform (Mac/Windows), auto-detect project pairs, and support general-purpose communication (not just API issues).

**Architecture:** Replace hardcoded paths and project pairs with dynamic OS detection and workspace scanning. Replace the rigid API-issue-only template with a flexible multi-type message format (issue, note, spec, decision).

**Tech Stack:** Markdown (SKILL.md), Shell commands (cross-platform)

---

### Task 1: Rewrite SKILL.md with Cross-Platform Bridge Skill

**Files:**
- Modify: `skills/cross-project-bridge/SKILL.md`

**Step 1: Rewrite the full SKILL.md**

Replace the entire contents of `skills/cross-project-bridge/SKILL.md` with the new skill definition below. Key changes from the old version:

- Remove all hardcoded absolute paths (`/Users/kyson/...`)
- Remove hardcoded project pair tables
- Add cross-platform path resolution section
- Add auto-detection logic for project pairs
- Add flexible message types (issue, note, spec, decision)
- Add platform-specific command guidance (mkdir -p vs mkdir, path separators)

```markdown
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

```
# [Type]: [Short Description]

**From:** [Current project name]
**To:** [Target project name]
**Date:** [YYYY-MM-DD]
**Type:** issue | note | spec | decision
```

5. Add type-specific sections:

**For issues:**
```
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
```
## Context
[Why this is being shared]

## Details
[The information being communicated]

## Action Needed
[What the other side should do, if anything]
```

**For specs:**
```
## Feature / Change
[What is being specified]

## Requirements
[Detailed requirements]

## Acceptance Criteria
[How to verify the work is done]
```

**For decisions:**
```
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

```
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
```

**Step 2: Verify the skill file**

Run: Read the file back and confirm:
- No hardcoded absolute paths exist
- No hardcoded project pairs (everything is auto-detected)
- Platform detection table is present
- All 4 message types have templates
- Cross-platform commands for mkdir are documented

**Step 3: Commit**

```bash
git add skills/cross-project-bridge/SKILL.md
git commit -m "feat(bridge): redesign cross-project-bridge for cross-platform and flexible messaging"
```

---

### Task 2: Update Global Rules File

**Files:**
- Modify: `~/.claude/rules/CrossProjectBridge.md`

**Step 1: Rewrite CrossProjectBridge.md**

Replace the entire contents of `~/.claude/rules/CrossProjectBridge.md` with an updated version that:

- Removes all hardcoded absolute paths (`/Users/kyson/...`)
- Removes hardcoded bridge location tables
- References `~/.claude/bridge/` as the base path (tilde notation is universal)
- Keeps the "never write unless instructed" rule
- Simplifies to defer to the skill for detailed instructions

```markdown
# Cross-Project Bridge Communication

## Important Rule

**NEVER write to the bridge unless the user explicitly instructs you to.**

Only read from or write to bridge files when the user says something like:
- "write this to the bridge"
- "document this in the bridge"
- "check the bridge"
- "read the bridge"

## Overview

Use shared bridge directories under `~/.claude/bridge/` to communicate between frontend/mobile and backend Claude sessions. The bridge supports multiple message types: issues, notes, specs, and decisions.

## Bridge Location

All bridge files are stored under the user's home directory:

```
~/.claude/bridge/
├── performance/       # Performance FE <-> Performance API
├── recruitment/       # Recruitment FE <-> Recruitment API
├── mobile-app/        # Mobile App <-> Main API
└── [other-pairs]/     # Auto-detected from workspace
```

Resolve `~` to the platform-appropriate home directory:
- macOS/Linux: `$HOME`
- Windows: `%USERPROFILE%`

## Structure

One file per topic. Delete when resolved.

```
bridge/{pair-name}/
└── {type}-{descriptive-name}.md
```

Message types: `issue`, `note`, `spec`, `decision`

## Workflow

### Writing (sender side)
1. Auto-detect the project pair from the workspace
2. Create the message file with type-specific template
3. Tell the user to switch to the other session

### Checking (receiver side)
1. Read all files in the bridge directory
2. Investigate and append response to the same file
3. Tell the user to switch back

## Cleanup

Delete the issue file when resolved.
```

**Step 2: Verify the rules file**

Read back and confirm no hardcoded absolute paths or user-specific paths remain.

**Step 3: Commit**

```bash
git add ~/.claude/rules/CrossProjectBridge.md
git commit -m "docs(rules): update cross-project bridge rules for cross-platform support"
```

Note: This file is outside the repo, so this commit only applies if the rules directory is tracked. If not, the file is simply updated in place.

---

### Task 3: Bump Plugin Version

**Files:**
- Modify: `.claude-plugin/plugin.json`

**Step 1: Update version**

Change `"version": "1.5.1"` to `"version": "1.6.0"` in `.claude-plugin/plugin.json`. This is a minor version bump because we're adding new functionality (flexible message types, cross-platform support) without breaking existing behavior.

**Step 2: Commit**

```bash
git add .claude-plugin/plugin.json
git commit -m "chore: bump version to 1.6.0"
```
