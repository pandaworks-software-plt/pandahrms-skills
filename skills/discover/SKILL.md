---
name: discover
description: The free-form intake door for a new feature, enhancement, or bug in Pandahrms. `/discover <free-form intent>`. Turns a raw, unstructured intent into a converged objective plus plain-statement acceptance criteria. Branches internally by intent type -- new-feature and enhancement run a brainstorm mode; a bug runs an understand-scope-then-root-cause investigate mode. Ends by writing one output contract (intent, type, objective, context, root cause for bugs, acceptance criteria, module, open questions) to a per-work location inside the current repo. Does NOT write code, run git, or commit, or write outside the repo.
---

# Discover

## Overview

Free-form intake. Take a raw intent, explore it, converge to confirmed conclusions, and emit one output contract. Two internal modes by intent type. The artifact is a converged conclusion. No code, no git, no commit.

## Step 1: Classify intent type

Read the intent. Set `type`:

- `new-feature` -- capability that does not exist yet.
- `enhancement` -- change or extension to existing behavior.
- `bug` -- existing behavior is wrong; restore correct behavior.

If the intent is ambiguous between feature/enhancement and bug, ask via AskUserQuestion before exploring. Otherwise echo the picked type on one line and proceed.

`new-feature` and `enhancement` route to Brainstorm mode. `bug` routes to Investigate mode.

## Step 2a: Brainstorm mode (new-feature / enhancement)

Explore the intent as a thinking partner:

- Restate what the user wants in plain terms.
- Surface the user-facing goal -- who benefits and what they can do after.
- Probe scope edges: what is in, what is out, what is deferred.
- Float approach options and shapes. Poke holes. Discard weak ones inline.
- Pull in real context: which module, which existing screens/flows/data it touches.
- Ask the user only when a fork blocks convergence -- via AskUserQuestion, candidate answers as options.

Aim for a converged objective and a set of plain testable acceptance criteria.

## Step 2b: Investigate mode (bug)

Root-cause first. Do not propose a fix shape until the cause is confirmed.

1. **Understand scope.** What is the wrong behavior. What is the correct behavior to restore. Where it shows (module, screen, endpoint). When it started, if known.
2. **Read evidence.** Reproduce steps, error text, logs, the failing path through the code. Search the codebase for the involved symbols.
3. **Find the pattern.** What ties the failing cases together; what separates passing from failing.
4. **Hypothesize and confirm.** Form the smallest hypothesis that explains every symptom. Confirm it against the code/evidence. Discard disproven hypotheses inline.

Aim for one confirmed root cause and acceptance criteria that assert the correct behavior. If the root cause cannot be confirmed, record it as an Open Question -- do not invent one. Acceptance criteria still capture the expected correct behavior.

## Step 3: Convergence gate (final move, both modes)

Before writing output:

- Re-read the whole exploration.
- Keep ONLY confirmed items -- things that survived scrutiny.
- Drop every dead end, wrong hypothesis, and rejected option.
- No "considered / rejected" section. No log of wrong turns.

## Step 4: Fill the output contract

One schema. Fill every applicable field.

| Field | Content |
|-------|---------|
| Intent / title | Short name for the work. |
| Type | `new-feature` \| `enhancement` \| `bug`. |
| Objective | One line -- what success looks like. For a bug: the correct behavior to restore. |
| Context | Only what survived the convergence gate. |
| Root cause | Bug only -- the one confirmed cause. Omit for feature/enhancement. |
| Acceptance criteria | Plain testable statements. One behavior per line. No Gherkin. |
| Module / affected area | Which module(s) the work touches. Infer it from the exploration. |
| Open questions | Anything unresolved the next step must settle. Omit if none. |

Rules:
- Acceptance criteria are plain English testable statements, not Gherkin.
- `Module / affected area` is required -- name the best-inferred module even when uncertain, and flag the uncertainty as an open question.
- Omit a field only when the table says it is conditional (Root cause, Open questions).

## Step 5: Resolve output location (per-work folder)

Create one per-work folder and write the contract as `_overview.md` inside it. The folder has this shape:

```
<work-folder>/
  _overview.md      # the intake output contract
  active/           # cards not yet done
  done/             # finished cards
```

Hard boundary: `<work-folder>` MUST resolve inside the current repo (the working git project). Reject any rung that resolves outside the repo root -- skip it and fall to the next. Never write the contract to an external location (home dir, external/iCloud vault, any path outside the repo).

Resolve `<work-folder>` by walking the ladder top-down; use the first that resolves inside the repo. `<slug>` = short kebab-case name derived from the title/intent.

1. **Configured (in-repo only)** -- a user-configured intake location inside the repo: `<configured-root>/projects/<project>/<slug>/`. Skip if it resolves outside the repo root.
2. **User-preferred (in-repo only)** -- a standing preferred location the user named, only when inside the repo. Skip if outside.
3. **In-project default** -- `docs/pandahrms/work/<slug>/`. Always inside the repo; the guaranteed fallback.

Create the work folder plus its `active/` and `done/` subfolders. Write `_overview.md` with the resolved path recorded at the top as a frontmatter field `work_folder: <repo-relative path>` -- the single source of truth for the path, always repo-relative since the folder lives inside the repo. State the resolved path on one line after writing.

## Step 6: Present and close

- Print the filled contract inline.
- State the written path.
- End. No code, no git, no commit, no follow-up offers.

## Hard Rules

- Manual only. Runs on `/discover` or an explicit name mention.
- No code edits, no migrations, no dev servers, no tests run as part of intake.
- No `git add`, `git commit`, `git push`, branch creation, or PR creation.
- Acceptance criteria stay plain-statement. No Gherkin.
- The written artifact contains only converged conclusions -- no dead ends, no rejected-option log.
- The output work folder MUST live inside the current repo. Never write the contract outside the repo root (no home dir, no external/iCloud vault).
- `Module / affected area` is filled by every run.
- One AskUserQuestion at a time, only when a fork blocks convergence.

## Out of Scope

- Writing or editing implementation code.
- Gherkin / `.feature` specs.
- Decomposing the work into cards or PRs.
- Branch creation, commits, pushes, PRs.
- Ticket-shaped intake (a sibling door handles a ticket reference).

## Next step

End by telling the user their next skill: if the change affects business behaviour, run `/spec`; if it is UI-only with no behaviour change, skip to `/slice`.
