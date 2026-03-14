# CLAUDE.md

## Project Overview

This is the **pandahrms-skills** repository -- a Claude Code plugin containing Pandahrms-specific skills, hooks, and documentation for the Pandahrms monorepo workspace.

## Structure

```
pandahrms-skills/
├── .claude-plugin/plugin.json   # Plugin metadata and version
├── skills/                      # Claude Code skills (SKILL.md files)
│   ├── context-continuation/    # Summarize and continue in fresh sessions
│   ├── create-branch/           # Safe branch creation with upstream protection
│   ├── cross-project-bridge/    # Communication between FE/BE Claude sessions
│   ├── development-workflow/    # Orchestrator for all development work
│   ├── ef-migrations/           # Entity Framework Core migrations
│   ├── react-web-frontend/      # Next.js frontend conventions
│   ├── review-and-commit/       # Code review and atomic commit workflow
│   ├── spec-writing/            # Gherkin spec writing (hard gate before implementation)
│   └── system-setup/            # Developer workstation setup
├── hooks/                       # Claude Code hooks (session-start, etc.)
└── docs/                        # Plans and documentation
```

## Versioning

- Version is tracked in `.claude-plugin/plugin.json` under the `"version"` field
- Follow semver: bump patch for fixes/tweaks, minor for new skills or significant changes, major for breaking changes
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
