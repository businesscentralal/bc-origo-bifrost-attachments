"""Artifact preparation regressions; strict inventory remains fail-closed."""
import shutil
import io
import zipfile
import struct
from xml.etree import ElementTree as ET
import tempfile
from pathlib import Path
import unittest
from unittest.mock import patch
from test_symbol_policy import fixture, G
from test_ready_to_run import wrap


def change_manifest(path, edit):
    data = path.read_bytes()
    with zipfile.ZipFile(io.BytesIO(data[40:])) as archive:
        entries = {name: archive.read(name) for name in archive.namelist()}
    root = ET.fromstring(entries['NavxManifest.xml'])
    edit(root)
    entries['NavxManifest.xml'] = ET.tostring(root)
    payload = io.BytesIO()
    with zipfile.ZipFile(payload, 'w', zipfile.ZIP_DEFLATED) as archive:
        for name, content in entries.items():
            archive.writestr(name, content)
    header = bytearray(data[:40])
    struct.pack_into('<Q', header, 28, len(payload.getvalue()))
    path.write_bytes(header + payload.getvalue())


class CatalogAliases(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.catalog, self.cache = self.root / "catalog", self.root / "cache"
        self.catalog.mkdir()
        self.cache.mkdir()
        self.versioned = self.catalog / 'Microsoft_Test Library_29.0.1.0.app'
        self.alias = self.catalog / 'Microsoft_Test Library.app'
        self.identity = fixture(self.versioned)
        shutil.copyfile(self.versioned, self.alias)

    def test_identical_alias_removed_and_receipted_before_strict_inventory(self):
        with self.assertRaisesRegex(G.GateError, 'Duplicate symbol identity'):
            G.symbol_inventory(self.catalog, 'compilerCatalog')
        before = self.versioned.read_bytes()
        receipt = G.normalize_compiler_catalog(self.catalog)
        self.assertEqual(1, len(receipt['aliasesRemoved']))
        item = receipt['aliasesRemoved'][0]
        self.assertEqual(self.versioned.name, item['retained'])
        self.assertEqual(self.alias.name, item['removed'])
        self.assertEqual(self.identity, item['identity'])
        self.assertEqual(G.digest(before), item['retainedSha256'])
        self.assertEqual(before, self.versioned.read_bytes())
        self.assertFalse(self.alias.exists())
        self.assertEqual(1, len(G.symbol_inventory(self.catalog, 'compilerCatalog')))
        self.assertEqual([], G.normalize_compiler_catalog(self.catalog)['aliasesRemoved'])

    def test_conflicting_symbols_fail_without_deleting_any_alias(self):
        fixture(self.alias, self.identity, content=b'conflicting symbols')
        with self.assertRaisesRegex(G.GateError, 'Conflicting duplicate'):
            G.normalize_compiler_catalog(self.catalog)
        self.assertTrue(self.alias.exists())
        self.assertTrue(self.versioned.exists())

    def test_unique_unversioned_and_distinct_versions_preserved(self):
        unique = self.catalog / 'Microsoft_System Application Test Library.app'
        fixture(unique)
        other = self.catalog / 'Microsoft_Test Library_30.0.1.0.app'
        fixture(other, dict(self.identity, version='30.0.1.0'))
        G.normalize_compiler_catalog(self.catalog)
        self.assertTrue(unique.exists())
        self.assertTrue(other.exists())
        self.assertEqual(3, len(G.symbol_inventory(self.catalog, 'compilerCatalog')))

    def test_non_microsoft_collision_remains_fatal(self):
        identity = dict(self.identity, publisher='Origo')
        fixture(self.versioned, identity)
        shutil.copyfile(self.versioned, self.alias)
        with self.assertRaisesRegex(G.GateError, 'non-Microsoft catalog collision'):
            G.normalize_compiler_catalog(self.catalog)
        self.assertTrue(self.alias.exists())

    def test_invalid_later_package_causes_no_partial_removal(self):
        (self.catalog / 'Z-invalid.app').write_bytes(b'invalid')
        with self.assertRaises(G.GateError):
            G.normalize_compiler_catalog(self.catalog)
        self.assertTrue(self.alias.exists())

    def test_changed_catalog_before_deletion_fails(self):
        original = G.file_hash
        def changed(path, deadline=None):
            # Measurement hashes twice; recheck has a third call per file.
            if changed.calls >= 4:
                return '0' * 64
            changed.calls += 1
            return original(path, deadline)
        changed.calls = 0
        with patch.object(G, 'file_hash', side_effect=changed):
            with self.assertRaisesRegex(G.GateError, 'changed before alias'):
                G.normalize_compiler_catalog(self.catalog)
        self.assertTrue(self.alias.exists())

    def test_catalog_preparation_does_not_relax_app_cache(self):
        shutil.copyfile(self.versioned, self.cache / self.versioned.name)
        shutil.copyfile(self.alias, self.cache / self.alias.name)
        G.normalize_compiler_catalog(self.catalog)
        with self.assertRaisesRegex(G.GateError, 'Duplicate symbol identity'):
            G.symbol_inventory(self.cache)

    def test_ready_to_run_alias_with_same_symbols_and_metadata(self):
        plain = self.alias.read_bytes()
        wrap(self.versioned, plain, self.identity)
        self.assertNotEqual(plain, self.versioned.read_bytes())
        receipt = G.normalize_compiler_catalog(self.catalog)
        item = receipt['aliasesRemoved'][0]
        self.assertNotEqual(item['retainedSha256'], item['removedSha256'])
        self.assertEqual(G.digest(b'symbols'), item['symbolReferenceSha256'])
        self.assertTrue(item['compilerMetadataEqual'])
        self.assertEqual(1, len(G.symbol_inventory(self.catalog, 'compilerCatalog')))

    def test_matching_symbols_with_changed_dependency_metadata_fail(self):
        dep = dict(self.identity, id='11111111-1111-1111-1111-111111111111', name='Different dependency')
        fixture(self.alias, self.identity, dependencies=[dep])
        with self.assertRaisesRegex(G.GateError, 'Conflicting duplicate'):
            G.normalize_compiler_catalog(self.catalog)
        self.assertTrue(self.alias.exists())

    def test_all_groups_validated_before_any_deletion(self):
        a, b = self.catalog / 'Z-one.app', self.catalog / 'Z-two.app'
        other = fixture(a)
        fixture(b, other, content=b'conflict')
        with self.assertRaisesRegex(G.GateError, 'Conflicting duplicate'):
            G.normalize_compiler_catalog(self.catalog)
        self.assertEqual(4, len(list(self.catalog.glob('*.app'))))

    def test_full_catalog_limits_apply_before_normalization(self):
        with patch.dict(G.SYMBOL_POLICIES, {'compilerCatalog': {'packages': 1, 'bytes': 1024 * 1024}}):
            with self.assertRaisesRegex(G.GateError, 'exceeds 1 packages'):
                G.normalize_compiler_catalog(self.catalog)
        self.assertTrue(self.alias.exists())

    def test_runtime_target_and_unknown_features_remain_conflicts(self):
        namespace = '{http://schemas.microsoft.com/navx/2015/manifest}'
        for attribute in ('Runtime', 'Target'):
            with self.subTest(attribute=attribute):
                fixture(self.alias, self.identity)
                change_manifest(self.alias, lambda root: root.find(namespace + 'App').set(attribute, 'different'))
                with self.assertRaisesRegex(G.GateError, 'Conflicting duplicate'):
                    G.normalize_compiler_catalog(self.catalog)
                self.assertTrue(self.alias.exists())
        fixture(self.alias, self.identity)
        def add_unknown_feature(root):
            ET.SubElement(ET.SubElement(root, namespace + 'Features'), namespace + 'Feature').text = 'UNKNOWN'
        change_manifest(self.alias, add_unknown_feature)
        with self.assertRaisesRegex(G.GateError, 'Conflicting duplicate'):
            G.normalize_compiler_catalog(self.catalog)

    def test_translation_packaging_and_build_timestamp_are_not_compiler_conflicts(self):
        namespace = '{http://schemas.microsoft.com/navx/2015/manifest}'
        def metadata(root, flag, timestamp):
            ET.SubElement(ET.SubElement(root, namespace + 'Features'), namespace + 'Feature').text = flag
            ET.SubElement(root, namespace + 'Build', {'Timestamp': timestamp})
        change_manifest(self.alias, lambda root: metadata(root, 'LCGTRANSLATIONFILE', 'time-one'))
        change_manifest(self.versioned, lambda root: metadata(root, 'TRANSLATIONFILE', 'time-two'))
        receipt = G.normalize_compiler_catalog(self.catalog)
        self.assertEqual(1, len(receipt['aliasesRemoved']))
        self.assertNotEqual(receipt['aliasesRemoved'][0]['retainedSha256'],
                            receipt['aliasesRemoved'][0]['removedSha256'])


if __name__ == '__main__':
    unittest.main(verbosity=2)
