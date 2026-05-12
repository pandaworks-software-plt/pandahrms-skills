---
name: optimise-prompt
description: ALWAYS run this as the very first step of every user-facing turn -- BEFORE any other tool call. Acts as a repeat-back step so the user can confirm Claude read their message correctly. Rephrases the user's request in clear B2-Level English and ALWAYS emits the restatement as a visible chat message, then pauses inline for the user to confirm before any downstream skill or agent acts. When intent is unambiguous, emits the one-line restatement plus an inline confirm prompt and waits; when the request is ambiguous, contradictory, or missing critical info, asks the user to pick from candidate intents via AskUserQuestion. Triggers on read-only questions, diagnostic questions, working-tree actions (write/edit/refactor/fix/add/remove/rename/drop/run/build/commit/migrate/deploy), one-line tweaks, single-file edits, single-className removals, config touches, and short follow-up directives -- nothing exempts the request. Mechanical skips only: short acks that carry no new verb or object (e.g. "yes", "ok", "got it", "sounds good", "go ahead", "continue", "stop", "skip", "cancel", "nevermind"), direct replies to an in-flight AskUserQuestion, and recursive self-calls when the skill is already running. Also triggers on direct user invocation -- "/optimise-prompt", "rephrase this", "what do you think I'm asking", "clarify my prompt". Returns a single normalized intent statement that the caller uses as the canonical request from that point forward.
---

# Optimise Prompt

## Overview

Rephrase user's request in clear B2-Level English. ALWAYS emit the restatement to the user as a visible chat message AND pause for confirmation before returning control. Confirm intent whenever input is not both **explicit** and **declarative**.

**Hard rule -- always echo:** every run of this skill MUST emit a one-line restatement printed in chat. Silent return is forbidden. The restatement is the artefact the user reads to confirm Claude understood them.

**Hard rule -- always pause:** every run of this skill MUST end with an inline confirm prompt and wait for the user to reply before returning control to the caller. No path is allowed to skip the pause. Downstream skills and agents only proceed after the user replies with a yes-style confirmation.

**Hard gate -- restate vs ask:** take the CLEAR path (echo restatement + inline confirm prompt) only when request is BOTH explicit (every key field named -- verb, object, qualifier) AND declarative (full statement of intent, not a question, fragment, or hedged guess). If user wrote a question, single noun, pronoun, or hedged guess ("maybe", "i think", "should we"), ask via AskUserQuestion with candidate intents -- the AskUserQuestion `question` text itself carries the rephrased intent and serves as the restatement.

## B2-Level English Rules

B2 is CEFR upper-intermediate level. For Pandahrms work this means:

- Use everyday vocabulary. Replace rare or formal words with common ones (`use` not `utilise`, `start` not `commence`, `next` not `subsequent`).
- One idea per sentence. Split long sentences into two short ones.
- Avoid idioms, sarcasm, double negatives, or culture-specific references.
- Keep technical terms (`migration`, `endpoint`, `DTO`, `token`, `tenant`) -- vocabulary the developer already knows. Do not over-simplify.
- Spell out abbreviations on first use when user did not introduce them (`FE` -> `frontend (FE)`).
- Prefer active voice (`I will read the file` not `the file will be read`).

### Scope: entire turn, not only this skill

These rules govern EVERY user-facing string produced for rest of current turn, including:

- This skill's own restatement, AskUserQuestion question text, and option labels / descriptions.
- Any subsequent skill's chat output, AskUserQuestion prompts, status updates, and end-of-turn summary (atlas, debugging, design-refinement, plan-writing, execute-plan, athena, aegis, hermes-commit, branching, ef-migrations, bridge-file, spec-writing, spec-review, and any other skill the assistant routes to after pre-flight).
- Standalone assistant chat output when no entry-point skill runs (trivial-edit path, read-only answers).

Rules do NOT apply to:

- File contents, code, code comments, commit messages, plan markdown, spec markdown, or any artefact whose audience is not user reading the chat.
- Internal tool arguments (Bash commands, file paths, etc.).

Treat scope rule as hard floor for rest of turn. Subsequent skills do not need to repeat B2 rule in their own SKILL.md -- locked here at pre-flight step and inherited by every later message assistant sends.

## Workflow

