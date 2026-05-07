# CLAUDE.md

## Project Overview

This is the **pandahrms-skills** repository -- a Claude Code plugin containing Pandahrms-specific skills, hooks, and documentation for the Pandahrms monorepo workspace.

## Structure

```
pandahrms-skills/
├── .claude-plugin/plugin.json   # Plugin metadata and version
├── skills/                      # Claude Code skills (SKILL.md files)
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
│   ├── hermes-commit/                 # Verify clean, plan and execute atomic commits
│   │  # Standalone skills
│   ├── branching/                     # Safe branch creation with upstream protection
│   ├── bridge-file/                   # Communication between FE/BE Claude sessions
│   └── ef-migrations/                 # Entity Framework Core migrations
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

## Conventions

- Product name: **Pandahrms** (not PandaHRMS)
- No emojis in any content
- Skills should be implementation-agnostic where possible
