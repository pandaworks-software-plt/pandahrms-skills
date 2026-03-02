# pandahrms-skills

Pandahrms-specific skills plugin for Claude Code. Provides domain skills that integrate with the [superpowers](https://github.com/obra/superpowers) plugin.

## Skills

| Skill | Slash Command | Description |
|-------|---------------|-------------|
| **spec-writing** | `/pandahrms:spec-writing` | Write/update Gherkin specs before implementing any change (hard gate) |
| **cross-project-bridge** | `/pandahrms:cross-project-bridge` | Structured protocol for debugging cross-project FE/BE issues |
| **system-setup** | `/pandahrms:system-setup` | Guide new developers through environment setup (macOS + Windows, Docker or IIS) |
| **ef-migrations** | `/pandahrms:ef-migrations` | EF Core migration commands for Performance and Recruitment APIs |

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
Any work request --> pandahrms:spec-writing (hard gate)
    --> superpowers:writing-plans --> superpowers:executing-plans (TDD)
    --> superpowers:code-review --> superpowers:finish-branch
```

Additional standalone skills: `pandahrms:cross-project-bridge`, `pandahrms:system-setup`, and `pandahrms:ef-migrations`.

## License

UNLICENSED - Proprietary. Pandaworks Software Plt.
