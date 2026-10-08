#!/usr/bin/env python3
"""Build, launch and observe the owned Koecho verification app."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys
import time

sys.dont_write_bytecode = True
import session
sys.path.insert(0, str(session.ROOT / 'scripts'))
import verify


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['build', 'launch', 'logs'])
    parser.add_argument('--run', required=True)
    parser.add_argument('--voice-input-on', action='store_true')
    parser.add_argument('--env', action='append', default=[])
    parser.add_argument('--arg', action='append', default=[])
    parser.add_argument('--timeout', type=float, default=600)
    parser.add_argument('--pattern', default='.')
    parser.add_argument('--limit', type=int, default=30)
    ns = parser.parse_args()
    assert Path(ns.run).name == ns.run and ns.run not in ('.', '..'), 'Use a single run directory name'
    assert ns.timeout > 0, 'Timeout must be positive'
    assert ns.action == 'launch' or not (ns.env or ns.arg or ns.voice_input_on), 'Launch options only apply to launch'
    evidence = session.ROOT / '.tmp/verification/verify-koecho' / ns.run
    state_file = evidence / 'session.json'
    state = json.loads(state_file.read_text())
    session.require_owner(ns.run)
    if ns.action == 'logs':
        assert state['owned'] == session.processes() and state['owned'], 'Owned process absent or replaced'
        pid = next(iter(state['owned']))
        command = ['/usr/bin/log', 'show', '--last', '5m', '--style', 'ndjson', '--info', '--debug',
                   '--predicate', f'processIdentifier == {pid} AND subsystem == "com.ryotapoi.koecho"']
        with (evidence / 'oslog.ndjson').open('w') as log:
            subprocess.run(command, stdout=log, stderr=subprocess.PIPE, check=True, timeout=30)
        matches = [line.rstrip() for line in (evidence / 'oslog.ndjson').open() if re.search(ns.pattern, line)]
        print(json.dumps({'total': len(matches), 'truncated': len(matches) > ns.limit,
                          'matches': matches[:ns.limit], 'full_log': str(evidence / 'oslog.ndjson')}))
        return
    assert not state['owned'] and not session.processes(), 'Verification app already running'
    assert not state.get('cleanup'), 'Run is closed'
    if ns.action == 'build':
        command = ['xcrun', 'xcodebuild', '-project', str(session.ROOT / 'Koecho.xcodeproj'),
                   '-scheme', 'Koecho', '-configuration', 'Debug', '-destination', 'platform=macOS',
                   '-derivedDataPath', str(session.SCRATCH / 'DerivedData'), *session.ARGS, 'build']
        result = verify.run_logged(command, evidence, ns.timeout, session.SCRATCH / 'DerivedData')
        result['app'] = str(session.APP)
        if result['success']:
            try:
                verify.save(evidence / 'identity.json', session.identity())
            except Exception as error:
                result['success'] = False
                result['identity_error'] = str(error)
        verify.save(evidence / 'build-result.json', result)
        print(json.dumps(result, indent=2))
        raise SystemExit(0 if result['success'] else 1)
    assert not state.get('build_only'), 'Build-only run cannot launch an app'
    result = json.loads((evidence / 'build-result.json').read_text())
    assert result['success'], 'Build failed'
    assert session.identity() == json.loads((evidence / 'identity.json').read_text()), 'Build artifact replaced'
    launch_args = ['-voiceInputMode', 'on' if ns.voice_input_on else 'off', *ns.arg]
    command = ['/usr/bin/open', '-n', '-a', str(session.APP), '--stdout', str(evidence / 'stdout.log'),
               '--stderr', str(evidence / 'stderr.log')]
    for value in ns.env:
        assert re.match(r'^[A-Za-z_][A-Za-z_0-9]*=', value), 'Use --env NAME=value'
        command.extend(['--env', value])
    command.extend(['--args', *launch_args])
    state['launch'] = {'arguments': launch_args, 'environment_keys': [e.split('=', 1)[0] for e in ns.env],
                       'requested_at': time.time()}
    verify.save(state_file, state)
    subprocess.run(command, check=True, timeout=15)
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        if session.processes():
            subprocess.run([sys.executable, str(Path(session.__file__)), 'adopt', '--run', ns.run], check=True)
            return
        time.sleep(.1)
    raise RuntimeError('Verification process did not appear; inspect before retrying')


if __name__ == '__main__':
    main()
