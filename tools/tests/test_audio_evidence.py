import copy
import importlib.util
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


REPOSITORY = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    'audio_evidence_checker', REPOSITORY / 'tools/check_audio_evidence.py')
CHECKER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECKER)
SOURCE = 'project/audio_core_v1/tools/sim_rom.py'
OLD_SHA = '13b2180793d00c0ff240944230dbb4a052a074e82f808380d187f91092f6cacc'


class HistoricalHarnessTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.harness = self.root / SOURCE
        self.harness.parent.mkdir(parents=True)
        shutil.copyfile(REPOSITORY / SOURCE, self.harness)
        review = self.root / 'review.json'
        shutil.copyfile(REPOSITORY / 'evidence/harness_review_2026-09-29.json', review)
        self.context = patch.multiple(
            CHECKER, ROOT=self.root, HARNESS_REVIEW=review,
            REVIEWED_HARNESS_MATCHES=set())
        self.context.start()
        self.addCleanup(self.context.stop)
        self.record = {'source_sha256': {SOURCE: OLD_SHA},
                       'source_lf_sha256': {SOURCE: OLD_SHA}}

    def test_reviewed_wrapper_keeps_historical_fingerprints_when_stamping(self):
        original = copy.deepcopy(self.record)
        self.assertEqual(CHECKER.verify(self.record, self.root, True, False), 1)
        self.assertEqual(self.record, original)
        self.assertEqual(CHECKER.REVIEWED_HARNESS_MATCHES, {SOURCE})

    def test_further_wrapper_edit_is_rejected(self):
        with self.harness.open('ab') as output:
            output.write(b'\n# Unreviewed change\n')
        with self.assertRaisesRegex(RuntimeError, 'Changed evidence source'):
            CHECKER.verify(self.record, self.root, False, False)

    def test_unreviewed_historical_digest_is_rejected(self):
        self.record['source_sha256'][SOURCE] = '0' * 64
        self.record['source_lf_sha256'][SOURCE] = '0' * 64
        with self.assertRaisesRegex(RuntimeError, 'Changed evidence source'):
            CHECKER.verify(self.record, self.root, False, False)

    def test_rtl_change_has_no_harness_exception(self):
        relative = 'project/example/src/voice.v'
        rtl = self.root / relative
        rtl.parent.mkdir(parents=True)
        rtl.write_text('module voice; endmodule\n', encoding='ascii')
        record = {'source_sha256': {relative: '0' * 64},
                  'source_lf_sha256': {relative: '0' * 64}}
        with self.assertRaisesRegex(RuntimeError, 'Changed evidence source'):
            CHECKER.verify(record, self.root, False, False)


if __name__ == '__main__':
    unittest.main()
