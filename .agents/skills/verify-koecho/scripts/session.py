#!/usr/bin/env python3
"""Own only the fixed Koecho verification process; never invoke xcodebuild."""
import argparse
import json
import os
from pathlib import Path
import plistlib
import signal
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[4]
SCRATCH = ROOT / 'tmp/verify-koecho'
APP = SCRATCH / 'DerivedData/Build/Products/Debug/Koecho.app'
EXE = APP / 'Contents/MacOS/Koecho'
BUNDLE = 'com.ryotapoi.Koecho.Verification'
IDENTITY = '85B7C4380400A535BE172DF27D367F6282068BE5'
ARGS = [f'PRODUCT_BUNDLE_IDENTIFIER={BUNDLE}', 'INFOPLIST_KEY_CFBundleName=Koecho Verification', 'INFOPLIST_KEY_CFBundleDisplayName=Koecho Verification',
        'CODE_SIGN_STYLE=Manual', 'DEVELOPMENT_TEAM=5AGP9L4RNN',
        f'CODE_SIGN_IDENTITY={IDENTITY}']

def call(*args):
    return subprocess.check_output(args, text=True, stderr=subprocess.STDOUT).strip()

def processes():
    rows = {}
    for row in call('/bin/ps', '-axo', 'pid=,lstart=,command=').splitlines():
        parts = row.split(None, 6)
        if len(parts) == 7 and (parts[6] == str(EXE) or parts[6].startswith(str(EXE) + ' ')):
            rows[parts[0]] = {'started': ' '.join(parts[1:6]), 'command': parts[6]}
    return rows

def identity():
    with (APP / 'Contents/Info.plist').open('rb') as f:
        info = plistlib.load(f)
    assert info['CFBundleIdentifier'] == BUNDLE, 'Unexpected bundle ID'
    assert info['CFBundleExecutable'] == EXE.name, 'Unexpected executable'
    assert info.get('CFBundleDisplayName') == 'Koecho Verification', 'Unexpected display name'
    call('/usr/bin/codesign', '--verify', '--strict', '-R',
         '=certificate leaf = H"' + IDENTITY + '"', str(APP))
    signature = call('/usr/bin/codesign', '-d', '-r-', '--verbose=4', str(APP))
    assert 'TeamIdentifier=5AGP9L4RNN' in signature, 'Unexpected signing team'
    assert 'Authority=Developer ID Application: Ryota Kurosaki (5AGP9L4RNN)' in signature, 'Unexpected signing authority'
    requirement = next(line for line in signature.splitlines() if line.startswith('designated =>'))
    return {'bundle_id': BUNDLE, 'app': str(APP), 'requirement': requirement, 'signature': signature}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['plan', 'prepare', 'adopt', 'doctor', 'cleanup'])
    parser.add_argument('--run', default='')
    parser.add_argument('--remove-build', action='store_true')
    parser.add_argument('--allow-shared-history', action='store_true')
    ns = parser.parse_args()
    if ns.action == 'plan':
        print(json.dumps({'defaults': {'projectPath': str(ROOT / 'Koecho.xcodeproj'),
              'scheme': 'Koecho', 'configuration': 'Debug', 'derivedDataPath': str(SCRATCH / 'DerivedData'),
              'preferXcodebuild': True}, 'extraArgs': ARGS, 'launchArgs': ['-voiceInputMode', 'off'],
              'app': str(APP)}, indent=2)); return
    assert ns.run and Path(ns.run).name == ns.run and ns.run not in ('.', '..'), 'Use a single run directory name'
    evidence = ROOT / 'tmp/verification/verify-koecho' / ns.run
    state_file = evidence / 'session.json'
    if ns.action == 'prepare':
        assert not processes(), 'Fixed verification app already running; do not adopt it'
        history = Path.home() / 'Library/Application Support/com.ryotapoi.koecho/history.json'
        assert not history.exists() or ns.allow_shared_history, (
            'Shared installed-app history exists. Use a dedicated macOS user or obtain explicit consent '
            'for startup purge before --allow-shared-history; disabling history does not skip purge.')
        evidence.mkdir(parents=True, exist_ok=False)
        state = {'before': {}, 'owned': {}, 'prepared_at': time.time()}
        state_file.write_text(json.dumps(state, indent=2))
        print(evidence); return
    state = json.loads(state_file.read_text())
    if ns.action == 'adopt':
        current = processes()
        assert not state['owned'], 'Run already has an owned process'
        assert len(current) == 1 and not state['before'], 'Expected one newly launched verification process'
        pid, process = next(iter(current.items()))
        launched = time.mktime(time.strptime(process['started'], '%a %b %d %H:%M:%S %Y'))
        assert launched >= int(state['prepared_at']), 'Process predates this run'
        state['owned'] = current
        state_file.write_text(json.dumps(state, indent=2))
        state['identity'] = identity()
        state_file.write_text(json.dumps(state, indent=2))
    elif ns.action == 'doctor':
        current = processes()
        assert 'identity' in state, 'Identification incomplete: adopt did not verify the app signature'
        ident = identity()
        assert current == state['owned'] and current, 'Owned process absent or replaced'
        assert ident['requirement'] == state['identity']['requirement'], 'Signing requirement changed'
        print(json.dumps({'identity': ident, 'processes': current,
              'readiness': 'process-only; UI and permissions must be observed separately'}, indent=2)); return
    elif ns.action == 'cleanup':
        state.pop('cleanup', None)
        state.pop('build_retained', None)
        try:
            current = processes()
            for pid, process in state['owned'].items():
                if current.get(pid) == process:
                    os.kill(int(pid), signal.SIGTERM)
            deadline = time.monotonic() + 5
            while any(pid in processes() for pid in state['owned']) and time.monotonic() < deadline:
                time.sleep(.1)
            remaining = processes()
            assert not remaining, f'Verification process remains at fixed path: {remaining}'
            if ns.remove_build and SCRATCH.exists():
                shutil.rmtree(SCRATCH)
        except Exception as error:
            state['cleanup_error'] = str(error)
            state_file.write_text(json.dumps(state, indent=2))
            raise
        state.pop('cleanup_error', None)
        state['cleanup'] = 'owned process stopped; evidence, preferences and TCC retained'
        state['build_retained'] = SCRATCH.exists()
        state_file.write_text(json.dumps(state, indent=2))
    print(json.dumps(state, indent=2))

if __name__ == '__main__':
    main()
