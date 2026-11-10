"""Testes do logind falso (ci/logind-fake.sh e ci/logind-fake.py).

Sobe o falso num dbus-daemon privado numa pasta temporária (nunca o
barramento do sistema nem o da sessão) e fala com ele pelo Gio: os inibidores
(os modos e o que conta como delay de sleep) e o stop, que só mata os
processos do falso.
"""

import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "ci" / "logind-fake.sh"


class LogindFakeTest(unittest.TestCase):
    def setUp(self):
        self.dir = Path(tempfile.mkdtemp(prefix="lucerna-logind-"))
        self.addCleanup(shutil.rmtree, self.dir, True)
        self.address = self.script("start").stdout.strip()
        self.addCleanup(self.script, "stop")
        flags = Gio.DBusConnectionFlags.AUTHENTICATION_CLIENT | Gio.DBusConnectionFlags.MESSAGE_BUS_CONNECTION
        self.conn = Gio.DBusConnection.new_for_address_sync(self.address, flags, None, None)
        # Depois do stop, o barramento já caiu e a conexão está fechada.
        self.addCleanup(lambda: self.conn.is_closed() or self.conn.close_sync(None))
        # As pontas de escrita dos inibidores pegos: fechá-las solta o inibidor.
        self.fds = []
        self.addCleanup(lambda: [os.close(fd) for fd in self.fds])

    def script(self, cmd):
        return subprocess.run(
            ["bash", str(SCRIPT), cmd, str(self.dir)], capture_output=True, text=True, timeout=30, check=True
        )

    def inhibit(self, what, mode):
        _reply, fds = self.conn.call_with_unix_fd_list_sync(
            "org.freedesktop.login1",
            "/org/freedesktop/login1",
            "org.freedesktop.login1.Manager",
            "Inhibit",
            GLib.Variant("(ssss)", (what, "teste", "teste", mode)),
            GLib.VariantType("(h)"),
            Gio.DBusCallFlags.NONE,
            5000,
            None,
            None,
        )
        self.fds.extend(fds.steal_fds())

    def status(self):
        reply = self.conn.call_sync(
            "org.freedesktop.login1",
            "/org/lucerna/Test",
            "org.lucerna.Test",
            "Status",
            None,
            GLib.VariantType("(s)"),
            Gio.DBusCallFlags.NONE,
            5000,
            None,
        )
        return json.loads(reply.unpack()[0])

    def test_weak_modes_accepted(self):
        # O block-weak e o delay-weak (systemd 257) valem; o delay-weak segura
        # o sono como o delay.
        self.inhibit("sleep", "block-weak")
        self.inhibit("sleep", "delay-weak")
        self.assertEqual(self.status()["delayHeld"], 1)

    def test_invalid_mode_rejected(self):
        with self.assertRaises(GLib.Error):
            self.inhibit("sleep", "forte")

    def test_sleep_matched_by_item(self):
        # O what é uma lista separada por ":"; conta o item sleep, não um
        # pedaço do texto.
        self.inhibit("shutdown:sleep", "delay")
        self.inhibit("nosleep", "delay")
        self.assertEqual(self.status()["delayHeld"], 1)

    def test_stop_spares_reused_pid(self):
        # Um pid do arquivo que já é de outro processo (reusado depois de o
        # falso cair) fica vivo.
        other = subprocess.Popen(["sleep", "30"])
        self.addCleanup(other.wait)
        self.addCleanup(other.kill)
        pids = self.dir / "lucerna-fake-system.pids"
        with pids.open("a", encoding="utf-8") as f:
            f.write(f"{other.pid}\n")
        self.script("stop")
        self.assertIsNone(other.poll(), "o stop matou um processo que não era do falso")
        self.assertFalse((self.dir / "lucerna-fake-system").exists())


if __name__ == "__main__":
    unittest.main()
