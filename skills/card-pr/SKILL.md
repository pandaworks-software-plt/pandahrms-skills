---
name: card-pr
description: Triggers after a card's execute + review pass when it is time to ship it -- phrasings like "raise a PR for this card", "open the PR", "ship this card", "card-pr", or the per-card "raise PR?" prompt in the main flow. Asks whether to raise a PR, asks the user how they want to branch (never auto-creates a branch), commits via hermes-commit, pushes, and opens the PR. A BE + FE vertical slice raises 2 linked PRs, one per repo, each cross-linking the other.
---

# Pandahrms Card PR

## Overview

Per-card PR step. After a card's execute + review pass, offer a PR, settle branching with the user, commit, and open the PR. Commit happens only on the PR path; hermes-commit stays the pure commit step.

**Announce at start:** "I'm using Pandahrms card-pr to raise the PR for this card."

## 1. Raise PR?

Ask via AskUserQuestion: "Raise a PR for this card now?" with options "Yes, raise it" and "No, leave it staged". On **No**: leave the card's changes staged and uncommitted, end, move to the next card.

## 2. Branch (user-owned)

Branching is user-owned. Ask via AskUserQuestion how to proceed:
- "Create a branch now" -- invoke `pandahrms:branching` (it confirms name + source with the user).
- "I'll branch myself" -- pause and wait for the user to say it is ready.
- "Use the current branch" -- only when the current branch is not protected.

If the current branch is `main`, `master`, `develop`, or `development`, do NOT commit or PR there -- re-offer the branch options. Never auto-create or auto-switch a branch.

## 3. Commit

Invoke `pandahrms:hermes-commit` to gate the tree and make atomic commits for this card's changes.

## 4. Push + open PR

- Push: `git push -u origin <branch>` (first push sets the upstream).
- Open the PR with `gh pr create --title "<card title>" --body "<summary>"`. The body states the capability the slice ships and the layers it touches, and links the card.
- Show the user the PR URL.
- If `gh` is not installed or not authenticated, push the branch and give the user the compare URL to open the PR by hand. Do not block on it.

## 5. Cross-repo slice (BE + FE)

A slice spanning two repos raises 2 PRs, one per repo. Open the first, then open the second in its repo. Edit each PR body to cross-link the other's URL, so each PR names its counterpart.

## Fast lane

A finished fast-lane change uses the same step: offer the PR, settle branching, commit, open the PR. Fast lane skips decompose and per-card review, not the PR offer.

## Red Flags

| Thought | Reality |
|---------|---------|
| "I'll create the branch myself to save a step" | Branching is user-owned. Ask how they want to branch; never auto-create or switch. |
| "I'll open the PR from main" | Never PR from a protected branch. Settle a feature branch first. |
| "I'll commit with git directly" | Use hermes-commit -- it gates the tree and plans atomic commits. |
| "BE + FE slice is one PR" | Two linked PRs, one per repo, each cross-linking the other. |
| "User said no to the PR, but I'll commit anyway" | On No, leave it staged and move on. |
| "I'll push with --no-verify to skip a failing hook" | Never bypass hooks. Fix the cause, then push. |
