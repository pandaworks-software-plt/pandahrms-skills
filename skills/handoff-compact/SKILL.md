---
name: handoff-compact
description: Manually invoked as `/handoff-compact [optional-path]` to write a handoff document capturing the current session's state, then trigger context compaction immediately after the file is written. Captures user intent, decisions made, pending follow-ups, file paths touched, test counts, and concrete next-step commands so a future session (or the same one after compact) can resume cleanly. Does NOT auto-trigger; does NOT commit.
---

# Handoff + Compact

Slash command: `/handoff-compact [optional-path]`.

Writes one Markdown handoff document, then triggers `/compact`. Reader of the file alone (no transcript) must be able to: (a) understand what was worked on, (b) know what is staged but uncommitted, (c) know what is broken and why, (d) run exact commands to resume.

## Inputs

- `$1` (optional) -- absolute or workspace-relative output path. Overrides default.
- No `$1` -> infer path:
  1. If `docs/handoffs/` exists -> `docs/handoffs/YYYY-MM-DD-<feature-slug>.md`.
  2. Else if `docs/plans/` exists -> `docs/plans/YYYY-MM-DD-<feature-slug>-state.md`.
  3. Else -> `docs/handoffs/YYYY-MM-DD-<feature-slug>.md` (create folder).
- `<feature-slug>` derived from the most prominent feature / branch discussed. Lowercase kebab-case. When unsure, ask once.

Use today's date via `date +%Y-%m-%d`.

## Before writing

1. Run `git status -s` for staged/unstaged inventory.
2. Run `git rev-parse --abbrev-ref HEAD` for branch line.
3. If atlas was running, read plan's `## Atlas Progress` for current step.
4. If a recent debug used direct DB / Redis evidence, fetch fresh terminal output.

## Template

Section order is fixed. Skip a section only when genuinely empty; mark skipped sections with `(no content this session)`. Never omit a heading.

```markdown
# <Feature / Topic> -- Handoff

**Last updated:** YYYY-MM-DD, <one-line phase, e.g. "mid-atlas Step 8 user-test pause">
**Working directory:** <project absolute path>
**Branch:** <git branch>

## TL;DR for the next session

One paragraph. What the session was about, what is built, what is open, what to do next. 4-8 sentences. A reader of only this section should still know where to pick up.

## Current state

| Layer | Status |
|---|---|
| Atlas / pipeline step | <e.g. "Step 8 (user-test), paused"> |
| Working tree | <e.g. "staged changes present, no commits"> |
| Tests | <pass counts per area, e.g. "BE unit 30/30, BE integration 47/47, FE 238/238"> |
| Type-check | <clean / breaking> |
| Local infra | <docker containers up, DB migrated, redis up, ngrok off, etc.> |

## Features built this session (uncommitted)

For each substantial feature or fix:

- **<Name>** -- one-line purpose. List files touched (link to them). Note non-obvious decisions.

## Open issue being debugged

If a bug investigation is in flight: the report, evidence already gathered (with file/line refs or DB/log snippets), hypotheses still open, next planned diagnostic.

## Recent fix history

Chronological table of recent fixes applied this session. One row per fix:

| # | Fix | Files | Why |

5-15 rows max.

## Decisions made and locked

Each decision the user confirmed this session. Format: `Decision: <X>. Reason: <Y>.` One line each. Include rejected alternatives only when they show the trade-off.

## Open product questions parked for later

Items raised then explicitly deferred. One line each.

## Resume cookbook for next session

A `bash`-fenced block with the exact commands to run first. Order:

1. Inspect git state (`git status -s`, `git diff --cached --stat | head -50`).
2. Verify tests (exact `pnpm vitest run ...` / `dotnet test --filter ...` lines that matter).
3. Verify type-check.
4. Verify infra (containers up, DB has expected rows, queue state if relevant).
5. Specific next-step commands for the open issue, if any.

Every command must run from a known working directory. State the cwd in a comment when it differs between commands.

## What atlas / the pipeline still owes after the open issue closes

Bullet list of remaining pipeline steps (code review, commit, deploy, etc.) so the resumed session knows what comes next.
```

## Writing rules

- Concrete over abstract. `POST returns 202 with jobId` beats `the endpoint is async`. File paths beat feature names.
- Cite evidence, not hopes. If a test currently fails, name it and the reason. Never claim "all green" with open work.
- No filler. Drop sentences like `moving forward we will...`. Use verbs and file paths.
- Link, do not duplicate. Refer to spec / plan / design markdown by path; never copy content.
- Names match reality. Use actual symbol names from code, not informal conversation names.

## Hard rules

- No commit. Handoff lands staged-or-untracked; user decides whether to commit.
- No push.
- No other skill calls.
- No long verbatim test logs or stack traces. Summarise; reader can re-run.
- No speculation about follow-up work. Capture only what was explicitly said.
- No code blocks longer than 30 lines. Reference the file path instead.

## After writing

1. Print one line: `Handoff written: <relative path>`.
2. Print one line: `Pick up next session with: cat <path>`.
3. Output `/compact` as the final assistant message. The CLI consumes it and triggers compaction. No further tool calls.
