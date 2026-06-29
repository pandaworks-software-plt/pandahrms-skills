---
name: discover-project
description: The project-queue intake door of the Pandahrms flow. `/discover-project <projectNumber> [--all]`. Takes an onboarding project number and an optional `--all` flag. By default it lists only the pending dev queue (needsDev tickets that are not closed/shipped/rejected); with `--all` it lists every ticket linked to the project regardless of dev status. Fetches via the workspace-prod MCP `list_tickets` tool, then prints the result as a numbered table for the user to pick from. Read-only router -- it surfaces the queue and points the user at `/discover-ticket <ticketNumber>` for the one they choose; it writes no files and emits no output contract. Fails fast if the workspace-prod MCP is not connected, and stops if no projectNumber is given.
disable-model-invocation: true
---

# Discover (project-queue door)

List a project's pending dev tickets, print them as a numbered table, route the user to `/discover-ticket` for their pick. Read-only. Writes nothing.

## Input

- `projectNumber` -- onboarding project number. Required. If missing, report and stop -- no listing.
- `--all` -- optional flag. Absent (default) = pending dev queue only. Present = every ticket linked to the project, any dev status.

## Workflow

### Phase 0: MCP guard

Confirm the workspace-prod MCP is connected (the `mcp__workspace-prod__list_tickets` tool is available). If unavailable, report the failure and stop. Do nothing else.

### Phase 1: Fetch tickets

Call `mcp__workspace-prod__list_tickets` with:
- `projectNumber` = the argument,
- `needsDev` = true by default; omit `needsDev` when `--all` is present,
- `limit` = 500.

Page through (`page` 2, 3, ...) until a page returns fewer rows than `limit`. Collect all rows.

Filter:
- Default -- drop any ticket whose `devStatus` is `shipped`, `rejected`, or `closed`, or whose `status` is closed. What remains is the pending dev queue.
- `--all` -- keep every collected row, any dev status.

If the call errors, report the failure and stop. If the queue is empty, say so plainly and stop.

### Phase 2: Present the queue

Print a numbered table, sorted by `priority` (highest first), then `createdAt` (oldest first):

| # | Ticket | Title | Type | Priority | Dev status | Customer |
|---|--------|-------|------|----------|------------|----------|

- `#` -- 1-based row index for the user to reference.
- `Ticket` -- the human `ticketNumber`.
- One row per ticket in the scoped queue.

End with a one-line count naming the scope (e.g. `7 pending tickets in project <projectNumber>` by default, or `23 tickets in project <projectNumber> (all)` with `--all`).

## Hard Rules

- Read-only. No `update_ticket`, no comment, no status change, no proposal post.
- No git, no commits, no file writes. No `_overview.md`, no card folder.
- Writes nothing today; should any output ever be added, it MUST live inside the current repo -- never outside the repo root (no home dir, no external/iCloud vault).
- Fail fast: stop on missing projectNumber, on a disconnected workspace-prod MCP, or on a list_tickets error.
- One project per run.

## Out of Scope

- Fetching a single ticket's detail or acceptance criteria (that is `/discover-ticket`).
- Writing the output contract, card decomposition, branching, commits, PRs.
- Editing tickets or the project on the workspace.

## Next step

End by telling the user to run `/discover-ticket <ticketNumber>` on the ticket they pick from the table.
