"""Rejection regressions for the source audit; these do not execute AL."""
import copy
import importlib.util
import json
import pathlib
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('api_matrix', ROOT / 'tools/Test-ApiSurfaceMatrix.py')
matrix = importlib.util.module_from_spec(spec)
spec.loader.exec_module(matrix)


class ApiSurfaceMatrixTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = pathlib.Path(self.temporary.name)
        shutil.copytree(ROOT / 'app/src', self.root / 'app/src')
        self.inventory = json.loads((ROOT / 'api-surface-objects.json').read_text())
        self.document = (ROOT / 'API-SURFACE.md').read_text()

    def errors(self):
        return matrix.validate(self.root, self.inventory, self.document)

    def assert_finding(self, finding):
        self.assertTrue(any(finding in error for error in self.errors()), self.errors())

    def test_current_inventory(self):
        self.assertEqual([], self.errors())

    def test_stale_renamed_path(self):
        obj = self.inventory['objects'][0]
        path = self.root / obj['file']
        path.rename(path.with_name('Renamed.Codeunit.al'))
        self.assert_finding('Inventory must contain every shipping file exactly once')
        self.assert_finding('Inventory path missing from current source: ' + obj['file'])

    def test_missing_source_cli_returns_findings_without_traceback(self):
        obj = self.inventory['objects'][0]
        (self.root / obj['file']).unlink()
        (self.root / 'api-surface-objects.json').write_text(json.dumps(self.inventory))
        (self.root / 'API-SURFACE.md').write_text(self.document)
        result = subprocess.run([sys.executable, str(ROOT / 'tools/Test-ApiSurfaceMatrix.py'), '--root', str(self.root)], capture_output=True, text=True)
        self.assertEqual(1, result.returncode)
        self.assertEqual('', result.stderr)
        self.assertIn('Inventory path missing from current source: ' + obj['file'], json.loads(result.stdout)['errors'])

    def test_missing_provider_interface(self):
        (self.root / 'app/src/Storage/StorageConnector.Interface.al').unlink()
        self.assert_finding('Provider interface source missing or unreadable')
        self.assert_finding('Provider members no longer all require the Storage Setup Record')

    def test_duplicate_inventory_entry(self):
        self.inventory['objects'].append(copy.deepcopy(self.inventory['objects'][0]))
        self.assert_finding('Inventory must contain every shipping file exactly once')

    def test_missing_inventory_entry(self):
        self.inventory['objects'].pop()
        self.assert_finding('Inventory must contain every shipping file exactly once')

    def test_changed_source_hash(self):
        obj = self.inventory['objects'][0]
        path = self.root / obj['file']
        path.write_text(path.read_text() + '\n// Unrecorded source change\n')
        self.assert_finding('Source hash mismatch: ' + obj['file'])

    def test_changed_identity(self):
        self.inventory['objects'][0]['namespace'] = 'Incorrect.Namespace'
        self.assert_finding('Source identity mismatch')

    def test_unrecognized_source_identity(self):
        obj = self.inventory['objects'][0]
        path = self.root / obj['file']
        path.write_text('namespace Origo.Bifrost.Attachments;\n')
        self.assert_finding('Unrecognized source identity')

    def test_changed_document_decision(self):
        self.document = self.document.replace('| KEEP Public: provider contract |', '| REMOVE Public |')
        self.assert_finding('Document matrix identity/decision mismatch')

    def test_provider_table_attribution(self):
        obj = next(obj for obj in self.inventory['objects'] if obj['name'] == 'Storage Setup ori' and obj['kind'] == 'table')
        obj['decision'] = 'KEEP Public: UI'
        self.assert_finding('Storage Setup table provider contract attribution missing')

    def test_public_table_members_cannot_be_attributed_to_page(self):
        self.document = self.document.replace('| table 10035636 [Storage Setup ori](app/src/Setup/StorageSetup.Table.al) | `', '| page 10035637 [Storage Setup ori](app/src/Setup/StorageSetup.Page.al) | `')
        self.assert_finding('Document public member kind/identity mismatch: app/src/Setup/StorageSetup.Table.al')

    def test_provider_signature_requires_setup_record(self):
        path = self.root / 'app/src/Storage/StorageConnector.Interface.al'
        path.write_text(path.read_text().replace('Record "Storage Setup ori"', 'Record "Other Table"', 1))
        self.assert_finding('Provider members no longer all require the Storage Setup Record')

    def test_lexical_matches_cannot_claim_kind_resolution(self):
        self.inventory['consumerSearch']['kindResolved'] = True
        self.assert_finding('Current lexical matches must not claim kind-resolved consumers')


if __name__ == '__main__':
    unittest.main()
