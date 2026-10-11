"""Compiler-catalog alias regressions. The app cache stays fail-closed."""
import shutil
import tempfile
import unittest
from pathlib import Path

from test_symbol_policy import G, fixture


class CompilerSymbolAliases(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.catalog = Path(self.temp.name) / "catalog"
        self.cache = Path(self.temp.name) / "cache"
        self.catalog.mkdir()
        self.cache.mkdir()

    def test_byte_identical_and_same_content_aliases_are_one_package(self):
        identity = fixture(self.catalog / "Microsoft_Library.app")
        shutil.copyfile(self.catalog / "Microsoft_Library.app",
                        self.catalog / "Microsoft_Library_29.0.1.0.app")
        data = (self.catalog / "Microsoft_Library.app").read_bytes()
        (self.catalog / "Microsoft_Library_tail.app").write_bytes(data + b"signature-tail")
        fixture(self.catalog / "Microsoft_Library_repacked.app", identity)
        original = G.package_info(self.catalog / "Microsoft_Library.app")
        tailed = G.package_info(self.catalog / "Microsoft_Library_tail.app")
        self.assertNotEqual(original["sha256"], tailed["sha256"])
        self.assertEqual(original["contentSha256"], tailed["contentSha256"])
        self.assertEqual(original["identity"], tailed["identity"])
        with self.assertRaisesRegex(G.GateError, "Duplicate symbol identity/version"):
            G.symbol_inventory(self.catalog, "compilerCatalog")
        removals = G.collapse_equivalent_compiler_symbols(self.catalog)
        self.assertEqual(["Microsoft_Library.app"], sorted(p.name for p in self.catalog.glob("*.app")))
        self.assertEqual(3, len(removals))
        self.assertEqual(1, len(G.symbol_inventory(self.catalog, "compilerCatalog")))
        self.assertEqual([], G.collapse_equivalent_compiler_symbols(self.catalog))

    def test_conflicting_content_or_version_fails_without_removing_aliases(self):
        identity = fixture(self.catalog / "A.app")
        shutil.copyfile(self.catalog / "A.app", self.catalog / "A-copy.app")
        other = fixture(self.catalog / "B.app")
        fixture(self.catalog / "B-other.app", other, content=b"conflicting symbols")
        with self.assertRaisesRegex(G.GateError, "conflicting content"):
            G.collapse_equivalent_compiler_symbols(self.catalog)
        self.assertEqual(4, len(list(self.catalog.glob("*.app"))))

        for path in self.catalog.glob("*.app"):
            path.unlink()
        identity = fixture(self.catalog / "One.app")
        shutil.copyfile(self.catalog / "One.app", self.catalog / "One-copy.app")
        fixture(self.catalog / "Two.app", dict(identity, version="30.0.0.0"))
        with self.assertRaisesRegex(G.GateError, "conflicting version"):
            G.collapse_equivalent_compiler_symbols(self.catalog)
        self.assertTrue((self.catalog / "One-copy.app").is_file())
        self.assertTrue((self.catalog / "Two.app").is_file())

    def test_app_cache_still_rejects_a_byte_identical_duplicate(self):
        fixture(self.cache / "One.app")
        shutil.copyfile(self.cache / "One.app", self.cache / "Two.app")
        with self.assertRaisesRegex(G.GateError, "Duplicate symbol identity/version"):
            G.symbol_inventory(self.cache)
        self.assertEqual(2, len(list(self.cache.glob("*.app"))))


if __name__ == "__main__":
    unittest.main(verbosity=2)