```
1. Read user's raw input
2. Classify clarity: CLEAR | AMBIGUOUS | UNDER-SPECIFIED
3. CLEAR        -> print one-line restatement + inline confirm prompt, wait for reply
   AMBIGUOUS    -> AskUserQuestion with 2-4 candidate intents (question text = restatement)
   UNDER-SPEC   -> AskUserQuestion to fill missing field (question text = restatement)
4. Lock the confirmed intent as the canonical request
5. Return control to the caller -- user has confirmed the intent
```

Every path produces a user-visible restatement AND a user confirmation. The CLEAR path prints the restatement plus an inline confirm prompt as plain chat text and waits for the user's reply. The AMBIGUOUS / UNDER-SPECIFIED paths embed the restatement in the AskUserQuestion `question` field and the user's option pick acts as the confirmation.

**Phase 1: Read raw input**

Take most recent user message that triggered parent skill. Do not include earlier conversation turns -- rephrase is scoped to current request only. Earlier turns are context, not intent.

**Phase 2: Classify clarity**

**Hard gate before classification:** request MUST be both **explicit** AND **declarative**. If either is missing, request is NOT CLEAR and skill MUST ask via AskUserQuestion. Either way, a visible restatement is emitted -- as plain chat (CLEAR) or as the AskUserQuestion `question` text (AMBIGUOUS / UNDER-SPECIFIED).

- **Explicit** means every key field of intent is named in the message itself, not inferred from earlier turns, open files, or "what was probably meant". Fields that must be named: verb (what to do), object (what to do it to), and any qualifier parent skill needs (which branch, which DB, which file, which scope).
- **Declarative** means message states an intent, not a question or fragment. `fix the failing UserService test` is declarative. `auth thing?`, `that bug`, `recruitment`, `?`, `the migration` are NOT declarative -- fragments, questions, or single nouns without a verb. A request opening with "should we...", "can you maybe...", "what about...", or ending with "?" is treated as non-declarative by default.

Then apply these checks in order. First match wins.

**CLEAR** -- print one-line restatement and return. Request is CLEAR when ALL hold:

- Passes explicit + declarative hard gate above.
- Verb is unambiguous (`fix`, `add`, `rename`, `delete`, `review`, `commit`, `migrate`, `restore`, etc.).
- Object is unambiguous (named file, function, feature, branch, PR, table, etc.) OR verb is self-contained (`/hermes-commit`, `/review`).
- No contradictory clauses (e.g. "add but don't add", "fix without changing the code").
- No critical field missing for parent skill (e.g. for `branching`, branch purpose provided; for `ef-migrations`, migration name or action verb provided).
- No hedging language signaling user is unsure ("maybe", "i think", "probably", "could you possibly"). Hedged input is exploratory and must be confirmed before any action.

**AMBIGUOUS** -- ask. Request is AMBIGUOUS when ANY hold:

- Explicit + declarative hard gate fails (message is a fragment, question, single noun, hedged, or relies on context assistant must guess).
- A pronoun (`it`, `this`, `that`) has more than one possible referent in recent context.
- A verb has more than one common meaning in current project (`fix` could be patch-only or root-cause; `clean` could be `git clean` or refactor).
- Two reasonable interpretations of request lead to different actions or different files.
- Request mixes two tasks assistant should not bundle without confirmation (e.g. "review and commit").

**UNDER-SPECIFIED** -- ask. Request is UNDER-SPECIFIED when:

- Explicit + declarative hard gate fails because a required field is missing rather than wording being non-declarative.
- A required field for parent skill is missing (branch name for `branching`, plan path for execute-plan Fast Path, DB name for `swap-perf-db`, etc.).
- User named a target not existing in working tree (file/function/branch not found).

**Phase 2 examples**

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

**Phase 3a: CLEAR path**

Print one B2-English chat message containing the restatement AND an inline confirm prompt, then stop and wait for the user's reply. This MUST be a visible assistant message -- not an internal log, not a thinking block, not a tool argument. Without this message, the skill has failed its core job.

Template (two short lines in one message):

```
Got it -- you want to <verb> <object> [<qualifier>].
Reply "yes" to proceed, or rephrase the request if I got it wrong.
```

Rephrase rules for the restatement line:

- Use B2 vocabulary -- swap rare or formal words for common ones.
- Make the verb and object explicit so the user can spot a misread in one glance.
- Include every qualifier from the raw input (file, branch, scope, target DB, etc.) so the user sees Claude caught all the details.
- Keep it to one line. If two ideas appear, pick the primary verb+object; secondary scope goes in the qualifier slot.

