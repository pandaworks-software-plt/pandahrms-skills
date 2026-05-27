# CLAUDE.md

## Project Overview

This is the **pandahrms-skills** repository -- a Claude Code plugin containing Pandahrms-specific skills, hooks, and documentation for the Pandahrms monorepo workspace.

## Structure

```
pandahrms-skills/
├── .claude-plugin/plugin.json   # Plugin metadata and version
├── skills/                      # Claude Code skills (SKILL.md files)
│   │  # Pre-flight (runs first on every user turn -- repeat-back / intent lock)
│   ├── optimise-prompt/               # Rephrase user request in B2-English on every turn so the user can confirm Claude read it right. Pipeline-node skills skip it.
│   │  # Pipeline orchestrator (entry point)
│   ├── atlas-pipeline-orchestrator/   # Unified design -> spec -> plan -> execute pipeline
│   │  # Pipeline components (used by atlas)
│   ├── design-refinement/             # Design refinement with mandatory test+spec context loading
│   ├── plan-writing/                  # Implementation plan writing
│   ├── execute-plan/                  # Subagent-driven execution with codex modes
│   │  # Spec + review skills
│   ├── spec-writing/                  # Gherkin spec writing (hard gate before implementation)
│   ├── spec-review/                   # Cross-check design docs against Gherkin specs
│   ├── athena-code-review/            # Code review, fix issues, /simplify (no commits)
│   ├── aegis-security-review/         # Security review (OWASP + Pandahrms-specific), no commits
│   ├── simplify/                      # 3-agent parallel reuse/quality/efficiency pass on working-tree changes (no commits)
│   ├── hermes-commit/                 # Verify clean, plan and execute atomic commits
│   │  # Standalone skills
│   ├── branching/                     # Safe branch creation with upstream protection
│   ├── bridge-file/                   # Communication between FE/BE Claude sessions
│   ├── ef-migrations/                 # Entity Framework Core migrations
│   ├── debugging/                     # 4-phase root-cause-first debugging for bugs/test failures
│   ├── retrospective/                 # Manual /pandahrms:retrospective on a completed atlas plan file -> markdown retro
│   └── tool-harness-bootstrap/        # Manual /pandahrms:tool-harness-bootstrap -- studies project, recommends + installs mechanical-check tools (Reqnroll, Semgrep, gitleaks, ESLint rules, PreToolUse hooks); per-project, per-tool approval
├── hooks/                       # Claude Code hooks (session-start, etc.)
└── docs/                        # Plans and documentation
```

## Versioning

- Version is tracked in `.claude-plugin/plugin.json` under the `"version"` field
- Follow semver: bump patch for fixes/tweaks, minor for new skills or significant changes
- Stay on the current major (v3) by default. Use minor bumps even for changes that look breaking (e.g. skill renames, slash-command changes) -- those are absorbed via the minor channel here
- Do NOT bump the major version unless the user explicitly asks for it
- Bump version with every push to main

## Editing Skills

- Each skill lives in `skills/<skill-name>/SKILL.md`
- Skills use YAML frontmatter (`name`, `description`) followed by markdown content
- The `description` field determines when Claude Code invokes the skill -- keep it precise
- Test skill changes by invoking the skill in a Pandahrms project workspace
- SKILL.md body content must NOT contain any of these three prose types:
  - **WHY prose** -- rationale, justification, or reasoning for a rule. Body holds rules and instructions only; rationale belongs in commit messages, design docs, or chat replies
  - **Upstream-flow prose** -- descriptions of which skill, step, or pipeline node invokes this one ("called by atlas Step 5", "triggered after spec-writing"). The invoker owns that knowledge; the invoked skill stays self-contained
  - **Negative-trigger prose** -- "does NOT trigger on X", "skip when Y", or any mention of skills/contexts the current skill should ignore. Silence is the rule; only state what the skill does. (This applies to the body only -- the frontmatter `description` field still needs precise trigger language for the harness)

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
