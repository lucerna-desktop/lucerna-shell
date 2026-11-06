"""Roda os testes Lua da base do Hyprland (session/hypr/tests/*_test.lua).

Cada arquivo roda com o `lua`, com session/hypr/?.lua no LUA_PATH, e precisa
sair com 0 e imprimir "SUITE <nome> casos=N" com N > 0.
"""

import os
import re
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HYPR = ROOT / "session" / "hypr"
TESTS = sorted((HYPR / "tests").glob("*_test.lua"))


class HyprLuaTest(unittest.TestCase):
    def test_lua_installed(self):
        self.assertIsNotNone(shutil.which("lua"), "falta o lua (ci/packages/rules.txt)")

    def test_files_found(self):
        self.assertTrue(TESTS, "nenhum session/hypr/tests/*_test.lua achado")

    def test_suites(self):
        env = dict(os.environ, LUA_PATH=f"{HYPR}/?.lua;;")
        for path in TESTS:
            with self.subTest(arquivo=path.name):
                proc = subprocess.run(
                    ["lua", str(path)], cwd=HYPR, env=env, capture_output=True, text=True, timeout=30, check=False
                )
                output = proc.stdout + proc.stderr
                self.assertEqual(proc.returncode, 0, f"{path.name} falhou:\n{output}")
                match = re.search(r"^SUITE \S+ casos=(\d+)$", proc.stdout, re.M)
                self.assertTrue(match and int(match.group(1)) > 0, f"{path.name} não rodou nenhum caso:\n{output}")


if __name__ == "__main__":
    unittest.main()
