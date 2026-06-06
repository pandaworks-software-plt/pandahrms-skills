---
name: status
description: The read-only status step of the Pandahrms close. Fires automatically when /execute finishes the LAST card in the per-work card folder (presents the completion conclusion), and also runs manually anytime the user asks "where are we", "what's left", "status", "what's pending", or "/status" to get a mid-flight snapshot. Scans every card's status, reports the in-progress card's current sequence step, surfaces piled/deferred tasks, and concludes with a completion summary when all cards are done. Read-only -- changes nothing; a requested change becomes a NEW card via /slice.
---

# Status

## Overview

Read-only where-are-we report on a piece of work. Auto on last card done; manual anytime. Changes nothing -- no file edits, no git, no ticket, no docspace writes.

## CHECK -- scan the per-work card folder

Read `work_folder` from `_overview.md`. Scan `<work-folder>/active/` and `<work-folder>/done/`.

- Card status: in `<work-folder>/active/` (active) or `<work-folder>/done/` (done).
- For any in-progress (active) card: which sequence step it is on, read from that card's checklist.
- Count total cards, done cards, remaining cards.

## PENDING -- surface piled / deferred tasks

Collect tasks flagged during execution to handle later:

- Follow-ups and TODOs noted on cards.
- Deferred items recorded in the docspace todo (`agent-zone/todo.md`).

List each with its source card / location.

## CONCLUDE -- report

All cards done -> completion summary:

- Every card, what was built.
- Confirm nothing remains active.
- List any piled / deferred tasks still open.

NOT all cards done (manual mid-flight) -> progress report:

- Progress: done count vs total.
- What's left: remaining cards + the in-progress card's current step.
- What's piled: deferred / follow-up tasks.

## OUTPUT

A where-are-we report only. The user comments in chat. A requested change routes to `/slice` as a NEW card -> `/execute` -- always a new card, never a silent patch. Updating the existing L1 spec for that change goes through `/spec`.

## Hard Rules

- Read-only. No file edits, no `git` of any kind, no ticket update, no docspace writes.
- No card moves (`active`->`done`), no close, no PR.
- A user comment requesting a change routes to `/slice` (new card); updating the existing L1 spec for it goes through `/spec`. This skill does not act on the change itself.

## Next step

End by telling the user their next skill: when every card is done, run `/close` to finish the work; if cards remain, run `/execute` for the next card.
