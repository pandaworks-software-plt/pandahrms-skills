# AGENTS.md

This repository is the dual-host Pandahrms skills plugin for Codex and Claude Code.

Read `CLAUDE.md` for the shared repository structure, editing rules, and release conventions. Interpret host-specific wording there as applying to the active host unless this file says otherwise.

## Codex compatibility

- Keep `.codex-plugin/plugin.json` and `.claude-plugin/plugin.json` versions synchronized.
- The shared `skills/` directory must remain valid for both hosts. Prefer capability wording such as "ask the user", "invoke the bundled skill", and "dispatch a subagent" over a host-specific tool name.
- Codex explicit invocation uses `$pandahrms:<skill-name>`; Claude Code uses `/pandahrms:<skill-name>`.
- Codex discovers the existing `hooks/hooks.json` automatically. Keep hook output and commands compatible with both hosts.
- Test manifest changes with the Codex plugin validator and test skill changes with the skill validator before handoff.
