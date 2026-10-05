---
name: spec
description: '`/spec` -- write or update the L1 behaviour spec in a dedicated git worktree of the L1 spec repo (location read from the `Spec repo:` line in the active host''s global instructions; asks the user and saves it there when the location is not stated) from intake output (objective + acceptance criteria + module). The L1 spec is the tech-agnostic product truth in Gherkin -- no UI mechanics, no API/endpoint detail. Presents a scenario-index table for user agreement, then asks whether to commit/PR to the L1 spec repo -- never auto-commits. Does NOT write L2 executable specs (those come later during execution).'
---

# /spec -- L1 Behaviour Spec

## Contents

- GATE-0 -- behaviour change?
- LOCATE
  - Dedicated worktree
- WRITE -- convert acceptance criteria -> Gherkin
  - BDD -- behaviour-focused, strict no-UI (the L1 rule)
  - No hard-coded messages or input-coercion
  - Structure
  - Tags -- at BOTH feature and scenario level
  - Mandatory scenarios
  - File splitting
  - Naming + roles
  - Self-check (loop until clean)
- GATE-1 -- present + agree
- COMMIT? -- ask, never auto
- RECORD
- Next step

Write/update **L1 behaviour spec** in dedicated `<spec-worktree>` of `<spec-repo>` (resolved in LOCATE) from intake output. L1 = tech-agnostic product truth (WHAT + when done), Gherkin, no UI mechanics, no API/endpoint detail, no field-level form steps. Write L1 only -- never L2 FE/BE executable specs.

INPUT: the per-work `_overview.md`. Read its `work_folder` frontmatter field for the work folder location -- never re-derive it. From `_overview.md` read objective + plain-statement acceptance criteria + `module`.

## GATE-0 -- behaviour change?

Behaviour change = new rule, changed rule, or bug that changes what "correct" means.
- No behaviour change (pure UI restyle, refactor preserving observable outputs, rename, formatting) -> ask the user to confirm SKIP; on confirm, return control.
- Yes -> continue.

## LOCATE

Resolve the L1 spec repo location (call the result `<spec-repo>`) in this order -- first hit wins:

1. **Stated location** -- if the session context or the active host's global instructions (`~/.codex/AGENTS.md` for Codex, `~/.claude/CLAUDE.md` for Claude Code) name where the L1 spec lives (e.g. a `Spec repo: <path>` line under a `## Spec` heading), use that path. Never re-derive it. Never guess a default path.
2. **Ask** -- if it does not resolve, ask the user for the L1 spec repo path. Do not guess a path; do not offer a default.

After the user answers via step 2, append a `Spec repo: <path>` line to the active host's global instructions (`~/.codex/AGENTS.md` for Codex, `~/.claude/CLAUDE.md` for Claude Code). Put it under a `## Spec` heading; create the file and heading if absent. The user's answer is authorization to write -- do not re-confirm. Never write this line to a project instruction file.

### Dedicated worktree

Resolve working project's current branch as `<work-branch>` with `git rev-parse --abbrev-ref HEAD`. STOP on detached HEAD.

Never checkout `<work-branch>` in primary `<spec-repo>` worktree and never write `.feature` files there. Use one dedicated spec worktree per `<work-branch>`:

- `<spec-worktree-root>` = sibling folder `<spec-repo-parent>/<spec-repo-name>-worktrees`
- `<spec-worktree-name>` = `<work-branch>` with each `/` replaced by `--`
- `<spec-worktree>` = `<spec-worktree-root>/<spec-worktree-name>`

Read `git -C <spec-repo> worktree list --porcelain` before reading any `.feature`:

1. `<work-branch>` already attached -> use reported worktree path as `<spec-worktree>`; do not create another.
2. `<work-branch>` exists as local branch but is not attached -> require computed `<spec-worktree>` path to be absent, create `<spec-worktree-root>`, then run `git -C <spec-repo> worktree add <spec-worktree> <work-branch>`.
3. `<work-branch>` has no local branch -> ask user to confirm creating it and name local source branch (recommend local `main`). After confirmation, require computed path absent, create root, then run `git -C <spec-repo> worktree add -b <work-branch> <spec-worktree> <local-source-branch>`. Never create from `origin/*`. Verify new branch has no upstream with `git -C <spec-worktree> branch -vv`.
4. Computed path exists but is not registered -> STOP and ask user. Never delete, prune, or reuse it automatically.

