---
name: close
description: Manually invoked as `/close` to close a finished piece of Pandahrms work after every card is executed. Verifies every card is already in the per-work `done/` folder and STOPS if any card remains in `active/`; for ticket-driven work updates the ticket to a done state via the workspace-prod MCP tools -- status + solution, dev status, Developer Resolution (`resolutionNotes`), a customer-facing resolved comment, and an internal dev-note; writes the docspace dev-diary log and updates progress; marks the work closed in the per-work `_overview`. Mutating -- it changes ticket state and writes the log. Does NOT move cards. Does NOT raise PRs (that is `/pr`). Does NOT auto-trigger -- only on the slash command or an explicit "close this work" mention.
---

# Close

## Overview

Mutating close of a finished piece of work. Verifies every card is already in `done/`, updates the ticket status for ticket work, writes the dev-diary log, marks the work closed. Manual. Stops if any card is still in `active/`.

## Pre-Flight: Optimise the prompt

If `pandahrms:optimise-prompt` has not run on the current user message, invoke it via the Skill tool with no arguments. Wait for it to return, then continue with the confirmed intent.

Skip when:
- Standalone pre-flight already ran on this message and locked an intent. Reuse it.
- Message is a direct reply to an AskUserQuestion the assistant just sent.
- Message is a one-word ack ("yes", "ok", "no", "go", "continue").
- optimise-prompt is already running in the call stack.

## Phase 1: VERIFY (gate)

Read `work_folder` from the per-work `_overview.md` frontmatter -- single source of truth for the path. Scan `<work-folder>/active/` and `<work-folder>/done/`.

- Any card still in `<work-folder>/active/` -> list each one (name + the sequence step it sits on) and STOP. Print: `Cannot close -- N card(s) still in active/.` followed by the list. Do not run any later phase. Do not touch the ticket or the log.
- Every card in `<work-folder>/done/` -> continue to Phase 2.

## Phase 2: TICKET (ticket work only)

Read the per-work `_overview.md` intake. Detect ticket work by the presence of a `Source`/ticket field. No ticket field -> skip this phase. Use the ticket ref from the `_overview` for every call below.

Ticket field present -> run all of the following via the workspace-prod MCP tools:

1. **Status** -> `update_ticket_status` to a done state. Set its `solution` field: a plain-business-language summary of what the customer now gets. CUSTOMER-FACING -- no code, file paths, PR/branch refs, or internal IDs. PLAIN TEXT only -- no HTML or markup (`<p>`, `<h1>`, `<br>`, `<ul>`, etc.); use line breaks for separation.
2. **Dev status** -> `update_ticket_dev_status` where the work carried a dev status.
3. **Developer Resolution** -> `update_ticket` with `resolutionNotes`: the engineering resolution -- root cause, code changes, files/areas touched, tests. Internal; full technical detail allowed. Scope to THIS ticket only (see Relevance gate below). PLAIN TEXT only -- no HTML or markup (`<p>`, `<h1>`, `<br>`, `<ul>`, etc.); use line breaks for separation.
4. **Customer comment** -> `add_ticket_comment` with `commentType="comment"`: short plain-language note that the work is resolved. CUSTOMER-FACING -- no engineering detail.
5. **Dev-note** -> `add_ticket_comment` with `commentType="dev-note"`: short internal note -- cards covered, branch/PR refs. Route the full resolution to `resolutionNotes` above, not here.

### Relevance gate (all four ticket fields)

Every ticket field -- `solution`, `resolutionNotes`, customer comment, dev-note -- carries only information about THIS ticket's problem and fix. Before writing each field, drop any content that is not about this ticket.

EXCLUDE (these are session noise, never written to the ticket):
- Pre-existing or unrelated test failures (e.g. "23 pre-existing unit failures on development", date-sensitive test flakiness).
- Follow-up tasks, ideas, or side-work surfaced during the session that are not part of this ticket's fix.
- Environment, tooling, or local-setup issues hit while working.
- Side observations about other modules, tickets, or tech debt.

A genuine follow-up that belongs to THIS ticket's fix (a known limitation of the delivered change) may stay in `resolutionNotes`. Anything else goes to `docspace/agent-zone` or a new card, not the ticket.

## Phase 3: LOG + CLOSE

- Write the docspace dev-diary log entry for the work (date, what was built, cards covered).
- Update the project progress.
- Mark the work closed in the per-work `_overview` (once).
- Print a one-line summary: cards verified done, ticket updated (status + solution + Developer Resolution + comment + dev-note, or n/a), log written.

## Hard Rules

- Phase 1 is a hard gate. Never mutate anything when a card is still in `active/`.
- `/close` does NOT move cards and does NOT stamp `## Closed:` on cards -- it only verifies they are already in `done/`.
- No PR creation, no push, no `/commit`.
- Ticket updates (status, solution, dev status, Developer Resolution, comment, dev-note) run only for ticket-sourced work.
- Customer-facing fields (`solution`, the `comment`) stay in plain business language -- never code, file paths, PR/branch refs, or internal IDs. Engineering detail goes only to `resolutionNotes` and the `dev-note`.
- Relevance gate is mandatory: no ticket field carries session noise (pre-existing/unrelated test failures, session follow-up tasks, environment issues, side observations). Every field is scoped to THIS ticket only.
- `solution` and `resolutionNotes` are PLAIN TEXT -- no HTML or markup (`<p>`, `<h1>`, `<br>`, `<ul>`, etc.). Use line breaks for separation.
- Always write the log and mark the work closed once Phase 1 passes, for ticket and free-form work alike.

## Next step

End by telling the user: to raise a PR for the work, run `/pr` (optional).
