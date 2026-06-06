---
name: discover-project
description: Manually invoked as `/discover-project <projectNumber>` (or by an explicit mention of "discover-project" / "use discover-project on project ..."). The project-queue intake door of the Pandahrms flow. Takes a single onboarding project number. Lists every pending ticket linked to that project via the workspace-prod MCP `list_tickets` tool (filtered to needsDev tickets that are not closed/shipped/rejected), then prints them as a numbered table for the user to pick from. Read-only router -- it surfaces the project's pending dev queue and points the user at `/discover-ticket <ticketNumber>` for the one they choose; it writes no files and emits no output contract. Fails fast if the workspace-prod MCP is not connected, and stops if no projectNumber is given. Does NOT auto-trigger -- naming a project or pasting a project URL alone is NOT enough. The user must explicitly invoke `/discover-project` or name the skill.
---

# Discover (project-queue door)

List a project's pending dev tickets, print them as a numbered table, route the user to `/discover-ticket` for their pick. Read-only. Writes nothing.

## Input

Single argument: onboarding `projectNumber`. Required. If missing, report and stop -- no listing.

## Workflow

### Phase 0: MCP guard

Confirm the workspace-prod MCP is connected (the `mcp__workspace-prod__list_tickets` tool is available). If unavailable, report the failure and stop. Do nothing else.

### Phase 1: Fetch pending tickets

Call `mcp__workspace-prod__list_tickets` with:
- `projectNumber` = the argument,
- `needsDev` = true,
- `limit` = 500.

Page through (`page` 2, 3, ...) until a page returns fewer rows than `limit`. Collect all rows.

From the collected rows, drop any ticket whose `devStatus` is `shipped`, `rejected`, or `closed`, or whose `status` is closed. What remains is the pending queue.

If the call errors, report the failure and stop. If the queue is empty, say so plainly and stop.

### Phase 2: Present the queue

Print a numbered table, sorted by `priority` (highest first), then `createdAt` (oldest first):

| # | Ticket | Title | Type | Priority | Dev status | Customer |
|---|--------|-------|------|----------|------------|----------|

- `#` -- 1-based row index for the user to reference.
- `Ticket` -- the human `ticketNumber`.
- One row per pending ticket.

End with a one-line count (e.g. `7 pending tickets in project <projectNumber>`).

## Hard Rules

- Read-only. No `update_ticket`, no comment, no status change, no proposal post.
- No git, no commits, no file writes. No `_overview.md`, no card folder.
- Fail fast: stop on missing projectNumber, on a disconnected workspace-prod MCP, or on a list_tickets error.
- One project per run.

## Out of Scope

- Fetching a single ticket's detail or acceptance criteria (that is `/discover-ticket`).
- Writing the output contract, card decomposition, branching, commits, PRs.
- Editing tickets or the project on the workspace.

## Next step

End by telling the user to run `/discover-ticket <ticketNumber>` on the ticket they pick from the table.
