---
name: retrospective
description: Manually invoked as `/pandahrms:retrospective [plan-file-path]` to generate a markdown retrospective from a completed atlas-pipeline-orchestrator run. With a path, reads the plan file's Atlas Progress timing block (optionally enriched with same-session conversation context). Without a path, reads the current session's conversation context for the atlas run that just finished -- no plan file required. Produces a step-level breakdown of where time went, the biggest time sinks with concrete cause-and-effect, an honest "where time could have been clawed back" list, and 1-3 skill improvement ideas. Writes to `docs/pandahrms/retrospectives/<feature-slug>-<YYYY-MM-DD>.md` in the working project so a team member can review the file and share it back to the plugin owner. Does NOT auto-trigger -- only on the slash command or an explicit "run a retrospective" mention. Does NOT commit, stage, or push.
---

# Retrospective

## When to run

Slash command: `/pandahrms:retrospective [plan-file-path]`. No auto-trigger.

## Required input

Either:

- A path to a plan file with a completed `## Atlas Progress` section (every step row is `done` or `skipped (<reason>)`; no rows in `pending` or `awaiting-user-test`), OR
- A current session that contains a completed atlas-pipeline-orchestrator run (atlas reached Step 11 commit, OR Step 8 user-test pause was followed by user confirmation to proceed, OR atlas was explicitly aborted with at least Steps 1-4 completed).

## Pre-flight

1. **Resolve mode:**
   - If user passed a path, set mode = `plan-file` and use that path.
   - Else set mode = `session` and read the current conversation context for the atlas run. The atlas run is identified by step announcements (`"Step 1 completed in ..."`, `"Scope Profile: ..."`, `"Development Summary [Scope: ...]"`, `"Atlas complete -- ..."`) and the plan file paths atlas printed during the run.
2. **Verify a completed run exists:**
   - `plan-file` mode: verify the plan file has an `## Atlas Progress` section. If missing, STOP and announce: `"Plan file '<path>' has no Atlas Progress section. Retrospective needs a completed atlas run."`
   - `session` mode: verify the conversation has atlas step announcements covering at least Steps 1-4 plus a terminal signal (Step 11 commit, Step 8 user-test pause, or explicit abort). If the session contains no atlas run at all (no Step announcements, no `"Scope Profile:"` line, no `"Atlas complete"` line), STOP and announce: `"This session has no atlas run to retrospect on. Run /atlas-pipeline-orchestrator first, or pass a completed plan file path: /pandahrms:retrospective <path>."` If the session contains atlas signals but Steps 1-4 are not all present, STOP and announce: `"Atlas run in this session has not reached Step 4 yet -- not enough data to retrospect on. Wait until execute completes (or aborts), then re-invoke."`
3. **Verify the run is complete:**
   - `plan-file` mode: every step row must be `done` or `skipped (<reason>)`. If any row is `pending` or `awaiting-user-test`, STOP and announce: `"Plan '<path>' is not finished -- step <N> is <status>. Run /atlas-pipeline-orchestrator --resume first."`
   - `session` mode: the session must have either the `"Atlas complete -- N commit(s) created on branch <branch>."` final line OR an explicit user "looks good" / "abort" decision at Step 8. If the run is still mid-pipeline, STOP and announce: `"Atlas run in this session is not finished -- last step seen was <step>. Wait until the run completes (or aborts), then re-invoke /pandahrms:retrospective."`
4. Announce:
   - `plan-file` mode: `"Generating retrospective from <plan-path>..."`
   - `session` mode: `"Generating retrospective from current session..."`

## What to read

From the environment (both modes):

- Branch name via `git rev-parse --abbrev-ref HEAD`.
- Today's date via `date +%Y-%m-%d`.

### `plan-file` mode

From the plan file, capture:

- **Header metadata** -- feature slug (derive from plan filename), Scope Profile, Codex mode, Codex execution mode, atlas start timestamp.
- **Step timing** -- every row of the Atlas Progress table (status + duration).
- **Step 4 task timing block** -- per-task dispatcher, type, wall-clock, test runtime, risk tag.
- **Subagent annotations** -- `DONE_WITH_CONCERNS` flags, retry counts, reviewer rejections, idle-wait observations.
- **Acknowledged Gaps block** -- bullet list if populated.

If the retrospective is invoked in the same session as the atlas run, also fold in conversation context for cause-and-effect detail on retries, reviewer rejections, and idle-wait. If conversation context is empty (fresh session), rely on plan-file annotations only.

### `session` mode

From the current conversation context, capture:

