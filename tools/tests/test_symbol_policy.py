"""Bounded collector/resolver fixtures, not actual runner or compiler certification."""
import copy
import importlib.util
import io
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch
import uuid
import zipfile

SPEC = importlib.util.spec_from_file_location('gate', Path(__file__).parents[1] / 'appsource_gate.py')
G = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(G)


def fixture(path, identity=None, dependencies=(), propagate=False, content=b'symbols'):
    """Synthetic NAVX shape for resource/identity adversarial tests only."""
    identity = identity or dict(id=str(uuid.uuid4()), publisher='Microsoft', name='Collector fixture', version='29.0.1.0')
    from xml.etree import ElementTree as E
    n = '{http://schemas.microsoft.com/navx/2015/manifest}'
    root = E.Element(n + 'Package')
    E.SubElement(root, n + 'App', {k.title(): v for k, v in identity.items()} | {'PropagateDependencies': str(propagate).lower()})
    deps = E.SubElement(root, n + 'Dependencies')
    for d in dependencies:
        E.SubElement(deps, n + 'Dependency', {'Id': d['id'], 'Publisher': d['publisher'], 'Name': d['name'], 'MinVersion': d['version']})
    E.SubElement(root, n + 'InternalsVisibleTo')
    output = io.BytesIO()
    with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as z:
        z.writestr('NavxManifest.xml', E.tostring(root))
        z.writestr('SymbolReference.json', content)
    header = bytearray(40)
    header[:4] = header[36:40] = b'NAVX'
    struct.pack_into('<II', header, 4, 40, 2)
    struct.pack_into('<Q', header, 28, len(output.getvalue()))
    path.write_bytes(header + output.getvalue())
    return identity


