"""Synthetic collector regressions; these never certify BC or a candidate."""
import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from collect_candidate_evidence import collect, EvidenceError, expected_rows, PROVIDERS, APP_ID, FOUNDATION_ID


class CollectorTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.config = Path(__file__).resolve().parents[2] / 'app/AppSourceCop.json'
        markets = json.loads(self.config.read_text())['supportedCountries']
        self.candidate = dict(appId=APP_ID, publisher='Origo', friends=[], version='28.0.0.4',
                              sha256='1'*64, contentSha256='2'*64, sourceCommit='a'*40, buildUrl='fixture://not-a-run',
                              foundation=dict(appId=FOUNDATION_ID, version='28.0.3.530', sha256='3'*64, friends=[]))
        self.packet = dict(schema=1, sourceCommit='a'*40, markets=markets, providers=list(PROVIDERS),
                           candidate=copy.deepcopy(self.candidate), receipts=[])
        self.raw = self.write('raw.txt', b'controlled fixture, not runtime')

    def write(self, name, data):
        (self.root/name).write_bytes(data)
        return dict(path=name, sha256=hashlib.sha256(data).hexdigest())

    def add(self, row, **overrides):
        receipt = dict(row=row, sourceCommit='a'*40, owner='fixture', observedAt='2026-10-07T00:00:00Z',
                       candidateSha256='1'*64, foundation=self.candidate['foundation'], evidenceKind='fixture',
                       outcome='passed', rawOutputs=[self.raw])
        if row.endswith('.runtime'):
            receipt['counts'] = dict(discovered=1, selected=1, executed=1, passed=1, failed=0, skipped=0, aborted=0, notRun=0)
        receipt.update(overrides)
        ref = self.write(str(len(self.packet['receipts']))+'.json', json.dumps(receipt).encode())
        self.packet['receipts'].append(ref)
        return receipt

    def run_packet(self):
        path = self.root/'packet.json'
        path.write_text(json.dumps(self.packet))
        return collect(path, self.config)

    def test_missing_candidate_is_blocked(self):
        self.packet['candidate'] = None
        result = self.run_packet()
        self.assertFalse(result['inventoryComplete'])
        self.assertIn('candidate:', result['gaps'][0])

    def test_fixture_matrix_never_certifies(self):
        for row in expected_rows(self.packet['markets']):
            self.add(row)
        result = self.run_packet()
        self.assertFalse(result['inventoryComplete'])
        self.assertFalse(result['candidateCertified'])
        self.assertEqual(len(result['gaps']), 29)

    def test_claimed_actual_inventory_still_requires_review(self):
        for row in expected_rows(self.packet['markets']):
            self.add(row, evidenceKind='actual')
        result = self.run_packet()
        self.assertTrue(result['inventoryComplete'])  # schema consistency, not proof of truth
        self.assertFalse(result['runnerCertified'])
        self.assertFalse(result['releaseReady'])

    def test_old_foundation_cannot_be_renamed_as_current(self):
        self.packet['candidate']['foundation']['version'] = '28.0.3.523'
        with self.assertRaises(EvidenceError): self.run_packet()

    def test_stale_source_and_candidate_refused(self):
        for changes in [dict(sourceCommit='b'*40), dict(candidateSha256='4'*64)]:
            with self.subTest(changes=changes):
                self.packet['receipts'] = []
                self.add('Default.postcompile', **changes)
                with self.assertRaises(EvidenceError): self.run_packet()

    def test_tampered_raw_bytes_refused(self):
        self.add('Default.postSign')
        (self.root/'raw.txt').write_bytes(b'changed')
        with self.assertRaises(EvidenceError): self.run_packet()

    def test_duplicate_rows_refused(self):
        self.add('cleanup'); self.add('cleanup')
        with self.assertRaises(EvidenceError): self.run_packet()

    def test_skipped_runtime_is_incomplete(self):
        self.add('Test.runtime', evidenceKind='actual', counts=dict(discovered=2, selected=2, executed=1,
                 passed=1, failed=0, skipped=1, aborted=0, notRun=0))
        self.assertIn('Test.runtime: incomplete or unsuccessful runtime', self.run_packet()['gaps'])

    def test_inconsistent_and_boolean_counts_refused(self):
        for count in (2, True):
            self.packet['receipts'] = []
            self.add('Test.runtime', counts=dict(discovered=1, selected=1, executed=1,
                     passed=count, failed=0, skipped=0, aborted=0, notRun=0))
            with self.assertRaises(EvidenceError): self.run_packet()

    def test_market_or_provider_omission_refused(self):
        self.packet['markets'].pop()
        with self.assertRaises(EvidenceError): self.run_packet()

    def test_path_escape_refused(self):
        self.add('cleanup')
        self.packet['receipts'][0]['path'] = '../outside.json'
        with self.assertRaises(EvidenceError): self.run_packet()

    def test_default_friends_refused(self):
        self.packet['candidate']['friends'] = [dict(id='test')]
        with self.assertRaises(EvidenceError): self.run_packet()

    def test_symlink_escape_refused(self):
        with tempfile.TemporaryDirectory() as outside:
            target = Path(outside)/'receipt.json'
            target.write_text('{}')
            (self.root/'link.json').symlink_to(target)
            self.packet['receipts'] = [dict(path='link.json', sha256=hashlib.sha256(b'{}').hexdigest())]
            with self.assertRaises(EvidenceError): self.run_packet()

    def test_oversized_receipt_refused(self):
        from collect_candidate_evidence import MAX_BYTES
        self.packet['receipts'] = [self.write('large.json', b' ' * (MAX_BYTES + 1))]
        with self.assertRaises(EvidenceError): self.run_packet()

    def test_duplicate_json_keys_refused(self):
        self.packet['receipts'] = [self.write('duplicate.json', b'{"row":"cleanup","row":"cleanup"}')]
        with self.assertRaises(EvidenceError): self.run_packet()


if __name__ == '__main__':
    unittest.main()
