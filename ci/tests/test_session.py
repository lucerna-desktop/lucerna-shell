"""Testes do lucerna-session (session/bin/lucerna-session).

Roda o script do repositório numa pasta temporária, com raízes falsas
(LUCERNA_SYSFS, LUCERNA_DEVFS, LUCERNA_ETC, LUCERNA_USR_SHARE, LUCERNA_RUN), HOME e
XDG_RUNTIME_DIR temporários e um PATH só com as ferramentas básicas (ligadas
às do sistema) e os falsos (systemctl, hyprctl, notify-send, start-hyprland,
os apps). Nada do host é lido nem chamado: nem o /sys, nem o /etc, nem o
D-Bus, nem um terminal instalado de verdade.
"""

import fcntl
import json
import os
import re
import shutil
import signal
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "session" / "bin" / "lucerna-session"
# As ferramentas que o script usa, ligadas às do sistema no PATH falso.
TOOLS = (
    "bash sh env cat mkdir realpath dirname basename sed grep tr head cut "
    "readlink date mv rm sort ls setsid kill sleep printf touch tail wc seq timeout flock"
).split()


class SessionBase(unittest.TestCase):
    """As raízes falsas, o PATH falso e os ajudantes; os testes ficam nas subclasses."""

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

    # Uma placa em class/drm. Com vendor, uma GPU PCI (class 0x030000 e o
    # driver dado); sem vendor, um dispositivo de plataforma (o simpledrm).
    def card(self, n, vendor, boot_vga=None, node=True, driver=None, pci_class="0x030000"):
        dev = self.sysfs / "devices" / f"pci{n}"
        dev.mkdir(parents=True)
        if vendor is not None:
            (dev / "vendor").write_text(f"{vendor}\n")
            (dev / "class").write_text(f"{pci_class}\n")
        if driver is not None:
            target = self.sysfs / "bus" / "drivers" / driver
            target.mkdir(parents=True, exist_ok=True)
            (dev / "driver").symlink_to(target)
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

    def wait_for(self, check, timeout=15, what="a condição"):
        end = time.monotonic() + timeout
        while time.monotonic() < end:
            if check():
                return
            time.sleep(0.05)
        self.fail(f"esperei {what} por {timeout} s; log:\n{self.supervisor_log()}")

    def supervisor_log(self):
        log = self.home / ".local" / "state" / "lucerna" / "session.log"
        return log.read_text(encoding="utf-8") if log.exists() else ""

    # lookalike(nome): um processo qualquer cujo cmdline contém o nome.
    def lookalike(self, name):
        proc = subprocess.Popen(["bash", "-c", f"exec -a '{name}' sleep 60"])
        self.addCleanup(proc.wait)
        self.addCleanup(proc.kill)
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


