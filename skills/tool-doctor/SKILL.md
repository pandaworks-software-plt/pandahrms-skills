---
name: tool-doctor
description: '`/tool-doctor` -- audit the work machine AND the current project for the deterministic code-quality guard tools used by the review flow (ripgrep, gitleaks, ast-grep, linters/analyzers, coverage, jscpd). Scans read-only first, prints a readiness table (guard -> tool -> machine status -> project status -> built-in fallback -> recommendation), then OFFERS, with per-item confirmation, to install missing machine tools and add missing project config. Never installs or edits anything without explicit confirmation, and never runs `sudo` silently. NOT part of the card flow -- no other skill invokes it.'
---

# Tool Doctor

Audit the work machine + current project for the deterministic code-quality guard tools. Report readiness, then offer to install/configure what's missing.

**Announce at start:** "I'm using Pandahrms tool-doctor to audit machine + project tooling."

## Invocation

- `/tool-doctor` -- scan and report; offer fixes.

## Safety (full gate -- never bypass)

- Read-only scan FIRST. Report the table before proposing any change. Every probe stays read-only -- any `npx` probe uses `npx --no-install <bin> --version` so a probe never triggers a download.
- Every install and every config edit is confirmed by the user before it runs. Use AskUserQuestion to let the user pick which fixes to apply; apply only the picked ones.
- NEVER run a machine install without showing the exact command and getting an explicit yes. NEVER use `sudo` unless the user is shown the full command and approves it.
- Detect the package manager before suggesting an install. Never assume one.
- Project config edits go through the Edit tool, only on confirmation. NEVER auto-write repo files.
- After applying, list every change made (machine + project) in the closing summary.

## Phase 1 -- Context detect

Read-only. Determine:

- Platform: `uname -s` (Darwin / Linux). On Darwin prefer `brew`; on Linux detect `apt-get`/`dnf`.
- Package managers present: `command -v brew apt-get dnf npm pnpm yarn dotnet go`.
- Project type(s) in cwd: presence of `package.json` (JS/TS) and/or `*.csproj` / `*.sln` (.NET). A repo may be both.

## Phase 2 -- Machine scan

For each, record present/absent + version (`command -v <bin>` then `<bin> --version`):

- `git` (always expected), `rg` (ripgrep), `gitleaks`, `ast-grep` (or `sg`), `node`, `pnpm`, `dotnet`, `go`.
- `jscpd`: present if a local devDependency OR runnable via `npx --no-install jscpd --version` (the `--no-install` guard keeps the scan read-only -- never let a probe trigger a download).

## Phase 3 -- Project scan

Read-only. Check the cwd project for:

- Linter config: `biome.json`/`biome.jsonc`, or `eslint.config.*`/`.eslintrc.*`, or a `lint` script in `package.json`.
- `.editorconfig` with analyzer severities (`dotnet_diagnostic.*`).
- .NET analyzers: `<PackageReference>` to any of `AsyncFixer`, `Meziantou.Analyzer`, `SonarAnalyzer.CSharp`, `Microsoft.VisualStudio.Threading.Analyzers` in `*.csproj` / `Directory.Build.props`.
- Coverage: `@vitest/coverage-v8` (JS) or `coverlet.collector` (.NET test project).
- Duplication: `jscpd` devDependency or `.jscpd.json`.
- Repo-root `CLAUDE.md` mechanical conventions (file-size limit, banned imports, required headers).

## Phase 4 -- Map to guard catalog

For each guard, resolve: needed tool, machine status, project status, the deterministic built-in fallback (a tool that runs without the named tool -- `git grep`, regex, `wc`), and the recommendation. A guard with no deterministic built-in falls back to the caller's LLM judgement, not to a tool.

| Guard | Tool | Lives where | Deterministic built-in fallback |
|-------|------|-------------|---------------------------------|
| TODO/FIXME/XXX | `git grep` (built-in) / `rg` faster | built-in; `rg` machine-optional | `git grep` |
| Secrets / leaked credentials | `gitleaks` | machine | `git diff` + regex |
| Dead code / unused / leftover debug | eslint / biome / .NET analyzers | project config | none -- LLM judgement until configured |
| Async correctness | `AsyncFixer` / threading analyzers; eslint `no-floating-promises` | project config | none -- LLM judgement until configured |
| Exact code duplication | `jscpd` | project devDep / `npx` | none -- LLM judgement until configured |
| Changed-file test coverage | `@vitest/coverage-v8` / `coverlet` | project config | none -- LLM judgement until configured |
| Structural AST rules | `ast-grep` | machine | limited (`git grep`) |
| Repo conventions (file-size / banned import / header) | `wc -l`, `grep` (built-in) | built-in | n/a |