Examples:

- `Got it -- you want to fix the failing test in UserServiceTests.cs.`
- `Got it -- you want to create a new branch off main for the performance overtime feature.`
- `Got it -- you want me to review the working-tree changes before commit.`

After printing the message, return control to the caller WITHOUT calling any other tool. The caller waits for the user's reply. Treat the next user turn as the confirmation:

- A yes-style reply (`yes`, `ok`, `go ahead`, `continue`, `sounds good`, `correct`, `right`) -- lock the restated intent as the canonical request; the caller resumes.
- A no-style reply or a rephrased request -- run Phase 2 on the new message. If still not confirmed after one extra round, stop and tell user: "I am still not sure I have it right. Please write the request again in a different way."

**Phase 3b: AMBIGUOUS / UNDER-SPECIFIED path**

Call AskUserQuestion once. The `question` field itself is the restatement -- it must rephrase the user's raw input in B2 English so the user can see Claude read the message and is now asking only because a detail is missing. Question MUST follow this shape:

- **question**: rephrased candidate intent in B2 English, ending in a question mark. Make the rephrase visible -- echo the verb, object, and any named qualifiers from the raw input before posing the choice.
- **header**: max 12 chars summary (e.g. `Confirm intent`).
- **options**: 2-4 distinct candidate intents OR (for UNDER-SPECIFIED) missing field choices. Each option label in B2 English.
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

**Phase 4: Lock the confirmed intent**

Once user picks an option (or CLEAR path applied), store confirmed intent as a single B2-English sentence. Parent skill reads this sentence and treats it as canonical request for rest of its run.

If user picks "Other" and writes free text, run Phase 2 once more on that free text. If still ambiguous after one extra round, stop and tell user: "I am still not sure what you want. Please write the request again in a different way."

**Phase 5: Return**

Hand control back to caller only after the user has confirmed (CLEAR-path yes reply, or AskUserQuestion option pick on the AMBIGUOUS / UNDER-SPECIFIED paths). Do not summarize at the end -- caller picks up from locked intent as canonical request.

## Follow-up Directives

Classify every mid-skill user message into one of four classes:

| Class | Definition | Action |
|-------|------------|--------|
| **Continuation reply** | Direct answer to an in-flight AskUserQuestion (`I picked option 2`, free-text reply to a question). | Absorb into in-flight question. |
| **Control ack** | Short ack, no new verb/object (`yes`, `ok`, `got it`, `sounds good`, `go ahead`, `continue`, `stop`, `skip`, `cancel`, `nevermind`). | Treat as control flow. |
| **In-flight clarification** | Small refinement of intent that current step is designed to absorb (e.g. "use 3 retries", "the cap is 50 not 100"). Verb and top-level object do NOT change. | Absorb into current step. |
| **Fresh directive** | Message that introduces a new verb, new top-level object, contradiction of locked intent, extra scope item ("also do X"), or redirect ("forget that, do Y instead"). | Re-invoke optimise-prompt with this message before acting. |

### Fresh-directive triggers (any one is sufficient)

A mid-skill message is a **fresh directive** when ANY hold:

- Starts with a new verb not part of current step's vocabulary (`also add...`, `now do...`, `instead, ...`, `wait, ...`, `forget that, ...`).
- Names a new top-level object (different file, feature, branch, table, PR than locked intent).
- Contradicts locked intent (`actually I don't want X` after X was confirmed).
- Expands scope (`also do Y`, `and rename Z while you're at it`).
- Changes parent skill mid-flight (`stop this and run debugging instead`, `cancel and commit what we have`).

## Hard Rules

- Skill NEVER edits files, runs git, runs tests, or calls any other skill. Read-only and dialogue-only.
- Skill MUST finish in one round of AskUserQuestion at most (AMBIGUOUS / UNDER-SPECIFIED paths only).
- Skill MUST NOT change user's intent. Clarifies; does not redirect.
- Skill MUST always emit a visible restatement -- plain chat on CLEAR path, AskUserQuestion `question` text on AMBIGUOUS / UNDER-SPECIFIED. Silent return is forbidden.
- Skill MUST always pause for user confirmation before returning control -- inline reply on CLEAR path, option pick on AMBIGUOUS / UNDER-SPECIFIED. Returning without a user confirmation is forbidden.