- **Header metadata** -- feature slug (from the plan file path atlas printed during Step 3 or from the design doc filename), Scope Profile (from the verbatim `"Scope Profile: <profile> (<rationale>)."` announcement), Codex mode (from atlas Step 0 start announcement or the `Codex enabled: ...` line in the plan file if atlas printed it), atlas start timestamp (from the first step announcement or atlas's `Atlas started: ...` line).
- **Step timing** -- from atlas's per-step completion announcements (`"Step N completed in Xm Ys (active work)"`) and the Development Summary block atlas printed at Step 8 (or the equivalent block reprinted at Step 11).
- **Step 4 task timing** -- from atlas's per-batch dispatch announcements and the Task Timing block, if atlas printed one.
- **Subagent annotations** -- from `DONE_WITH_CONCERNS` flags in dispatch reports, retry announcements, reviewer rejection messages, idle-wait observations atlas surfaced.
- **Acknowledged Gaps** -- from any `### Acknowledged Gaps` block atlas surfaced at Step 8 or Step 10, plus follow-up loop notes.
- **Cause-and-effect detail** -- richer than plan-file mode because the full subagent dispatch reports, user replies, and inline retry reasoning are in the conversation.

If the conversation references a plan file path that still exists on disk, read it for any numeric timing not announced inline -- but the session is the primary source.

## Output sections (in this exact order)

1. **Header** -- feature, branch, Scope Profile, Codex mode, total active time, run date, data sources line.
2. **Where the time went** -- table: step / wall-clock / one-line description. Skipped steps include the skip reason.
3. **Biggest single time sinks** -- top 3 items. Each: name, wall-clock, one-paragraph cause-and-effect.
4. **Where time could have been clawed back** -- 3-5 items. Each: change, estimated savings, one-line risk note. Sum the estimated savings as `Total potential clawback: ~<Xm>`.
5. **What is NOT a time sink** -- counter-narrative section listing what NOT to change (e.g. zero failures, zero reviewer rejects, user-wait excluded, test runtime under N seconds).
6. **Detailed timing block** -- verbatim Atlas Progress timing table, plus Step 4 task timing block if present.
7. **Future skill improvement ideas** -- 1-3 bullets, each a specific suggestion the plugin owner could act on (e.g. "Plan-writing template could add an FE form gotchas appendix"). One sentence per bullet, three bullets maximum.

Use plain markdown tables. B2 English throughout. No emojis.

## Output location

Write to `docs/pandahrms/retrospectives/<feature-slug>-<YYYY-MM-DD>.md` in the working project where:

- `<feature-slug>` matches the plan filename's slug (strip `.md`; strip any leading date prefix).
- `<YYYY-MM-DD>` is today's date from `date +%Y-%m-%d`.

If `docs/pandahrms/retrospectives/` does not exist, create it via `mkdir -p`.

If the target file already exists, append `-2`, `-3`, ... until the path is free. Announce the chosen path before writing.

## After write

Print to chat:

```
Retrospective saved: <full-path>

Top 3 time sinks:
- <sink 1>: <duration> -- <one-line cause>
- <sink 2>: <duration> -- <one-line cause>
- <sink 3>: <duration> -- <one-line cause>

Estimated clawback: ~<total>m if every suggestion lands.
```

Then stop. No follow-up offers. No commit. No push.

## Hard rules

- Read-only on the plan file (when given a path) and the conversation context. Never modify the plan file.
- No commits. The retrospective file stays uncommitted. The user decides when to commit and share.
- No `git push`, no staging beyond the retrospective file itself (and skill does not stage even that -- user stages manually).
- Output is markdown. Never YAML, JSON, or HTML.
- One retrospective per atlas run. Do not aggregate across multiple plan files or multiple session runs.
- One file write per invocation. If the user asks for "retrospectives on the last 5 runs", refuse and ask them to invoke once per atlas run (passing each plan file path in turn).

## Template

Use this skeleton when writing the retrospective. Replace bracketed values. Remove a section that has no content with a one-line `_(skipped: <reason>)_` note instead of leaving an empty heading.

```markdown
# Retrospective -- [feature-slug]

- **Branch:** [branch-name]
- **Scope Profile:** [lightweight|standard|heavyweight]
- **Codex mode:** [full|none]
- **Total active time:** [Xh Ym]
- **Run date:** [YYYY-MM-DD]
- **Data sources:** [plan file only] OR [plan file + same-session conversation context] OR [current session only -- no plan file path supplied]

## Where the time went

| Step | Wall-clock | What it was |
|------|-----------|-------------|
| Step 1 (Design) | [Xm] | [one-line description] |
| Step 2 (Spec) | [Xm] | [one-line description] |
| Step 3 (Plan) | [Xm] | [one-line description] |
| Step 4 (Execute) | [Xm Ys] | [one-line description, N batches, M tasks] |
| Step 5 (Audit) | [Xm] | [one-line description] |
| Step 6 (Simplify) | [Xm] | [one-line description] OR _skipped (<reason>)_ |
| Step 7 (Playwright) | [Xm] | [one-line description] OR _skipped (<reason>)_ |
| Step 10 (Code review) | [Xm] | [one-line description] |
| Step 11 (Commit) | [Xm] | [one-line description] |

## Biggest single time sinks

| Task or step | Wall-clock | Cause |
|--------------|-----------|-------|
| [name] | [Xm Ys] | [one-paragraph cause-and-effect] |
| [name] | [Xm Ys] | [one-paragraph cause-and-effect] |
| [name] | [Xm Ys] | [one-paragraph cause-and-effect] |

## Where time could have been clawed back

1. **[Change]** -- estimated savings ~[Xm]. Risk: [one-line].
2. **[Change]** -- estimated savings ~[Xm]. Risk: [one-line].
3. **[Change]** -- estimated savings ~[Xm]. Risk: [one-line].

**Total potential clawback:** ~[Xm] -- would have landed around [Xm] active time.

## What is NOT a time sink in this run

- [Item, e.g. "Zero subagent failures."]
- [Item, e.g. "Zero reviewer rejections at Step 10."]
- [Item, e.g. "Test runtime sum < 30s."]
- [Item, e.g. "User-wait excluded from active time."]

## Detailed timing block

[verbatim Atlas Progress timing table]

[Step 4 task timing block if present]

## Future skill improvement ideas

- [Specific, actionable suggestion 1.]
- [Specific, actionable suggestion 2.]
- [Specific, actionable suggestion 3.]
```
