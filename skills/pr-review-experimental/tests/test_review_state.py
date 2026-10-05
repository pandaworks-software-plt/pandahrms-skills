import copy
import importlib.util
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).parents[1] / 'scripts' / 'review_state.py'
spec = importlib.util.spec_from_file_location('review_state', SCRIPT)
review = importlib.util.module_from_spec(spec)
spec.loader.exec_module(review)

HEAD = 'a' * 40
BASE = 'b' * 40
TODAY = '2026-09-14'


def report(findings=None, **overrides):
    value = dict(head=HEAD, base=BASE, checks_passed=True,
                 checks_evidence='CI run 123 passed at this head/base',
                 review_complete=True, gaps=[], findings=findings or [])
    value.update(overrides)
    return value


def finding(kind='NO-GO', **overrides):
    value = dict(id='F001', key='payroll/export/tenant-boundary',
                 classification=kind, status='open', evidence='export.cs:20; caller lacks tenant guard',
                 impact='Cross-tenant export', mitigation='Disable export',
                 owner='maintainer', due='2026-09-21', ticket='TRACK-123',
                 accepted_by='maintainer', acceptance_evidence='User explicitly accepted F001 on 2026-09-14')
    value.update(overrides)
    return value


class ReviewStateTests(unittest.TestCase):
    def setUp(self):
        self.state = review.new_state('org/repo#42')

    def record(self, value=None, fourth=False):
        self.state = review.record_round(self.state, value or report(), fourth, TODAY)
        return review.verdict(self.state, HEAD, BASE, TODAY)

    def test_clean_review_ready_and_blockers_block(self):
        self.assertEqual(self.record(report([finding()])), 'BLOCKED')
        self.assertEqual(self.record(report([finding(status='resolved')])), 'READY')

    def test_mel_needs_all_conditions_and_human_acceptance(self):
        self.assertEqual(self.record(report([finding('MEL')])), 'READY WITH MEL')
        for field in ('impact', 'mitigation', 'owner', 'due', 'ticket', 'accepted_by', 'acceptance_evidence'):
            with self.subTest(field=field):
                state = review.record_round(review.new_state('org/repo#42'), report([finding('MEL', **{field: ''})]), False, TODAY)
                self.assertEqual(review.verdict(state, HEAD, BASE, TODAY), 'BLOCKED')

    def test_expired_mel_blocks_without_new_round(self):
        self.record(report([finding('MEL')]))
        self.assertEqual(review.verdict(self.state, HEAD, BASE, '2026-09-22'), 'BLOCKED')

    def test_missing_checks_review_or_evidence_blocks(self):
        for overrides in ({'checks_passed': False}, {'checks_evidence': ''},
                          {'review_complete': False}, {'gaps': ['Cannot inspect endpoint caller']}):
            with self.subTest(overrides=overrides):
                state = review.record_round(review.new_state('org/repo#42'), report(**overrides), False, TODAY)
                self.assertEqual(review.verdict(state, HEAD, BASE, TODAY), 'BLOCKED')

    def test_head_or_base_change_invalidates_ready(self):
        self.record()
        self.assertEqual(review.verdict(self.state, 'c' * 40, BASE, TODAY), 'BLOCKED')
        self.assertEqual(review.verdict(self.state, HEAD, 'c' * 40, TODAY), 'BLOCKED')

    def test_three_round_limit_and_new_head_does_not_reset(self):
        for head in (HEAD, 'c' * 40, 'd' * 40):
            self.record(report(head=head))
        with self.assertRaises(ValueError):
            self.record(report(head='e' * 40))
        with self.assertRaises(ValueError):
            self.record(fourth=True)
        self.assertEqual(len(self.state['rounds']), 3)

    def test_fourth_requires_open_no_go_and_never_allows_fifth(self):
        for _ in range(3):
            self.record(report([finding()]))
        with self.assertRaises(ValueError):
            self.record(report([finding()]))
        self.assertEqual(self.record(report([finding(status='resolved')]), fourth=True), 'READY')
        with self.assertRaises(ValueError):
            self.record(fourth=True)

    def test_no_go_at_limit_stays_blocked(self):
        for _ in range(3):
            self.record(report([finding()]))
        self.assertEqual(self.record(report([finding()]), fourth=True), 'BLOCKED')

    def test_stop_reason_identifies_missing_no_go_before_suggesting_flag(self):
        for _ in range(3):
            self.record()
        with self.assertRaisesRegex(ValueError, 'requires open NO-GO'):
            review.may_start(self.state)

    def test_findings_cannot_disappear_change_identity_or_auto_downgrade(self):
        self.record(report([finding()]))
        for findings in ([], [finding(id='F002')], [finding(key='renamed')], [finding('MEL')]):
            with self.subTest(findings=findings), self.assertRaises(ValueError):
                self.record(report(findings))

    def test_duplicate_root_cause_and_evidenceless_resolution_rejected(self):
        for findings in ([finding(), finding(id='F002')], [finding(status='resolved', evidence='')]):
            with self.subTest(findings=findings), self.assertRaises(ValueError):
                self.record(report(findings))

    def test_mel_can_escalate_to_no_go_when_risk_grows(self):
        self.assertEqual(self.record(report([finding('MEL')])), 'READY WITH MEL')
        self.assertEqual(self.record(report([finding()])), 'BLOCKED')
        self.assertEqual(self.state['rounds'][0]['findings'][0]['classification'], 'MEL')

    def test_invalid_input_is_rejected_without_mutating_history(self):
        before = copy.deepcopy(self.state)
        for overrides in ({'checks_passed': 'true'}, {'head': 'main'}, {'gaps': 'none'},
                          {'findings': [finding(classification='NIT')]}):
            with self.subTest(overrides=overrides), self.assertRaises(ValueError):
                self.record(report(**overrides))
        self.assertEqual(self.state, before)

    def test_cli_rejects_different_pr_and_preserves_existing_state(self):
        import json
        import subprocess
        import sys
        with tempfile.TemporaryDirectory() as directory:
            state = Path(directory) / 'review-state.json'
            payload = Path(directory) / 'round.json'
            payload.write_text(json.dumps(report()))
            command = [sys.executable, str(SCRIPT), 'record', '--state', str(state),
                       '--pr', 'org/repo#42', '--report', str(payload)]
            self.assertEqual(subprocess.run(command, capture_output=True).returncode, 0)
            saved = state.read_bytes()
            command[command.index('org/repo#42')] = 'org/other#42'
            self.assertNotEqual(subprocess.run(command, capture_output=True).returncode, 0)
            self.assertEqual(state.read_bytes(), saved)


if __name__ == '__main__':
    unittest.main()
