# pandahrms-skills

**Version:** 4.12.0

Pandahrms-specific skills plugin for Claude Code.

The plugin is a set of manual, standalone skills. There is no orchestrator -- you run each step yourself.

## Skills

### Flow skills (run in order)

| Skill | Slash Command | Description |
|-------|---------------|-------------|
| **discover** | `/pandahrms:discover` | Free-form intake door: a new feature / enhancement / bug -> objective + acceptance criteria |
| **discover-ticket** | `/pandahrms:discover-ticket` | Ticket intake door (workspace-prod MCP) -> same output contract as `/discover` |
| **discover-project** | `/pandahrms:discover-project` | Project-queue door (workspace-prod MCP) -> numbered table of a project's pending dev tickets; user picks -> `/discover-ticket` |
| **spec** | `/pandahrms:spec` | Write/update the L1 behaviour Gherkin spec in pandahrms-spec; conditional on behaviour change; user-agreement gate |
| **slice** | `/pandahrms:slice` | Cut agreed work into independently-completable cards; each card holds its L2 spec files + an ordered work sequence |
| **execute** | `/pandahrms:execute` | Run one card: guided run with stop-gates, spec-first TDD, inline `/lint-gate` + `/code-review` per layer, `/verify` at card pre-complete; `/execute card-NN` or bare `/execute` for the next card |
| **execute-sonnet** | `/pandahrms:execute-sonnet` | Sonnet-pinned variant of `/execute`; `--blast-mode` queues the cards as a Workflow of Sonnet subagents |
| **status** | `/pandahrms:status` | Read-only summary: auto-fires when `/execute` finishes the last card, also a manual status report |
| **close** | `/pandahrms:close` | Mutating close: verify all cards done, invoke `/resolve-ticket` for ticket work, write the log, mark the work closed |
| **resolve-ticket** | `/pandahrms:resolve-ticket` | Card-less ticket resolution: one ticket ref -> resolved, ready-for-release state (confirm before mutate) |
| **pr** | `/pandahrms:pr` | Optional final PR: runs `/commit` first, then raises the PR (ticket reference in the body) |

### Quality skills (leaf actions inside `/execute`; also standalone)

| Skill | Slash Command | Description |
|-------|---------------|-------------|
| **lint-gate** | `/pandahrms:lint-gate` | Diff-scoped deterministic guard runner (linter, TODO/secrets/debug scans, structural tier, L1->L2 traceability); writes `.lint-gate-result.md` |
| **verify** | `/pandahrms:verify` | Project-scoped runner: full build + full test suite + coverage gate; writes `.verify-result.json` |
| **code-review** | `/pandahrms:code-review` | Diff-scoped LLM-judgment review in 3 modes (standalone \| orchestrated \| autonomous); consumes the lint-gate result file, fixes issues, runs `/simplify` (no commits) |
| **security-review** | `/pandahrms:security-review` | Security review (OWASP Top 10 + Pandahrms tenant/audit/PII checks) (no commits) |
| **simplify** | `/pandahrms:simplify` | 3-agent reuse/quality/efficiency pass on working-tree changes (no commits) |
| **commit** | `/pandahrms:commit` | Branch-scope commit gate: format + lint auto-fix, `/verify` PASS required, then atomic commits |

### Utilities

| Skill | Slash Command | Description |
|-------|---------------|-------------|
| **optimise-prompt** | `/pandahrms:optimise-prompt` | Manual rephrase: restate your request in B1 English on demand (the per-turn repeat-back lives in the plugin hooks) |
| **pr-approver-review** | `/pandahrms:pr-approver-review` | Senior-approver review of an already-opened GitHub PR by number |
| **branching** | `/pandahrms:branching` | Safe branch creation with upstream protection and folder-based naming |
| **ef-migrations** | `/pandahrms:ef-migrations` | EF Core migration commands for Performance and Recruitment APIs |
| **handoff-compact** | `/pandahrms:handoff-compact` | Write a session handoff doc, then compact |
| **tool-doctor** | `/pandahrms:tool-doctor` | Once-per-project setup: audit machine + project for the guard tools, offer install/config per item |

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
/discover  (or /discover-ticket; /discover-project to pick from a project's pending queue)   intake -> objective + acceptance criteria
   -> /spec        L1 behaviour Gherkin spec (central pandahrms-spec)
   -> /slice       work cards (each holds its L2 spec files + an ordered sequence)
   -> /execute     per card: guided run with stop-gates + spec-first TDD
                   inline leaf actions: /lint-gate then /code-review orchestrated
                   (+ /security-review when sensitive), deploy BE, regen FE types,
                   /verify at card pre-complete. No per-card commit or PR -- changes accumulate
   -> /status      auto when the last card is done (conclusion) + manual status anytime
   -> /close       update ticket status, write the log, tidy cards
   -> /pr          final PR for the whole work, once every card is done (runs /commit first)
```

The always-on execution rules (TDD markers, gates, sensitivity list, output discipline, the per-turn repeat-back) ship via the plugin's SessionStart hook (`hooks/execution-rules.md`), with a slim UserPromptSubmit reminder each turn -- no per-member setup.

## License

UNLICENSED - Proprietary. Pandaworks Software Plt.
