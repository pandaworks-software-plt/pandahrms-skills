# Experimental bounded PR review

Status: complete locally, unreleased (2026-09-14)

## Objective

Add `pr-review-experimental` to the shared plugin. Review one GitHub PR with NO-GO / MEL classification, persistent findings, three normal rounds and one conditional final round. Default to read-only; apply local fixes only when requested. Never imply permission to publish or merge.

## Acceptance

- Verified blocking defects prevent readiness; uncertainty and missing required checks also block readiness.
- MEL requires bounded impact, mitigation, owner, due date, follow-up reference and explicit human acceptance. Expired MEL blocks readiness.
- Naming/style suggestions do not block or trigger another round.
- Every round records repository/PR identity and base/head SHA. New commits preserve the round count and invalidate old readiness.
- Keep stable finding IDs and root-cause keys. Preserve resolved and dismissed findings with evidence; prevent silent omission or automatic NO-GO downgrade.
- Round four is available only after round three leaves an open NO-GO. Round five is rejected. Reaching a limit never grants readiness.
- Return READY, READY WITH MEL or BLOCKED against the current reviewed revision. Report the stopping reason.
- Documentation supports both Codex and Claude Code.

## Card 01 — experimental bounded PR review

Category: implementation. Sensitivity: standard (local review records; no application auth, tenant, money, schema or PII implementation).

Product L1/L2: not applicable to this developer-tool plugin. Observable behavior is specified above and exercised by Python unittest fixtures below.

- [x] Agree objective and acceptance from the conversation.
- [x] Write failing tests in `skills/pr-review-experimental/tests/test_review_state.py`.
- [x] Implement `skills/pr-review-experimental/scripts/review_state.py` and `skills/pr-review-experimental/SKILL.md`.
- [x] Add README and repository structure entries.
- [x] Run state tests, skill validator and isolated workflow exercise.
- [x] Inspect final diff and record outcome.

No commit, push, release, GitHub comment or merge in this task. Versions stay synchronized at the current release; the repository requires the new-skill minor bump at release/push.

## Verification

- `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s skills/pr-review-experimental/tests -v`: 14 tests passed. Includes CLI state persistence and wrong-PR rejection.
- Skill creator `quick_validate.py`: `Skill is valid!`.
- Codex `validate_plugin.py`: passed. Validator-only PyYAML installed in temporary environment; helper uses Python standard library only.
- Independent skill invocation in isolated Pandahrms fixture: reused existing READY at same revision after three rounds; refused extra naming-only review; left ledger unchanged. No live GitHub PR was reviewed.
- Found and corrected overly strict classification lock: allow MEL escalation to NO-GO; continue rejecting NO-GO downgrade. Regression test added.
- Forward-test feedback corrected stop reason: report missing open NO-GO before suggesting fourth-round flag. Regression test added.
- `git diff --check`: passed. Existing unrelated `skills/spec/SKILL.md` edits preserved.

## Closed: 2026-09-14

Local implementation and validation complete. Source lives in shared plugin; installed plugin cache remains at released version until user requests release/update. Ledger is a local workflow guard, not CI attestation or tamper-proof storage.
