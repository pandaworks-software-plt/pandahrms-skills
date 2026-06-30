---
name: release
description: Cut a release of the pandahrms-skills plugin. Triggers on `/release`, "release", "bump version and release", "cut a release", "ship a release", "publish the plugin". Auto-detects the semver bump level from the unreleased changes (new skill / rename / slash-command change = minor; fix/tweak/docs = patch; never major without an explicit ask), shows the chosen `current -> next` with its reason, and confirms before bumping. Writes the new version to `.claude-plugin/plugin.json` (source of truth) and the README version line, runs `/commit` (format + lint + `/verify` gate, then atomic commits, so the version bump ships in the commit), pushes `main`, then tags `v<version>` and creates a matching GitHub release via `gh`. Outward-facing: confirms before the push and before the GitHub release. Does NOT skip the `/commit` gate, never force-pushes, never major-bumps on its own.
---

# Release

## Overview

Cut a plugin release: pick the semver bump from the unreleased changes, write it to the version files, run the `/commit` gate, push `main`, tag `v<version>`, create the GitHub release. Outward-facing steps (push, GitHub release) confirm first.

## Phase 1: Determine bump level (auto from changes)

Find the unreleased changes:

- Baseline = latest `v*` tag (`git tag --list 'v*' --sort=-v:refname | head -1`); if none, baseline = `origin/main`.
- Gather: `git log <baseline>..HEAD --oneline`, plus working-tree changes (`git status --porcelain`, `git diff --stat`).

Classify the bump level per the repo rule:

- **minor** -- a new skill dir added (`skills/<name>/SKILL.md` is new), a skill renamed or removed, a slash-command added/renamed/removed, a new hook, or another structurally significant change.
- **patch** -- fixes, tweaks, docs, content edits to existing skills.
- **major** -- never auto. Only when the user explicitly asked for a major bump this turn; then confirm.

Read the current version from `.claude-plugin/plugin.json`. Compute the next version.

Present one line: `current <x.y.z> -> next <x.y.z> (<level>): <one-line reason>`. Confirm via AskUserQuestion:

- **Proceed** -> Phase 2.
- **Change level** -> user picks patch / minor / major (major needs explicit confirm), recompute, re-present.
- **Abort** -> STOP. No file edits.

## Phase 2: Bump version files

- Edit `.claude-plugin/plugin.json` `version` to the next version.
- Edit the README version line (`**Version:** <x.y.z>`).
- `grep` the tracked tree for the old version string; update any other canonical plugin-version mention. Leave unrelated version strings (dependency versions, examples) untouched.

## Phase 3: Commit gate (`/commit`)

Invoke `/commit`. It runs format + lint + `/verify` (build + test), requires `VERIFY RESULT: PASS`, then plans and executes atomic commits -- the version bump rides in the commit.

- `/commit` reaches `Committed N atomic commits. Working tree clean.` -> Phase 4.
- `/commit` STOPS at its gate (format/lint/`/verify` fail) -> STOP. Surface the failure. Re-run `/release` after the user fixes it.

## Phase 4: Push main

- Determine the release branch -- this repo releases from `main`. If the current branch is not `main`, STOP and ask the user how to proceed.
- Show what will push: `git log origin/main..HEAD --oneline`.
- Confirm via AskUserQuestion before pushing (outward-facing): **Push** or **Abort**.
- On Push: `git push origin main`.

## Phase 5: Tag + GitHub release

- `git tag v<version>` at `HEAD`, then `git push origin v<version>`.
- Build release notes from the unreleased commit subjects (Phase 1 list), grouped by type.
- Confirm via AskUserQuestion before creating the release (outward-facing): **Create release** or **Skip**.
- On Create: `gh release create v<version> --title "v<version>" --notes "<notes>"`.
- If `gh` is missing or unauthenticated, STOP after the tag push and report -- the tag is pushed; the GitHub release can be created later.

## Phase 6: Terminate

Emit one line: `Released v<version>: pushed main, tagged, GitHub release <created|skipped>.` Then STOP.

## Hard Rules

- Manual. Outward-facing: confirm before the push (Phase 4) and before the GitHub release (Phase 5).
- Never major-bump on auto-detection. Major needs an explicit user ask plus a confirm.
- Never bypass the `/commit` gate -- it owns format + lint + `/verify`. No `--skip` unless the user passes it.
- Never force-push, never push a branch other than `main`, never delete or move an existing tag.
- Version source of truth is `.claude-plugin/plugin.json`; the README line mirrors it.
- One release per run.

## Out of Scope

- Editing skill behavior or fixing code as part of the release.
- Creating branches or PRs (this repo releases by pushing `main`).
- Publishing to any registry other than the GitHub release.