Run `git -C <spec-worktree> status --porcelain` before editing. If changes exist, inspect them. Continue only when all changes belong to current work; otherwise STOP and ask user. State `<spec-worktree>` path used.

Find `specs/<module>/<feature>/*.feature` under `<spec-worktree>`. `module` comes from intake -- never hard-code a module list. `<feature>` = kebab-case of affected feature area (e.g. `adhoc-review`). Full path: `specs/<module>/<feature>/<entity>-<area>.feature`. Check existing FIRST: update matching `.feature`; create new file only when none fits.

Study conventions before writing: read the most recently modified `.feature` in `specs/<module>/` (or, if none, one from another module) and match its tags, section headers, role names, scenario phrasing, Background structure verbatim. State which file you used as reference.

## WRITE -- convert acceptance criteria -> Gherkin

Sub-step order (do not reorder): decide file split -> Feature header per file -> section banners in CRUD order -> scenarios in CRUD order -> scenario tags as each is written -> validate naming/roles/BDD on the finished file.

### BDD -- behaviour-focused, strict no-UI (the L1 rule)

Every scenario describes business behaviour + outcomes, implementation-agnostic.

NEVER use UI language:
- controls: "click button", "tap", "select from dropdown", "fill textbox", "date picker", "toggle"
- feedback: "see a toast", "modal appears", "spinner", "page redirects"
- layout: "in the sidebar", "top right", "header"
- styling: "highlighted red", "greyed out", "bold"

Use business-outcome phrasing instead:

| Instead of (UI) | Write (behaviour) |
|---|---|
| "I click the Apply Leave button" | "I apply for leave" |
| "I select Annual Leave from the dropdown" | "I choose leave type Annual Leave" |
| "I pick 2026-03-10 in the date picker" | "from 2026-03-10 to 2026-03-12" |
| "I click Submit" | omit -- implied by the action |
| "I see a green toast Success" | "the application should be submitted successfully" |
| "a modal appears asking for confirmation" | "I am asked to confirm the action" |
| "the row is highlighted in red" | "the leave request should be flagged as conflicting" |
| "the page redirects to dashboard" | "I should see my leave summary" |

`Then` steps assert business outcomes (balance changes, status transitions, records created, permission checks, rule enforcement) -- NOT toasts, modals, colors, redirects, spinners.

### No hard-coded messages or input-coercion

Do not name a literal validation message string or commit to an input behaviour (auto-clamp vs reject). Assert the outcome.

| Bad (hard-coded) | Good (outcome) |
|---|---|
| `Then I see "Months must be between 1 and 24"` | `Then the request is rejected as out of range` |
| `When I enter 25 then the input becomes 24` | `Then 25 is not accepted as a valid value` |
| `When I enter 0.5 then the value is rounded to 1` | `Then 0.5 is not accepted as a valid value` |

Exception: a literal message that IS the business behaviour (legal/compliance disclosure) -- keep the string PLUS a comment naming the requirement.

### Structure

Feature header per file:

```gherkin
@module-tag @feature-tag
Feature: Clear Feature Name
  As a [role]
  I want to [action]
  So that [benefit]

  Background:
    Given [common preconditions]
```

Section banners (comment headers) in exact CRUD order -- creation, listing, editing, deletion, then special features. Do not reorder.

```gherkin
# =============================================================================
# Section Name
# =============================================================================
```

Scenario:

```gherkin
@tag
Scenario: Clear, specific description
  Given [initial context]
  When [action taken]
  Then [expected outcome]
  And [additional outcomes]
```

- First-person phrasing ("I create", "I update"). "When I try to..." for invalid actions.
- Data tables for structured input; triple quotes for multi-line text.

### Tags -- at BOTH feature and scenario level

Feature-level: module tag + sub-feature tag (e.g. `@template`, `@response`, `@review-lifecycle`).

Scenario-level:

