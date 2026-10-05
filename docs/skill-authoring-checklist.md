# Skill authoring checklist

Run through this before a plugin release or when adding or reshaping a skill. It applies Anthropic's updated skill best practices (as summarised in "Everything You Know About Skills IS OUTDATED", Simon Scrapes, 1 Oct 2026) to this plugin. The short form lives in `CLAUDE.md` under "Skill Layout and Self-Check Rules"; `scripts/skill-audit.sh` checks the mechanical items.

## Mechanical (scripted -- `bash scripts/skill-audit.sh`)

- [ ] Every `SKILL.md` body is 500 lines or fewer.
- [ ] Every skill file over 100 lines (`SKILL.md` or `references/*.md`) opens with a `## Contents` list that matches its H2 headings; container sections list their phases or H3s underneath.
- [ ] References are one level deep: every `references/*.md` is linked from `SKILL.md` directly and never links another reference.
- [ ] Frontmatter carries `name` and `description` and no `model:` key.

## Judgment (by hand)

- [ ] **Read in full.** Any instruction that loads another skill file (Codex inline fallback, a reference) says "in full" / "to end of file". A `head`-style preview skips rules past line 100.
- [ ] **Degrees of freedom match fragility.** Judgment steps state goal + criteria. Shaped output uses a template with named slots. Fragile or irreversible steps (hashes, result files, ticket mutation order, git commands) are an exact command or a bundled script with no parameter the model may vary. One skill mixes all three.
- [ ] **Scripts run, prose reads.** Anything that must be identical on every run and every model is a script under `skills/<skill>/scripts/`, not a paragraph.
- [ ] **Ordered steps are a checklist.** When order matters, the skill prints the checklist and ticks it in its output; a failed check returns to the named step, never forward. When order does not matter, no checklist.
- [ ] **Artifacts self-check.** A skill that writes a spec, card, contract, ticket field or result file checks it against its own rules, fixes, re-checks until clean, then presents. Prefer `grep`/`wc` over prose checks.
- [ ] **Skill improves itself.** A run that fails for a reason no rule covers may end with ONE line proposing the rule; the user approves; it lands by PR.
- [ ] **Dependencies are explicit.** Every script or CLI call names its runtime and install line right next to it (`python3`, `gh`, `dotnet-ef`, ...). Detect -> install on confirmation or fall back. Never assume a tool is installed.
- [ ] **Tested per model.** Run the changed skill on the same task with every model the team uses. Haiku: enough guidance? Sonnet: clear and efficient? Opus / Fable: avoids over-explaining? A step a smaller model skips becomes clearer or a script; an instruction a larger model does worse with is removed. Record the models tested in the release commit message.
- [ ] **No new rationale, upstream-flow or negative-trigger prose** in a `SKILL.md` body (existing CLAUDE.md rule).
