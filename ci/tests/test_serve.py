"""Testes do services/scripts/serve.sh, com um programa falso numa pasta
temporária (que só escreve o que viu e sai: nenhum serviço de verdade, nenhum
processo solto no fim)."""

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "services" / "scripts" / "serve.sh"

# Escreve os argumentos, a pasta e o stdin no stdout, e uma linha no stderr.
FAKE = """#!/bin/sh
echo "args=$*"
echo "pwd=$(pwd)"
echo "stdin=$(readlink /proc/self/fd/0)"
echo "erro" >&2
"""


class ServeTest(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.dir = Path(tmp.name)
        self.program = self.dir / "lucerna-falso"
        self.program.write_text(FAKE, encoding="utf-8")
        self.program.chmod(0o755)
        self.log = self.dir / "state" / "lucerna" / "falso" / "serve.log"

    def run_serve(self, *args):
        # De outra pasta: o serviço precisa rodar em /, não na de quem chamou.
        return subprocess.run(
            [str(SCRIPT), *args],
            cwd=self.dir,
            stdin=subprocess.PIPE,
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )

    def test_roda_serve_com_o_log_e_a_pasta(self):
        done = self.run_serve(str(self.program), str(self.log))
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertEqual(done.stdout, "", "a saída vai toda para o log")
        lines = self.log.read_text(encoding="utf-8").splitlines()
        self.assertEqual(lines, ["args=serve", "pwd=/", "stdin=/dev/null", "erro"])

    def test_acrescenta_ao_log(self):
        self.log.parent.mkdir(parents=True)
        self.log.write_text("antes\n", encoding="utf-8")
        self.run_serve(str(self.program), str(self.log))
        self.assertEqual(self.log.read_text(encoding="utf-8").splitlines()[0], "antes")

    def test_log_grande_recomeca(self):
        self.log.parent.mkdir(parents=True)
        self.log.write_bytes(b"x" * (1048576 + 1))
        self.run_serve(str(self.program), str(self.log))
        self.assertEqual(self.log.read_text(encoding="utf-8").splitlines()[0], "args=serve")

    def test_log_no_limite_fica(self):
        self.log.parent.mkdir(parents=True)
        self.log.write_bytes(b"x" * 1048576)
        self.run_serve(str(self.program), str(self.log))
        self.assertTrue(self.log.read_bytes().startswith(b"x" * 1048576))

    def test_programa_inexistente_escreve_no_log(self):
        done = self.run_serve(str(self.dir / "nao-existe"), str(self.log))
        self.assertNotEqual(done.returncode, 0)
        self.assertIn("nao-existe", self.log.read_text(encoding="utf-8"))

    def test_sem_argumentos_recusa(self):
        done = self.run_serve()
        self.assertNotEqual(done.returncode, 0)
        self.assertIn("uso:", done.stderr)

    def test_executavel(self):
        self.assertTrue(os.access(SCRIPT, os.X_OK))


if __name__ == "__main__":
    unittest.main()
