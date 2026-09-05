# Pandahrms execution rules (always on)

## Communication style (B1-English standard)
Applies to all user-facing chat prose this session -- chat replies, user-input questions and option labels, status updates, end-of-turn summaries, and every skill's chat output. Does NOT apply to file contents, code, code comments, commit messages, plan/spec markdown, or tool arguments (shell commands, paths).
- Simple, common words -- `use` not `utilise`, `start` not `commence`, `next` not `subsequent`, `help` not `assist`, `show` not `demonstrate`.
- Short sentences. One idea per sentence.
- No idioms, sarcasm, double negatives, culture-specific references.
- Keep technical terms (`migration`, `endpoint`, `DTO`, `token`, `tenant`) as-is -- do NOT simplify or replace them.
- Spell out abbreviations on first use unless the user introduced them (`FE` -> `frontend (FE)`).
- Explain any non-basic word in a few simple words, UNLESS it is a technical term.
- Active voice.

Apply to all coding work this session, inside or outside any pipeline.

## TDD markers (emit user-facing)
- Test-ref task: announce `RED -- <test> failing` -- MUST include one verbatim line of the test runner's failure output (copied, not paraphrased) -- then `GREEN -- <test> passing`. No production code before a failing test.
- No-test-pattern task: announce `VERIFICATION -- <category>: <command output>` instead. No RED/GREEN.

## No-Test-Pattern Categories (closed list of 5)
Verification slot, not a Test ref, ONLY for:
1. EF mapping -- property/relationship in `IEntityTypeConfiguration<T>`
2. EF migration -- an Add-Migration artifact
3. Read DTO + projection -- pure projection from an EF query, no business logic
4. API regen / generated types -- `pnpm openapi-ts`, swagger-typescript-api
5. Pure config change -- appsettings flag, tsconfig alias, env var, no behavior branch

Real logic is never exempt: a mapping/DTO/config carrying real behavior (e.g. a `HasConversion` lambda doing work) needs a real Test ref. List is closed -- adding a category is a discussion with the user, not a unilateral call.

## Gates
- **Auto Gate** -- mechanical idempotent local commands (`pnpm openapi-ts`, `dotnet ef database update` on local DB, local docker rebuild). Announce one line, run automatically, no pause.
- **Manual Gate** -- operator action needing judgment or out-of-band steps (prod deploy, migration on shared/prod env, DBA review, anything destructive or cross-team). Pause and wait for the user's confirmation phrase.
- Do NOT reclassify a gate at runtime -- no Auto to Manual "to be safe", no Manual to Auto "looks safe".
- **BE to deploy to regen to FE order**: finish BE, deploy BE locally so swagger is live, regen FE types, then FE work. Never hand-edit generated types to start FE early.

## Sensitivity list (sensitive-card tagging + security-review gating)
A change is sensitive when it touches any of:
- authentication / authorization / session
- multi-tenant data boundary -- tenant_id filters, row-level security, cross-tenant checks
- money / billing / payment
- database schema / migration / data-rewrite script
- PII handling / audit logging / data retention
- anything a design doc flagged as risky

Tag such cards sensitive; run /security-review on them.

## Spec vs code conflict
If a spec and the code or plan disagree, STOP and report the conflict. Never silently reconcile or pick one side.

## Surface concerns
Never silently absorb a problem or a mid-run user correction. Surface concerns to the user; record what was wrong AND the corrected behavior.

## Fast-lane threshold
A change is fast-lane (do it directly with TDD, no decompose, no per-card ceremony) only when ALL hold: 3 files or fewer, about 60 lines or fewer, no new public API, no new spec scenario, behavior obvious. Anything past this goes through the main flow.

## Skill invocation
Any `/skill-name` reference inside a skill body means: invoke the bundled `pandahrms:<skill-name>` skill with the active host's skill mechanism, passing any flags as arguments. In Codex, when nested skill invocation is not exposed as a tool, read the sibling `skills/<skill-name>/SKILL.md` and execute it inline. Never print the command as chat text instead of running the skill.

## Output discipline (every skill, every flow)
- Lead with the result. First line answers "what happened" or "what was found".
- Emit ONLY the artifacts the skill defines: its tables, result blocks, one-line announcements, markers (RED/GREEN/VERIFICATION/DECISION). No preamble, no filler, no restating the skill's own rules.
- Never re-summarise in prose what a table or result block already shows.
- Never narrate routine tool activity ("now I will run...", "let me check..."). Announce-at-start lines and gate announcements are the defined exceptions.
- B1-English still applies to the prose that remains -- short, direct, technical terms kept.

## Ambiguity
When a request is genuinely ambiguous or missing a required field (file, DB, branch, scope), ask the user before acting. Use the host's structured user-input UI when available; otherwise ask in chat and end the turn. Otherwise proceed -- no per-turn restatement ceremony.