class SessionTest(SessionBase):
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

    def test_detect_simpledrm_and_nvidia_is_nvidia(self):
        # Desktop só com NVIDIA (driver < 545 ou fbdev=0): o simpledrm do
        # firmware fica como card0, sem vendor. Não é uma híbrida.
        self.card(0, None, driver="simpledrm")
        self.card(1, "0x10de", boot_vga=1)
        self.modeset("Y")
        info = self.detect()
        self.assertEqual(info["gpu"], "nvidia")
        self.assertEqual(info["drm"], ["/dev/dri/card0", "/dev/dri/card1"])
        env = self.session_env()
        self.assertNotIn("AQ_DRM_DEVICES", env)
        self.assertEqual(env["LIBVA_DRIVER_NAME"], "nvidia")

    def test_detect_evdi_and_nvidia_is_nvidia(self):
        # Um adaptador DisplayLink (evdi) num notebook só com NVIDIA.
        self.card(0, "0x10de", boot_vga=1)
        self.card(1, None, driver="evdi")
        self.assertEqual(self.detect()["gpu"], "nvidia")
        self.assertNotIn("AQ_DRM_DEVICES", self.session_env())

    def test_detect_pci_card_with_pseudo_driver_or_other_class_is_skipped(self):
        # Com vendor PCI, mas com driver de quadro simples ou classe que não é
        # de vídeo: também não faz híbrida.
        self.card(0, "0x10de", boot_vga=1)
        self.card(1, "0x17e9", driver="evdi")
        self.card(2, "0x8086", pci_class="0x040300")
        self.assertEqual(self.detect()["gpu"], "nvidia")

    def test_detect_hybrid_with_simpledrm_keeps_integrated(self):
        # Uma híbrida de verdade com o simpledrm junto: o AQ_DRM_DEVICES leva a
        # integrada, nunca o simpledrm.
        self.card(0, None, driver="simpledrm")
        self.card(1, "0x10de", boot_vga=0)
        self.card(2, "0x8086", boot_vga=1, driver="i915")
        self.modeset("Y")
        info = self.detect()
        self.assertEqual(info["gpu"], "hybrid")
        self.assertEqual(self.session_env()["AQ_DRM_DEVICES"], "/dev/dri/card2:/dev/dri/card1")

    def test_detect_only_simpledrm_is_other(self):
        self.card(0, None, driver="simpledrm")
        info = self.detect()
        self.assertEqual(info["gpu"], "other")
        self.assertEqual(info["drm"], ["/dev/dri/card0"])
        self.assertIsNone(info["nvidiaModeset"])

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

    def test_init_with_systemctl_hanging_is_other(self):
        # Um gerente do usuário que não responde não prende a detecção (o
        # timeout; LUCERNA_SYSTEMD_TIMEOUT só nos testes).
        (self.run_root / "systemd" / "system").mkdir(parents=True)
        self.fake("systemctl", '[ "$2" = show-environment ] && exec sleep 30\nexit 0')
        start = time.monotonic()
        env = self.env()
        env["LUCERNA_SYSTEMD_TIMEOUT"] = "0.5"
        proc = subprocess.run([str(SCRIPT), "detect"], env=env, capture_output=True, text=True, timeout=20, check=True)
        self.assertEqual(json.loads(proc.stdout)["init"], "other")
        self.assertLess(time.monotonic() - start, 10)

    def test_runtime_dir_without_xdg_runtime_dir_is_run_user(self):
        # Sem o XDG_RUNTIME_DIR, o /run/user/<uid>, exportado: o shell que o
        # supervisor sobe (o config.safe.json, a marca do bloqueio) usa a mesma
        # pasta que o lucerna-session.
        self.fake("id", 'echo 4242')
        env = self.env()
        del env["XDG_RUNTIME_DIR"]
        common = ROOT / "session" / "lib" / "common.sh"
        out = subprocess.run(
            ["bash", "-c", f'. "{common}"; echo "$runtime_dir"; bash -c \'echo "$XDG_RUNTIME_DIR"\''],
            env=env, capture_output=True, text=True, timeout=10, check=True,
        ).stdout.split()
        self.assertEqual(out, ["/run/user/4242/lucerna", "/run/user/4242"])

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

    def test_session_env_quotes_around_the_value_are_dropped(self):
        # Como no environment.d: um par de aspas em volta do valor sai; o
        # AppsScale grava sem aspas, e esses valores ficam como estão.
        self.write(
            self.home / ".config" / "lucerna" / "session.env",
            'DOUBLE="com espaço"\n'
            "SINGLE='simples'\n"
            "PLAIN=1.25\n"
            'HALF="aberta\n'
            "MIXED=\"a'\n"
            'INSIDE=a"b"c\n'
            "LAST=sem quebra no fim",
        )
        env = self.session_env()
        self.assertEqual(env["DOUBLE"], "com espaço")
        self.assertEqual(env["SINGLE"], "simples")
        self.assertEqual(env["PLAIN"], "1.25")
        self.assertEqual(env["HALF"], '"aberta')
        self.assertEqual(env["MIXED"], "\"a'")
        self.assertEqual(env["INSIDE"], 'a"b"c')
        self.assertEqual(env["LAST"], "sem quebra no fim")

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

    def test_open_ignores_shell_functions_and_builtins(self):
        # O have só acha programas do PATH: um apps.conf com o nome de uma
        # função do script (log) ou de um builtin (echo) não é "instalado".
        self.fake("kitty")
        for name in ("log", "echo"):
            self.write(self.home / ".config" / "lucerna" / "apps.conf", f"terminal={name}\n")
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

    def test_unlock_clears_lock_marker_without_shell(self):
        # Sem o qs vivo, o unlock do TTY (a pessoa entrou com a senha) também
        # esvazia a marca: o shell start seguinte não bloqueia de novo.
        marker = self.runtime / "lucerna" / "locked"
        self.write(marker, "locked\n")
        self.run_session("unlock")
        self.assertEqual(marker.read_text().strip(), "")

    def test_unlock_keeps_lock_marker_with_shell(self):
        # Com o qs vivo (o bloqueio dele está de pé), a marca fica.
        qs = self.lookalike("qs -c lucerna")
        marker = self.runtime / "lucerna" / "locked"
        self.write(marker, "locked\n")
        self.write(self.runtime / "lucerna" / "qs.pid", f"{qs.pid}\n")
        self.run_session("unlock")
        self.assertEqual(marker.read_text().strip(), "locked")

    def test_open_terminal_runs_command(self):
        self.fake("foot")
        self.run_session("open", "terminal", "less", "+G", "/tmp/x.log")
        self.assertEqual(self.calls_log()[-1], "foot less +G /tmp/x.log")
        self.fake("alacritty")
        self.write(self.home / ".config" / "lucerna" / "apps.conf", "terminal=alacritty\n")
        self.run_session("open", "terminal", "less", "/tmp/x.log")
        self.assertEqual(self.calls_log()[-1], "alacritty -e less /tmp/x.log")

    def test_session_term_stops_supervisor(self):
        # A sessão derrubada de fora (TERM/HUP) ainda para o shell.
        supervisor = self.lookalike("lucerna-session supervise")
        (self.runtime / "lucerna").mkdir()
        (self.runtime / "lucerna" / "supervisor.pid").write_text(f"{supervisor.pid}\n")
        self.fake("start-hyprland", "trap 'kill $s; exit 143' TERM; sleep 30 & s=$!; wait $s")
        proc = subprocess.Popen([str(SCRIPT)], env=self.env())
        self.addCleanup(proc.wait)
        self.addCleanup(proc.kill)
        self.wait_for(lambda: "start-hyprland -- --config" in " ".join(self.calls_log()))
        proc.send_signal(signal.SIGTERM)
        proc.wait(timeout=10)
        self.assertIsNotNone(supervisor.wait(timeout=5), "o supervisor recebeu o TERM")

    # emergency_qs(corpo_ipc, corpo_p): um qs falso que anota o modo da
    # emergência e roda um corpo para o `qs -c … ipc` e outro para o `qs -p`.
    def emergency_qs(self, ipc="exit 0", panel="exit 0"):
        self.fake(
            "qs",
            f"""if [ "$1" = -p ]; then
    echo "mode=${{LUCERNA_EMERGENCY_MODE-}} log=${{LUCERNA_EMERGENCY_LOG-}}" >> "{self.tmp / "emergency.txt"}"
    {panel}
fi
{ipc}""",
        )

    def emergency_modes(self):
        path = self.tmp / "emergency.txt"
        return path.read_text().splitlines() if path.exists() else []

    def test_power_uses_shell_menu_when_alive(self):
        self.emergency_qs()
        self.run_session("power")
        self.assertIn("qs -c lucerna ipc call panels open power", self.calls_log())
        self.assertEqual(self.emergency_modes(), [])

    def test_power_falls_back_to_emergency(self):
        # O shell morto (o ipc falha): a tela de emergência no modo power. Ela
        # fica aberta mais de 2 s, então não há a notificação de recurso.
        self.emergency_qs(ipc="exit 1", panel="sleep 2.3; exit 0")
        self.run_session("power")
        calls = self.calls_log()
        self.assertIn("qs -c lucerna ipc call panels open power", calls)
        data = SCRIPT.resolve().parents[1]
        self.assertIn(f"qs -p {data}/emergency/shell.qml", calls)
        self.assertEqual(len(self.emergency_modes()), 1)
        self.assertTrue(self.emergency_modes()[0].startswith("mode=power "), self.emergency_modes())
        self.assertFalse(any(c.startswith("hyprctl eval") for c in calls), calls)

    def test_emergency_falls_back_to_notification(self):
        # O qs -p que sai na hora (a emergência não abriu): o aviso do Hyprland,
        # com a saída pelo terminal e o registro mais novo.
        logs = self.home / ".local" / "state" / "lucerna" / "shell"
        self.write(logs / "qs-20261104-100000.log", "velho\n")
        newest = logs / "qs-20261104-110000.log"
        self.write(newest, "novo\n")
        os.utime(logs / "qs-20261104-100000.log", (1, 1))
        self.emergency_qs(panel="exit 1")
        self.run_session("emergency", "--mode", "crashed", check=False)
        self.assertEqual(self.emergency_modes(), [f"mode=crashed log={newest}"])
        evals = [c for c in self.calls_log() if c.startswith("hyprctl eval")]
        self.assertEqual(len(evals), 1, self.calls_log())
        self.assertIn("hl.notification.create(", evals[0])
        self.assertIn("O Lucerna não conseguiu iniciar.", evals[0])
        self.assertIn("Super+Enter abre um terminal", evals[0])
        self.assertIn("Ctrl+Alt+Shift+Esc sai da sessão", evals[0])
        self.assertIn(f"Registro: {newest}", evals[0])
        # Sem prazo de verdade: no Hyprland 0.56, timeout = 0 some na hora (conferido
        # no container); um dia inteiro é o "fica até a pessoa agir".
        self.assertIn("timeout = 86400000", evals[0])

    # A tela de emergência falsa que fica aberta e responde ao `state` pelo
    # modo dela (gravado num arquivo); o ipc do shell falha (shell morto).
    def lasting_emergency_qs(self):
        state = self.tmp / "emergency-state.txt"
        self.fake(
            "qs",
            f"""if [ "$1" = -p ] && [ "$3" = ipc ]; then
    [ "$6" = state ] && cat "{state}" 2> /dev/null
    exit 0
fi
if [ "$1" = -p ]; then
    mode=${{LUCERNA_EMERGENCY_MODE-}}
    echo "mode=$mode" >> "{self.tmp / "emergency.txt"}"
    echo "$mode" > "{state}"
    trap 'kill $s 2> /dev/null; echo "fechada=$mode" >> "{self.tmp / "emergency.txt"}"; exit 143' TERM
    sleep 600 & s=$!
    wait $s
    exit 0
fi
exit 1""",
        )

    def background_session(self, *args):
        proc = subprocess.Popen([str(SCRIPT), *args], env=self.env())
        self.addCleanup(proc.wait)
        self.addCleanup(proc.kill)
        return proc

    def test_crashed_replaces_power_emergency(self):
        # O Ctrl+Alt+Delete com o shell travado abriu a tela power; o shell
        # cai e o supervisor pede a crashed: a power fecha e a crashed abre.
        self.lasting_emergency_qs()
        power = self.background_session("power")
        self.wait_for(lambda: self.emergency_modes() == ["mode=power"], what="a tela power")
        self.wait_for(lambda: (self.runtime / "lucerna" / "emergency.pid").exists(), what="o emergency.pid")
        crashed = self.background_session("emergency", "--mode", "crashed")
        self.wait_for(
            lambda: self.emergency_modes() == ["mode=power", "fechada=power", "mode=crashed"],
            what="a troca pela crashed",
        )
        self.assertEqual(power.wait(timeout=10), 0, "o power sai quando a tela dele fecha")
        self.assertIsNone(crashed.poll(), "a crashed fica aberta, esperando")
        self.assertIn("é a do Ctrl+Alt+Delete; troco pela da queda", self.supervisor_log())
        # Uma segunda queda com a crashed aberta não troca nada.
        self.run_session("emergency", "--mode", "crashed")
        self.assertEqual(self.emergency_modes()[-1], "mode=crashed")
        self.assertIn("a tela de emergência já está aberta", self.supervisor_log())
        # Nem o power: ele só traz a tela inteira de volta.
        self.run_session("power")
        self.assertEqual(len(self.emergency_modes()), 3)
        pid = int((self.runtime / "lucerna" / "emergency.pid").read_text().strip())
        os.kill(pid, signal.SIGTERM)
        self.assertEqual(crashed.wait(timeout=10), 0)

    def test_session_log_rotates_at_start(self):
        # O session.log de sessões antigas fica só com as últimas linhas.
        log = self.home / ".local" / "state" / "lucerna" / "session.log"
        self.write(log, "".join(f"antiga {n}\n" for n in range(1, 31)))
        self.fake("start-hyprland")
        env = self.env()
        env["LUCERNA_SESSION_LOG_LINES"] = "10"
        proc = subprocess.run([str(SCRIPT)], env=env, capture_output=True, text=True, timeout=30, check=False)
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        lines = log.read_text(encoding="utf-8").splitlines()
        self.assertEqual(lines[:10], [f"antiga {n}" for n in range(21, 31)], "as 10 últimas antigas, na ordem")
        self.assertIn("a sessão começa", "\n".join(lines[10:]), "e a sessão nova depois delas")
        self.assertFalse(log.with_name("session.log.tmp").exists())
        # Abaixo do limite, nada muda.
        before = log.read_text(encoding="utf-8")
        env["LUCERNA_SESSION_LOG_LINES"] = "100000"
        subprocess.run([str(SCRIPT)], env=env, capture_output=True, text=True, timeout=30, check=False)
        self.assertTrue(log.read_text(encoding="utf-8").startswith(before))

    def test_help_tells_the_tty_way_out_of_a_stuck_lockscreen(self):
        proc = self.run_session("--help")
        self.assertIn("travado na tela de bloqueio", proc.stderr)
        self.assertIn("lucerna-session shell restart (volta", proc.stderr)

    def test_emergency_rejects_unknown_mode(self):
        self.emergency_qs()
        proc = self.run_session("emergency", "--mode", "nada", check=False)
        self.assertEqual(proc.returncode, 64)
        self.assertEqual(self.emergency_modes(), [])

    def test_poweroff_simulated_in_dev(self):
        self.fake("loginctl")
        env = self.env()
        env["LUCERNA_DEV"] = "1"
        for action, label in (("poweroff", "Desligar"), ("reboot", "Reiniciar")):
            proc = subprocess.run([str(SCRIPT), action], env=env, capture_output=True, text=True, timeout=30)
            self.assertEqual(proc.returncode, 0, proc.stderr)
            self.assertIn(f"notify-send Lucerna {label}: ação simulada.", self.calls_log())
        calls = self.calls_log()
        self.assertFalse(any(c.startswith(("systemctl", "loginctl")) for c in calls), calls)
        self.assertIn("simulad", self.supervisor_log())

    def test_poweroff_simulated_without_notification_server(self):
        # Com o shell caído não há servidor de notificações: o aviso vai pelo Hyprland.
        self.fake("notify-send", "exit 1")
        env = self.env()
        env["LUCERNA_DEV"] = "1"
        proc = subprocess.run([str(SCRIPT), "poweroff"], env=env, capture_output=True, text=True, timeout=30)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        evals = [c for c in self.calls_log() if c.startswith("hyprctl eval")]
        self.assertEqual(len(evals), 1, self.calls_log())
        self.assertIn('text = "Desligar: ação simulada."', evals[0])

    def test_poweroff_without_systemd_uses_loginctl(self):
        self.fake("loginctl")
        self.run_session("poweroff")
        self.run_session("reboot")
        calls = self.calls_log()
        self.assertIn("loginctl poweroff", calls)
        self.assertIn("loginctl reboot", calls)
        self.assertNotIn("systemctl poweroff", calls)

    def test_poweroff_with_systemd_uses_systemctl(self):
        self.fake("loginctl")
        (self.run_root / "systemd" / "system").mkdir(parents=True)
        self.run_session("poweroff")
        self.run_session("reboot")
        calls = self.calls_log()
        self.assertIn("systemctl poweroff", calls)
        self.assertIn("systemctl reboot", calls)
        self.assertFalse(any(c.startswith("loginctl") for c in calls), calls)

    def test_unknown_subcommand_fails(self):
        proc = self.run_session("nada", check=False)
        self.assertEqual(proc.returncode, 64)


