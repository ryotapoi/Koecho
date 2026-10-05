"""Regression checks for false passes, truncation and owned timeout cleanup."""
import json
from pathlib import Path
import sys
import tempfile
import unittest

import verify


class VerificationTests(unittest.TestCase):
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
