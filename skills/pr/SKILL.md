---
name: pr
description: 'Triggers on requests to raise the PR for finished work -- `/pr`, "raise a PR", "raise the pr", "open the PR". Raises the single PR for the whole branch once every card is done -- determines the branch first (asking the user how to branch when the current one is protected), runs `/commit` (clean-tree gate + atomic commits), then raises the PR, with the ticket number / ticket URL in the body and linked PRs for cross-repo work. Never auto-creates a branch. There are no per-card PRs.'
---

# Pandahrms /pr

Determine the branch, commit, then raise the one PR for the whole work.

**Announce at start:** "I'm using Pandahrms /pr to commit and raise the PR for this work."

## 1. Branch first (user-owned)

Determine the branch BEFORE committing. If the current branch is `main`, `master`, `develop`, or `development`, do NOT `/commit` or PR there. Ask via AskUserQuestion how to branch and CREATE the branch before committing:
- "Create a branch now" -- invoke `pandahrms:branching` (confirms name + source with the user).
- "I'll branch myself" -- pause, wait for the user to say the branch is ready.

If the current branch is not protected, use it. Never auto-create or auto-switch a branch.

## 2. Commit

Run `/commit` once the branch is settled. `/commit` gates the tree (0 test, 0 lint, 0 format, 0 build errors) and plans atomic commits. Never `/commit` onto a protected branch.

## 3. Raise the PR

- Push: `git push -u origin <branch>` (first push sets the upstream).
- Open: `gh pr create --title "<work title>" --body "<body>"`.
- Show the user the PR URL.
- If `gh` is missing or unauthenticated, push the branch and give the user the compare URL to open the PR by hand. Do not block on it.

## 4. PR body

State the work shipped and the layers / repos touched, and link the cards.

Ticket-driven work: include the ticket number and ticket URL. Read them from the intake Source field / per-work `_overview`. Free-form work omits the ticket reference.

## 5. Cross-repo work (BE + FE)

Work spanning two repos raises 2 PRs, one per repo. Run `/commit` (clean-check + atomic commits) in EACH repo. Open the first PR, then the second in its repo. Edit each PR body to cross-link the other's URL, so each PR names its counterpart.

## Next step

End by telling the user the flow is complete -- the work is committed and the PR(s) are open.
