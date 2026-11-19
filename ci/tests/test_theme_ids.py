"""A lista de temas do tests/theme.test.js contra os themes/*.json."""

import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class ThemeIdsTest(unittest.TestCase):
    def test_theme_test_lists_every_theme(self):
        # O runner do qs não lista pastas (o FolderListModel é assíncrono):
        # o teste das cores tem a lista à mão, e um tema novo em themes/
        # ficaria fora dos testes de contraste sem ninguém avisar.
        text = (ROOT / "tests" / "theme.test.js").read_text(encoding="utf-8")
        match = re.search(r"const ids = (\[[^\]]*\]);", text)
        self.assertIsNotNone(match, "a lista ids sumiu do tests/theme.test.js")
        ids = json.loads(match.group(1))
        themes = sorted(p.stem for p in (ROOT / "themes").glob("*.json"))
        self.assertEqual(sorted(ids), themes)


if __name__ == "__main__":
    unittest.main()
