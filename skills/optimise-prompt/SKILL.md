---
name: optimise-prompt
description: ALWAYS run this as the very first step of the user-facing entry-point skills -- atlas-pipeline-orchestrator, debugging, and design-refinement -- before any other action. Pipeline-node skills (athena-code-review, plan-writing, execute-plan, spec-writing, spec-review, hermes-commit, aegis-security-review, branching, bridge-file, ef-migrations) do NOT auto-invoke this skill, because they are normally reached through an entry-point skill that already ran the pre-flight. Rephrases the user's request in clear B2-Level English, then either proceeds silently (when intent is unambiguous) or asks the user to confirm via AskUserQuestion (when the request is ambiguous, contradictory, or missing critical info). Also triggers on direct user invocation -- "/optimise-prompt", "rephrase this", "what do you think I'm asking", "clarify my prompt". Never writes code, never edits files, never invokes other skills. Returns a single normalized intent statement that the caller (skill or assistant) uses as the canonical request from that point forward.
---

# Optimise Prompt

## Overview

Pandahrms developers often write requests in non-native English: short, ungrammatical, sometimes missing nouns or verbs. Acting on a misread of that input wastes time and produces wrong work. This skill is a thin pre-flight check that runs before every entry-point skill: it rephrases the request in clear B2-Level English and confirms intent whenever the input is not both **explicit** and **declarative**.

**Core principle:** the user's intent must be settled in clean B2 English before any other skill begins. Skills downstream act on the *normalized* intent, not the raw input.

**Hard gate:** the skill proceeds silently (CLEAR path) only when the request is BOTH explicit (every key field named -- verb, object, qualifier) AND declarative (a full statement of intent, not a question, fragment, or hedged guess). If the user wrote a question, a single noun, a pronoun, or a hedged guess ("maybe", "i think", "should we"), the skill MUST ask via AskUserQuestion. Silence is reserved for unambiguous commands only.

## When to Use

Auto-invoked as the pre-flight step by the user-facing entry-point skills only:

- `pandahrms:atlas-pipeline-orchestrator`
- `pandahrms:debugging`
- `pandahrms:design-refinement`

Pipeline-node skills (athena-code-review, plan-writing, execute-plan, spec-writing, spec-review, hermes-commit, aegis-security-review, branching, bridge-file, ef-migrations) do NOT auto-invoke this skill. They are normally reached through an entry-point skill that already ran the pre-flight, and re-running it on every internal hop would slow the pipeline and frustrate the user.

Also triggers on direct user invocation, regardless of which skill is active:

- `/optimise-prompt` slash command
- "rephrase this", "what are you understanding", "is that what you got from my message"
- Any session where the user is unsure they communicated their intent clearly

**Re-runs on mid-skill follow-up directives.** A long-running entry-point skill (atlas pipeline, debugging investigation, design refinement) will receive follow-up user messages between steps. Some of those are continuation chatter (replies to questions, acks, small clarifications) and must NOT re-trigger this skill. Others are **new directives** that change the scope, redirect the work, or introduce fresh intent -- those MUST pass the same explicit + declarative gate before the parent skill acts on them. See [Follow-up Directives](#follow-up-directives) for the trigger rules.

## When NOT to Use

- The skill is already running in the current call stack (no recursion). Each invocation calls `optimise-prompt` exactly once per directive being normalized.
- The current message is a direct reply to an AskUserQuestion the assistant just sent. The reply belongs to the in-flight question, not to a fresh intent.
- The current message is a one-word ack ("yes", "ok", "no", "go", "continue", "stop"). Treat as control flow, not intent.
- The current message is a small clarification or addition that the parent skill's own dialogue is designed to absorb (e.g. "use 3 retries not 5" during plan-writing's task-design dialogue; "exclude the audit table" during EF migration scoping). These belong to the parent skill's in-flight Q&A loop, not to a fresh top-level directive.

## B2-Level English Rules

B2 is the CEFR upper-intermediate level. For Pandahrms work this means:

