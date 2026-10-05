#!/usr/bin/env python3
"""Record bounded PR review rounds. Local ledger only; no GitHub mutations."""

import argparse
import copy
from datetime import date
import json
import os
from pathlib import Path
import re
import tempfile


def require(condition, message):
    if not condition:
        raise ValueError(message)


def nonempty(value):
    return isinstance(value, str) and bool(value.strip())


def new_state(pr):
    require(isinstance(pr, str) and re.fullmatch(r'[^/#\s]+/[^/#\s]+#[1-9][0-9]*', pr),
            'PR must be owner/repo#number')
    return {'version': 1, 'pr': pr, 'rounds': []}


def validate_report(report):
    require(isinstance(report, dict), 'Round report must be an object')
    for key in ('head', 'base'):
        require(isinstance(report.get(key), str) and
                re.fullmatch(r'[0-9a-f]{40}|[0-9a-f]{64}', report[key]), f'{key} must be full SHA')
    for key in ('checks_passed', 'review_complete'):
        require(type(report.get(key)) is bool, f'{key} must be boolean')
    require(isinstance(report.get('checks_evidence'), str), 'checks_evidence must be string')
    require(isinstance(report.get('gaps'), list) and all(nonempty(gap) for gap in report['gaps']),
            'gaps must be list of nonempty strings')
    require(isinstance(report.get('findings'), list), 'findings must be list')
    ids, keys = set(), set()
    for finding in report['findings']:
        require(isinstance(finding, dict), 'Finding must be object')
        for key in ('id', 'key', 'evidence'):
            require(nonempty(finding.get(key)), f'Finding {key} required')
        require(finding['id'] not in ids, 'Duplicate finding ID')
        require(finding['key'] not in keys, 'Duplicate root-cause key; update existing finding')
        ids.add(finding['id'])
        keys.add(finding['key'])
        require(finding.get('classification') in ('NO-GO', 'MEL'), 'Invalid finding classification')
        require(finding.get('status') in ('open', 'resolved', 'dismissed'), 'Invalid finding status')


def may_start(state, fourth=False):
    count = len(state['rounds'])
    require(count < 4, 'Round limit reached; hand off to human')
    require(not fourth or count == 3, 'Fourth-round flag requires three recorded rounds')
    if count == 3:
        require(any(f['classification'] == 'NO-GO' and f['status'] == 'open'
                    for f in state['rounds'][-1]['findings']),
                'Fourth round requires open NO-GO after round three')
        require(fourth, 'Three rounds complete; explicit fourth-round flag required')


def record_round(state, report, fourth=False, today=None):
    today = today or date.today().isoformat()
    date.fromisoformat(today)
    may_start(state, fourth)
    validate_report(report)
    if state['rounds']:
        previous = {f['id']: f for f in state['rounds'][-1]['findings']}
        current = {f['id']: f for f in report['findings']}
        require(previous.keys() <= current.keys(), 'Retain every finding; resolve or dismiss with evidence')
        for identity, old in previous.items():
            require(current[identity]['key'] == old['key'], 'Keep stable root-cause key')
            require(old['classification'] != 'NO-GO' or current[identity]['classification'] == 'NO-GO',
                    'NO-GO downgrade forbidden; use evidenced resolution/dismissal')
    result = copy.deepcopy(state)
    item = copy.deepcopy(report)
    item['recorded_on'] = today
    result['rounds'].append(item)
    return result


def valid_mel(finding, today):
    fields = ('impact', 'mitigation', 'owner', 'due', 'ticket', 'accepted_by', 'acceptance_evidence')
    if not all(nonempty(finding.get(key)) for key in fields):
        return False
    try:
        return date.fromisoformat(finding['due']) >= date.fromisoformat(today)
    except ValueError:
        return False


def verdict(state, head, base, today=None):
    today = today or date.today().isoformat()
    if not state['rounds']:
        return 'BLOCKED'
    latest = state['rounds'][-1]
    if (latest['head'] != head or latest['base'] != base or
            not latest['checks_passed'] or not nonempty(latest['checks_evidence']) or
            not latest['review_complete'] or latest['gaps']):
        return 'BLOCKED'
    opened = [f for f in latest['findings'] if f['status'] == 'open']
    if any(f['classification'] == 'NO-GO' or not valid_mel(f, today) for f in opened):
        return 'BLOCKED'
    return 'READY WITH MEL' if opened else 'READY'


def read_state(path, pr):
    if not path.exists():
        return new_state(pr)
    state = json.loads(path.read_text())
    require(isinstance(state, dict) and state.get('version') == 1, 'Unsupported state version')
    require(state.get('pr') == pr, 'State belongs to another PR')
    require(isinstance(state.get('rounds'), list), 'Invalid round history')
    rebuilt = new_state(pr)
    for index, report in enumerate(state['rounds']):
        rebuilt = record_round(rebuilt, report, index == 3, report['recorded_on'])
    return rebuilt


def write_state(path, state):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode='w', dir=path.parent, prefix='.review-', delete=False) as handle:
        json.dump(state, handle, indent=2)
        handle.write('\n')
        temporary = handle.name
    os.replace(temporary, path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('status', 'record'))
    parser.add_argument('--state', required=True, type=Path)
    parser.add_argument('--pr', required=True)
    parser.add_argument('--report', type=Path)
    parser.add_argument('--head')
    parser.add_argument('--base')
    parser.add_argument('--fourth', action='store_true')
    args = parser.parse_args()
    try:
        state = read_state(args.state, args.pr)
        if args.action == 'record':
            require(args.report is not None, 'record requires --report')
            report = json.loads(args.report.read_text())
            state = record_round(state, report, args.fourth)
            write_state(args.state, state)
            head, base = report['head'], report['base']
        else:
            require(nonempty(args.head) and nonempty(args.base), 'status requires current --head and --base')
            head, base = args.head, args.base
        try:
            may_start(state, args.fourth)
            can_start, reason = True, 'Round available'
        except ValueError as error:
            can_start, reason = False, str(error)
        print(json.dumps({'pr': args.pr, 'rounds': len(state['rounds']),
                          'verdict': verdict(state, head, base),
                          'can_start': can_start, 'reason': reason,
                          'state': str(args.state)}, indent=2))
    except (ValueError, OSError, KeyError, TypeError) as error:
        parser.exit(2, f'ERROR: {error}\n')


if __name__ == '__main__':
    main()
