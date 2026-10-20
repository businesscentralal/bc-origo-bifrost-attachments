"""Mutation checks for the shipped-type help coverage guard."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("help_guard", Path(__file__).parents[1] / "check_help_chapters.py")
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)

REGISTRATION = '''enumextension 1 "Types" extends "Message Type ori"
{
    value(1; "Test.File.Get")
    {
        Implementation = "Msg Contract ori" = "Test Impl";
    }
}
'''
IMPLEMENTATION = '''codeunit 2 "Test Impl"
{
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Downloads the selected file.';
        exit(true);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        Examples.Add(ContractMgt.Example('A file', '{"type":"Test.File.Get","data":{}}', '{"exists":true}'));
        exit(true);
    end;
}
'''


class HelpChapterTests(unittest.TestCase):
    def run_check(self, implementation=IMPLEMENTATION, registration=REGISTRATION):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "src").mkdir()
            (root / "src/types.al").write_text(registration)
            (root / "src/impl.al").write_text(implementation)
            return guard.check(root)

    def test_complete_type_passes(self):
        self.assertEqual(self.run_check(), (1, []))

    def test_missing_overview_is_rejected(self):
        broken = IMPLEMENTATION.replace("Overview := 'Downloads the selected file.';", "Clear(Overview);")
        self.assertIn("Test.File.Get: missing or empty overview chapter", self.run_check(broken)[1])

    def test_examples_stub_cannot_claim_success(self):
        start = IMPLEMENTATION.index("        Examples.Add(")
        end = IMPLEMENTATION.index("\n", start)
        broken = IMPLEMENTATION[:start] + "        Clear(Examples);" + IMPLEMENTATION[end:]
        self.assertIn("Test.File.Get: missing or empty examples chapter", self.run_check(broken)[1])

    def test_false_return_and_comment_do_not_supply_examples(self):
        broken = IMPLEMENTATION.replace("Examples.Add(", "// Examples.Add(")
        self.assertIn("Test.File.Get: missing or empty examples chapter", self.run_check(broken)[1])

    def test_new_registered_type_cannot_escape_guard(self):
        added = REGISTRATION.replace("\n}", '\n    value(2; "Test.File.New") { Implementation = "Msg Contract ori" = "Absent Impl"; }\n}')
        count, problems = self.run_check(registration=added)
        self.assertEqual(count, 2)
        self.assertIn("Test.File.New: missing implementation Absent Impl", problems)

    def test_empty_registry_fails_closed(self):
        with self.assertRaisesRegex(ValueError, "No registered"):
            self.run_check(registration="")

    def test_missing_contract_binding_fails_closed(self):
        with self.assertRaisesRegex(ValueError, "no contract binding"):
            self.run_check(registration=REGISTRATION.replace('"Msg Contract ori"', '"Msg Interface ori"'))

    def test_shared_overview_must_name_the_requested_type(self):
        source = '''    procedure GetOverview(var Overview: Text): Boolean
    var
        Parts: Codeunit "Parts";
    begin
        Overview := Parts.GetOverview('Wrong.File.Get');
        exit(true);
    end;
'''
        self.assertFalse(guard.chapter_present(source, {}, "Overview", "Test.File.Get"))


if __name__ == "__main__":
    unittest.main()
