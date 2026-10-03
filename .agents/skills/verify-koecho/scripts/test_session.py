"""Regression tests for verification process ownership and cleanup."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import sys
import tempfile
import time
import unittest
from unittest import mock

SPEC = importlib.util.spec_from_file_location('session', Path(__file__).with_name('session.py'))
session = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(session)


class SessionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.scratch = self.root / 'tmp/verify-koecho'
        self.scratch.mkdir(parents=True)
        self.run = 'test-run'
        self.evidence = self.root / 'tmp/verification/verify-koecho' / self.run
        self.evidence.mkdir(parents=True)
        self.state_file = self.evidence / 'session.json'
        self.process = {'started': time.strftime('%a %b %d %H:%M:%S %Y'), 'command': str(session.EXE)}
        self.owned = {'12345': self.process}
        self.patch_root = mock.patch.object(session, 'ROOT', self.root)
        self.patch_scratch = mock.patch.object(session, 'SCRATCH', self.scratch)
        self.patch_root.start()
        self.patch_scratch.start()
        self.addCleanup(self.patch_root.stop)
        self.addCleanup(self.patch_scratch.stop)

    def state(self, **values):
        data = {'owned': {}, 'prepared_at': time.time() - 1}
        data.update(values)
        self.state_file.write_text(json.dumps(data))
        return data

    def run_action(self, action, *options):
        with mock.patch.object(sys, 'argv', ['session.py', action, '--run', self.run, *options]):
            with contextlib.redirect_stdout(io.StringIO()):
                session.main()

    def saved(self):
        return json.loads(self.state_file.read_text())

    def test_signature_failure_keeps_owned_process_for_cleanup(self):
        self.state()
        running = dict(self.owned)

        def terminate(pid, sig):
            self.assertEqual(pid, 12345)
            self.assertEqual(sig, session.signal.SIGTERM)
            running.clear()

        with mock.patch.object(session, 'processes', side_effect=lambda: dict(running)), \
             mock.patch.object(session, 'identity', side_effect=RuntimeError('bad signature')), \
             mock.patch.object(session.os, 'kill', side_effect=terminate) as kill:
            with self.assertRaisesRegex(RuntimeError, 'bad signature'):
                self.run_action('adopt')
            self.assertEqual(self.saved()['owned'], self.owned)
            self.assertNotIn('identity', self.saved())
            with self.assertRaisesRegex(AssertionError, 'Identification incomplete'):
                self.run_action('doctor')
            self.run_action('cleanup')
            kill.assert_called_once()
        self.assertIn('cleanup', self.saved())

    def test_unowned_residue_rejects_cleanup_and_retains_scratch(self):
        self.state(cleanup='previous success', build_retained=False)
        with mock.patch.object(session, 'processes', return_value=self.owned), \
             mock.patch.object(session.os, 'kill') as kill:
            with self.assertRaisesRegex(AssertionError, 'Verification process remains'):
                self.run_action('cleanup', '--remove-build')
            kill.assert_not_called()
        saved = self.saved()
        self.assertNotIn('cleanup', saved)
        self.assertNotIn('build_retained', saved)
        self.assertIn('Verification process remains', saved['cleanup_error'])
        self.assertTrue(self.scratch.exists())

    def test_owned_process_stops_and_build_is_removed(self):
        self.state(owned=self.owned)
        running = dict(self.owned)

        def terminate(pid, sig):
            running.clear()

        with mock.patch.object(session, 'processes', side_effect=lambda: dict(running)), \
             mock.patch.object(session.os, 'kill', side_effect=terminate) as kill:
            self.run_action('cleanup', '--remove-build')
            kill.assert_called_once_with(12345, session.signal.SIGTERM)
        saved = self.saved()
        self.assertIn('cleanup', saved)
        self.assertFalse(saved['build_retained'])
        self.assertNotIn('cleanup_error', saved)
        self.assertFalse(self.scratch.exists())

    def test_process_query_failure_clears_prior_success(self):
        self.state(owned=self.owned, cleanup='previous success', build_retained=False)
        with mock.patch.object(session, 'processes', side_effect=RuntimeError('ps failed')), \
             mock.patch.object(session.os, 'kill') as kill:
            with self.assertRaisesRegex(RuntimeError, 'ps failed'):
                self.run_action('cleanup', '--remove-build')
            kill.assert_not_called()
        saved = self.saved()
        self.assertNotIn('cleanup', saved)
        self.assertNotIn('build_retained', saved)
        self.assertEqual(saved['cleanup_error'], 'ps failed')
        self.assertTrue(self.scratch.exists())

    def test_owned_process_timeout_records_failure(self):
        self.state(owned=self.owned, cleanup='previous success')
        with mock.patch.object(session, 'processes', return_value=self.owned), \
             mock.patch.object(session.os, 'kill') as kill, \
             mock.patch.object(session.time, 'monotonic', side_effect=[0, 6]):
            with self.assertRaisesRegex(AssertionError, 'Verification process remains'):
                self.run_action('cleanup')
            kill.assert_called_once_with(12345, session.signal.SIGTERM)
        saved = self.saved()
        self.assertNotIn('cleanup', saved)
        self.assertIn('Verification process remains', saved['cleanup_error'])
        self.assertTrue(self.scratch.exists())

    def test_plan_does_not_override_history_setting(self):
        with mock.patch.object(sys, 'argv', ['session.py', 'plan']):
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                session.main()
        self.assertEqual(json.loads(output.getvalue())['launchArgs'], ['-voiceInputMode', 'off'])


if __name__ == '__main__':
    unittest.main()
