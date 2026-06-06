---
name: close
description: Manually invoked as `/close` to close a finished piece of Pandahrms work after every card is executed. Verifies every card is already in the per-work `done/` folder and STOPS if any card remains in `active/`; for ticket-driven work updates the ticket status to a done state via the workspace-prod MCP tools; writes the docspace dev-diary log and updates progress; marks the work closed in the per-work `_overview`. Mutating -- it changes ticket state and writes the log. Does NOT move cards. Does NOT raise PRs (that is `/pr`). Does NOT auto-trigger -- only on the slash command or an explicit "close this work" mention.
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

Read the per-work `_overview.md` intake. Detect ticket work by the presence of a `Source`/ticket field.

- Ticket field present -> update the ticket status to a done state via the workspace-prod MCP tools (`update_ticket_status`, and `update_ticket_dev_status` where the work carried a dev status). Use the ticket ref from the `_overview`.
- No ticket field -> skip this phase.

## Phase 3: LOG + CLOSE

- Write the docspace dev-diary log entry for the work (date, what was built, cards covered).
- Update the project progress.
- Mark the work closed in the per-work `_overview` (once).
- Print a one-line summary: cards verified done, ticket updated (yes/no), log written.

## Hard Rules

- Phase 1 is a hard gate. Never mutate anything when a card is still in `active/`.
- `/close` does NOT move cards and does NOT stamp `## Closed:` on cards -- it only verifies they are already in `done/`.
- No PR creation, no push, no `/commit`.
- Ticket update runs only for ticket-sourced work.
- Always write the log and mark the work closed once Phase 1 passes, for ticket and free-form work alike.

## Next step

End by telling the user: to raise a PR for the work, run `/pr` (optional).
