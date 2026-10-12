"""Regression checks for false passes, truncation and owned timeout cleanup."""
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch
import subprocess
import uuid

import verify


class VerificationTests(unittest.TestCase):
    def test_detached_residue_cleanup_leaves_other_hosts_in_shared_cache_running(self):
        with tempfile.TemporaryDirectory() as directory:
            evidence = Path(directory)
            records = evidence / 'hosted-defaults'
            records.mkdir()
            launch = str(uuid.uuid4()).upper()
            process = {'group': 9, 'started': 'owned start', 'command': '/shared/Koecho'}
            (records / (launch + '.json')).write_text(json.dumps({
                'version': 1, 'launchID': launch,
                'suiteName': 'com.ryotapoi.Koecho.hosted-tests-' + launch,
                'pid': 12345, 'started': process['started'], 'command': process['command'],
                'runID': 'owned-run'}))
            running = {}
            child = Mock(pid=1000, returncode=0)

            def launch_command(*args, **kwargs):
                running.update({12345: process, 54321: dict(process)})
                return child

            def terminate(pid, sig):
                running.pop(pid)

            with patch.object(verify, 'processes', side_effect=lambda: dict(running)), \
                 patch.object(verify.subprocess, 'Popen', side_effect=launch_command), \
                 patch.object(verify.subprocess, 'check_output', return_value='/Xcode/Developer'), \
                 patch.object(verify.os, 'kill', side_effect=terminate) as kill:
                result = verify.run_logged(['fake-command'], evidence,
                                           hosted_records=records, run_id='owned-run')
            kill.assert_called_once_with(12345, verify.signal.SIGTERM)
            self.assertEqual(set(running), {54321})
            self.assertEqual(set(result['residue_detected']), {12345})
            self.assertFalse(result['remaining'])
            self.assertFalse(result['success'])

    def test_detached_host_ownership_uses_launch_identity_not_shared_build_path(self):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            launch = str(uuid.uuid4()).upper()
            path = directory / (launch + '.json')
            process = {'group': 9, 'started': 'owned start',
                       'command': '/shared/DerivedData/Koecho.app/Contents/MacOS/Koecho'}
            record = {'version': 1, 'launchID': launch,
                      'suiteName': 'com.ryotapoi.Koecho.hosted-tests-' + launch,
                      'pid': 12345, 'started': process['started'], 'command': process['command'],
                      'runID': 'owned-run'}
            path.write_text(json.dumps(record))
            current = {12345: process, 54321: dict(process)}
            self.assertEqual(verify.recorded_hosts(directory, 'owned-run', current), {12345: process})
            self.assertEqual(verify.recorded_hosts(directory, 'another-run', current), {})
            self.assertEqual(verify.recorded_hosts(directory, 'owned-run', {
                12345: {**process, 'started': 'reused PID'}}), {})
            path.write_text('{unfinished')
            self.assertEqual(verify.recorded_hosts(directory, 'owned-run', current), {})

    def test_owned_defaults_cleanup_checks_ownership_liveness_and_recovery(self):
        with tempfile.TemporaryDirectory() as directory:
            launch = str(uuid.uuid4()).upper()
            path = Path(directory) / (launch + '.json')
            record = {'version': 1, 'launchID': launch,
                      'suiteName': 'com.ryotapoi.Koecho.hosted-tests-' + launch,
                      'pid': 12345, 'started': 'start', 'command': '/run/scratch/Koecho',
                      'runID': 'owned-run', 'appCleanup': False}
            path.write_text(json.dumps(record))
            present = subprocess.CompletedProcess([], 0, stdout='sentinel = value', stderr='')
            absent = subprocess.CompletedProcess([], 1, stdout='', stderr='Domain does not exist')
            deleted = subprocess.CompletedProcess([], 0, stdout='', stderr='')
            with patch.object(verify, 'processes', return_value={}), patch.object(
                    verify.subprocess, 'run', side_effect=[present, deleted, absent, absent]) as execute:
                result = verify.cleanup_hosted_defaults([path], 'owned-run', Path('/run/scratch'))
                self.assertTrue(result['success'])
                self.assertTrue(result['domains'][0]['recovered_by_helper'])
                self.assertEqual(execute.call_args_list[1].args[0],
                                 ['/usr/bin/defaults', 'delete', record['suiteName']])
            with patch.object(verify, 'processes', return_value={}), patch.object(
                    verify.subprocess, 'run', side_effect=[absent, absent, absent]) as execute:
                self.assertTrue(verify.cleanup_hosted_defaults([path])['success'])
                self.assertTrue(all(call.args[0][1] == 'read' for call in execute.call_args_list))
            empty = subprocess.CompletedProcess([], 0, stdout='{\n}', stderr='')
            not_found = subprocess.CompletedProcess([], 1, stdout='',
                stderr=f"Error: Domain '{record['suiteName']}' not found.")
            with patch.object(verify, 'processes', return_value={}), patch.object(
                    verify.subprocess, 'run', side_effect=[empty, not_found, not_found]) as execute:
                self.assertTrue(verify.cleanup_hosted_defaults([path])['success'])
                self.assertTrue(all(call.args[0][1] == 'read' for call in execute.call_args_list))
            with patch.object(verify, 'processes', return_value={12345: {}}), patch.object(
                    verify.subprocess, 'run') as execute:
                self.assertFalse(verify.cleanup_hosted_defaults([path])['success'])
                execute.assert_not_called()
            for changes in ({'suiteName': 'normal-domain'}, {'runID': 'another-run'},
                            {'launchID': str(uuid.uuid4()).upper()}):
                path.write_text(json.dumps({**record, **changes}))
                with patch.object(verify.subprocess, 'run') as execute:
                    self.assertFalse(verify.cleanup_hosted_defaults([path], 'owned-run')['success'])
                    execute.assert_not_called()
            path.write_text(json.dumps(record))
            with patch.object(verify, 'processes', return_value={}), patch.object(
                    verify.subprocess, 'run', side_effect=[present,
                        subprocess.CompletedProcess([], 1, stdout='', stderr='write failed')]):
                self.assertFalse(verify.cleanup_hosted_defaults([path])['success'])
                self.assertEqual(json.loads(path.read_text()), record)
            self.assertFalse(verify.cleanup_hosted_defaults([])['success'])

    def test_app_zero_failures_skips_and_missing_result_do_not_pass(self):
        valid = {'passedTests': 2, 'failedTests': 0, 'skippedTests': 0, 'result': 'Passed'}
        self.assertTrue(verify.check_app(valid))
        for changes in ({'passedTests': 0}, {'failedTests': 1}, {'skippedTests': 1},
                        {'result': 'Failed'}, {'testFailures': [{'message': 'failure'}]}):
            self.assertFalse(verify.check_app({**valid, **changes}))
        self.assertFalse(verify.check_app({}))

    def test_event_failures_after_display_limit_are_retained(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'events.jsonl'
            rows = [{'kind': 'event', 'payload': {'kind': 'runStarted'}}]
            rows.extend({'kind': 'event', 'payload': {'kind': 'issueRecorded', 'issue': n}}
                        for n in range(150))
            rows.append({'kind': 'event', 'payload': {'kind': 'runEnded', 'messages': [
                {'symbol': 'fail', 'text': 'Test run with 151 tests failed.'}]}})
            path.write_text('\n'.join(json.dumps(r) for r in rows))
            summary = verify.package_summary(path)
            self.assertEqual(summary['total'], 151)
            self.assertEqual(len(summary['failures']), 151)
            self.assertTrue(summary['complete'])

    def test_timeout_and_nonzero_exit_are_not_success(self):
        with tempfile.TemporaryDirectory() as directory:
            evidence = Path(directory)
            timed = verify.run_logged([sys.executable, '-c', 'import time; time.sleep(60)'], evidence, .1)
            self.assertFalse(timed['success'])
            self.assertTrue(timed['timeout'])
            self.assertFalse(timed['remaining'])
            failed = verify.run_logged([sys.executable, '-c', 'raise SystemExit(7)'], evidence, 5)
            self.assertFalse(failed['success'])
            self.assertEqual(failed['exit_code'], 7)


if __name__ == '__main__':
    unittest.main()
