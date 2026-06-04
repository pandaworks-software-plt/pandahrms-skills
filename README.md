# pandahrms-skills

Pandahrms-specific skills plugin for Claude Code.

## Skills

| Skill | Slash Command | Description |
|-------|---------------|-------------|
| **atlas-pipeline-orchestrator** | `/pandahrms:atlas-pipeline-orchestrator` | Thin runner: fast lane + main flow (understand -> spec -> decompose -> per-card execute + review -> PR) |
| **card-decompose** | `/pandahrms:card-decompose` | Cut an understood change into independently-shippable vertical-slice cards (path + sensitivity tags) |
| **card-execute** | `/pandahrms:card-execute` | Native TDD execution of one card; SOLID/DDD inlined; gates + markers; commit-after-review |
| **card-pr** | `/pandahrms:card-pr` | Per-card PR step: raise PR?, ask how to branch, commit via hermes-commit, open the PR (cross-repo = 2 linked PRs) |
| **spec-writing** | `/pandahrms:spec-writing` | Conditional Gherkin spec step: check/update specs when behavior changes; user-agreement gate; inline design-coverage cross-check |
| **athena-code-review** | `/pandahrms:athena-code-review` | Review git changes against code standards, fix issues, run /simplify (no commits) |
| **aegis-security-review** | `/pandahrms:aegis-security-review` | Security review (OWASP Top 10 + Pandahrms tenant/audit/PII checks); optionally invoked from athena-code-review |
| **hermes-commit** | `/pandahrms:hermes-commit` | Verify code is reviewed and clean, plan and execute atomic commits |
| **branching** | `/pandahrms:branching` | Safe branch creation with upstream protection and folder-based naming |
| **bridge-file** | `/pandahrms:bridge-file` | Structured protocol for debugging cross-project FE/BE issues |
| **ef-migrations** | `/pandahrms:ef-migrations` | EF Core migration commands for Performance and Recruitment APIs |
| **debugging** | `/pandahrms:debugging` | 4-phase root-cause-first debugging for bugs, test failures, and unexpected behavior |

## Installation

1. Launch Claude Code
2. Add the marketplace:
   ```
   /plugins marketplace add https://github.com/pandaworks-software-plt/pandahrms-skills.git
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

`atlas-pipeline-orchestrator` is the single entry point for build work in Pandahrms projects. It is a thin runner: a fast lane for trivial changes, and a main flow that cuts work into vertical-slice cards and ships each as its own small PR.

```
Trivial change --> fast lane: confirm --> native TDD --> offer a PR --> done

Everything else --> pandahrms:atlas-pipeline-orchestrator (main flow)
    --> understand (native, no skill)
    --> pandahrms:spec-writing (check/update; you agree)
    --> pandahrms:card-decompose (vertical-slice cards; you agree)
    --> per card: pandahrms:card-execute (native TDD)
                  --> pandahrms:athena-code-review (+ pandahrms:aegis-security-review when sensitive)
                  --> pandahrms:card-pr (raise PR?, ask-branch, commit, open PR)
```

The always-on execution rules (TDD markers, gates, sensitivity list, fast-lane threshold) ship via the plugin's SessionStart hook, so they apply in every session with no per-member setup.

Additional standalone skills: `pandahrms:branching`, `pandahrms:bridge-file`, `pandahrms:athena-code-review`, `pandahrms:aegis-security-review`, `pandahrms:hermes-commit`, `pandahrms:ef-migrations`, and `pandahrms:debugging`.

## License

UNLICENSED - Proprietary. Pandaworks Software Plt.