| Tag | Usage |
|---|---|
| `@create` | creation |
| `@list` | listing |
| `@edit`, `@update` | modification |
| `@delete` | deletion/archival |
| `@validation` | error/validation cases |
| `@filter`, `@search` | filtering/search |
| `@submit`, `@status` | workflow/status transitions |
| `@authorization` | permission checks |
| `@bulk`, `@batch` | bulk operations |
| `@hierarchy` | hierarchical relationships |
| `@employee`, `@reviewer`, `@manager` | role-specific |
| `@bugfix` | scenario covering a fixed bug |
| `@refactor` | scenario documenting preserved behaviour |

### Mandatory scenarios

- `@validation` scenarios for every feature.
- Bug fix -> a `@bugfix` scenario capturing the correct behaviour.
- Refactor -> `@refactor` scenarios documenting preserved behaviour.

If a mandatory `@validation` scenario needs behaviour not present in the intake acceptance criteria, STOP and ask the user for that behaviour -- never invent the rule.

### File splitting

Split by functional concern / bounded context (different actors, lifecycle phases, or concerns) -- NOT by CRUD. Keep CRUD on the same entity together.
- Each `.feature` <= 200 lines. Target 3-4 files, max 6 per feature.
- Naming `[entity]-[functional-area].feature`, singular entity names (e.g. `adhoc-review-template.feature`).

### Naming + roles

- Feature names: clear capability description.
- Scenario names: describe expected behaviour, verbatim from action.
- Consistent role names: "HR administrator", "Head of Department", "employee", "reviewer", "manager".

### Self-check (loop until clean)

Run on every `.feature` written or changed this pass, after the sub-steps above:

1. UI language: `grep -nEi 'click|tap|dropdown|textbox|date picker|toggle|toast|modal|spinner|redirect|sidebar|top right|highlighted|greyed' <file>` -> rewrite each hit with the behaviour table.
2. Hard-coded messages: `grep -nE 'Then I see "' <file>` -> rewrite as an outcome, unless a comment names the legal/compliance requirement.
3. Tags: feature header carries module + sub-feature tags; every `Scenario:` has a tag line above it; at least one `@validation` scenario per feature; `@bugfix` / `@refactor` where mandatory.
4. Size: `wc -l <file>` <= 200.

Any failure -> fix it, run all four checks again. Only a clean set goes to GATE-1. Print `Self-check: clean after <N> pass(es)` under the Totals footer.

## GATE-1 -- present + agree

Present the complete L1 spec. Output a scenario-index table per `.feature` file changed or added:

```markdown
### [<filename>.feature](<relative-path-from-working-project>)

| # | Line | Scenario |
|---|---|---|
| 1 | <line> | <scenario title> |
```

Table rules:
- One table per file changed/added this pass.
- Heading is a markdown link `[<filename>](<relative-path>)`.
- One row per `Scenario:` / `Scenario Outline:` (skip `Background`). Title verbatim. Line = source line of the keyword. Numbering restarts per file.
- Footer: `**Totals:** <N> files, <M> scenarios (<per-file counts>).`

Highlight assumptions and gaps. Wait for explicit agreement. On change requests, edit ONLY what was asked, re-present (refreshed table), loop until approved. Do not rewrite unaffected scenarios.

## COMMIT? -- ask, never auto

After agreement, write `.feature` file(s) to `specs/<module>/<feature>/` in `<spec-worktree>`.

Then ask the user: commit/PR the spec, or leave it written and stop?
- **No** -> leave the `.feature` files written in the working tree, stop. Nothing staged, nothing committed.
- **Yes** -> in `<spec-worktree>`: stage ONLY `.feature` files this skill produced (`git -C <spec-worktree> add <each .feature path>`) -- never `git add .`/`-A`, never any non-`.feature` path; leave all other working-tree files untouched. Commit them in `<spec-worktree>`. Then optionally open a PR if user wants one.

Nothing auto-commits. Never stage or commit outside `<spec-worktree>`.

Commit-message format when the user opts to commit:
- new: `feat(<module>): add spec for <feature>`
- updated: `feat(<module>): update spec for <feature>`
- bug fix: `fix(<module>): add spec covering <bug>`

## RECORD

Record the written L1 `.feature` path(s) back into the per-work `_overview.md` (the file at `work_folder` from INPUT) so later steps can find the parent spec.

## Next step

End by telling the user to run `/slice` to cut the work into cards.
