"""Testes do lucerna-session (session/bin/lucerna-session).

Roda o script do repositório numa pasta temporária, com raízes falsas
(LUCERNA_SYSFS, LUCERNA_DEVFS, LUCERNA_ETC, LUCERNA_USR_SHARE, LUCERNA_RUN), HOME e
XDG_RUNTIME_DIR temporários e um PATH só com as ferramentas básicas (ligadas
às do sistema) e os falsos (systemctl, hyprctl, notify-send, start-hyprland,
os apps). Nada do host é lido nem chamado: nem o /sys, nem o /etc, nem o
D-Bus, nem um terminal instalado de verdade.
"""

import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "session" / "bin" / "lucerna-session"
# As ferramentas que o script usa, ligadas às do sistema no PATH falso.
TOOLS = (
    "bash sh env cat mkdir realpath dirname basename sed grep tr head cut "
    "readlink date mv rm sort ls setsid kill sleep printf"
).split()


class SessionTest(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="lucerna-session-"))
        self.addCleanup(shutil.rmtree, self.tmp, True)
        self.sysfs = self.tmp / "sys"
        self.devfs = self.tmp / "dev"
        self.etc = self.tmp / "etc"
        self.share = self.tmp / "usr-share"
        self.run_root = self.tmp / "run"
        self.home = self.tmp / "home"
        self.runtime = self.tmp / "xdg-run"
        self.bin = self.tmp / "bin"
        self.calls = self.tmp / "calls.log"
        for d in (
            self.sysfs / "class" / "drm",
            self.devfs / "dri",
            self.etc,
            self.share,
            self.run_root,
            self.home,
            self.bin,
        ):
            d.mkdir(parents=True)
        self.runtime.mkdir(mode=0o700)
        for tool in TOOLS:
            real = shutil.which(tool)
            if real:
                (self.bin / tool).symlink_to(real)
        # Os falsos de sempre: anotam a chamada e saem com 0.
        for name in ("systemctl", "hyprctl", "notify-send"):
            self.fake(name)

    # fake(nome, corpo): um programa falso no PATH que anota "nome args" no
    # calls.log e roda o corpo (bash).
    def fake(self, name, body="exit 0"):
        path = self.bin / name
        path.write_text(f'#!/bin/bash\necho "{name} $*" >> "{self.calls}"\n{body}\n', encoding="utf-8")
        path.chmod(0o755)

    def calls_log(self):
        return self.calls.read_text(encoding="utf-8").splitlines() if self.calls.exists() else []

    def card(self, n, vendor, boot_vga=None, node=True):
        dev = self.sysfs / "devices" / f"pci{n}"
        dev.mkdir(parents=True)
        (dev / "vendor").write_text(f"{vendor}\n")
        if boot_vga is not None:
            (dev / "boot_vga").write_text(f"{boot_vga}\n")
        card = self.sysfs / "class" / "drm" / f"card{n}"
        card.mkdir()
        (card / "device").symlink_to(dev)
        if node:
            (self.devfs / "dri" / f"card{n}").touch()
        # Um conector (card0-eDP-1) não é uma placa.
        (self.sysfs / "class" / "drm" / f"card{n}-eDP-1").mkdir()

    def modeset(self, value):
        params = self.sysfs / "module" / "nvidia_drm" / "parameters"
        params.mkdir(parents=True)
        (params / "modeset").write_text(f"{value}\n")

    def write(self, path, text):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def env(self):
        return {
            "PATH": str(self.bin),
            "HOME": str(self.home),
            "XDG_RUNTIME_DIR": str(self.runtime),
            "LUCERNA_SYSFS": str(self.sysfs),
            "LUCERNA_ETC": str(self.etc),
            "LUCERNA_USR_SHARE": str(self.share),
            "LUCERNA_RUN": str(self.run_root),
            "LUCERNA_DEVFS": str(self.devfs),
            "LANG": "C.UTF-8",
        }

    def run_session(self, *args, check=True):
        proc = subprocess.run(
            [str(SCRIPT), *args], env=self.env(), capture_output=True, text=True, timeout=30, check=False
        )
        if check:
            self.assertEqual(proc.returncode, 0, f"lucerna-session {' '.join(args)}:\n{proc.stdout}{proc.stderr}")
        return proc

    def detect(self):
        out = self.run_session("detect").stdout
        info = json.loads(out)
        saved = json.loads((self.runtime / "lucerna" / "session.json").read_text(encoding="utf-8"))
        self.assertEqual(info, saved, "o detect grava o mesmo que imprime")
        return info

    # A sessão com um start-hyprland falso que grava o ambiente e os argumentos.
    def session_env(self):
        dump = self.tmp / "env.txt"
        self.fake("start-hyprland", f'echo "ARGS=$*" > "{dump}"; env >> "{dump}"')
        self.run_session()
        lines = dump.read_text(encoding="utf-8").splitlines()
        return dict(line.split("=", 1) for line in lines if "=" in line)

    def test_detect_intel_only(self):
        self.card(0, "0x8086", boot_vga=1)
        info = self.detect()
        self.assertEqual(info["gpu"], "intel")
        self.assertEqual(info["drm"], ["/dev/dri/card0"])
        self.assertIsNone(info["nvidiaModeset"])
        env = self.session_env()
        for name in ("LIBVA_DRIVER_NAME", "__GLX_VENDOR_LIBRARY_NAME", "NVD_BACKEND", "AQ_DRM_DEVICES"):
            self.assertNotIn(name, env)

    def test_detect_nvidia_only_sets_env_and_modeset(self):
        self.card(0, "0x10de", boot_vga=1)
        self.modeset("Y")
        info = self.detect()
        self.assertEqual(info["gpu"], "nvidia")
        self.assertIs(info["nvidiaModeset"], True)
        env = self.session_env()
        self.assertEqual(env["LIBVA_DRIVER_NAME"], "nvidia")
        self.assertEqual(env["__GLX_VENDOR_LIBRARY_NAME"], "nvidia")
        self.assertEqual(env["NVD_BACKEND"], "direct")
        self.assertNotIn("AQ_DRM_DEVICES", env)

    def test_detect_hybrid_integrated_first(self):
        # A NVIDIA vem primeiro na numeração; a integrada (boot_vga=1) vai antes.
        self.card(0, "0x10de", boot_vga=0)
        self.card(1, "0x8086", boot_vga=1)
        self.modeset("Y")
        info = self.detect()
        self.assertEqual(info["gpu"], "hybrid")
        self.assertEqual(info["drm"], ["/dev/dri/card0", "/dev/dri/card1"])
        env = self.session_env()
        self.assertEqual(env["AQ_DRM_DEVICES"], "/dev/dri/card1:/dev/dri/card0")
        self.assertNotIn("__GLX_VENDOR_LIBRARY_NAME", env)
        self.assertNotIn("LIBVA_DRIVER_NAME", env)

    def test_detect_modeset_off_and_missing(self):
        self.card(0, "0x10de")
        self.assertIs(self.detect()["nvidiaModeset"], False, "sem o arquivo, com NVIDIA")
        self.modeset("N")
        self.assertIs(self.detect()["nvidiaModeset"], False, "N")

    def test_detect_skips_cards_without_node(self):
        # Num container, o /sys mostra a NVIDIA do host, mas só a Intel foi repassada.
        self.card(0, "0x10de", node=False)
        self.card(1, "0x8086", boot_vga=1)
        info = self.detect()
        self.assertEqual(info["gpu"], "intel")
        self.assertEqual(info["drm"], ["/dev/dri/card1"])
        self.assertIsNone(info["nvidiaModeset"])

    def test_detect_without_cards_is_none(self):
        info = self.detect()
        self.assertEqual(info["gpu"], "none")
        self.assertEqual(info["drm"], [])
        self.assertIsNone(info["nvidiaModeset"])

    def test_detect_amd_and_other(self):
        self.card(0, "0x1002")
        self.assertEqual(self.detect()["gpu"], "amd")
        self.card(1, "0x1af4")
        self.assertEqual(self.detect()["gpu"], "amd", "a placa principal (a primeira) decide")

    def test_keyboard_from_xorg_conf(self):
        self.write(
            self.etc / "X11" / "xorg.conf.d" / "00-keyboard.conf",
            'Section "InputClass"\n'
            '        Identifier "system-keyboard"\n'
            '        MatchIsKeyboard "on"\n'
            '        Option "XkbLayout" "br"\n'
            '        Option "XkbModel" "abnt2"\n'
            '        Option "XkbVariant" "thinkpad"\n'
            '        Option "XkbOptions" "terminate:ctrl_alt_bksp"\n'
            "EndSection\n",
        )
        # O vconsole fica de reserva: o xorg.conf vem antes.
        self.write(self.etc / "vconsole.conf", "KEYMAP=us\n")
        kb = self.detect()["keyboard"]
        self.assertEqual(
            kb, {"layout": "br", "variant": "thinkpad", "model": "abnt2", "options": "terminate:ctrl_alt_bksp"}
        )
        env = self.session_env()
        self.assertEqual(env["LUCERNA_KB_LAYOUT"], "br")
        self.assertEqual(env["LUCERNA_KB_MODEL"], "abnt2")

    def test_keyboard_from_default_keyboard(self):
        self.write(
            self.etc / "default" / "keyboard", 'XKBMODEL="pc105"\nXKBLAYOUT="pt"\nXKBVARIANT=""\nXKBOPTIONS=""\n'
        )
        kb = self.detect()["keyboard"]
        self.assertEqual(kb, {"layout": "pt", "variant": "", "model": "pc105", "options": ""})

    def test_keyboard_from_vconsole_via_kbd_model_map(self):
        self.write(self.etc / "vconsole.conf", "# comentário\nKEYMAP=br-abnt2\nFONT=lat0-16\n")
        self.write(
            self.share / "systemd" / "kbd-model-map",
            "# Generated\n"
            "# consolelayout\t\tx11layout\tx11model\tx11variant\tx11options\n"
            "us\t\t\tus\tpc105\t\t-\tterminate:ctrl_alt_bksp\n"
            "br-abnt2\t\tbr\tabnt2\t\t-\tterminate:ctrl_alt_bksp\n",
        )
        kb = self.detect()["keyboard"]
        self.assertEqual(kb, {"layout": "br", "variant": "", "model": "abnt2", "options": "terminate:ctrl_alt_bksp"})

    def test_keyboard_falls_back_to_us(self):
        self.assertEqual(self.detect()["keyboard"], {"layout": "us", "variant": "", "model": "", "options": ""})
        # Um KEYMAP que o mapa não conhece também cai no us.
        self.write(self.etc / "vconsole.conf", "KEYMAP=desconhecido\n")
        self.write(self.share / "systemd" / "kbd-model-map", "br-abnt2 br abnt2 - -\n")
        self.assertEqual(self.detect()["keyboard"]["layout"], "us")

    def test_init_without_systemd_is_other(self):
        self.assertEqual(self.detect()["init"], "other", "sem /run/systemd/system")
        # A pasta sem um systemctl --user que responda também não é systemd.
        (self.run_root / "systemd" / "system").mkdir(parents=True)
        self.fake("systemctl", "exit 1")
        self.assertEqual(self.detect()["init"], "other")

    def test_init_with_systemd(self):
        (self.run_root / "systemd" / "system").mkdir(parents=True)
        self.assertEqual(self.detect()["init"], "systemd")

    def test_session_runs_base_and_exports(self):
        env = self.session_env()
        base = ROOT / "session" / "hypr" / "hyprland.lua"
        self.assertEqual(env["ARGS"], f"-- --config {base}")
        self.assertEqual(env["LUCERNA_DATA_DIR"], str(ROOT / "session"))
        self.assertEqual(env["LUCERNA_SESSION"], "1")
        self.assertEqual(env["XDG_SESSION_TYPE"], "wayland")
        self.assertEqual(env["XDG_CURRENT_DESKTOP"], "Hyprland")
        self.assertEqual(env["XDG_SESSION_DESKTOP"], "lucerna")
        self.assertTrue((self.runtime / "lucerna" / "session.json").is_file())
        self.assertTrue((self.home / ".local" / "state" / "lucerna" / "session.log").is_file())

    def test_session_without_start_hyprland_runs_hyprland(self):
        dump = self.tmp / "args.txt"
        self.fake("Hyprland", f'echo "$*" > "{dump}"')
        self.run_session()
        self.assertEqual(dump.read_text().strip(), f"--config {ROOT / 'session' / 'hypr' / 'hyprland.lua'}")

    def test_session_end_stops_systemd_target(self):
        (self.run_root / "systemd" / "system").mkdir(parents=True)
        self.session_env()
        self.assertIn("systemctl --user stop lucerna-session.target", self.calls_log())

    def test_session_env_only_allowlisted_lines(self):
        marker = self.tmp / "pwned"
        self.write(
            self.home / ".config" / "lucerna" / "session.env",
            "# comentário\n"
            "MY_VAR=valor com espaço\n"
            "_PRIV=1\n"
            "rm -rf /\n"
            "export X=1; y\n"
            "lower=1\n"
            f"SUB=$(touch {marker})\n"
            "  INDENTED=1\n",
        )
        env = self.session_env()
        self.assertEqual(env["MY_VAR"], "valor com espaço")
        self.assertEqual(env["_PRIV"], "1")
        self.assertNotIn("X", env)
        self.assertNotIn("lower", env)
        self.assertNotIn("INDENTED", env)
        self.assertEqual(env["SUB"], f"$(touch {marker})", "o valor entra como texto, sem rodar")
        self.assertFalse(marker.exists(), "nada do arquivo é executado")

    def test_ready_without_systemd_starts_supervisor(self):
        started = self.tmp / "qs.txt"
        self.fake("qs", f'echo "$*" > "{started}"')
        self.run_session("ready")
        for _ in range(50):
            if started.exists():
                break
            subprocess.run(["sleep", "0.1"], check=True)
        self.assertEqual(started.read_text().strip(), "-c lucerna")
        self.assertFalse([c for c in self.calls_log() if c.startswith("systemctl")])

    def test_ready_with_systemd_imports_and_starts_target(self):
        (self.run_root / "systemd" / "system").mkdir(parents=True)
        self.run_session("ready")
        calls = self.calls_log()
        imported = [c for c in calls if c.startswith("systemctl --user import-environment")]
        self.assertTrue(imported, calls)
        for name in ("WAYLAND_DISPLAY", "HYPRLAND_INSTANCE_SIGNATURE", "LUCERNA_SESSION", "LUCERNA_DATA_DIR"):
            self.assertIn(name, imported[0].split())
        self.assertIn("systemctl --user start lucerna-session.target", calls)

    def test_open_uses_apps_conf_then_list(self):
        self.fake("foot")
        self.fake("kitty")
        self.fake("alacritty")
        self.write(self.home / ".config" / "lucerna" / "apps.conf", "# apps\nterminal=alacritty\n")
        self.run_session("open", "terminal")
        self.assertEqual(self.calls_log()[-1], "alacritty ")
        # O do apps.conf não instalado: o primeiro da lista.
        self.write(self.home / ".config" / "lucerna" / "apps.conf", "terminal=wezterm\n")
        self.run_session("open", "terminal")
        self.assertEqual(self.calls_log()[-1], "kitty ")

    def test_open_without_any_notifies(self):
        proc = self.run_session("open", "browser", check=False)
        self.assertEqual(proc.returncode, 1)
        self.assertIn("notify-send Lucerna Nenhum navegador instalado", self.calls_log())

    def test_open_rejects_unknown_kind(self):
        proc = self.run_session("open", "editor", check=False)
        self.assertNotEqual(proc.returncode, 0)

    def test_detect_apps(self):
        self.fake("foot")
        self.fake("firefox")
        self.fake("dolphin")
        self.fake("thunar")
        apps = json.loads(self.run_session("detect-apps").stdout)
        self.assertEqual(apps, {"terminal": ["foot"], "browser": ["firefox"], "files": ["dolphin", "thunar"]})

    def test_logout_calls_exit(self):
        self.run_session("logout")
        self.assertIn("hyprctl dispatch hl.dsp.exit()", self.calls_log())

    def test_unlock_clears_crashed_lockscreen(self):
        self.run_session("unlock")
        self.assertIn("hyprctl --instance 0 eval hl.clear_crashed_lockscreen()", self.calls_log())

    def test_unknown_subcommand_fails(self):
        proc = self.run_session("nada", check=False)
        self.assertEqual(proc.returncode, 64)


if __name__ == "__main__":
    unittest.main()
