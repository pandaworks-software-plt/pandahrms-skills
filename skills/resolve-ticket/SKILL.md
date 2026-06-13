---
name: resolve-ticket
description: Manually invoked as `/resolve-ticket <ticket_number>` (or by an explicit mention of "resolve-ticket" / "resolve this ticket") to move ONE workspace-prod ticket to a resolved, ready-for-release state -- card-less, no work folder, no card scan, no docspace log. Takes a single ticket reference (a UUID or a human number like T26050092), fetches it via the workspace-prod MCP `get_ticket` tool, then runs the ticket updates in order: dev status -> `ready-for-release` first (ensuring the ticket sits in `developer` with `needsDev=true` so dev status is editable), then status -> `resolved` with a plain customer-facing `solution`, then `resolutionNotes` (Developer Resolution, engineering detail), then a customer-facing resolved `comment` and an internal `dev-note`. Drafts every field from the session context, applies the relevance gate + plain-text rule + customer-facing tone rule, and STOPS for an explicit user confirmation before any write. Mutating -- it changes ticket state. Does NOT move cards, write logs, run git, or raise PRs. Does NOT auto-trigger -- pasting a ticket URL or saying "look at this ticket" is NOT enough; the user must invoke `/resolve-ticket` or name the skill.
---

# Resolve Ticket

## Overview

Card-less ticket resolution. Take one ticket ref, move the workspace-prod ticket to a resolved + ready-for-release state with the right fields, in the right order. Mutating. Confirms before any write. One ticket per run.

## Input

Single argument: ticket reference. Accepts a UUID or a human ticket number (e.g. `T26050092`). Missing -> ask via AskUserQuestion. `get_ticket` resolves both forms.

## Pre-Flight: Optimise the prompt

If `pandahrms:optimise-prompt` has not run on the current user message, invoke it via the Skill tool with no arguments. Wait for it to return, then continue with the confirmed intent.

Skip when:
- Standalone pre-flight already ran on this message and locked an intent. Reuse it.
- Message is a direct reply to an AskUserQuestion the assistant just sent.
- Message is a one-word ack ("yes", "ok", "no", "go", "continue").
- optimise-prompt is already running in the call stack.

## Phase 1: Fetch

Call `mcp__workspace-prod__get_ticket` with `id` = the ref. Capture: `id` (UUID), `ticketNumber`, `status`, `needsDev`, `devStatus`, `customer`, `title`, `type`. Use the UUID `id` for every mutating call below.

- Call errors or no ticket -> report the failure and STOP. No writes.
- `status` already `resolved` or `closed` -> surface the current state and ask via AskUserQuestion whether to re-write the fields anyway or stop.

## Phase 2: Draft the fields

Draft from the current session context -- what was built or fixed. Context too thin to draft from -> ask the user for the resolution summary before drafting.

Draft four field values:

1. **`solution`** -- CUSTOMER-FACING. Plain-business-language summary of what the customer now gets.
2. **`resolutionNotes`** (Developer Resolution) -- INTERNAL. Root cause, code changes, files/areas touched, tests, branch/PR refs. Full engineering detail allowed.
3. **Customer comment** -- CUSTOMER-FACING. Short note that the work is resolved.
4. **Dev-note** -- INTERNAL. Short note: branch/PR refs, anything the next engineer needs.

Apply the Field rules (below) to every value before showing it.

## Phase 3: Confirm (gate)

Show the planned state transitions and the four drafted field values in one message, then call AskUserQuestion: proceed / edit / cancel.

- Planned transitions line: current `status`/`devStatus`/`needsDev` -> the targets (`developer` + `needsDev=true` if needed, dev status `ready-for-release`, status `resolved`).
- `proceed` -> Phase 4. `edit` -> revise the named field(s), re-show, ask again. `cancel` -> STOP, no writes.

No mutating call runs before an explicit `proceed`.

## Phase 4: Mutate (ordered)

