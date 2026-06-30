---
name: discover-ticket
description: The ticket intake door of the Pandahrms flow. `/discover-ticket <ticket-ref>`. Takes a single ticket reference -- a UUID or a human ticket number like T26050092. Fetches the ticket via the workspace-prod MCP `get_ticket` tool, reads its description sections and existing `typeSpecificData.acceptanceCriteria`, validates and fills gaps in that acceptance criteria (never generates it from scratch), and emits the same converged output contract as `/discover` (objective/root-cause + plain-statement acceptance criteria + module), with the Source field carrying ticketNumber, customer, and affected sys version. Writes to a per-ticket card folder `<TICKET>-<slug>/_overview.md` inside the current repo (never outside the repo root).
---

# Discover (ticket door)

Fetch a ticket, validate its acceptance criteria, converge, emit the shared output contract. Read-only on the ticket. Writes one `_overview.md`.

## Input

Single argument: ticket reference. Accepts a UUID or a human ticket number (e.g. `T26050092`). If missing, ask for it via AskUserQuestion. One ticket per run.

## Workflow

### Phase 1: Fetch

Call `mcp__workspace-prod__get_ticket` with `id` = the ticket reference. Both UUID and human number resolve. Response carries both `id` and `ticketNumber`.

If the call errors or returns no ticket, report the failure and stop. No `_overview.md`.

### Phase 2: Read

Read from the fetched ticket:

- Description sections (intent, Expected-Behaviour / expected behaviour, steps, context).
- `typeSpecificData.acceptanceCriteria` -- the existing acceptance criteria shipped on the ticket.
- Classifier fields: `module`, `isBug`, `type`, `affectedSysVersion`.
- Customer.

Derive intent type from the ticket:
- `isBug` true (or `type` indicates a bug) -> `bug`.
- Otherwise map `type` to `new-feature` or `enhancement`. If the ticket `type` maps to either and the choice is ambiguous, ask the user via AskUserQuestion. Do not guess silently.

### Phase 3: Validate + fill gaps in acceptance criteria

Start from the ticket's existing `typeSpecificData.acceptanceCriteria`. Do NOT regenerate from scratch.

- Keep each existing criterion that is a plain, testable statement.
- Rewrite any criterion that is vague, untestable, or restates the title into a plain testable statement of the same intent.
- Add a criterion ONLY to cover an expected behaviour stated in the description that the existing list misses. Each added criterion traces to ticket content.
- For a `bug`, frame criteria as the correct behaviour to restore.

Acceptance criteria stay plain testable statements. No Gherkin.

### Phase 4: Convergence gate (final move)

Re-read the exploration. Keep ONLY confirmed items. Drop every dead end and discarded hypothesis. No "considered/rejected" section.

- Objective: one line -- what success looks like. For a `bug`, the correct behaviour to restore.
- Root cause: `bug` only -- the one confirmed cause, if known from the ticket. If not yet known, leave it for investigation and note in Open questions.
- Context: only what survived scrutiny.
- Module: from the ticket's `module` field.

### Phase 5: Resolve output location

The work lives in a per-work folder of this shape:

```
<work-folder>/
  _overview.md      # this intake output contract
  active/           # cards not yet done
  done/             # finished cards
```

Hard boundary: `<work-folder>` MUST resolve inside the current repo (the working git project). Reject any rung that resolves outside the repo root -- skip it and fall to the next. Never write `_overview.md` to an external location (home dir, external/iCloud vault, any path outside the repo).

Resolve `<work-folder>` by the ladder; use the first that resolves inside the repo:
1. user-configured location, only when inside the repo. Skip if it resolves outside the repo root.
2. user-preferred location if stated, only when inside the repo. Skip if outside.
3. in-project default: `docs/pandahrms/work/<TICKET>-<slug>/`. Always inside the repo; the guaranteed fallback.

- `<TICKET>` = the human `ticketNumber`.
- `<slug>` = short kebab-case slug from the ticket title.

Create `<work-folder>/`, `<work-folder>/active/`, and `<work-folder>/done/` if missing. Write `_overview.md` into `<work-folder>/`.

### Phase 6: Write `_overview.md`

Fill the shared output contract. Same output contract as `/discover`, PLUS the ticket-only `Source` field (ticketNumber, customer, sys version). `Source` is an intentional additive field for the ticket door, not a mismatch.

Record the resolved `<work-folder>` path as a `work_folder:` frontmatter field at the top of `_overview.md`. This is the single source of truth for the path that later steps read; always repo-relative since the folder lives inside the repo.

```
---
work_folder: <repo-relative path to <work-folder>>
---

# <Intent / title>

- Type: new-feature | enhancement | bug
- Objective: <one line -- what success looks like; bug: correct behaviour to restore>
- Module / affected area: <module(s) the work touches>
- Source: ticket <ticketNumber> | customer <customer> | sys version <affectedSysVersion>

## Context
<only what survived scrutiny>

## Root cause      (bug only)
<the one confirmed cause>

## Acceptance criteria
- <plain testable statement>
- <plain testable statement>

## Open questions   (if any)
- <question>
```

Omit `## Root cause` for non-bug types. Omit `## Open questions` when none.

Print the written path and a one-line summary. End. Return control to caller or user.

## Hard Rules

- Read-only on the ticket. No `update_ticket`, no comment, no status change, no proposal post.
- No git, no commits, no file edits outside the `<TICKET>-<slug>/_overview.md` write.
- The output work folder MUST live inside the current repo. Never write `_overview.md` outside the repo root (no home dir, no external/iCloud vault).
- Acceptance criteria are validated + gap-filled from ticket content, never invented from scratch.
- Same output contract as `/discover`, plus the ticket-only `Source` field (ticketNumber, customer, sys version).
- Acceptance criteria stay plain testable statements. No Gherkin at intake.
- One ticket per run.

## Out of Scope

- Generating acceptance criteria the ticket does not support.
- Gherkin / spec conversion.
- Editing the ticket on the workspace.
- Card decomposition, implementation, branching, commits, PRs.

## Next step

End by telling the user their next skill: if the change affects business behaviour, run `/spec`; if it is UI-only with no behaviour change, skip to `/slice`.
