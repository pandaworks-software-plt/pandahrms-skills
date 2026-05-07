# pandahrms-skills

Pandahrms-specific skills plugin for Claude Code.

## Skills

| Skill | Slash Command | Description |
|-------|---------------|-------------|
| **atlas-pipeline-orchestrator** | `/pandahrms:atlas-pipeline-orchestrator` | Unified pipeline: design -> specs -> QA review -> plan -> Plan/Spec cross-review -> execute -> simplify -> test |
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

## Installation

1. Launch Claude Code
2. Add the marketplace:
   ```
   /plugins marketplace add pandaworks-software-plt/pandahrms-skills
   ```
3. Install the plugin:
   ```
   /plugins install pandahrms@pandahrms-skills
   ```

### Updating

To update the plugin to the latest version:
```
/plugins update pandahrms@pandahrms-skills
```

## How it fits

`atlas-pipeline-orchestrator` is the single entry point for design-through-execution work in Pandahrms projects:

```
Any work request --> pandahrms:atlas-pipeline-orchestrator
    --> pandahrms:design-refinement (design)
    --> pandahrms:spec-writing (Gherkin specs - hard gate)
    --> QA review (conditional)
    --> pandahrms:plan-writing (implementation plan)
    --> Plan <-> Spec cross-review
    --> pandahrms:execute-plan (subagent-driven TDD)
    --> /simplify
    --> Playwright e2e (conditional)
    --> user tests --> pandahrms:hermes-commit
```

It ensures `spec-writing` is never skipped after design and that code review, security review (when applicable), simplification, and spec compliance are verified before the user tests.

Additional standalone skills: `pandahrms:branching`, `pandahrms:bridge-file`, `pandahrms:athena-code-review`, `pandahrms:aegis-security-review`, `pandahrms:hermes-commit`, and `pandahrms:ef-migrations`.

## License

UNLICENSED - Proprietary. Pandaworks Software Plt.
