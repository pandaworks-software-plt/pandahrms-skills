---
name: pr
description: Manually invoked as `/pr` (or an explicit "raise a PR" / "open the PR" request) to raise the single PR for a piece of work once every card is done. There are no per-card PRs -- this is the one PR for the whole branch. Does NOT auto-trigger -- only on the `/pr` slash command or an explicit PR request; a bare mention of "pr" or a finished card alone is not enough. Determines the branch first -- if the current branch is protected, asks the user how to branch and creates it before committing -- then runs `/commit` (clean-tree gate + atomic commits), then raises the PR. Cross-repo work raises linked PRs that cross-link each other. The PR body includes the ticket number / ticket URL when the work came from a ticket. Never auto-creates a branch.
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
