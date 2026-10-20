"""Controlled receipt regressions; never sandbox, provider or certification proof."""
import base64
import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).parents[1]))
import validate_submission as V


class SmokeReceipt(unittest.TestCase):
    def setUp(self):
        self.package = {'sha256': 'b' * 64, 'sourceCommit': 'a' * 40,
                        'identity': {'id': '672df32a-a0c5-4a22-b591-0efa38023e95',
                                     'version': '28.0.0.113'}, 'friends': []}
        url = 'https://example.invalid/controlled-fixture'
        self.receipt = {
            'schema': 1, 'sourceCommit': 'a' * 40,
            'candidate': {'sha256': 'b' * 64, 'version': '28.0.0.113'},
            'environment': {'sandbox': True, 'validatorOwned': True, 'id': 'fixture',
                            'owner': 'fixture', 'company': 'fixture', 'bcVersion': '28.5',
                            'country': 'w1', 'lcid': 1033},
            'qa': {'outcome': 'passed', 'sourceCommit': 'a' * 40,
                   'candidateSha256': 'b' * 64, 'evidenceUrl': url,
                   'foundation': {'version': '28.0.3.530', 'sha256': 'c' * 64}},
            'foundation': {'version': '28.0.3.530', 'sha256': 'c' * 64},
            'signature': {'status': 'Valid', 'realCertificate': True,
                          'candidateSha256': 'b' * 64, 'tamperRejected': True, 'evidenceUrl': url},
            'steps': [{'id': s, 'outcome': 'passed', 'evidenceUrl': url} for s in V.STEPS],
            'createsOwnData': True, 'nonSuperIdentity': True,
            'readbackContentBase64': base64.b64encode(V.SAMPLE).decode(),
            'negative': {'status': 'Error', 'code': 'fixture', 'parameter': 'storageCode',
                         'nextStep': 'fixture', 'stateUnchanged': True},
            'cleanup': {'created': ['own-file', 'own-connection'], 'removed': ['own-file', 'own-connection'],
                        'verifiedAbsent': ['own-file', 'own-connection'], 'evidenceUrl': url,
                        'containerRetained': True}}

    def gaps(self, receipt=None):
        with patch('appsource_gate.package_info', return_value=self.package):
            return V.smoke(receipt or self.receipt, 'unused-fixture.app')[0]

    def test_consistent_controlled_receipt(self):
        self.assertEqual([], self.gaps())

    def test_candidate_change_invalidates_old_qa(self):
        self.package['sha256'] = 'd' * 64
        self.assertIn('candidate/package/source/version/friends mismatch', self.gaps())
        self.receipt['candidate']['sha256'] = 'd' * 64
        self.assertIn('passing exact-candidate issue80 QA receipt missing', self.gaps())

    def test_wrong_source_version_or_friend_refused(self):
        for field, value in [('sourceCommit', 'd' * 40), ('friends', [{'id': 'fixture'}])]:
            with self.subTest(field=field):
                original = copy.deepcopy(self.package)
                self.package[field] = value
                self.assertTrue(self.gaps())
                self.package = original
        self.receipt['candidate']['version'] = '28.0.0.87'
        self.assertTrue(self.gaps())

    def test_unknown_production_or_foreign_environment_refused(self):
        for key in ('sandbox', 'validatorOwned', 'owner', 'company', 'bcVersion', 'country', 'lcid'):
            row = copy.deepcopy(self.receipt)
            row['environment'].pop(key)
            with self.subTest(key=key):
                self.assertTrue(self.gaps(row))

    def test_different_installed_dependency_invalidates_qa(self):
        self.receipt['foundation']['sha256'] = 'd' * 64
        self.assertIn('installed Foundation version/hash differs from QA or is missing', self.gaps())

    def test_self_signed_and_signing_success_do_not_prove_trust(self):
        for key in ('status', 'realCertificate', 'tamperRejected', 'candidateSha256', 'evidenceUrl'):
            row = copy.deepcopy(self.receipt)
            row['signature'].pop(key)
            with self.subTest(key=key):
                self.assertIn('real-certificate NAVX trust/tamper receipt missing', self.gaps(row))

    def test_missing_duplicate_and_unknown_steps_refused(self):
        for steps in (self.receipt['steps'][:-1], self.receipt['steps'] * 2,
                      self.receipt['steps'] + [{'id': 'invented', 'outcome': 'passed'}]):
            row = copy.deepcopy(self.receipt)
            row['steps'] = steps
            self.assertIn('smoke steps missing/duplicated/unknown', self.gaps(row))

    def test_unrun_failed_skipped_and_unreferenced_steps_refused(self):
        for outcome in ('failed', 'skipped', 'unrun', None):
            row = copy.deepcopy(self.receipt)
            row['steps'][0]['outcome'] = outcome
            self.assertIn('unproved smoke step', self.gaps(row))
        self.receipt['steps'][0].pop('evidenceUrl')
        self.assertIn('unproved smoke step', self.gaps())

    def test_bytes_and_negative_effect_are_checked(self):
        self.receipt['readbackContentBase64'] = base64.b64encode(b'changed').decode()
        self.assertIn('readback bytes differ from synthetic input', self.gaps())
        self.receipt['negative']['stateUnchanged'] = False
        self.assertIn('structured missing-storage error and unchanged-state proof missing', self.gaps())

    def test_partial_cleanup_duplicates_and_deleted_container_refused(self):
        for key, value in [('removed', ['own-file']), ('verifiedAbsent', []),
                           ('created', ['own-file', 'own-file']), ('containerRetained', False),
                           ('created', 'own-file')]:
            row = copy.deepcopy(self.receipt)
            row['cleanup'][key] = value
            self.assertIn('owned fixture cleanup/absence or container retention not proved', self.gaps(row))

    def test_shared_data_or_super_not_accepted(self):
        for key in ('createsOwnData', 'nonSuperIdentity'):
            self.receipt[key] = False
            self.assertIn('self-created fixtures/restricted identity missing', self.gaps())

    def test_no_secrets_in_reference_urls(self):
        for url in ('http://example.invalid', 'https://u:p@example.invalid',
                    'https://example.invalid/?token=private', 'https:///missing'):
            self.assertFalse(V.reference(url))

    def test_duplicate_json_and_oversized_input_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / 'receipt.json'
            for data in ('{"schema":1,"schema":1}', ' ' * (V.MAX_BYTES + 1)):
                p.write_text(data)
                with self.assertRaises(ValueError):
                    V.load(p)


if __name__ == '__main__':
    unittest.main()
