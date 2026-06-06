# Pandahrms execution rules (always on)

Apply to all coding work this session, inside or outside any pipeline.

## TDD markers (emit user-facing)
- Test-ref task: announce `RED -- <test> failing with <reason>`, then `GREEN -- <test> passing`. No production code before a failing test.
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