- Use everyday vocabulary. Replace rare or formal words with common ones (`use` not `utilise`, `start` not `commence`, `next` not `subsequent`).
- One idea per sentence. Split long sentences into two short ones.
- Avoid idioms, sarcasm, double negatives, or culture-specific references.
- Keep technical terms (`migration`, `endpoint`, `DTO`, `token`, `tenant`) -- those are vocabulary the developer already knows. Do not over-simplify these.
- Spell out abbreviations the first time when the user did not introduce them (`FE` -> `frontend (FE)`).
- Prefer active voice (`I will read the file` not `the file will be read`).

These rules also govern every assistant response back to the user, not just this skill's output. See the global rule in `~/.claude/CLAUDE.md`.

## Workflow

```
1. Read user's raw input
2. Classify clarity: CLEAR | AMBIGUOUS | UNDER-SPECIFIED
3. CLEAR        -> echo one-line restatement, return immediately
   AMBIGUOUS    -> AskUserQuestion with 2-4 candidate intents
   UNDER-SPEC   -> AskUserQuestion to fill the missing field
4. Lock the confirmed intent as the canonical request
5. Return control to the caller
```

### Phase 1: Read raw input

Take the most recent user message that triggered the parent skill. Do not include earlier conversation turns -- the rephrase is scoped to the current request only. Earlier turns are context, not intent.

### Phase 2: Classify clarity

**Hard gate before classification:** the request MUST be both **explicit** AND **declarative**. If either is missing, the request is NOT CLEAR and the skill MUST ask via AskUserQuestion -- proceed silently is forbidden in that case.

- **Explicit** means every key field of the intent is named in the message itself, not inferred from earlier turns, not inferred from open files, not inferred from "what was probably meant". Fields that must be named: the verb (what to do), the object (what to do it to), and any qualifier the parent skill needs (which branch, which DB, which file, which scope).
- **Declarative** means the message states an intent, not a question or a fragment. `fix the failing UserService test` is declarative. `auth thing?`, `that bug`, `recruitment`, `?`, `the migration` are NOT declarative -- they are fragments, questions, or single nouns without a verb. A request that opens with "should we...", "can you maybe...", "what about...", or that ends with "?" is treated as non-declarative by default, because the user is exploring, not commanding.

Then apply these checks in order. First match wins.

**CLEAR** -- proceed silently. The request is CLEAR when ALL of these hold:

- Passes the explicit + declarative hard gate above.
- Verb is unambiguous (`fix`, `add`, `rename`, `delete`, `review`, `commit`, `migrate`, `restore`, etc.).
- Object is unambiguous (a named file, function, feature, branch, PR, table, etc.) OR the verb is self-contained (`/hermes-commit`, `/review`).
- No contradictory clauses (e.g. "add but don't add", "fix without changing the code").
- No critical field missing for the parent skill (e.g. for `branching`, a branch purpose is provided; for `ef-migrations`, a migration name or action verb is provided).
- No hedging language that signals the user is unsure ("maybe", "i think", "probably", "could you possibly"). Hedged input is exploratory and must be confirmed before any action.

**AMBIGUOUS** -- ask. The request is AMBIGUOUS when ANY of these hold:

- The explicit + declarative hard gate fails (the message is a fragment, a question, a single noun, hedged, or relies on context the assistant must guess).
- A pronoun (`it`, `this`, `that`) has more than one possible referent in the recent context.
- A verb has more than one common meaning in the current project (`fix` could be patch-only or root-cause; `clean` could be `git clean` or refactor).
- Two reasonable interpretations of the request lead to different actions or different files.
- The request mixes two tasks the assistant should not bundle without confirmation (e.g. "review and commit").

**UNDER-SPECIFIED** -- ask. The request is UNDER-SPECIFIED when:

- The explicit + declarative hard gate fails because a required field is missing rather than because the wording is non-declarative.
- A required field for the parent skill is missing (branch name for `branching`, plan path for execute-plan Fast Path, DB name for `swap-perf-db`, etc.).
- The user named a target that does not exist in the working tree (file/function/branch not found).

