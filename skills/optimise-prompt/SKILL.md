---
name: optimise-prompt
description: ALWAYS run this as the very first step of every user-facing turn -- BEFORE any other tool call. Acts as a repeat-back step so the user can confirm Claude read their message correctly. Rephrases the user's request in clear B2-Level English and emits the restatement as a visible chat message. When intent is unambiguous (CLEAR), prints a one-line restatement and proceeds in the same turn without pausing -- the user interrupts if Claude misread. When the request is ambiguous, contradictory, or missing critical info, calls AskUserQuestion with candidate intents and waits for the user to pick. Triggers on read-only questions, diagnostic questions, working-tree actions (write/edit/refactor/fix/add/remove/rename/drop/run/build/commit/migrate/deploy), one-line tweaks, single-file edits, single-className removals, config touches, and short follow-up directives. Mechanical skips only: short acks that carry no new verb or object (e.g. "yes", "ok", "got it", "sounds good", "go ahead", "continue", "stop", "skip", "cancel", "nevermind"), direct replies to an in-flight AskUserQuestion, recursive self-calls when the skill is already running, and any message whose first non-whitespace character is "/" (slash-command skill trigger -- the slash command itself is the explicit intent). Also triggers on direct user invocation -- "rephrase this", "what do you think I'm asking", "clarify my prompt". Returns a single normalized intent statement that the caller uses as the canonical request from that point forward.
---

# Optimise Prompt

Rephrase user's request in B2-Level English. Always emit a visible restatement. Pause only on AMBIGUOUS or UNDER-SPECIFIED.

## B2-English Rules

- Everyday vocabulary -- `use` not `utilise`, `start` not `commence`, `next` not `subsequent`.
- One idea per sentence.
- No idioms, sarcasm, double negatives, culture-specific references.
- Keep technical terms (`migration`, `endpoint`, `DTO`, `token`, `tenant`).
- Spell out abbreviations on first use unless user introduced them (`FE` -> `frontend (FE)`).
- Active voice.

### Scope

Rules govern every user-facing string for rest of turn: this skill's restatement, AskUserQuestion text and options, every later skill's chat output, status updates, end-of-turn summary, standalone assistant replies.

Rules do NOT apply to file contents, code, code comments, commit messages, plan/spec markdown, or internal tool arguments (Bash commands, paths).

Locked at pre-flight. Later skills inherit; they do not repeat the rule in their own SKILL.md.

## Workflow

```
1. Read raw input (most recent user message only).
2. Classify: CLEAR | AMBIGUOUS | UNDER-SPECIFIED.
3. CLEAR        -> print one-line restatement, return control immediately (no pause).
   AMBIGUOUS    -> AskUserQuestion with 2-4 candidate intents. Wait for pick.
   UNDER-SPEC   -> AskUserQuestion with missing-field choices. Wait for pick.
4. Lock confirmed intent as the canonical request.
5. Return control.
```

CLEAR path is non-blocking. Restatement is informational; caller proceeds in the same turn. User interrupts if Claude misread.

AMBIGUOUS / UNDER-SPECIFIED paths block on AskUserQuestion. Option pick acts as confirmation.

### Phase 1: Read raw input

Most recent user message only. Earlier turns are context, not intent.

### Phase 2: Classify clarity

Hard gate: request MUST be both **explicit** AND **declarative**. If either fails, request is NOT CLEAR.

- **Explicit**: every key field named in the message -- verb, object, and any qualifier the parent skill needs (branch, DB, file, scope).
- **Declarative**: states an intent. `fix the failing UserService test` is declarative. Fragments, single nouns, questions, hedged guesses are not. Openings `should we...`, `can you maybe...`, `what about...`, or trailing `?` count as non-declarative.

Apply checks in order. First match wins.

**CLEAR** when ALL hold:

- Passes explicit + declarative gate.
- Verb unambiguous (`fix`, `add`, `rename`, `delete`, `review`, `commit`, `migrate`, `restore`).
- Object unambiguous (named file, function, feature, branch, PR, table).
- No contradictory clauses (`add but don't add`, `fix without changing the code`).
- No critical field missing for parent skill.
- No hedging (`maybe`, `i think`, `probably`, `could you possibly`).

**AMBIGUOUS** when ANY hold:

- Gate fails (fragment, question, single noun, hedged, relies on guess).
- Pronoun (`it`, `this`, `that`) has multiple referents in recent context.
- Verb has multiple common meanings (`fix` = patch-only or root-cause; `clean` = `git clean` or refactor).
- Two interpretations lead to different actions or different files.
- Mixes two tasks (`review and commit`).

**UNDER-SPECIFIED** when:

- Gate fails on a missing required field.
- Parent skill requires a field not provided (branch name, plan path, DB name).
- Named target not found in working tree.

**Examples**

