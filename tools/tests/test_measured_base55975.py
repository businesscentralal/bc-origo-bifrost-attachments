"""Genuine Base55975 capacity checks; no runner/runtime/signature certification."""
import copy
import os
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

from test_symbol_policy import G, fixture


OUTER_HASH = '4e4aca03643b998452dc3c6e525ce9a611a804a7bd581bbe6734e33b22891c67'
INNER_HASH = 'ab800f38121e7eda19d1fa65bee3915a8b31010f2d9a87800f4aeb023dba9d48'
IDENTITY = dict(id='437dbf0e-84ff-417a-965d-ed2bb9650972', publisher='Microsoft',
                name='Base Application', version='29.0.54011.55975')


class MeasuredBase55975(unittest.TestCase):
    def setUp(self):
        self.outer = Path(os.environ['APPSOURCE_GATE_READYTORUN_BASE55975'])
        self.inner = Path(os.environ['APPSOURCE_GATE_EMBEDDED_BASE55975'])
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def layers(self):
        return [(OUTER_HASH, self.outer, True), (INNER_HASH, self.inner, False)]

    def test_genuine_two_layer_positive_and_exact_measurements(self):
        info = G.package_info(self.outer, allow_ready_to_run=True)
        inner = G.package_info(self.inner)
        self.assertEqual(IDENTITY, info['identity'])
        self.assertEqual(OUTER_HASH, info['sha256'])
        self.assertEqual(OUTER_HASH, info['resourceProfile'])
        self.assertEqual(INNER_HASH, inner['sha256'])
        self.assertEqual(INNER_HASH, inner['resourceProfile'])
        self.assertEqual(INNER_HASH, info['readyToRun']['embeddedSha256'])
        self.assertEqual(10, info['entryCount'])
        self.assertEqual(8665, inner['entryCount'])
        self.assertEqual(288402113, info['readyToRun']['outerExpandedBytes'])
        self.assertEqual(379592378, inner['expandedBytes'])
        self.assertEqual(667994491, info['expandedBytes'])
        self.assertFalse(info['readyToRun']['signatureTrustVerified'])

    def test_baseline_and_outer_only_still_refuse(self):
        profiles = {k: v for k, v in G.MEASURED_PACKAGE_PROFILES.items()
                    if k not in (OUTER_HASH, INNER_HASH)}
        with patch.dict(G.MEASURED_PACKAGE_PROFILES, profiles, clear=True):
            with self.assertRaisesRegex(G.GateError, 'expanded-byte'):
                G.package_info(self.outer, allow_ready_to_run=True)
            with self.assertRaisesRegex(G.GateError, 'entry bound'):
                G.package_info(self.inner)
        profiles[OUTER_HASH] = G.MEASURED_PACKAGE_PROFILES[OUTER_HASH]
        with patch.dict(G.MEASURED_PACKAGE_PROFILES, profiles, clear=True):
            with self.assertRaisesRegex(G.GateError, 'entry bound'):
                G.package_info(self.outer, allow_ready_to_run=True)

    def test_each_identity_field_requires_exact_match_at_both_layers(self):
        for hash_value, path, ready in self.layers():
            for key, value in [('id', '00000000-0000-0000-0000-000000000000'),
                               ('publisher', 'Other'), ('name', 'Other'),
                               ('version', '29.0.54011.55935')]:
                profile = copy.deepcopy(G.MEASURED_PACKAGE_PROFILES[hash_value])
                profile['identity'][key] = value
                with self.subTest(layer=hash_value, field=key), patch.dict(
                        G.MEASURED_PACKAGE_PROFILES, {hash_value: profile}):
                    with self.assertRaisesRegex(G.GateError, 'profile identity mismatch'):
                        G.package_info(path, allow_ready_to_run=ready)

    def test_changed_hashes_cannot_inherit_profiles(self):
        for hash_value, path, ready in self.layers():
            changed = self.root / (hash_value + '.app')
            shutil.copyfile(path, changed)
            with changed.open('ab') as stream:
                stream.write(b'changed-signature-tail')
            with self.subTest(layer=hash_value), self.assertRaisesRegex(
                    G.GateError, 'expanded-byte' if ready else 'entry bound'):
                G.package_info(changed, allow_ready_to_run=ready)

    def test_independent_entry_and_expansion_bounds(self):
        for hash_value, path, ready in self.layers():
            entries, expanded = (10, 288402113) if ready else (8665, 379592378)
            for key, value, message in [('maxEntries', entries - 1, 'entry bound'),
                                         ('maxExpandedBytes', expanded - 1, 'expanded-byte')]:
                profile = copy.deepcopy(G.MEASURED_PACKAGE_PROFILES[hash_value])
                profile[key] = value
                with self.subTest(layer=hash_value, bound=key), patch.dict(
                        G.MEASURED_PACKAGE_PROFILES, {hash_value: profile}):
                    with self.assertRaisesRegex(G.GateError, message):
                        G.package_info(path, allow_ready_to_run=ready)

    def test_disk_manifest_and_deadline_bounds_remain(self):
        for hash_value, path, ready in self.layers():
            for constant, limit, message in [('PACKAGE_BYTES', path.stat().st_size - 1, '128 MiB'),
                                             ('MANIFEST_BYTES', 1, '16 MiB'),
                                             ('INVENTORY_SECONDS', -1, 'elapsed budget')]:
                with self.subTest(layer=hash_value, bound=constant), patch.object(G, constant, limit):
                    with self.assertRaisesRegex(G.GateError, message):
                        G.package_info(path, allow_ready_to_run=ready)

    def test_shipping_wrapper_still_refused(self):
        with self.assertRaisesRegex(G.GateError, 'Missing/duplicate NAVX manifest'):
            G.package_info(self.outer)

    def test_unknown_version_uses_generic_policy(self):
        path = self.root / 'unknown.app'
        fixture(path, dict(IDENTITY, version='29.0.54011.55976'))
        self.assertEqual('generic', G.package_info(path)['resourceProfile'])

    def test_crc_and_truncation_refusals_reach_payload_checks(self):
        changed = self.root / 'bad-crc.app'
        data = bytearray(self.inner.read_bytes())
        position = data.index(b'PK\x01\x02')
        data[position + 16] ^= 1  # Central-directory CRC; retain lengths and entries.
        changed.write_bytes(data)
        # Test-only hash registration gets past capacity to exercise CRC handling.
        profile = copy.deepcopy(G.MEASURED_PACKAGE_PROFILES[INNER_HASH])
        with patch.dict(G.MEASURED_PACKAGE_PROFILES, {G.file_hash(changed): profile}):
            with self.assertRaisesRegex(G.GateError, 'Invalid compiled NAVX payload'):
                G.package_info(changed)
        changed.write_bytes(self.inner.read_bytes()[:100])
        with self.assertRaisesRegex(G.GateError, 'payload length/header'):
            G.package_info(changed)

    def test_mutation_during_genuine_measurement_refused(self):
        original = G.file_hash
        calls = []
        def changed(path, deadline=None):
            calls.append(str(path))
            return original(path, deadline) if len(calls) == 1 else '0' * 64
        with patch.object(G, 'file_hash', side_effect=changed):
            with self.assertRaisesRegex(G.GateError, 'changed during measurement'):
                G.package_info(self.inner)

    def test_catalog_and_cache_aggregate_limits_remain(self):
        catalog = self.root / 'catalog'
        catalog.mkdir()
        shutil.copyfile(self.outer, catalog / 'Base.app')
        # A measured package's work includes both layers, even in an app cache.
        with self.assertRaisesRegex(G.GateError, 'aggregate expanded'):
            G.symbol_inventory(catalog, 'appCache')
        with patch.dict(G.SYMBOL_POLICIES, {'compilerCatalog': dict(
                packages=256, bytes=1024 * 1024 * 1024, expandedBytes=667994490)}):
            with self.assertRaisesRegex(G.GateError, 'aggregate expanded'):
                G.symbol_inventory(catalog, 'compilerCatalog')


if __name__ == '__main__':
    unittest.main(verbosity=2)