### Phase 2 examples

| Raw input | Verdict | Why |
|-----------|---------|-----|
| `fix the failing UserServiceTests.GetUser_ReturnsActiveOnly test` | CLEAR | Verb + object + qualifier all named, declarative, no hedging. |
| `/hermes-commit` | CLEAR | Self-contained slash command, declarative. |
| `auth thing?` | AMBIGUOUS | Non-declarative (ends in `?`), single noun, no verb. |
| `recruitment` | AMBIGUOUS | Single noun, no verb, not declarative. |
| `maybe we should clean up the migration code` | AMBIGUOUS | Hedged ("maybe"), and `clean` has two meanings. |
| `fix it` | AMBIGUOUS | Pronoun `it` -- no explicit object. |
| `add a new endpoint` | UNDER-SPECIFIED | Verb + object class named, but which endpoint? No qualifier. |
| `create a branch` | UNDER-SPECIFIED | Branch purpose missing -- required field for `branching`. |
| `switch perf db` | UNDER-SPECIFIED | DB name missing -- required field for `swap-perf-db`. |

### Phase 3a: CLEAR path

Emit a single line in B2 English:

```
Got it -- you want to <verb> <object> [<qualifier>]. Starting now.
```

Examples:

- `Got it -- you want to fix the failing test in UserServiceTests.cs. Starting now.`
- `Got it -- you want to create a new branch off main for the performance overtime feature. Starting now.`
- `Got it -- you want me to review the working-tree changes before commit. Starting now.`

Do NOT call AskUserQuestion. Return control to the caller.

### Phase 3b: AMBIGUOUS / UNDER-SPECIFIED path

Call AskUserQuestion once. The question MUST follow this shape:

- **question**: the rephrased candidate intent in B2 English, ending in a question mark.
- **header**: max 12 chars summary (e.g. `Confirm intent`).
- **options**: 2-4 distinct candidate intents OR (for UNDER-SPECIFIED) the missing field choices. Each option label in B2 English.
- **multiSelect**: false.

Example for AMBIGUOUS:

```
question: "I want to make sure I read your request right. Which of these do you mean?"
header: "Confirm intent"
options:
  - { label: "Fix the root cause of the failing test", description: "Run the debugging skill: find why the test fails, then patch the source." }
  - { label: "Only patch the test so it passes", description: "Edit the test file so it passes without changing the production code." }
  - { label: "Skip the test for now", description: "Mark the test as skipped and add a TODO. No other changes." }
```

Example for UNDER-SPECIFIED:

```
question: "Which database do you want me to switch the Performance API to?"
header: "DB target"
options:
  - { label: "Local sandbox DB", description: "performance_sandbox" }
  - { label: "Restored prod copy", description: "performance_prod_2026_05_10" }
```

### Phase 4: Lock the confirmed intent

Once the user picks an option (or the CLEAR path applied), store the confirmed intent as a single B2-English sentence. The parent skill reads this sentence and treats it as the canonical request for the rest of its run.

If the user picks "Other" and writes free text, run Phase 2 once more on that free text. If still ambiguous after one extra round, stop and tell the user: "I am still not sure what you want. Please write the request again in a different way."

### Phase 5: Return

Hand control back to the parent skill. Do not summarize at the end -- the parent skill will pick up from its own Step 1.

## Follow-up Directives

The pre-flight runs once at skill start. Mid-skill, the user often sends more messages. Not all of them are new directives -- most are continuation chatter that belongs to the parent skill's own dialogue. The parent skill MUST re-invoke optimise-prompt only when the new message is a **fresh directive**, defined below.

### Classify every mid-skill user message

When the parent skill receives a user message after its pre-flight has completed, classify it BEFORE acting:

| Class | Definition | What the parent skill does |
|-------|------------|---------------------------|
| **Continuation reply** | Direct answer to an in-flight AskUserQuestion (`I picked option 2`, free-text reply to a question). | Absorb into the in-flight question. Do NOT re-invoke optimise-prompt. |
| **Control ack** | One-word or short control token (`yes`, `ok`, `no`, `go`, `continue`, `stop`, `pause`, `skip`). | Treat as control flow. Do NOT re-invoke optimise-prompt. |
| **In-flight clarification** | A small refinement of intent that the parent skill's current step is designed to absorb (e.g. mid plan-writing: "use 3 retries"; mid design-refinement: "the cap is 50 not 100"). The verb and top-level object do NOT change. | Absorb into the current step. Do NOT re-invoke optimise-prompt. |
| **Fresh directive** | A message that introduces a new verb, a new top-level object, a contradiction of the locked intent, an extra scope item ("also do X"), or a redirect ("forget that, do Y instead"). | RE-INVOKE optimise-prompt with this message before acting. The new directive must pass the same explicit + declarative gate as the original. |

### Fresh-directive triggers (any one is sufficient)

A mid-skill message is a **fresh directive** when ANY of these hold:

- It starts with a new verb that is not part of the current step's vocabulary (`also add...`, `now do...`, `instead, ...`, `wait, ...`, `forget that, ...`).
- It names a new top-level object (a different file, feature, branch, table, PR than the locked intent).
- It contradicts the locked intent (`actually I don't want X` after X was confirmed).
- It expands scope (`also do Y`, `and rename Z while you're at it`).
- It changes the parent skill mid-flight (`stop this and run debugging instead`, `cancel and commit what we have`).

### What the re-invoke does

When a fresh directive arrives, the parent skill:

1. Pauses its current step.
2. Re-invokes `pandahrms:optimise-prompt` with the fresh directive as the input.
3. Waits for CLEAR confirmation (or for the user to clarify via AskUserQuestion).
4. Once the new directive is locked, the parent skill decides whether to:
   - Replace the original intent and restart from its Step 1.
   - Add the new directive to the existing intent and continue.
   - Branch into a different skill entirely (rare; usually requires explicit user choice).

The parent skill announces in B2 English which path it took:

- `"Got the new directive. I am replacing the old plan and starting again from design."`
- `"Got the new directive. I am adding it to the current plan and continuing."`
- `"The new directive needs a different skill. Stopping atlas and starting debugging."`

### Anti-patterns

- **Do NOT re-invoke optimise-prompt on every user turn.** That breaks flow and ignores the parent skill's dialogue.
- **Do NOT silently absorb a fresh directive without re-running the gate.** A scope change like "also rename FooService" deserves the same explicit + declarative check the original request got.
- **Do NOT treat short messages as control acks when they introduce new intent.** `add tests` is short but it is a fresh verb + object -- it is a directive, not an ack.

## Hard Rules

- This skill NEVER edits files, runs git, runs tests, or calls any other skill. It is read-only and dialogue-only.
- This skill NEVER triggers itself recursively. If a parent skill detects it is already inside an optimise-prompt run, it skips Step 0.
- The skill MUST finish in one round of AskUserQuestion at most. Two-question chains are forbidden -- they slow the pipeline and frustrate the user.
- The skill MUST NOT change the user's intent. It clarifies; it does not redirect. If the user wants to do something the assistant thinks is wrong, that disagreement belongs in the parent skill, not here.

## Calling Pattern (for parent skills)

The user-facing entry-point skills listed in [When to Use](#when-to-use) start with a Pre-Flight block that reads:

```markdown
## Step 0: Optimise the prompt (mandatory first step)

Before any other action in this skill, invoke `pandahrms:optimise-prompt` via the
Skill tool with no arguments. It will either echo a one-line restatement (CLEAR)
or ask the user to confirm intent (AMBIGUOUS / UNDER-SPECIFIED). Wait for it to
return, then continue from Step 1 using the confirmed intent as the canonical
request.

Skip Step 0 only when:
- The current message is a direct reply to an AskUserQuestion the assistant
  just sent.
- The current message is a one-word ack ("yes", "ok", "no", "go", "continue").
- optimise-prompt is already running in the current call stack.
```