| Raw input | Verdict | Reason |
|-----------|---------|--------|
| `fix the failing UserServiceTests.GetUser_ReturnsActiveOnly test` | CLEAR | Verb + object + qualifier, declarative. |
| `/hermes-commit` | CLEAR | Self-contained slash command. |
| `auth thing?` | AMBIGUOUS | Trailing `?`, single noun. |
| `recruitment` | AMBIGUOUS | Single noun, no verb. |
| `maybe we should clean up the migration code` | AMBIGUOUS | Hedged + `clean` has two meanings. |
| `fix it` | AMBIGUOUS | Pronoun with no clear referent. |
| `add a new endpoint` | UNDER-SPECIFIED | Which endpoint? |
| `create a branch` | UNDER-SPECIFIED | Branch purpose missing. |
| `switch perf db` | UNDER-SPECIFIED | DB name missing. |

### Phase 3a: CLEAR path (non-blocking)

Print one B2-English chat message as a visible assistant message (not a thinking block, not a tool argument):

```
You want to <verb> <object> [<qualifier>].
```

Return control to the caller in the same turn. No confirm prompt, no pause. Caller proceeds with the task. If Claude misread, the user interrupts in the next turn and the new message re-enters Phase 2.

Rephrase rules for the restatement line:

- B2 vocabulary.
- Verb and object explicit so the user spots a misread in one glance.
- Include every qualifier from raw input (file, branch, scope, target DB).
- One line. Two ideas: pick primary verb+object; secondary scope goes in the qualifier slot.

Examples:

- `You want to fix the failing test in UserServiceTests.cs.`
- `You want to create a new branch off main for the performance overtime feature.`
- `You want me to review the working-tree changes before commit.`

### Phase 3b: AMBIGUOUS / UNDER-SPECIFIED path (blocking)

Call AskUserQuestion once. The `question` text IS the restatement -- rephrase the raw input in B2 English so the user sees Claude read the message and is asking because a detail is missing.

Shape:

- **question**: rephrased candidate intent in B2 English, ending in `?`. Echo verb, object, named qualifiers before posing the choice.
- **header**: max 12 chars (e.g. `Confirm intent`).
- **options**: 2-4 distinct candidate intents (AMBIGUOUS) or missing-field choices (UNDER-SPECIFIED). Labels in B2 English.
- **multiSelect**: false.

AMBIGUOUS example:

```
question: "I want to make sure I read your request right. Which of these do you mean?"
header: "Confirm intent"
options:
  - { label: "Fix the root cause of the failing test", description: "Run the debugging skill: find why the test fails, then patch the source." }
  - { label: "Only patch the test so it passes", description: "Edit the test file so it passes without changing the production code." }
  - { label: "Skip the test for now", description: "Mark the test as skipped and add a TODO. No other changes." }
```

UNDER-SPECIFIED example:

```
question: "Which database do you want me to switch the Performance API to?"
header: "DB target"
options:
  - { label: "Local sandbox DB", description: "performance_sandbox" }
  - { label: "Restored prod copy", description: "performance_prod_2026_05_10" }
```

### Phase 4: Lock confirmed intent

After option pick (AMBIGUOUS / UNDER-SPECIFIED) or restatement print (CLEAR), store intent as one B2-English sentence. Parent skill treats this as the canonical request.

If user picks `Other` with free text, run Phase 2 once on that text. If still ambiguous after one round, stop and say: `I am still not sure what you want. Please write the request again in a different way.`

### Phase 5: Return

Hand control to caller. No end summary.

## Follow-up Directives

Classify every mid-skill user message:

| Class | Definition | Action |
|-------|------------|--------|
| **Continuation reply** | Direct answer to in-flight AskUserQuestion. | Absorb into the question. |
| **Control ack** | Short ack, no new verb/object (`yes`, `ok`, `got it`, `sounds good`, `go ahead`, `continue`, `stop`, `skip`, `cancel`, `nevermind`). | Treat as control flow. |
| **In-flight clarification** | Small refinement (`use 3 retries`, `cap is 50 not 100`). Verb + top-level object unchanged. | Absorb into current step. |
| **Fresh directive** | New verb, new top-level object, contradiction of locked intent, extra scope, or skill redirect. | Re-invoke optimise-prompt before acting. |

Fresh-directive triggers (any one):

- New verb not in current step's vocabulary (`also add...`, `now do...`, `instead, ...`, `wait, ...`, `forget that, ...`).
- New top-level object (different file, feature, branch, table, PR).
- Contradicts locked intent (`actually I don't want X` after X was confirmed).
- Expands scope (`also do Y`, `and rename Z while you're at it`).
- Changes parent skill mid-flight (`stop this and run debugging instead`, `cancel and commit what we have`).

## Hard Rules

- Read-only and dialogue-only. No file edits, no git, no tests, no other skill calls.
- One round of AskUserQuestion at most (AMBIGUOUS / UNDER-SPECIFIED only).
- Clarify; do not redirect the user's intent.
- Always emit a visible restatement -- plain chat (CLEAR) or AskUserQuestion `question` text (AMBIGUOUS / UNDER-SPECIFIED). Silent return is forbidden.
- Pause only on AMBIGUOUS / UNDER-SPECIFIED. CLEAR path returns immediately.
