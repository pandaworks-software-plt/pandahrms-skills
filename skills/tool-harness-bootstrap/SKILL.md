---
name: tool-harness-bootstrap
description: Manually invoked as `/pandahrms:tool-harness-bootstrap` to study the current project, recommend mechanical-check tools (Reqnroll, Semgrep, gitleaks, ESLint rules, Roslyn analyzers, PreToolUse git allowlist hook), and install the user-picked subset per project. Probes language stack, test runners, existing analyzers, and CI config; outputs a ranked recommendation grouped by category (Spec executor, SAST, secret scan, lint, hook); installs only after per-tool AskUserQuestion approval. Idempotent on re-run. Does NOT auto-trigger -- only on the slash command or an explicit "tool-harness-bootstrap" mention.
---

# Tool Harness Bootstrap

Slash command: `/pandahrms:tool-harness-bootstrap`.

Studies the working project, recommends mechanical-check tools to install, and installs the user-picked subset per project. Replaces LLM-prompt validation with tool-enforced gates where practical.

## Inputs

- `$1` (optional) -- absolute path or workspace-relative path to one project file (`*.csproj`, `package.json`). Skill scopes to that project only.
- No `$1` -> auto-discover every `*.csproj`, `package.json` (excluding `node_modules`), `pyproject.toml`, `go.mod` in the working directory tree.

## Phases

Five phases. Each phase completes before the next starts.

### Phase 1 -- Detect stack

Run all reads in parallel:

1. `find . -maxdepth 4 -name '*.csproj' -not -path './node_modules/*' -not -path './bin/*' -not -path './obj/*'`
2. `find . -maxdepth 4 -name 'package.json' -not -path './node_modules/*'`
3. `find . -maxdepth 4 -name 'pyproject.toml' -o -name 'requirements.txt' -o -name 'go.mod'`
4. Read `.editorconfig`, `Directory.Build.props`, `Directory.Packages.props` if present.
5. Read `.github/workflows/*.yml`, `.gitlab-ci.yml`, `azure-pipelines.yml` if present.
6. Read `_docker/docker-compose.yml` if present (Pandahrms convention).

For each discovered project file, infer:

| Field | How |
|-------|-----|
| Language | `*.csproj` -> .NET; `package.json` -> JS/TS; `pyproject.toml` -> Python; `go.mod` -> Go |
| Test runner | Grep `*.csproj` for `xunit`/`nunit`/`mstest`; grep `package.json` for `vitest`/`jest`/`playwright` |
| TS or JS | `package.json` has `typescript` dependency -> TS |
| Framework | Grep `*.csproj` `<TargetFramework>`; grep `package.json` for `react`/`svelte`/`vue`/`solid` |

Emit one-line stack summary per project.

### Phase 2 -- Inventory existing tools

