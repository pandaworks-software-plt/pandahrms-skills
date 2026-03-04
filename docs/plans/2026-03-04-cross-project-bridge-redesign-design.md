# Cross-Project Bridge Redesign

**Date:** 2026-03-04
**Status:** Approved

## Problem

The current cross-project-bridge skill has hardcoded absolute paths (`/Users/kyson/.claude/bridge/...`) making it Mac-only. It also only supports API debugging issues with rigid templates and hardcoded project pairs.

## Goals

1. Cross-platform compatibility (Mac and Windows)
2. Auto-detection of project pairs (no hardcoded pairs)
3. General-purpose communication (not just API issues)
4. Zero configuration required

## Approach: Smart Auto-Detection with Flexible Messaging

### Cross-Platform Path Resolution

Resolve the bridge path dynamically based on platform:

| Platform | Home Directory | Bridge Path |
|----------|---------------|-------------|
| macOS/Linux | `$HOME` | `$HOME/.claude/bridge/` |
| Windows | `%USERPROFILE%` | `%USERPROFILE%\.claude\bridge\` |

No hardcoded absolute paths. Claude detects the platform from its environment context and uses the appropriate command to resolve the home directory.

### Auto-Detection of Project Pairs

1. Identify the current project from the working directory name
2. Scan sibling directories in the parent workspace folder
3. Classify each project by type:
   - Has `package.json` with `next` dependency: Frontend (Next.js)
   - Has `app.json` or expo config: Mobile
   - Has `*.csproj` files: Backend (.NET)
4. Match pairs by shared domain name (strip suffixes like `_Api`, `-Performance`, `Pandahrms-`, `Pandahrms_`)
5. Bridge directory named by domain: `performance/`, `recruitment/`, `mobile-app/`
6. If detection fails, ask the user

### Message Format

Unified header for all messages:

```markdown
# [Type]: [Short Description]

**From:** [Project name]
**To:** [Target project name]
**Date:** [YYYY-MM-DD]
**Type:** issue | note | spec | decision
```

Type-specific sections:

| Type | Sections |
|------|----------|
| issue | Endpoint, Request Payload, Actual Response, Expected Behavior, Platform (mobile only), Relevant Code |
| note | Context, Details, Action Needed (optional) |
| spec | Feature/Change Description, Requirements, Acceptance Criteria |
| decision | Context, Options Considered, Decision Made, Rationale |

Response format (appended by receiving side):

```markdown
---

## Response

**From:** [Responding project]
**Date:** [YYYY-MM-DD]

### Findings
[What was discovered]

### Actions Taken
[Changes made, with file paths]

### Other Side Needs To
[Any changes the original side needs, or "Nothing"]
```

File naming: `{type}-{descriptive-name}.md`

### Workflow

**Writing:** Detect platform -> resolve bridge path -> auto-detect pair -> ask message type -> create directory if needed -> write message -> tell user to switch sessions.

**Checking:** Detect platform -> resolve bridge path -> auto-detect bridge -> list and read files -> investigate -> append response -> tell user to switch back.

### Rules

- NEVER write to bridge unless user explicitly instructs
- One file per topic
- Both sides append, never overwrite
- Delete when resolved
- Always tell user to switch sessions after writing
- Use platform-appropriate commands
