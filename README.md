# pandahrms-skills

Pandahrms-specific skills plugin for Claude Code.

The plugin is a set of manual, standalone skills. There is no orchestrator -- you run each step yourself.

## Skills

### Flow skills (run in order)

| Skill | Slash Command | Description |
|-------|---------------|-------------|
| **discover** | `/pandahrms:discover` | Free-form intake door: a new feature / enhancement / bug -> objective + acceptance criteria |
| **discover-ticket** | `/pandahrms:discover-ticket` | Ticket intake door (workspace-prod MCP) -> same output contract as `/discover` |
| **spec** | `/pandahrms:spec` | Write/update the L1 behaviour Gherkin spec in pandahrms-spec; conditional on behaviour change; user-agreement gate |
| **slice** | `/pandahrms:slice` | Cut agreed work into vertical-slice cards; each card holds its L2 spec files + an ordered work sequence |
| **execute** | `/pandahrms:execute` | Run one card: guided run with stop-gates, spec-first TDD, inline review/deploy/regen; `/execute card-NN` or bare `/execute` for the next card |
| **status** | `/pandahrms:status` | Read-only summary: auto-fires when `/execute` finishes the last card, also a manual status report |
| **close** | `/pandahrms:close` | Mutating close: re-check all cards done, update ticket status, write the log, tidy cards |
| **pr** | `/pandahrms:pr` | Optional final PR: runs `/commit` first, then raises the PR (ticket reference in the body) |

### Quality skills (leaf actions inside `/execute`; also standalone)

| Skill | Slash Command | Description |
|-------|---------------|-------------|
| **code-review** | `/pandahrms:code-review` | Review git changes against code standards, fix issues, run `/simplify` (no commits) |
| **security-review** | `/pandahrms:security-review` | Security review (OWASP Top 10 + Pandahrms tenant/audit/PII checks) (no commits) |
| **simplify** | `/pandahrms:simplify` | 3-agent reuse/quality/efficiency pass on working-tree changes (no commits) |
| **commit** | `/pandahrms:commit` | Verify the working tree is clean, plan and execute atomic commits |

### Pre-flight and utilities

| Skill | Slash Command | Description |
|-------|---------------|-------------|
| **optimise-prompt** | (runs each turn) | Repeat-back in B1 English (keep technical terms) so you can confirm Claude read you right |
| **branching** | `/pandahrms:branching` | Safe branch creation with upstream protection and folder-based naming |
| **ef-migrations** | `/pandahrms:ef-migrations` | EF Core migration commands for Performance and Recruitment APIs |
| **handoff-compact** | `/pandahrms:handoff-compact` | Write a session handoff doc, then compact |

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

Each skill is manual and standalone -- you run each step. There is no orchestrator: each skill ends by suggesting the next one (`## Next step`), so the flow self-guides while you stay in control of every hop. A typical piece of work flows like this:

```
/discover  (or /discover-ticket)     intake -> objective + acceptance criteria
   -> /spec        L1 behaviour Gherkin spec (central pandahrms-spec)
   -> /slice       vertical-slice cards (each holds its L2 spec files + an ordered sequence)
   -> /execute     per card: guided run with stop-gates + spec-first TDD
                   inline leaf actions: /code-review (+ /security-review when sensitive),
                   deploy BE, regen FE types, per-card commit/PR
   -> /status      auto when the last card is done (conclusion) + manual status anytime
   -> /close       update ticket status, write the log, tidy cards
   -> /pr          optional final PR (runs /commit first)
```

The always-on execution rules (TDD markers, gates, sensitivity list) ship via the plugin's SessionStart hook, so they apply in every session with no per-member setup.

## License

UNLICENSED - Proprietary. Pandaworks Software Plt.
