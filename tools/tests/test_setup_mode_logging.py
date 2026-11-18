"""#232 AC03: permission checks must not emit successful-write telemetry.

Foundation owns Data.Records.Set logging after success. Its telemetry capture is
internal and unavailable to the feature test app, so this is a source-boundary
regression; AL/MCP tests separately exercise writes and refusals.
"""

from pathlib import Path
import re
import unittest


class SetupModeLogging(unittest.TestCase):
    def test_restriction_checks_do_not_log_writes(self):
        source = (Path(__file__).parents[2] /
                  "app/src/Upload/StorageDataRestriction.Codeunit.al").read_text()
        source = re.sub(r"/\*.*?\*/|//[^\n]*", "", source, flags=re.S)
        self.assertNotRegex(source, r"(?i)\bLogWrite\s*\(",
                            "Foundation logs successful writes; a restriction check is not a write.")


if __name__ == "__main__":
    unittest.main()
