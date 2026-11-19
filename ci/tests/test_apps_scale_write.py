"""Testes do services/scripts/apps-scale-write.sh (a gravação do modo "Escala
pelos apps"), numa pasta temporária no lugar do ~/.config. Um chmod falso no
PATH anota as permissões do .lucerna-tmp na hora em que o script as copia do
original (e chama o chmod de verdade)."""

import os
import shutil
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "services" / "scripts" / "apps-scale-write.sh"

FAKE_CHMOD = """#!/bin/sh
for last; do :; done
stat -c %a -- "$last" >> "$CHMOD_LOG"
exec {chmod} "$@"
"""


class AppsScaleWriteTest(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.dir = Path(tmp.name)
        self.home = self.dir / "config"
        self.home.mkdir()
        self.bin = self.dir / "bin"
        self.bin.mkdir()
        self.log = self.dir / "chmod.log"
        fake = self.bin / "chmod"
        fake.write_text(FAKE_CHMOD.format(chmod=shutil.which("chmod")), encoding="utf-8")
        fake.chmod(0o755)

    def run_write(self, mode, *triples, copies=""):
        env = dict(os.environ, PATH=f"{self.bin}:{os.environ['PATH']}", CHMOD_LOG=str(self.log))
        args = [str(SCRIPT), str(self.home), mode, copies]
        for triple in triples:
            args.extend(triple)
        return subprocess.run(
            args, env=env, capture_output=True, text=True, timeout=10, check=False, preexec_fn=lambda: os.umask(0o022)
        )

    def mode_of(self, path):
        return stat.S_IMODE(path.stat().st_mode)

    def test_grava_cria_pastas_e_apaga(self):
        (self.home / "velho.conf").write_text("x", encoding="utf-8")
        done = self.run_write("apply", ("gtk-3.0/settings.ini", "w", "[Settings]\n"), ("velho.conf", "rm", ""))
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertEqual((self.home / "gtk-3.0" / "settings.ini").read_text(encoding="utf-8"), "[Settings]\n")
        self.assertFalse((self.home / "velho.conf").exists())
        self.assertEqual(list(self.home.rglob("*.lucerna-tmp")), [], "nenhum temporário fica")

    def test_arquivo_novo_com_o_umask(self):
        done = self.run_write("apply", ("lucerna/session.env", "w", "A=1\n"))
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertEqual(self.mode_of(self.home / "lucerna" / "session.env"), 0o644)

    def test_o_temporario_nunca_fica_aberto_aos_outros(self):
        # Um original 600: o temporário não pode nascer 644 (o umask) e só
        # depois virar 600, nem herdar um temporário velho com 644.
        original = self.home / "chromium-flags.conf"
        original.write_text("--a\n", encoding="utf-8")
        original.chmod(0o600)
        stale = self.home / "chromium-flags.conf.lucerna-tmp"
        stale.write_text("velho", encoding="utf-8")
        stale.chmod(0o644)
        done = self.run_write("apply", ("chromium-flags.conf", "w", "--a\n--b\n"))
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertEqual(original.read_text(encoding="utf-8"), "--a\n--b\n")
        self.assertEqual(self.mode_of(original), 0o600, "as permissões do original ficam")
        seen = self.log.read_text(encoding="utf-8").split()
        self.assertTrue(seen, "o chmod --reference foi chamado")
        for mode in seen:
            self.assertEqual(int(mode, 8) & 0o077, 0, f"o .lucerna-tmp estava {mode} antes do chmod")

    def test_link_simbolico_gravado_no_lugar(self):
        real = self.dir / "dotfiles" / "electron-flags.conf"
        real.parent.mkdir()
        real.write_text("--a\n", encoding="utf-8")
        link = self.home / "electron-flags.conf"
        link.symlink_to(real)
        done = self.run_write("apply", ("electron-flags.conf", "w", "--b\n"))
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertTrue(link.is_symlink(), "o link continua link")
        self.assertEqual(real.read_text(encoding="utf-8"), "--b\n")

    def test_copias_so_na_primeira_vez_e_sem_sobrescrever(self):
        (self.home / "a.conf").write_text("antes", encoding="utf-8")
        (self.home / "b.conf").write_text("modo", encoding="utf-8")
        (self.home / "b.conf.lucerna-bak").write_text("de antes", encoding="utf-8")
        done = self.run_write("fresh", ("a.conf", "w", "depois"), copies="a.conf\nb.conf\nfalta.conf")
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertEqual((self.home / "a.conf.lucerna-bak").read_text(encoding="utf-8"), "antes")
        self.assertEqual((self.home / "b.conf.lucerna-bak").read_text(encoding="utf-8"), "de antes")
        self.assertFalse((self.home / "falta.conf.lucerna-bak").exists())
        self.assertEqual((self.home / "a.conf").read_text(encoding="utf-8"), "depois")
        (self.home / "c.conf").write_text("c", encoding="utf-8")
        self.run_write("apply", ("c.conf", "w", "d"), copies="c.conf")
        self.assertFalse((self.home / "c.conf.lucerna-bak").exists(), "fora da primeira vez, nenhuma cópia")

    def test_falha_numa_pasta_segue_com_as_outras(self):
        (self.home / "bloqueio").write_text("arquivo no lugar da pasta", encoding="utf-8")
        done = self.run_write("apply", ("bloqueio/x.ini", "w", "x"), ("ok.conf", "w", "y"))
        self.assertEqual(done.returncode, 1)
        self.assertEqual((self.home / "ok.conf").read_text(encoding="utf-8"), "y")


if __name__ == "__main__":
    unittest.main()
