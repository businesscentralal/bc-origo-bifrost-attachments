"""Previous Apps in AL-Go's actual cache: identity cleanup, not gate exemptions."""
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parents[1]))
import prune_self_symbols as P
from test_symbol_policy import fixture


class PrecompileCache(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.cache = self.root / '.packages'
        self.cache.mkdir()
        self.identities = {}
        for folder, app_id in [('app', '672df32a-a0c5-4a22-b591-0efa38023e95'),
                               ('test', '7cdb530b-b74b-446b-9ece-80e2b911bfb3')]:
            project = self.root / folder
            project.mkdir()
            identity = dict(id=app_id, publisher='Origo', name=folder, version='28.3.0.0')
            self.identities[folder] = identity
            (project / 'app.json').write_text(json.dumps(identity))

    def run_prune(self, project='app'):
        return P.prune(self.root, self.root / project, self.cache)

    def test_previous_self_aliases_removed_but_dependencies_and_baseline_preserved(self):
        previous = dict(self.identities['app'], version='28.3.0.122')
        for name in ('previous.app', 'renamed.app'):
            fixture(self.cache / name, previous)
        fixture(self.cache / 'Foundation.app')
        dependency_bytes = (self.cache / 'Foundation.app').read_bytes()
        baseline = self.root / 'previousApps'
        baseline.mkdir()
        fixture(baseline / 'previous.app', previous)
        result = self.run_prune()
        self.assertEqual(['previous.app', 'renamed.app'], [x['file'] for x in result['removed']])
        self.assertEqual(dependency_bytes, (self.cache / 'Foundation.app').read_bytes())
        self.assertTrue((baseline / 'previous.app').exists())
        self.assertEqual([], self.run_prune()['removed'])

    def test_test_compile_keeps_product_dependency_and_removes_only_test_self(self):
        fixture(self.cache / 'Product.app', self.identities['app'])
        fixture(self.cache / 'Tests.app', self.identities['test'])
        self.assertEqual('Tests.app', self.run_prune('test')['removed'][0]['file'])
        self.assertTrue((self.cache / 'Product.app').exists())

    def test_foreign_cache_and_unknown_project_refused(self):
        with self.assertRaisesRegex(P.GateError, 'owned workspace'):
            P.prune(self.root, self.root / 'app', self.root)
        with self.assertRaisesRegex(P.GateError, 'Unknown compiling project'):
            P.prune(self.root, self.root, self.cache)

    def test_corrupt_input_prevents_partial_cleanup(self):
        fixture(self.cache / 'a-self.app', self.identities['app'])
        (self.cache / 'z-corrupt.app').write_bytes(b'broken')
        with self.assertRaises(P.GateError):
            self.run_prune()
        self.assertTrue((self.cache / 'a-self.app').exists())

    def test_symlink_and_identity_collision_refused(self):
        fixture(self.root / 'outside.app', self.identities['app'])
        (self.cache / 'linked.app').symlink_to(self.root / 'outside.app')
        with self.assertRaises(P.GateError):
            self.run_prune()
        (self.cache / 'linked.app').unlink()
        fixture(self.cache / 'collision.app', dict(self.identities['app'], publisher='Other'))
        with self.assertRaisesRegex(P.GateError, 'unexpected publisher'):
            self.run_prune()
        self.assertTrue((self.cache / 'collision.app').exists())


if __name__ == '__main__':
    unittest.main()
