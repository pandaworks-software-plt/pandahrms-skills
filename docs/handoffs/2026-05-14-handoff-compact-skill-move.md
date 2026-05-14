# handoff-compact skill move -- Handoff

**Last updated:** 2026-05-14, post skill move, pre-compact
**Working directory:** /Users/kyson/Developer/pandaworks/pandahrms-skills
**Branch:** main

## TL;DR for the next session

Moved the global `/handoff` skill into the pandahrms-skills plugin and renamed it `/handoff-compact`. The new skill chains the original handoff document writer with a final `/compact` trigger. Source SKILL.md lives at [skills/handoff-compact/SKILL.md](skills/handoff-compact/SKILL.md). The original at `~/.claude/skills/handoff/` was deleted. Plugin version in `.claude-plugin/plugin.json` was NOT bumped (per project rule: bump at push time, not per commit). Working tree has one untracked folder, no commits made. After this doc lands, the session triggers `/compact`.

## Current state

| Layer | Status |
|---|---|
| Atlas / pipeline step | n/a (single-skill maintenance task, not an atlas run) |
| Working tree | untracked: `skills/handoff-compact/` and `docs/handoffs/` (this file). No commits. |
| Tests | n/a (skill plugin has no test suite) |
| Type-check | n/a |
| Local infra | n/a |

## Features built this session (uncommitted)

- **handoff-compact skill** -- handoff doc writer + final `/compact` trigger. Files touched: [skills/handoff-compact/SKILL.md](skills/handoff-compact/SKILL.md) (new), `~/.claude/skills/handoff/SKILL.md` (deleted). Non-obvious decision: the skill's final step instructs the assistant to output `/compact` as the last assistant message so the CLI consumes it and triggers compaction. SKILL.md body follows the plugin's compression rules (no WHY, no upstream-flow, no negative-trigger prose).

## Open issue being debugged

(no content this session)

## Recent fix history

(no content this session)

## Decisions made and locked

- Decision: rename `/handoff` to `/handoff-compact` and chain a `/compact` step at the end. Reason: user wants one slash command that saves session state to disk then immediately frees context.
- Decision: do not bump `.claude-plugin/plugin.json` version now. Reason: project rule -- version bumps happen at push time, not per commit.
- Decision: delete original `~/.claude/skills/handoff/`. Reason: user said "move", not "copy".

## Open product questions parked for later

(no content this session)

## Resume cookbook for next session

```bash
# cwd: /Users/kyson/Developer/pandaworks/pandahrms-skills

# 1. Inspect working tree
git status -s

# 2. Verify the new skill is in place
ls skills/handoff-compact/
cat skills/handoff-compact/SKILL.md | head -10

# 3. Confirm the original is gone
ls ~/.claude/skills/handoff/ 2>&1   # expect "No such file or directory"

# 4. When ready to ship, bump version then commit
#    Edit .claude-plugin/plugin.json: "3.27.0" -> "3.28.0" (minor: new skill)
#    Then: /hermes-commit
```

## What atlas / the pipeline still owes after the open issue closes

- Bump `.claude-plugin/plugin.json` version (minor: new skill) before push.
- Commit untracked files (`skills/handoff-compact/`, `docs/handoffs/2026-05-14-handoff-compact-skill-move.md`).
- Push to main.
