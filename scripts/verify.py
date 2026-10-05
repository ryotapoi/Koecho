#!/usr/bin/env python3
"""Run Koecho's CLI gates with bounded execution and retained evidence."""
import argparse
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]


def save(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def processes():
    rows = subprocess.check_output(['/bin/ps', '-axo', 'pid=,pgid=,lstart=,command='], text=True)
    result = {}
    for row in rows.splitlines():
        fields = row.split(None, 7)
        if len(fields) == 8:
            result[int(fields[0])] = {'group': int(fields[1]), 'started': ' '.join(fields[2:7]),
                                      'command': fields[7]}
    return result


def run_logged(command, evidence, timeout=600, owned_path=None):
    """A unique output path and new process group identify this command's residue."""
    before = processes()
    if owned_path and any(str(owned_path) in p['command'] for p in before.values()):
        raise RuntimeError('Output path is in use; do not touch another run')
    started = time.monotonic()
    timed_out = False
    interrupted = False
    with (evidence / 'build.log').open('w') as log:
        child = subprocess.Popen(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT,
                                 start_new_session=True)
        try:
            child.wait(timeout=timeout)
        except (subprocess.TimeoutExpired, KeyboardInterrupt) as error:
            timed_out = isinstance(error, subprocess.TimeoutExpired)
            interrupted = not timed_out
        current = processes()
        residue = {pid: p for pid, p in current.items() if pid != os.getpid()
                   and (p['group'] == child.pid or
                        (pid not in before and owned_path and str(owned_path) in p['command']))}
        for pid, process in residue.items():
            if processes().get(pid) == process:
                os.kill(pid, signal.SIGTERM)
        deadline = time.monotonic() + 5
        while any(processes().get(pid) == p for pid, p in residue.items()) and time.monotonic() < deadline:
            time.sleep(.1)
        for pid, process in residue.items():
            if processes().get(pid) == process:
                os.kill(pid, signal.SIGKILL)
        child.wait(timeout=5)
        remaining = {pid: p for pid, p in processes().items() if pid != os.getpid()
                     and (p['group'] == child.pid or
                          (pid not in before and owned_path and str(owned_path) in p['command']))}
    result = {'command': command, 'cwd': str(ROOT), 'developer_dir': os.environ.get('DEVELOPER_DIR'),
              'selected_developer_dir': subprocess.check_output(['xcode-select', '-p'], text=True).strip(),
              'duration_seconds': round(time.monotonic() - started, 3), 'exit_code': child.returncode,
              'timeout': timed_out, 'interrupted': interrupted, 'residue_detected': residue,
              'remaining': remaining, 'log': str(evidence / 'build.log')}
    result['success'] = child.returncode == 0 and not (timed_out or interrupted or residue or remaining)
    save(evidence / 'command-result.json', result)
    return result


def xcresult(bundle, kind='summary', test_id=None):
    command = ['xcrun', 'xcresulttool', 'get', 'test-results', kind, '--path', str(bundle)]
    if test_id:
        command.extend(['--test-id', test_id])
    return json.loads(subprocess.check_output(command, text=True, timeout=60))


def check_app(summary):
    return (summary.get('passedTests', 0) > 0 and summary.get('failedTests') == 0
            and summary.get('skippedTests') == 0 and summary.get('result') == 'Passed'
            and not summary.get('testFailures'))


def package_summary(path):
    with path.open() as file:
        rows = [json.loads(line) for line in file]
    events = [r['payload'] for r in rows if r['kind'] == 'event']
    definitions = {r['payload']['id']: r['payload'] for r in rows if r['kind'] == 'test'}
    runs = [e for e in events if e['kind'] == 'runEnded']
    total = sum(int(m.group(1)) for e in runs for msg in e.get('messages', [])
                if (m := re.search(r'Test run with (\d+) tests?', msg['text'])))
    failures = [e for e in events if e['kind'] == 'issueRecorded'
                or any(m['symbol'] == 'fail' for m in e.get('messages', []))]
    skipped = [e for e in events if e['kind'] == 'testSkipped']
    targets = sorted({e['testID'].split('.')[0] for e in events if e['kind'] == 'testEnded'
                      and definitions.get(e.get('testID'), {}).get('kind') != 'suite'})
    return {'total': total, 'failed': len(failures), 'skipped': len(skipped), 'failures': failures,
            'targets': targets, 'completed_runs': len(runs),
            'complete': len(runs) == sum(e['kind'] == 'runStarted' for e in events)}


def app_list(path):
    raw = json.loads(path.read_text())
    if raw.get('errors'):
        raise RuntimeError(str(raw['errors']))
    tests = []
    def walk(nodes, target='', suite=''):
        for node in nodes:
            kind, name = node.get('kind'), node.get('name', '')
            if kind == 'test':
                tests.append({'target': target, 'identifier': f'{target}/{suite}/{name}'})
            walk(node.get('children', []), name if kind == 'target' else target,
                 name if kind == 'class' else suite)
    walk(raw.get('values', []))
    return tests


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['build', 'app-tests', 'app-list', 'package-tests',
                                         'package-list', 'results', 'log'])
    parser.add_argument('--run')
    parser.add_argument('--only', action='append', default=[])
    parser.add_argument('--filter')
    parser.add_argument('--timeout', type=float, default=600)
    parser.add_argument('--path', type=Path)
    parser.add_argument('--test-id')
    parser.add_argument('--pattern', default=r'error:|warning:|failed|failure|timed out')
    parser.add_argument('--limit', type=int, default=30)
    ns = parser.parse_args()
    if ns.action == 'results':
        print(json.dumps(xcresult(ns.path, 'test-details' if ns.test_id else 'summary', ns.test_id), indent=2))
        return
    if ns.action == 'log':
        matches = [(n, line.rstrip()) for n, line in enumerate(ns.path.open(), 1)
                   if re.search(ns.pattern, line, re.IGNORECASE)]
        print(json.dumps({'total': len(matches), 'truncated': len(matches) > ns.limit,
                          'matches': matches[:ns.limit], 'full_log': str(ns.path)}, indent=2))
        return
    if not ns.run or Path(ns.run).name != ns.run or ns.run in ('.', '..'):
        parser.error('--run must be a new single directory name')
    if ns.timeout <= 0:
        parser.error('--timeout must be positive')
    if ns.only and ns.action not in ('app-tests', 'app-list'):
        parser.error('--only is for App tests')
    if ns.filter and ns.action != 'package-tests':
        parser.error('--filter is for Package tests')
    if any(not t.startswith('KoechoTests/') for t in ns.only):
        parser.error('--only must be a discovered KoechoTests/<suite>/<test> identifier')
    evidence = ROOT / 'tmp/verification/cli' / ns.run
    evidence.mkdir(parents=True, exist_ok=False)
    scratch = ROOT / 'tmp/verification-scratch' / ns.run
    if scratch.exists():
        parser.error('Scratch already exists')
    if ns.action.startswith('package'):
        command = ['xcrun', 'swift', 'test', '--package-path', str(ROOT / 'Packages/KoechoKit'),
                   '--scratch-path', str(scratch)]
        if ns.action == 'package-list':
            command.append('list')
        else:
            command.extend(['--event-stream-output-path', str(evidence / 'events.jsonl')])
            if ns.filter:
                command.extend(['--filter', ns.filter])
    else:
        command = ['xcrun', 'xcodebuild', '-project', str(ROOT / 'Koecho.xcodeproj'),
                   '-scheme', 'Koecho', '-configuration', 'Debug', '-destination', 'platform=macOS',
                   '-derivedDataPath', str(scratch)]
        if ns.action == 'build':
            command.append('build')
        else:
            command.extend(['-only-testing:' + t for t in ns.only or ['KoechoTests']])
            command.extend(['-skip-testing:KoechoUITests', '-parallel-testing-enabled', 'NO'])
            if ns.action == 'app-list':
                command.extend(['test', '-enumerate-tests', '-test-enumeration-format', 'json',
                                '-test-enumeration-output-path', str(evidence / 'tests.json')])
            else:
                command.extend(['-resultBundlePath', str(evidence / 'tests.xcresult'),
                                '-test-timeouts-enabled', 'YES',
                                '-default-test-execution-time-allowance', '60', 'test'])
    result = run_logged(command, evidence, ns.timeout, scratch)
    try:
        if ns.action == 'app-list':
            tests = app_list(evidence / 'tests.json')
            save(evidence / 'test-list.json', tests)
            result['discovery'] = {'total': len(tests), 'targets': sorted({t['target'] for t in tests}),
                                   'full_list': str(evidence / 'test-list.json')}
            result['success'] = result['success'] and bool(tests) and result['discovery']['targets'] == ['KoechoTests']
        elif ns.action == 'package-list':
            tests = [line for line in (evidence / 'build.log').read_text().splitlines()
                     if re.match(r'^Koecho(Core|Platform)Tests\.', line)]
            save(evidence / 'test-list.json', tests)
            result['discovery'] = {'total': len(tests), 'targets': sorted({t.split('.')[0] for t in tests}),
                                   'full_list': str(evidence / 'test-list.json')}
            result['success'] = result['success'] and bool(tests) and result['discovery']['targets'] == ['KoechoCoreTests', 'KoechoPlatformTests']
        elif ns.action == 'app-tests' and (evidence / 'tests.xcresult').exists():
            summary = xcresult(evidence / 'tests.xcresult')
            save(evidence / 'test-summary.json', summary)
            result['tests'] = summary
            result['success'] = result['success'] and check_app(summary)
        elif ns.action == 'package-tests' and (evidence / 'events.jsonl').exists():
            summary = package_summary(evidence / 'events.jsonl')
            save(evidence / 'test-summary.json', summary)
            result['tests'] = summary
            result['success'] = (result['success'] and summary['total'] > 0 and summary['complete']
                                 and not (summary['failed'] or summary['skipped']))
            if not ns.filter:
                result['success'] = result['success'] and summary['targets'] == ['KoechoCoreTests', 'KoechoPlatformTests']
        elif ns.action.endswith('tests'):
            result['success'] = False
            result['result_error'] = 'No test result artifact'
    except Exception as error:
        result['success'] = False
        result['result_error'] = str(error)
    save(evidence / 'result.json', result)
    print(json.dumps(result, indent=2))
    raise SystemExit(0 if result['success'] else 1)


if __name__ == '__main__':
    main()