Dev status is editable only while the ticket sits in `developer` status, and `update_ticket_dev_status` requires `needsDev=true`. So always set dev status FIRST, then move the main status.

Run in this exact order:

1. **Ensure developer.** Make the ticket sit in `developer` with `needsDev=true`:
   - Already `developer` + `needsDev=true` -> nothing to do.
   - `needsDev=false` -> call `set_ticket_needs_dev` with `needsDev=true` (this moves the ticket to `developer` and seeds `devStatus=triage`). The move to `developer` is valid only from `l2-support`; if the current status blocks it, first `update_ticket_status` to `l2-support`, then enable `needsDev`.
   - `needsDev=true` but `status` not `developer` -> `update_ticket_status` to `developer` (via `l2-support` first if the direct transition is rejected).
   - Any required transition is rejected by the server -> report what failed and STOP. Do not force-skip the dev-status step.
2. **Dev status** -> `update_ticket_dev_status` with `devStatus="ready-for-release"`.
3. **Status** -> `update_ticket_status` with `status="resolved"` and the `solution` field set.
4. **Developer Resolution** -> `update_ticket` with `resolutionNotes`.
5. **Customer comment** -> `add_ticket_comment` with `commentType="comment"` and the customer note.
6. **Dev-note** -> `add_ticket_comment` with `commentType="dev-note"` and the internal note.

After the writes, print a one-line summary: ticketNumber, dev status set, status resolved, resolutionNotes + comment + dev-note written.

## Field rules

All four fields obey these rules. Apply before writing.

- **Plain text only.** No HTML and no Markdown formatting -- no `<p>`/`<h1>`/`<br>`/`<ul>` tags, no `#` headings, no `**bold**`, no `-`/`*` bullet markup. Use line breaks for separation.
- **Customer-facing fields** (`solution`, the customer comment) stay in plain business language. Never code, file paths, function names, stack traces, internal IDs, or branch/PR refs.
- **Internal fields** (`resolutionNotes`, the dev-note) carry the engineering detail. Branch/PR refs and files touched go here, not in the customer-facing fields.
- **Engineering substance, not local-dev noise.** Every field carries durable substance: root cause, the fix, files/endpoints/areas touched, commit/PR refs. Drop local-dev or session progress noise -- "deployed to local Docker", "not yet committed / PR pending", test pass counts ("122 tests pass"), "validated via Playwright / validated locally".

### Relevance gate

Every field carries only information about THIS ticket's problem and fix. Before writing each field, drop content that is not about this ticket.

EXCLUDE (session noise, never written to the ticket):
- Pre-existing or unrelated test failures (e.g. "23 pre-existing failures on development", date-sensitive flakiness).
- Follow-up tasks, ideas, or side-work surfaced during the session that are not part of this ticket's fix.
- Environment, tooling, or local-setup issues hit while working.
- Side observations about other modules, tickets, or tech debt.

A genuine limitation of the delivered change (a known follow-up that belongs to THIS fix) may stay in `resolutionNotes`. Anything else goes to `docspace/agent-zone` or a new card, not the ticket.

## Hard Rules

- Phase 3 confirmation is a hard gate. No mutating MCP call runs before an explicit `proceed`.
- Dev status before main status, always. Ensure `developer` + `needsDev=true`, set dev status -> `ready-for-release`, then move status -> `resolved`.
- A rejected required transition STOPS the run with a report. Never silently skip a step.
- Customer-facing fields (`solution`, the customer comment) stay plain business language -- never code, file paths, branch/PR refs, or internal IDs. Engineering detail goes only to `resolutionNotes` and the dev-note.
- All fields are PLAIN TEXT -- no HTML, no Markdown formatting. Use line breaks for separation.
- Relevance gate is mandatory: no field carries session noise (pre-existing/unrelated test failures, session follow-up tasks, environment issues, side observations).
- One ticket per run. No card moves, no docspace log, no git, no PR.
