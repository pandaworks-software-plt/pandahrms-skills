---
name: execute-sonnet
description: 'The Sonnet-pinned variant of `/execute`, invoked explicitly as `/pandahrms:execute-sonnet [card-NN]`. Runs a work card exactly as `/execute` does -- guided spec-first TDD run with stop-gates, `/lint-gate` + `/code-review` per layer, `/verify` at card pre-complete -- but pinned to the Sonnet model via its frontmatter model pin; `--blast-mode` queues the cards as a Workflow of Sonnet subagents. Does NOT commit per card and does NOT raise per-card PRs -- the whole branch is committed and ONE PR raised at the end via `/commit` or `/pr`.'
model: sonnet
---

# Pandahrms Execute (Sonnet)

**Announce at start:** "I'm using Pandahrms execute (Sonnet) to run this card."

## Shared body

Read `../execute/SKILL.md` (sibling skill folder, resolve relative to this file's base directory) and apply ALL of its sections as this skill's rules. The deltas below OVERRIDE the shared body where they differ. Where the shared body says `/execute`, read `/pandahrms:execute-sonnet`.

## Invocation

- `/pandahrms:execute-sonnet card-NN` -- run that card.
- `/pandahrms:execute-sonnet` (bare) -- run the next available card = lowest-order active card not yet done.
- Append `--approve` to either form (`/pandahrms:execute-sonnet card-NN --approve`) for low-touch mode -- see Low-touch mode.
- `/pandahrms:execute-sonnet --blast-mode` -- blast mode: spawn a dynamic Workflow that queues every available card as a flow item and runs them in card order on Sonnet, no stop-gates; `/commit` + `/pr` prohibited. See Blast mode.

## Deltas

The sections below OVERRIDE the shared body.

### Model pin

Run the card on the Sonnet model (`model: sonnet`). Note: `model: sonnet` is turn-scoped -- it pins Sonnet for the turn you invoke it; after a stop-gate reply the session model resumes unless re-invoked.

A single-card or non-blast run is native, current context -- no subagent dispatch, no batches. `--blast-mode` is the one exception: it spawns a dynamic Workflow that queues the cards as flow items and runs them on Sonnet (see Blast mode).

## Blast mode (`--blast-mode`)

**Replaces the shared body's Blast mode.** `--blast-mode` runs EVERY available card in `<work-folder>/active/` autonomously by spawning a dynamic Workflow that queues the cards as flow items -- NOT a native in-context run. No human pause at any gate. Invoking `--blast-mode` is the user opt-in that authorises the Workflow tool.

Build and run the Workflow:

1. Collect runnable cards from `<work-folder>/active/`, lowest `order` first, skipping done cards. This ordered list is the flow-item queue; pass it to the Workflow as `args`.
2. Author a dynamic Workflow script (inline to the Workflow tool). Queue each card as ONE flow item. Run them STRICTLY IN ORDER, one at a time -- a `for` loop of `await agent(...)`, never a parallel `pipeline`/`parallel` (cards share the one working tree and later cards build on earlier ones).
3. Pin every card agent to Sonnet -- `agent(prompt, { model: 'sonnet', schema: CARD_RESULT })`. This holds Sonnet across the whole run; the frontmatter `model:` alone is turn-scoped and would not survive it.
4. Each card agent runs that card's full ordered sequence under every execute-sonnet rule (spec-first TDD with RED/GREEN/VERIFICATION, `/lint-gate`, `/code-review autonomous`, `/security-review --no-commit` when the card is sensitive, deploy + regen when the architecture needs it, Pre-complete `/verify` requiring `VERIFY RESULT: PASS`). It resolves each decision point autonomously (`DECISION -- <point>: <choice> (<reason>)` on the card Progress), marks a card `BLOCKED -- <reason>` left in `active/` when it cannot reach `/verify` PASS, moves a done card `active/` -> `done/` with a `## Closed: <date>` block, and returns a structured `CARD_RESULT`.
5. After each flow item, read its result. When a card is BLOCKED and the remaining cards depend on it, STOP the queue. Otherwise continue to the next flow item. Stop when the queue is empty.

**Commit + PR prohibited.** Never `/commit` or `/pr` in this mode -- inside a card agent or after the Workflow. Deploy BE to local Docker and FE regen still run. All cards' changes pile up uncommitted in the one working tree for the user to review and commit later.

**Nothing silent.** Every autonomous call is a `DECISION` on the card Progress; every unrunnable card is `BLOCKED`, left in `active/`. Never fake a pass, never commit broken code, never silently absorb a block.

**Diff scope.** No commits between cards -- the working-tree diff accumulates. Each card agent scopes its `/lint-gate` and `/code-review` to the files THAT card touched, not the whole accumulated diff; `/verify` stays project-scoped.

**Wrap-up (always).** When the Workflow returns, aggregate every `CARD_RESULT` into a dated `## Blast run <date>` section appended to `_overview.md` AND printed to chat:

- Cards done, each with its `## Closed` note.
- Cards blocked, each with its `BLOCKED -- <reason>`.
- Every `DECISION` the card agents made during the run.
- A line stating nothing was committed: all changes sit uncommitted in the working tree.
- Next step: the user reviews the working tree, then runs `/commit` or `/pr` to ship.

Reference Workflow shape (sequential queue, Sonnet-pinned):

```js
export const meta = {
  name: 'execute-sonnet-blast',
  description: 'Run every active card back to back on Sonnet, in card order',
  phases: [{ title: 'Cards' }],
}
// CARD_RESULT: { status: 'done'|'blocked', closed?: string, decisions: string[], blockedReason?: string }
phase('Cards')
const results = []
for (const card of args.cards) {                       // args.cards = ordered card refs
  const r = await agent(
    `Run ${card.id} end to end under the execute-sonnet blast rules: spec-first TDD, ` +
    `/lint-gate + /code-review autonomous (+ /security-review --no-commit if sensitive), ` +
    `deploy + regen if the architecture needs it, Pre-complete /verify must return PASS. ` +
    `Resolve decisions autonomously and record DECISION lines; mark BLOCKED if it cannot pass; ` +
    `move it active->done with a Closed block. Never /commit or /pr.`,
    { label: `card:${card.id}`, model: 'sonnet', schema: CARD_RESULT }
  )
  results.push({ card: card.id, ...r })
  if (r?.status === 'blocked' && card.blocksRest) break // dependents can't run
}
return results
```

## Red Flags (deltas)

| Thought | Reality |
|---------|---------|
| "I'll dispatch subagents for a single card's steps" | Run a single card natively in the current context. Only `--blast-mode` dispatches -- it spawns the Workflow that queues the cards as flow items. |

## Next step

End by telling the user their next skill: if active cards remain, run `/pandahrms:execute-sonnet` for the next card; when the last card finishes, this skill invokes `/status` itself to present the conclusion.

Under `--blast-mode` the run ends with the Blast mode wrap-up (saved to `_overview.md` + chat); next step is the user reviews the uncommitted working tree, then runs `/commit` or `/pr`.
