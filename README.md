# pandahrms-skills

Pandahrms-specific skills plugin for Claude Code. Provides domain skills that integrate with the [superpowers](https://github.com/obra/superpowers) plugin.

## Skills

| Skill | Slash Command | Description |
|-------|---------------|-------------|
| **forge-pipeline-orchestrator** | `/pandahrms:forge-pipeline-orchestrator` | Unified pipeline: brainstorm -> specs -> plan -> execute -> test |
| **atlas-pipeline-orchestrator** | `/pandahrms:atlas-pipeline-orchestrator` | No-superpowers cousin of forge; manual-only entry via the slash command or forge handoff |
| **design-refinement** | `/pandahrms:design-refinement` | Sectioned design refinement with mandatory test+spec context loading |
| **plan-writing** | `/pandahrms:plan-writing` | Turn an approved design into a bite-sized implementation plan |
| **execute-plan** | `/pandahrms:execute-plan` | Dispatch implementer subagents per plan task; supports codex modes |
| **spec-writing** | `/pandahrms:spec-writing` | Write/update Gherkin specs before implementing any change (hard gate) |
| **spec-review** | `/pandahrms:spec-review` | Cross-check design docs against Gherkin specs for coverage gaps |
| **athena-code-review** | `/pandahrms:athena-code-review` | Review git changes against code standards, fix issues, run /simplify (no commits) |
| **aegis-security-review** | `/pandahrms:aegis-security-review` | Security review (OWASP Top 10 + Pandahrms tenant/audit/PII checks); optionally invoked from athena-code-review |
| **hermes-commit** | `/pandahrms:hermes-commit` | Verify code is reviewed and clean, plan and execute atomic commits |
| **branching** | `/pandahrms:branching` | Safe branch creation with upstream protection and folder-based naming |
| **bridge-file** | `/pandahrms:bridge-file` | Structured protocol for debugging cross-project FE/BE issues |
| **ef-migrations** | `/pandahrms:ef-migrations` | EF Core migration commands for Performance and Recruitment APIs |
| **forge-slow-mode** | `/pandahrms:forge-slow-mode` | Experimental iterative pipeline; one atomic piece at a time |

## Installation

### Prerequisites

Requires [superpowers](https://github.com/obra/superpowers) plugin.

### Steps

1. Launch Claude Code
2. Add the marketplaces:
   ```
   /plugins marketplace add obra/superpowers-marketplace
   /plugins marketplace add pandaworks-software-plt/pandahrms-skills
   ```
3. Install the plugins:
   ```
   /plugins install superpowers@superpowers-marketplace
   /plugins install pandahrms@pandahrms-skills
   ```

### Updating

To update the plugin to the latest version:
```
/plugins update pandahrms@pandahrms-skills
```

## How it fits

This plugin adds domain-specific skills to the superpowers development pipeline:

```
Any work request --> pandahrms:forge-pipeline-orchestrator
    --> superpowers:brainstorming (design)
    --> pandahrms:spec-writing (Gherkin specs - hard gate)
    --> pandahrms:spec-review (cross-check design vs specs)
    --> superpowers:writing-plans (implementation plan)
    --> superpowers:executing-plans (TDD)
    --> pandahrms:athena-code-review
        --> pandahrms:aegis-security-review (if security-sensitive)
        --> /simplify --> spec cross-check
    --> user tests --> pandahrms:hermes-commit --> superpowers:finish-branch
```

`forge-pipeline-orchestrator` is the single orchestrator from brainstorming through execution. It ensures `spec-writing` is never skipped after brainstorming, and that code review, security review (when applicable), simplification, and spec compliance are verified before the user tests.

Additional standalone skills: `pandahrms:branching`, `pandahrms:bridge-file`, and `pandahrms:ef-migrations`.

## License

UNLICENSED - Proprietary. Pandaworks Software Plt.