For each project, grep for every tool in the [Tool Catalogue](#tool-catalogue). Build a table:

| Tool | Project | Present? | Version | Action |
|------|---------|----------|---------|--------|
| Reqnroll | `Pandahrms.Foo.Tests.csproj` | yes | 2.4.0 | skip |
| Semgrep CLI | (binary) | no | -- | candidate |
| gitleaks | (binary) | no | -- | candidate |
| ESLint `no-warning-comments` rule | `package.json` | yes (eslint installed) | -- | check rule config |

For binaries (Semgrep, gitleaks): check `command -v <tool>` and `ls .claude/hooks/`.

For PreToolUse hooks: read `.claude/settings.json` (project) -- check `hooks.PreToolUse` entries.

### Phase 3 -- Recommend by gap

For each missing tool, decide `recommend` or `skip` using the rules below. First match wins.

| Rule | Decision |
|------|----------|
| Language not used in any project | skip |
| Near-equivalent already installed (e.g. SonarAnalyzer.CSharp covers most Semgrep C# rules) | skip with note |
| SpecFlow detected in any project | recommend **Reqnroll migration** (not parallel install); flag SpecFlow as deprecated |
| Reqnroll already in some test projects but not all | recommend adding to missing projects |
| gitleaks missing AND repo has > 50 commits | recommend |
| Git allowlist hook missing from `.claude/settings.json` | recommend |
| Tool is Semgrep AND project is published/shipped to customers | recommend with Semgrep Rules License warning |
| All checks pass | recommend |

Group recommendations by category:

- **Spec executor** (Reqnroll, Cucumber.js)
- **SAST** (Semgrep CLI, Roslyn analyzers, SonarAnalyzer.CSharp, Security Code Scan)
- **Secret scan** (gitleaks)
- **Lint rules** (ESLint `no-warning-comments`, ESLint `no-console`)
- **PreToolUse hooks** (git allowlist, TODO/FIXME grep gate)

Output: one ranked block per project. Each line shows tool name, install command, license, one-line rationale.

### Phase 4 -- Confirm per project

For each project with at least one recommendation, call `AskUserQuestion` once with `multiSelect: true`. The question text names the project; options list each recommended tool.

```
question: "Which tools should I install into <project-name>?"
header: "Install picks"
multiSelect: true
options:
  - { label: "Reqnroll (BDD runner)", description: "dotnet add package Reqnroll -- BSD-3-Clause -- replaces deprecated SpecFlow" }
  - { label: "Semgrep CLI (SAST)", description: "brew install semgrep -- engine LGPL-2.1 -- rule license restricts SaaS resale" }
  - { label: "gitleaks (secret scan)", description: "brew install gitleaks -- MIT" }
  - { label: "PreToolUse git allowlist hook", description: "Writes .claude/settings.json + .claude/hooks/git-allowlist.sh -- blocks commit/push/reset during atlas execute window" }
```

User picks subset (or `Other` -> free-text adjustment). Skip Phase 5 if user picks nothing for a project.

### Phase 5 -- Install picked tools

Install in this order per project: SAST/analyzer NuGets first, then test runners, then binaries, then hooks. Stop on first failure within a project; continue to next project.

For each picked tool, run the install command verbatim from the [Tool Catalogue](#tool-catalogue). Capture stdout+stderr. On non-zero exit, announce: `"Install failed for <tool> in <project>: <error>. Skipping remaining tools in this project."`

After all installs complete (success or partial), write log to `docs/pandahrms/tool-harness-log-<YYYY-MM-DD>.md`:

```markdown
# Tool Harness Bootstrap log -- YYYY-MM-DD

## Project: <name>
- Stack: .NET 8, xUnit
- Installed: Reqnroll 2.4.0, gitleaks 8.18.4
- Skipped: Semgrep (user declined)
- Hook config written: .claude/settings.json (PreToolUse git allowlist)
- Failures: none

## Project: <name 2>
...
```

Other Pandahrms skills (audit steps, review steps) may read this log to decide which tools to invoke.

## Tool Catalogue

Verified licenses + install commands. Update this table when adding a new tool.

| Tool | Category | License | Install command | Notes |
|------|----------|---------|-----------------|-------|
| Reqnroll | Spec executor (.NET) | BSD-3-Clause | `dotnet add <csproj> package Reqnroll && dotnet add <csproj> package Reqnroll.xUnit` (or `.NUnit`/`.MsTest`) | Active SpecFlow replacement |
| Cucumber.js | Spec executor (JS/TS) | MIT | `pnpm add -D @cucumber/cucumber` | |
| Microsoft.CodeAnalysis.NetAnalyzers | SAST (.NET) | MIT | `dotnet add <csproj> package Microsoft.CodeAnalysis.NetAnalyzers` | Often already pulled by SDK |
| SonarAnalyzer.CSharp | SAST (.NET) | LGPL-3.0 | `dotnet add <csproj> package SonarAnalyzer.CSharp` | Roslyn rules only; no server needed |
| Semgrep CLI | SAST (multi-language) | LGPL-2.1 engine | `brew install semgrep` (mac) / `pip install semgrep` | Community rule pack has Semgrep Rules License -- restricts SaaS resale |
| Security Code Scan | SAST (.NET) | LGPL-3.0 | `dotnet add <csproj> package SecurityCodeScan.VS2019` | Slower release cadence; prefer Roslyn + Semgrep combo |
| gitleaks | Secret scan | MIT | `brew install gitleaks` (mac) / download binary from GitHub releases | Run as pre-commit hook or CI step |
| ESLint | Lint (JS/TS) | MIT | `pnpm add -D eslint` | Add `"no-warning-comments": "error"` to rules to fail on TODO/FIXME |
| Playwright | E2E | Apache-2.0 | `pnpm add -D @playwright/test && pnpm exec playwright install` | MCP variant covered elsewhere |
| pytest | Test runner (Python) | MIT | `pip install pytest` | |
| mypy | Type check (Python) | MIT | `pip install mypy` | |

## PreToolUse Hook Templates

Project-scoped. Write to `.claude/settings.json` (create if missing) and `.claude/hooks/<name>.sh` (chmod +x after write).

### Git allowlist hook

`.claude/hooks/git-allowlist.sh`:

```bash
#!/usr/bin/env bash
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Always-allowed verbs (read-only inspections + stage-only writes)
if echo "$COMMAND" | grep -qE '^\s*git (add|diff|status|log|show|ls-files|rev-parse|blame)( |$)'; then
  exit 0
fi

# Block destructive verbs unless plan file marks Step 11 active
if echo "$COMMAND" | grep -qE '^\s*git (commit|push|checkout|restore|reset|stash|rebase|merge|branch|tag|clean|rm|mv|cherry-pick|revert)( |$)'; then
  PLAN=$(find docs -maxdepth 5 -name '*.md' -path '*/plans/*' 2>/dev/null | head -1)
  if [ -n "$PLAN" ] && grep -qE '^\| 11\. Commit \| (in-progress|done)' "$PLAN" 2>/dev/null; then
    exit 0
  fi
  echo "Blocked: git verb outside Step 11 commit window. Use hermes-commit to commit." >&2
  exit 2
fi

exit 0
```

`.claude/settings.json` entry (merge into existing `hooks` block; do not overwrite siblings):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": ".claude/hooks/git-allowlist.sh" }
        ]
      }
    ]
  }
}
```

### TODO/FIXME grep gate

`.claude/hooks/todo-grep.sh`:

```bash
#!/usr/bin/env bash
INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
if [ "$TOOL" != "Write" ] && [ "$TOOL" != "Edit" ]; then exit 0; fi

CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // .tool_input.new_string // empty')
if echo "$CONTENT" | grep -qE '(TODO|FIXME|XXX)([: (]|$)'; then
  echo "Blocked: write/edit contains TODO/FIXME/XXX. Surface deferred work to user first." >&2
  exit 2
fi
exit 0
```

Same `.claude/settings.json` merge pattern, matcher `Write|Edit`.

## Idempotency

Re-running the skill must not double-install or duplicate hook entries.

- Phase 2 detects already-installed tools and excludes from Phase 3 recommendations.
- Hook installer: before writing `.claude/settings.json`, read existing file. If a hook with identical `command` already exists, skip. Never append a duplicate entry.
- Hook script: before writing `.claude/hooks/<name>.sh`, check if file exists with identical contents (`shasum` compare). Skip write if identical.

## Settings Merge Rules

When writing to `.claude/settings.json`:

1. Read existing file via Read. If missing, start from `{}`.
2. Parse as JSON. If parse fails, STOP and report: `".claude/settings.json is not valid JSON. Fix manually before running this skill."` Do not auto-repair.
3. Add `hooks.PreToolUse` array if missing.
4. Append new matcher entry only if no existing entry has the same `command`.
5. Write back via Write tool. Preserve key order where possible.

## Hard Rules

- Manual trigger only. No auto-invocation from other skills.
- Read-only Phases 1-3. Phase 4 is dialogue. Phase 5 is the only writing phase.
- Per-tool approval. No `--yes` flag, no bulk install.
- Never install globally (`npm i -g`, `pip install --user`, `sudo brew`).
- Never edit production config (`appsettings.json`, `web.config`, `vite.config.ts`) beyond appending a single line for a new lint rule, AND only when user explicitly picked that tool.
- Never commit, stage, or push.
- Never modify `.csproj` for any reason other than `dotnet add package`.
- On Semgrep pick: announce the rules-license restriction once before install: `"Semgrep engine is LGPL-2.1 (free for commercial use). Semgrep's community rule pack has a separate license that forbids SaaS resale of scan results. Safe for internal CI use."`
- On SpecFlow detected: announce `"SpecFlow reached end-of-life on 31 Dec 2024. Recommending Reqnroll migration. This skill does NOT auto-migrate -- migration is a separate manual task."` Recommend Reqnroll for NEW test projects only; do not touch existing SpecFlow projects.

## Red Flags

| Thought | Reality |
|---------|---------|
| "I'll install all recommended tools without asking, the user already invoked the skill" | No. Per-tool AskUserQuestion is mandatory. Phase 4 is the only consent point. |
| "I'll write `.claude/settings.json` from scratch -- simpler than merging" | No. Existing settings carry user customizations. Always read-merge-write. |
| "User picked Semgrep; I'll skip the rules-license warning since they're an experienced dev" | No. Warning fires once per Semgrep install, every time. License surprises hurt later. |
| "SpecFlow is already there; I'll add Reqnroll alongside so both work" | No. Parallel install causes step-definition conflicts. Recommend migration as a separate task and skip install. |
| "I'll install gitleaks globally via brew -- it's a binary anyway" | brew install is fine; the project-local hook references the global binary. Do NOT chmod /usr/local/bin or modify global config. |
| "Repo has no `docs/pandahrms/`, I'll create it for the log" | Fine. `mkdir -p docs/pandahrms/` before write. Not a violation of "no new state files" -- log is the documented output. |
| "Skip Phase 2 to save time -- just install everything from Phase 3" | No. Phase 2 prevents duplicate installs and detects deprecated tools (SpecFlow). |
| "User said `Other` with vague text -- I'll guess what they meant" | No. Re-ask via single-question AskUserQuestion with concrete options derived from the free text. |

## When to Use

- First time setting up a Pandahrms project for the new tool-based check stack.
- After cloning a Pandahrms repo on a fresh machine -- detects what's missing locally vs in the repo.
- After a major dependency bump that may have replaced an analyzer.
- When a developer asks "what tools should I install to make atlas faster".