class SymbolPolicy(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.catalog, self.cache = self.root / 'catalog', self.root / 'cache'
        self.catalog.mkdir(); self.cache.mkdir()

    def test_complete_186_catalog_with_small_cache_and_exact_resolved_additions(self):
        identities = []
        for index in range(186):
            identities.append(fixture(self.catalog / f'Microsoft-{index:03}.app'))
        catalog = G.symbol_inventory(self.catalog, 'compilerCatalog')
        self.assertEqual(186, len(catalog))
        with self.assertRaisesRegex(G.GateError, '128 packages'):
            G.symbol_inventory(self.catalog, 'appCache')
        resolution = G.resolve_helper_inputs({'dependencies': [identities[12]]}, [], catalog)
        self.assertEqual(['Microsoft-012.app'], [s['file'] for s in resolution['copies']])
        output_id = fixture(self.cache / 'Output.app', dict(id=str(uuid.uuid4()), publisher='Origo', name='Output', version='1.0.0.0'))
        import shutil
        shutil.copy2(self.catalog / 'Microsoft-012.app', self.cache / 'Microsoft-012.app')
        snapshot = {'symbolsFolder': str(self.cache.resolve()), 'compilerSymbolsFolder': str(self.catalog.resolve()),
                    'symbols': [], 'compilerSymbols': catalog, 'resolution': resolution}
        request = {'symbolsFolder': str(self.cache), 'compilerSymbolsFolder': str(self.catalog)}
        boundaries = G.reconcile_symbols(snapshot, request, G.package_info(self.cache / 'Output.app'))
        self.assertFalse(boundaries['consumedInputsCertified'])
        self.assertEqual(186, boundaries['measurements']['compilerCatalog']['packages'])
        self.assertEqual(2, boundaries['measurements']['appCache']['packages'])
        self.assertFalse(boundaries['measurements']['appCache']['runnerCapacityValidated'])
        missing_resolution = dict(snapshot)
        del missing_resolution['resolution']
        with self.assertRaisesRegex(G.GateError, 'Missing bounded dependency'):
            G.reconcile_symbols(missing_resolution, request, G.package_info(self.cache / 'Output.app'))
        fixture(self.cache / 'Injected.app')
        with self.assertRaisesRegex(G.GateError, 'Unattributed'):
            G.reconcile_symbols(snapshot, request, G.package_info(self.cache / 'Output.app'))

    def test_catalog_overflow_and_case_insensitive_duplicate_and_identity_duplicate(self):
        for index in range(257):
            (self.catalog / f'{index}.app').write_bytes(b'invalid')
        with self.assertRaisesRegex(G.GateError, '256 packages'):
            G.symbol_inventory(self.catalog, 'compilerCatalog')
        for p in self.catalog.iterdir(): p.unlink()
        identity = fixture(self.catalog / 'One.app')
        fixture(self.catalog / 'Two.app', identity)
        with self.assertRaisesRegex(G.GateError, 'Duplicate symbol identity'):
            G.symbol_inventory(self.catalog, 'compilerCatalog')
        (self.catalog / 'Two.app').unlink()
        fixture(self.catalog / 'one.APP')
        with self.assertRaisesRegex(G.GateError, 'filename collision'):
            G.symbol_inventory(self.catalog, 'compilerCatalog')

    def test_aggregate_disk_expansion_manifest_entry_and_time_bounds(self):
        fixture(self.catalog / 'One.app', content=b'A' * 10000)
        size = (self.catalog / 'One.app').stat().st_size
        with patch.dict(G.SYMBOL_POLICIES, {'compilerCatalog': {'packages': 256, 'bytes': size - 1}}):
            with self.assertRaisesRegex(G.GateError, 'aggregate-byte'):
                G.symbol_inventory(self.catalog, 'compilerCatalog')
        with patch.dict(G.SYMBOL_POLICIES, {'compilerCatalog': {'packages': 256, 'bytes': size + 1}}):
            with self.assertRaisesRegex(G.GateError, 'aggregate expanded'):
                G.symbol_inventory(self.catalog, 'compilerCatalog')
        for constant, value, error in [('PACKAGE_BYTES', size - 1, '128 MiB'), ('PACKAGE_BYTES', size + 1, 'expanded-byte'),
                                        ('MANIFEST_BYTES', 1, 'Manifest'), ('PACKAGE_ENTRIES', 1, 'entry bound')]:
            with patch.object(G, constant, value), self.assertRaisesRegex(G.GateError, error):
                G.package_info(self.catalog / 'One.app')
        with patch.object(G, 'INVENTORY_SECONDS', -1), self.assertRaisesRegex(G.GateError, 'elapsed budget'):
            G.symbol_inventory(self.catalog, 'compilerCatalog')

    def test_streams_bounded_reads_and_detects_mid_measurement_mutation(self):
        path = self.catalog / 'One.app'
        fixture(path, content=b'A' * (2 * G.CHUNK_BYTES + 10))
        with patch.object(Path, 'read_bytes', side_effect=AssertionError('unbounded whole-file read')):
            self.assertTrue(G.package_info(path)['sha256'])
        original = G.file_hash
        count = 0
        def mutate(p, deadline=None):
            nonlocal count
            count += 1
            if count == 2:
                with path.open('ab') as f: f.write(b'mutation')
            return original(p, deadline)
        with patch.object(G, 'file_hash', side_effect=mutate), self.assertRaisesRegex(G.GateError, 'changed during'):
            G.package_info(path)

    def test_header_truncated_duplicate_and_wrong_version_negatives(self):
        path = self.catalog / 'One.app'
        fixture(path)
        data = path.read_bytes()
        path.write_bytes(data[:-10])
        with self.assertRaises(G.GateError): G.package_info(path)
        fixture(path, dict(id=str(uuid.uuid4()), publisher='Microsoft', name='WrongVersion', version='bad'))
        with self.assertRaisesRegex(G.GateError, 'version'): G.package_info(path)

    def test_existing_highest_and_all_compatible_catalog_versions(self):
        dep = fixture(self.catalog / 'v1.app')
        fixture(self.catalog / 'v2.app', dep | {'version': '30.0.0.0'})
        catalog = G.symbol_inventory(self.catalog, 'compilerCatalog')
        r = G.resolve_helper_inputs({'dependencies': [dep]}, [], catalog)
        self.assertEqual({'v1.app', 'v2.app'}, {s['file'] for s in r['copies']})
        r = G.resolve_helper_inputs({'dependencies': [dep]}, catalog, catalog)
        self.assertEqual([], r['copies'])
        self.assertEqual('v2.app', r['trace'][0]['selected'][0]['file'])
        for d in (dep | {'publisher': 'Injected'}, dep | {'name': 'Wrong'}, dep | {'version': '31.0.0.0'}):
            with self.assertRaises(G.GateError): G.resolve_helper_inputs({'dependencies': [d]}, [], catalog)

    def test_implicit_application_system_and_propagated_transitive_roots(self):
        child = fixture(self.catalog / 'child.app')
        application = fixture(self.catalog / 'Application.app', dict(id='c1335042-3002-4257-bf8a-75c898ccb1b8', publisher='Microsoft', name='Application', version='29.0.0.0'), [child], True)
        system = fixture(self.catalog / 'System.app', dict(id='8874ed3a-0643-4247-9ced-7a7002f7135d', publisher='Microsoft', name='System', version='29.0.0.0'))
        catalog = G.symbol_inventory(self.catalog, 'compilerCatalog')
        existing = [i for i in catalog if i['identity'] == application]
        r = G.resolve_helper_inputs({'application': '28.0.0.0', 'platform': '28.0.0.0'}, existing, catalog)
        self.assertEqual({'child.app', 'System.app'}, {i['file'] for i in r['copies']})
        for missing in ('Application.app', 'System.app', 'child.app'):
            reduced = [i for i in catalog if i['file'] != missing]
            with self.subTest(missing=missing), self.assertRaises(G.GateError):
                G.resolve_helper_inputs({'application': '28.0.0.0', 'platform': '28.0.0.0'}, [], reduced)

    def test_resolved_cache_cannot_omit_preexisting_inputs_or_exceed_bound(self):
        for index in range(128): fixture(self.cache / f'existing-{index}.app')
        dep = fixture(self.catalog / 'New.app')
        with self.assertRaisesRegex(G.GateError, 'Resolved app cache package'):
            G.resolve_helper_inputs({'dependencies': [dep]}, G.symbol_inventory(self.cache), G.symbol_inventory(self.catalog, 'compilerCatalog'))


if __name__ == '__main__': unittest.main()
