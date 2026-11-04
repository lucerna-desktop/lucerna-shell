"""Testes do lucerna-session (session/bin/lucerna-session).

Roda o script do repositório numa pasta temporária, com raízes falsas
(LUCERNA_SYSFS, LUCERNA_DEVFS, LUCERNA_ETC, LUCERNA_USR_SHARE, LUCERNA_RUN), HOME e
XDG_RUNTIME_DIR temporários e um PATH só com as ferramentas básicas (ligadas
às do sistema) e os falsos (systemctl, hyprctl, notify-send, start-hyprland,
os apps). Nada do host é lido nem chamado: nem o /sys, nem o /etc, nem o
D-Bus, nem um terminal instalado de verdade.
"""

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
    "readlink date mv rm sort ls setsid kill sleep printf touch tail wc seq"
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
        self.exits.write_text("")
        # Cada linha do exits.txt é uma partida: CÓDIGO, ou CÓDIGO@SEGUNDOS
        # (roda esse tempo e sai). Sem linha, fica rodando até o TERM.
        self.fake(
            "qs",
            f"""n=$(( $(cat "{self.counter}" 2> /dev/null || echo 0) + 1 )); echo "$n" > "{self.counter}"
echo "start=$n safe=${{LUCERNA_SAFE_MODE:-}} qt=${{QT_SCALE_FACTOR-unset}} handler=${{QS_DISABLE_CRASH_HANDLER-}} args=$*" >> "{self.starts}"
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

    def test_safe_mode_crashes_open_emergency(self):
        self.supervise(["1"] * 6)
        self.wait_for(lambda: any(c.startswith("hyprctl notify") for c in self.calls_log()), what="a emergência")
        self.wait_for(lambda: self.status() == "supervised emergency", what="o status emergency")
        time.sleep(0.5)
        self.assertEqual(len(self.start_lines()), 6, "na emergência, espera o shell start")
        # O shell start volta ao normal.
        self.run_session("shell", "start")
        self.starts_at_least(7)
        self.assertIn("safe= ", self.start_lines()[6])
        self.assertEqual(self.status(), "supervised running")

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