## Phase 5 -- Report

Print the readiness table: `Guard | Needed tool | Machine | Project | Fallback | Recommendation`. Mark each guard one of: `READY` (tool present / config in place), `FALLBACK` (a deterministic built-in covers it -- `git grep`, regex, `wc`; the named-tool upgrade is optional), `GAP` (no deterministic built-in; relies on the caller's LLM judgement until the tool/config is added). Use `FALLBACK` only for guards whose table row names a deterministic built-in fallback; the rows marked "none" are `GAP` when their tool/config is absent.

## Phase 6 -- Offer fixes (per-item confirm)

List the proposed fixes -- machine installs and project-config edits -- and use AskUserQuestion (multiSelect) to let the user pick which to apply. Apply only the picked ones; announce each as it runs.

### Machine installs (show the exact command; run only on yes)

- ripgrep: macOS `brew install ripgrep` / Debian/Ubuntu `apt-get install -y ripgrep`.
- gitleaks: macOS `brew install gitleaks` / Linux download the release binary, or `go install github.com/gitleaks/gitleaks/v8@latest` when `go` is present.
- ast-grep: macOS `brew install ast-grep` / any `npm install -g @ast-grep/cli`.

### Project config (Edit tool, only on yes)

- JS/TS linter (biome): `pnpm add -D -E @biomejs/biome` then `pnpm biome init`. Enable rules covering dead code + debug: `noUnusedVariables`, `noConsoleLog`, `noDebugger`.
- JS/TS lint rules (eslint): enable `no-unused-vars`, `no-unreachable`, `no-console`, `no-debugger`, `require-await`, and (type-aware) `@typescript-eslint/no-floating-promises`.
- .NET analyzers (add to `Directory.Build.props` so every project inherits):
  ```xml
  <ItemGroup>
    <PackageReference Include="AsyncFixer" Version="*" PrivateAssets="all" />
    <PackageReference Include="Meziantou.Analyzer" Version="*" PrivateAssets="all" />
    <PackageReference Include="Microsoft.VisualStudio.Threading.Analyzers" Version="*" PrivateAssets="all" />
  </ItemGroup>
  ```
  Set severities in `.editorconfig` (e.g. `dotnet_diagnostic.VSTHRD002.severity = warning`).
- Coverage: JS `pnpm add -D @vitest/coverage-v8`; .NET `dotnet add <TestProject> package coverlet.collector`.
- Duplication: `pnpm add -D jscpd` (or run `npx jscpd` ad hoc -- note plain `npx jscpd` may download; only the read-only scan probe uses `--no-install`).
- `.gitleaks.toml` (optional) to tune the secret scan for the repo.

## Phase 7 -- Summary

Emit a closing summary: which tools are now READY, which stay FALLBACK (deterministic built-in available, upgrade optional), which remain GAP (no deterministic fallback -- declined; relies on the caller's LLM judgement until configured), and every machine install + project edit applied this run.

## Red Flags -- STOP

| Thought | Reality |
|---------|---------|
| "I'll just install it, faster than asking" | Every install needs an explicit yes. Show the exact command first. |
| "I'll `sudo` the install to be safe" | Never `sudo` silently. Show the full command; only run on approval. |
| "I'll add the eslint rules / `.csproj` block directly" | Project edits go through Edit on confirmation only. No auto-write. |
| "`brew` will be there" | Detect the package manager first. Never assume one exists. |
| "This guard has no tool, so it's broken" | Check the table. A guard with a deterministic built-in fallback (`git grep`, regex, `wc`) is FALLBACK. A guard whose row says "none" is GAP -- it relies on the caller's LLM judgement until configured, not on a tool. |
| "All guards have a built-in fallback, so mark everything FALLBACK" | No. Only the rows that name a deterministic built-in are FALLBACK. The "none" rows are GAP when their tool/config is absent. |