class SupervisorTest(SessionBase):
    """O supervisor (lucerna-session supervise), com um qs falso que lê de um
    arquivo como cada partida termina e anota o ambiente, e um hyprctl falso
    que falha no `-j version` quando o arquivo gone existe (o compositor saiu)."""

    def setUp(self):
        super().setUp()
        self.exits = self.tmp / "exits.txt"
        self.starts = self.tmp / "starts.txt"
        self.counter = self.tmp / "count.txt"
        self.gone = self.tmp / "gone"
        # A tela de emergência (qs -p): anota o modo e fica aberta até o TERM.
        self.emergency = self.tmp / "emergency.txt"
        self.exits.write_text("")
        # Cada linha do exits.txt é uma partida: CÓDIGO, ou CÓDIGO@SEGUNDOS
        # (roda esse tempo e sai). Sem linha, fica rodando até o TERM.
        self.fake(
            "qs",
            f"""if [ "$1" = -p ]; then
    echo "mode=${{LUCERNA_EMERGENCY_MODE-}} log=${{LUCERNA_EMERGENCY_LOG-}} args=$*" >> "{self.emergency}"
    trap 'kill $s 2> /dev/null; echo fechada >> "{self.emergency}"; exit 143' TERM
    sleep 600 & s=$!
    wait $s
    exit 0
fi
n=$(( $(cat "{self.counter}" 2> /dev/null || echo 0) + 1 )); echo "$n" > "{self.counter}"
echo "start=$n safe=${{LUCERNA_SAFE_MODE:-}} qt=${{QT_SCALE_FACTOR-unset}} handler=${{QS_DISABLE_CRASH_HANDLER-}} supervised=${{LUCERNA_SUPERVISED-}} args=$*" >> "{self.starts}"
echo "partida $n"
line=$(sed -n "${{n}}p" "{self.exits}")
trap 'kill $s 2> /dev/null; exit 143' TERM
if [ -n "$line" ]; then
    case "$line" in *@*) sleep "${{line#*@}}" & s=$!; wait $s ;; esac
    exit "${{line%@*}}"
fi
sleep 600 & s=$!
wait $s""",
        )
        self.fake("hyprctl", f'[ "$1" = -j ] && [ -e "{self.gone}" ] && exit 1\nexit 0')

    def env(self):
        env = super().env()
        env.update(LUCERNA_CRASH_DELAYS="0.1 0.2 0.4", LUCERNA_CRASH_WINDOW="30", LUCERNA_SAFE_TRIES="2")
        return env

    def start_lines(self):
        return self.starts.read_text().splitlines() if self.starts.exists() else []

    def supervise(self, exits=(), **extra):
        self.exits.write_text("".join(f"{e}\n" for e in exits))
        env = self.env()
        env.update(extra)
        proc = subprocess.Popen([str(SCRIPT), "supervise"], env=env)

        def stop():
            if proc.poll() is None:
                proc.terminate()
                try:
                    proc.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    proc.kill()

        self.addCleanup(stop)
        return proc

    def starts_at_least(self, n):
        self.wait_for(lambda: len(self.start_lines()) >= n, what=f"{n} partidas")
        # A partida anotada: o qs.pid já aponta para ela.
        time.sleep(0.2)

    def crash_json(self):
        return json.loads((self.runtime / "lucerna" / "crash.json").read_text(encoding="utf-8"))

    def delays(self):
        return re.findall(r"volta em ([0-9.]+) s", self.supervisor_log())

    def status(self):
        return self.run_session("shell", "status").stdout.strip()

    def test_isolated_crash_restarts_after_first_delay(self):
        self.supervise(["1"])
        self.starts_at_least(2)
        self.assertEqual(self.delays(), ["0.1"])
        self.assertEqual(self.status(), "supervised running")

    def test_delays_grow_1_2_4(self):
        self.supervise(["1", "1", "1"])
        self.starts_at_least(4)
        self.assertEqual(self.delays(), ["0.1", "0.2", "0.4"])
        self.assertTrue(all("safe= " in line for line in self.start_lines()), self.start_lines())

    def test_fourth_crash_in_window_goes_safe(self):
        safe_config = self.runtime / "lucerna" / "config.safe.json"
        self.write(safe_config, '{"theme": "da sessão segura anterior"}')
        self.supervise(["1", "1", "1", "1"])
        self.starts_at_least(5)
        lines = self.start_lines()
        self.assertTrue(all("safe= " in line for line in lines[:4]), lines)
        self.assertIn("safe=1 ", lines[4])
        self.assertFalse(safe_config.exists(), "o config.safe.json é apagado ao entrar no modo de segurança")
        crash = self.crash_json()
        self.assertTrue(crash["safe"])
        self.assertEqual(self.status(), "supervised safe")

    def test_crashes_outside_window_do_not_accumulate(self):
        self.supervise(["1@1.2"] * 5, LUCERNA_CRASH_WINDOW="1")
        self.starts_at_least(6)
        self.assertEqual(self.delays(), ["0.1"] * 5)
        self.assertTrue(all("safe= " in line for line in self.start_lines()), self.start_lines())

    def emergency_lines(self):
        return self.emergency.read_text().splitlines() if self.emergency.exists() else []

    def test_safe_mode_crashes_open_emergency(self):
        self.supervise(["1"] * 6)
        self.wait_for(lambda: self.emergency_lines(), what="a tela de emergência")
        self.wait_for(lambda: self.status() == "supervised emergency", what="o status emergency")
        line = self.emergency_lines()[0]
        self.assertTrue(line.startswith("mode=crashed log="), line)
        # O registro da última queda (a 6ª partida).
        log = Path(line.split("log=")[1].split(" args=")[0])
        self.assertIn("partida 6", log.read_text())
        self.assertIn(f"args=-p {SCRIPT.resolve().parents[1]}/emergency/shell.qml", line)
        self.assertFalse(any(c.startswith("hyprctl notify") for c in self.calls_log()), self.calls_log())
        time.sleep(0.5)
        self.assertEqual(len(self.start_lines()), 6, "na emergência, espera o shell start")
        # O shell start volta ao normal e fecha a tela de emergência que ficou.
        self.run_session("shell", "start")
        self.starts_at_least(7)
        self.assertIn("safe= ", self.start_lines()[6])
        self.assertEqual(self.status(), "supervised running")
        self.wait_for(lambda: "fechada" in self.emergency_lines(), what="a emergência fechada")
        # O aviso da queda já foi a emergência: o shell normal não diz "modo de segurança".
        self.assertFalse((self.runtime / "lucerna" / "crash.json").exists())

    def test_second_supervisor_exits_while_lock_is_held(self):
        # Um supervisor que acabou de pegar a trava e ainda não gravou o pid
        # (a corrida de dois ao mesmo tempo): o segundo sai sem subir um qs.
        pid_file = self.runtime / "lucerna" / "supervisor.pid"
        pid_file.parent.mkdir(parents=True, exist_ok=True)
        with open(pid_file, "a+") as held:
            fcntl.flock(held, fcntl.LOCK_EX | fcntl.LOCK_NB)
            proc = self.supervise()
            self.assertEqual(proc.wait(timeout=10), 0)
        self.assertEqual(self.start_lines(), [])
        self.assertIn("já há um supervisor", self.supervisor_log())

    def test_two_supervisors_at_once_start_one_shell(self):
        first = self.supervise()
        second = self.supervise()
        self.wait_for(lambda: first.poll() is not None or second.poll() is not None, what="um dos dois sair")
        self.starts_at_least(1)
        time.sleep(0.5)
        self.assertEqual(len(self.start_lines()), 1, self.start_lines())

    def test_shell_does_not_inherit_the_supervisor_lock(self):
        # O qs e a pausa não herdam a trava: com o supervisor morto à força,
        # o próximo sobe (e o qs que sobrou não o barra).
        self.supervise()
        self.starts_at_least(1)
        qs_pid = int((self.runtime / "lucerna" / "qs.pid").read_text())
        pid_file = str((self.runtime / "lucerna" / "supervisor.pid").resolve())
        links = []
        for fd in os.listdir(f"/proc/{qs_pid}/fd"):
            try:
                links.append(os.readlink(f"/proc/{qs_pid}/fd/{fd}"))
            except OSError:
                pass
        self.assertNotIn(pid_file, links)

    def test_compositor_gone_stops_without_restart(self):
        self.gone.touch()
        proc = self.supervise(["1"])
        self.assertEqual(proc.wait(timeout=10), 0)
        self.assertEqual(len(self.start_lines()), 1)
        self.assertFalse((self.runtime / "lucerna" / "crash.json").exists())
        self.assertFalse([c for c in self.calls_log() if c.startswith("hyprctl notify")])
        self.assertEqual(self.status(), "unsupervised")

    def test_hold_does_not_count_as_crash(self):
        self.supervise()
        self.starts_at_least(1)
        self.run_session("shell", "stop")
        self.assertEqual(self.status(), "supervised held")
        self.assertFalse((self.runtime / "lucerna" / "qs.pid").exists() and self.qs_alive())
        time.sleep(0.5)
        self.assertEqual(len(self.start_lines()), 1, "parado, não volta sozinho")
        self.run_session("shell", "start")
        self.starts_at_least(2)
        self.assertEqual(self.status(), "supervised running")
        self.assertFalse((self.runtime / "lucerna" / "crash.json").exists())
        self.assertNotIn("caiu", self.supervisor_log())
        # O contador continua 0: a próxima queda é a primeira.
        self.exits.write_text("0\n1\n")
        self.kill_qs()
        self.starts_at_least(3)
        self.assertEqual(self.crash_json()["count"], 1)

    def test_stop_during_crash_pause_holds(self):
        # Um shell stop na pausa depois de uma queda: nenhum qs sobe, o estado
        # é held, e não sobra hold para a queda seguinte virar "parada".
        self.supervise(["1"], LUCERNA_CRASH_DELAYS="2 2 2")
        self.wait_for(lambda: "volta em 2 s" in self.supervisor_log(), what="a pausa")
        self.run_session("shell", "stop")
        self.assertEqual(self.status(), "supervised held")
        time.sleep(2.5)
        self.assertEqual(len(self.start_lines()), 1, "parado na pausa, não sobe")
        self.run_session("shell", "start")
        self.starts_at_least(2)
        self.assertFalse((self.runtime / "lucerna" / "hold").exists())
        self.assertEqual(self.status(), "supervised running")
        # A queda seguinte é queda de verdade: reinicia e conta.
        self.kill_qs()
        self.starts_at_least(3)
        self.assertEqual(self.crash_json()["count"], 1)

    def qs_alive(self):
        pid = int((self.runtime / "lucerna" / "qs.pid").read_text())
        try:
            os.kill(pid, 0)
        except ProcessLookupError:
            return False
        return True

    def kill_qs(self):
        pid = int((self.runtime / "lucerna" / "qs.pid").read_text())
        os.kill(pid, signal.SIGKILL)

    def test_crash_json_written(self):
        self.supervise(["3"])
        self.starts_at_least(2)
        crash = self.crash_json()
        self.assertEqual(set(crash), {"time", "log", "count", "safe"})
        self.assertEqual(crash["count"], 1)
        self.assertIs(crash["safe"], False)
        log = Path(crash["log"])
        self.assertEqual(log.parent, self.home / ".local" / "state" / "lucerna" / "shell")
        self.assertRegex(log.name, r"^qs-\d{8}-\d{6}(-\d+)?\.log$")
        self.assertIn("partida 1", log.read_text())
        self.assertRegex(crash["time"], r"^\d{4}-\d{2}-\d{2}T")

    def test_reports_keep_last_five(self):
        self.supervise(["1"] * 6, LUCERNA_SAFE_TRIES="3")
        self.starts_at_least(7)
        logs = sorted((self.home / ".local" / "state" / "lucerna" / "shell").glob("qs-*.log"))
        self.assertEqual(len(logs), 5, logs)
        kept = sorted(int(log.read_text().split()[1]) for log in logs)
        self.assertEqual(kept, [3, 4, 5, 6, 7])

    def test_qs_runs_without_qt_scale_factor(self):
        self.supervise(QT_SCALE_FACTOR="2")
        self.starts_at_least(1)
        self.assertIn("qt=unset", self.start_lines()[0])
        # O tratador de quedas do Quickshell desligado: a queda é do supervisor.
        self.assertIn("handler=1 ", self.start_lines()[0])
        # O shell sabe que é o do supervisor: na sessão Lucerna, um qs sem a
        # LUCERNA_SUPERVISED (o exec_cmd do hyprland.lua da pessoa) sai.
        self.assertIn("supervised=1 ", self.start_lines()[0])
        self.assertIn("args=-c lucerna", self.start_lines()[0])

    def test_status_unsupervised_without_pid(self):
        self.assertEqual(self.status(), "unsupervised")
        # Um pid de outro processo no supervisor.pid também não é o supervisor.
        other = self.lookalike("outro programa")
        self.write(self.runtime / "lucerna" / "supervisor.pid", f"{other.pid}\n")
        self.assertEqual(self.status(), "unsupervised")

    def test_stop_does_not_signal_foreign_pid(self):
        other = self.lookalike("outro programa")
        self.write(self.runtime / "lucerna" / "qs.pid", f"{other.pid}\n")
        self.write(self.runtime / "lucerna" / "supervisor.pid", f"{other.pid}\n")
        self.run_session("shell", "stop")
        self.assertIsNone(other.poll(), "o processo de outro não recebe o TERM")


if __name__ == "__main__":
    unittest.main()
