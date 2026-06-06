# CLAUDE.md

## Project Overview

This is the **pandahrms-skills** repository -- a Claude Code plugin containing Pandahrms-specific skills, hooks, and documentation for the Pandahrms monorepo workspace.

## Structure

The plugin is a set of manual, standalone skills. There is no orchestrator -- the user runs each step. Typical order: `/discover` (or `/discover-ticket`) -> `/spec` -> `/slice` -> `/execute` (per card) -> `/status` -> `/close` -> `/pr`.

```
pandahrms-skills/
├── .claude-plugin/plugin.json   # Plugin metadata and version
├── skills/                      # Claude Code skills (SKILL.md files)
│   │  # Pre-flight (runs first on every user turn -- repeat-back / intent lock)
│   ├── optimise-prompt/               # Rephrase user request in B1-English (keep technical terms) each turn so the user can confirm Claude read it right
│   │  # Flow skills (manual, standalone; run in order, no orchestrator)
│   ├── discover/                      # Free-form intake door: a new feature / enhancement / bug -> objective + acceptance criteria
│   ├── discover-ticket/               # Ticket intake door (workspace-prod MCP) -> same output contract as /discover
│   ├── discover-project/              # Project-queue door (workspace-prod MCP) -> numbered table of pending dev tickets, user picks -> /discover-ticket
│   ├── spec/                          # Write/update the L1 behaviour Gherkin spec in pandahrms-spec (conditional on behaviour change)
│   ├── slice/                         # Cut agreed work into vertical-slice cards (each holds its L2 spec files + an ordered work sequence)
│   ├── execute/                       # Run one card: guided run with stop-gates, spec-first TDD, inline review/deploy/regen
│   ├── status/                        # Read-only summary: auto-fires when /execute finishes the last card, also a manual status report
│   ├── close/                         # Mutating close: re-check, update ticket status, write log, tidy cards
│   ├── pr/                            # Optional final PR: runs /commit first, then raises the PR (ticket ref in body)
│   │  # Quality skills (leaf actions inside /execute; also standalone)
│   ├── code-review/                   # Code review, fix issues, /simplify (no commits)
│   ├── security-review/               # Security review (OWASP + Pandahrms-specific), no commits
│   ├── simplify/                      # 3-agent parallel reuse/quality/efficiency pass on working-tree changes (no commits)
│   ├── commit/                        # Verify clean, plan and execute atomic commits
│   │  # Standalone utilities
│   ├── branching/                     # Safe branch creation with upstream protection
│   ├── ef-migrations/                 # Entity Framework Core migrations
│   └── handoff-compact/               # Write a session handoff doc, then compact
├── hooks/                       # Claude Code hooks (session-start, etc.)
└── docs/                        # Plans and documentation
```

## Versioning

- Version is tracked in `.claude-plugin/plugin.json` under the `"version"` field
- Follow semver: bump patch for fixes/tweaks, minor for new skills or significant changes
- Stay on the current major (v4) by default. Use minor bumps even for changes that look breaking (e.g. skill renames, slash-command changes) -- those are absorbed via the minor channel here
- Do NOT bump the major version unless the user explicitly asks for it
- Bump version with every push to main

## Editing Skills

- Each skill lives in `skills/<skill-name>/SKILL.md`
- Skills use YAML frontmatter (`name`, `description`) followed by markdown content
- The `description` field determines when Claude Code invokes the skill -- keep it precise
- **Plugin content must be self-contained.** Never reference per-member files such as `~/.claude/rules/*` (TDD.md, SOLID.md, Security.md, etc.) from any SKILL.md body, frontmatter `description`, hook, or plugin doc. A teammate who installs the plugin may not have those files, so the reference dangles. Inline the principle you need (the TDD loop, the SOLID rules, the OWASP/security checks) directly. The plugin ships its own rules; it never depends on a member's home-directory config.
- Test skill changes by invoking the skill in a Pandahrms project workspace
- SKILL.md body content must NOT contain any of these three prose types:
  - **WHY prose** -- rationale, justification, or reasoning for a rule. Body holds rules and instructions only; rationale belongs in commit messages, design docs, or chat replies
  - **Upstream-flow prose** -- descriptions of which skill, step, or pipeline node invokes this one ("called by atlas Step 5", "triggered after spec-writing"). The invoker owns that knowledge; the invoked skill stays self-contained
  - **Negative-trigger prose** -- "does NOT trigger on X", "skip when Y", or any mention of skills/contexts the current skill should ignore. Silence is the rule; only state what the skill does. (This applies to the body only -- the frontmatter `description` field still needs precise trigger language for the harness)
- **Allowed exception -- the `## Next step` line.** A flow skill MAY end with a single `## Next step` section that suggests the next skill to the user (e.g. "run `/spec` next"). This is the one permitted downstream-flow line: it is a user-facing recommendation, not a runner and not an instruction the model auto-executes. The dev still invokes the next skill by hand, and that skill re-reads the durable `_overview.md` / cards -- no state passes by prose. Keep it to one short section; do not let it grow into orchestration logic.

## SKILL.md Prose Compression Rules

SKILL.md bodies are loaded into Claude's context on every invocation, so prose is paying rent. Write skill bodies in compressed form. The frontmatter `description` field is exempt -- it stays in normal English so trigger language remains precise.

**Drop:**
- Articles: a, an, the (where omission is unambiguous)
- Filler: just, really, basically, actually, simply, essentially
- Pleasantries: "you should", "make sure to", "remember to", "it is important that"
- Hedging: "it might be worth", "you could consider", "would be good to"
- Redundant phrasing: "in order to" -> "to", "the reason is because" -> "because"
- Connective fluff: "however", "furthermore", "additionally", "in addition"

**Preserve EXACTLY (never modify):**
- Frontmatter (`name`, `description`, any YAML keys)
- Code blocks (fenced ``` and indented)
- Inline code (`backtick content`)
- File paths, commands, URLs, env vars, version numbers
- Technical terms, library names, API names, error strings
- Markdown structure: headings, list nesting, table layout
- Proper nouns: skill names, project names, person names

**Compress:**
- Short synonyms: "use" not "utilize", "fix" not "implement a solution for", "big" not "extensive"
- Fragments OK: "Run tests before commit" not "You should always run tests before committing"
- One example where multiple show the same pattern
- Merge bullets that say the same thing differently

**Safety rails:**
- If a fragment makes step order or scope ambiguous, keep the full sentence
- Security warnings, destructive-action confirmations, and irreversible-op gates stay in full English
- Tables: compress cell text but keep every column and row

## Conventions

- Product name: **Pandahrms** (not PandaHRMS)
- No emojis in any content
- Skills should be implementation-agnostic where possible
