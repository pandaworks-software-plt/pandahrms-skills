# pandahrms-skills

Pandahrms-specific skills plugin for Claude Code. Provides domain skills that integrate with the [superpowers](https://github.com/obra/superpowers) plugin.

## Skills

| Skill | Slash Command | Description |
|-------|---------------|-------------|
| **design-pipeline** | `/pandahrms:design-pipeline` | Design phase: brainstorm -> specs -> plan |
| **execution-pipeline** | `/pandahrms:execution-pipeline` | Execution phase: execute plan -> code review -> simplify -> spec cross-check -> test |
| **spec-writing** | `/pandahrms:spec-writing` | Write/update Gherkin specs before implementing any change (hard gate) |
| **code-review** | `/pandahrms:code-review` | Review git changes against code standards, fix issues, run /simplify (no commits) |
| **commit** | `/pandahrms:commit` | Verify code is reviewed and clean, plan and execute atomic commits |
| **react-web-frontend** | `/pandahrms:react-web-frontend` | Frontend conventions and patterns for Next.js projects |
| **cross-project-bridge** | `/pandahrms:cross-project-bridge` | Structured protocol for debugging cross-project FE/BE issues |
| **ef-migrations** | `/pandahrms:ef-migrations` | EF Core migration commands for Performance and Recruitment APIs |
| **system-setup** | `/pandahrms:system-setup` | Guide new developers through environment setup (macOS + Windows, Docker or IIS) |

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
Any work request --> pandahrms:design-pipeline
    --> superpowers:brainstorming (design)
    --> pandahrms:spec-writing (Gherkin specs - hard gate)
    --> superpowers:writing-plans (implementation plan)

Plan ready --> pandahrms:execution-pipeline
    --> superpowers:executing-plans (TDD)
    --> pandahrms:code-review --> /simplify --> spec cross-check
    --> user tests --> pandahrms:commit --> superpowers:finish-branch
```

The `design-pipeline` ensures `spec-writing` is never skipped after brainstorming. The `execution-pipeline` ensures code review, simplification, and spec compliance are verified before the user tests.

Additional standalone skills: `pandahrms:cross-project-bridge`, `pandahrms:system-setup`, and `pandahrms:ef-migrations`.

## License

UNLICENSED - Proprietary. Pandaworks Software Plt.
