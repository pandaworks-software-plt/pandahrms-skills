# pandahrms-skills

Pandahrms-specific skills plugin for Claude Code. Provides domain skills that integrate with the [superpowers](https://github.com/obra/superpowers) plugin.

## Skills

| Skill | Description |
|-------|-------------|
| **spec-writing** | Convert design documents into Gherkin feature specs in pandahrms-spec |
| **cross-project-bridge** | Structured protocol for debugging cross-project FE/BE issues |
| **system-setup** | Guide new developers through environment setup (macOS + Windows) |

## Installation

```bash
claude plugins add pandaworks-software-plt/pandahrms-skills
```

## How it fits

This plugin adds domain-specific skills to the superpowers development pipeline:

```
superpowers:brainstorming --> superpowers:writing-plans --> pandahrms-skills:spec-writing
    --> superpowers:executing-plans (TDD) --> superpowers:code-review --> superpowers:finish-branch
```

Additional standalone skills: `cross-project-bridge` and `system-setup`.

## License

UNLICENSED - Proprietary. Pandaworks Software Plt.
