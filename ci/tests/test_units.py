"""Testes das unidades do systemd e da entrada no gerenciador de login (session/)."""

import configparser
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SESSION = ROOT / "session"
# O destino de session/bin/lucerna-session na tabela de caminhos instalados.
INSTALLED_SESSION_BIN = "/usr/bin/lucerna-session"


def read(path):
    parser = configparser.ConfigParser(strict=False, interpolation=None)
    parser.optionxform = str
    parser.read_string(Path(path).read_text(encoding="utf-8"))
    return parser


class UnitsTest(unittest.TestCase):
    def test_shell_service_restarts_the_supervisor(self):
        unit = read(SESSION / "systemd" / "lucerna-shell.service")
        self.assertEqual(unit["Unit"]["Description"], "Lucerna: o shell")
        self.assertEqual(unit["Unit"]["PartOf"], "graphical-session.target")
        self.assertEqual(unit["Unit"]["After"], "graphical-session.target")
        self.assertEqual(unit["Unit"]["Requisite"], "graphical-session.target")
        self.assertEqual(unit["Service"]["ExecStart"], f"{INSTALLED_SESSION_BIN} supervise")
        self.assertEqual(unit["Service"]["Restart"], "on-failure")
        self.assertEqual(unit["Service"]["RestartSec"], "1")
        self.assertEqual(unit["Service"]["Slice"], "session.slice")

    def test_target_binds_graphical_session(self):
        unit = read(SESSION / "systemd" / "lucerna-session.target")
        self.assertEqual(unit["Unit"]["Description"], "Lucerna: a sessão gráfica")
        self.assertEqual(unit["Unit"]["BindsTo"], "graphical-session.target")
        self.assertEqual(unit["Unit"]["Wants"].split(), ["graphical-session-pre.target", "lucerna-shell.service"])
        self.assertEqual(unit["Unit"]["After"], "graphical-session-pre.target")

    def test_desktop_entry_runs_lucerna_session(self):
        entry = read(SESSION / "wayland-sessions" / "lucerna.desktop")["Desktop Entry"]
        self.assertEqual(entry["Name"], "Lucerna")
        self.assertEqual(entry["Comment"], "A sessão do Lucerna sobre o Hyprland")
        self.assertEqual(entry["Exec"], "lucerna-session")
        self.assertEqual(entry["Type"], "Application")
        self.assertEqual(entry["DesktopNames"], "Hyprland")

    def test_exec_paths_match_install_layout(self):
        unit = read(SESSION / "systemd" / "lucerna-shell.service")
        binary = unit["Service"]["ExecStart"].split()[0]
        self.assertEqual(binary, INSTALLED_SESSION_BIN)
        self.assertTrue((SESSION / "bin" / Path(binary).name).is_file())


if __name__ == "__main__":
    unittest.main()
