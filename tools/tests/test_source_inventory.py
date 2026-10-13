"""Source inventory generator regressions; these never certify a candidate."""
from pathlib import Path
import sys
import unittest
from unittest import mock
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import generate_source_inventory as gen

ENUM = '''enumextension {id} "X ori" extends "Message Type ori"
{{
{values}
}}
'''


def enum(object_id, *values):
    body = '\n'.join(f'    value({ordinal}; "{name}") {{ }}' for ordinal, name in values)
    return ENUM.format(id=object_id, values=body).encode()


class MessageTypeTests(unittest.TestCase):
    def run_with(self, files):
        with mock.patch.object(gen, 'tree', lambda sha, prefix: sorted(files)), \
             mock.patch.object(gen, 'blob', lambda sha, path: files[path]):
            return gen.message_types('a' * 40)

    def test_collects_values_sorted_by_ordinal(self):
        rows = self.run_with({
            'app/src/B.EnumExt.al': enum(2, (20, 'B.Get')),
            'app/src/A.EnumExt.al': enum(1, (10, 'A.Get'), (11, 'A.Set')),
        })
        self.assertEqual([(r['ordinal'], r['name'], r['source']) for r in rows],
                         [(10, 'A.Get', 'app/src/A.EnumExt.al'), (11, 'A.Set', 'app/src/A.EnumExt.al'),
                          (20, 'B.Get', 'app/src/B.EnumExt.al')])

    def test_ignores_other_enum_extensions_and_files(self):
        other = b'enumextension 3 "Y ori" extends "Storage Type ori"\n{\n    value(30; "Mock") { }\n}\n'
        rows = self.run_with({
            'app/src/A.EnumExt.al': enum(1, (10, 'A.Get')),
            'app/src/Y.EnumExt.al': other,
            'app/src/A.Codeunit.al': b'value(99; "Not.An.Enum")',
        })
        self.assertEqual([r['name'] for r in rows], ['A.Get'])

    def test_refuses_duplicate_ordinal(self):
        with self.assertRaisesRegex(gen.InventoryError, 'ordinal 10'):
            self.run_with({'app/src/A.EnumExt.al': enum(1, (10, 'A.Get')),
                           'app/src/B.EnumExt.al': enum(2, (10, 'B.Get'))})

    def test_refuses_duplicate_name(self):
        with self.assertRaisesRegex(gen.InventoryError, 'name A.Get'):
            self.run_with({'app/src/A.EnumExt.al': enum(1, (10, 'A.Get')),
                           'app/src/B.EnumExt.al': enum(2, (11, 'A.Get'))})


class RepositoryTests(unittest.TestCase):
    def test_committed_inventory_is_current(self):
        self.assertEqual(gen.main(['--check']), 0)


if __name__ == '__main__':
    unittest.main()
