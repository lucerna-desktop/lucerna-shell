#!/usr/bin/env python3
"""O logind falso do container de teste (dev/test.sh) e da fumaça.

Fala num barramento privado (o dbus-daemon que o ci/logind-fake.sh sobe em
<pasta>/lucerna-fake-system), nunca no barramento do sistema: o container
monta o do host, e um inibidor ou um sinal ali seria no logind de verdade.
Só o Gio (python-gobject); roda com `python3 -I`.

  ci/logind-fake.py --address unix:path=<pasta>/lucerna-fake-system

Pega o nome org.freedesktop.login1 e serve:

- /org/freedesktop/login1, org.freedesktop.login1.Manager:
  - GetSession(s) → o: sempre /org/freedesktop/login1/session/_31;
  - CanHibernate() → s: "na" (o container não tem swap), ou o que o
    SetCanHibernate pôs;
  - Inhibit(ssss) → h: guarda o fd (a ponta de leitura de um pipe; a de
    escrita vai para quem pediu) e o mode; o inibidor some quando quem pediu
    fecha a ponta dele (POLLHUP);
  - as propriedades LidClosed (b, com PropertiesChanged), Docked (b) e
    InhibitDelayMaxUSec (t, 5 s);
  - o sinal PrepareForSleep(b).
- /org/freedesktop/login1/session/_31, org.freedesktop.login1.Session: os
  sinais Lock e Unlock, SetLockedHint(b) e a propriedade LockedHint (com
  PropertiesChanged).
- /org/lucerna/Test, org.lucerna.Test (o controle dos testes):
  - Suspend(): emite PrepareForSleep(true), espera os inibidores delay de
    sleep fecharem (até o InhibitDelayMaxUSec), registra
    {releasedMs, timedOut, lockedHintAtSleep}, "dorme" 1 s e emite
    PrepareForSleep(false). Responde só no fim do ciclo;
  - LockSession(), UnlockSession(): emitem Lock e Unlock na sessão;
  - SetLid(b): muda o LidClosed;
  - SetCanHibernate(s): a resposta dos CanHibernate seguintes;
  - Status() → s: JSON com delayHeld, lockedHint, lid, lastSleep e
    canHibernateAsked (quantos CanHibernate vieram).

Cada pedido e cada mudança vão numa linha para stderr (o log do falso).
"""

import argparse
import json
import os
import sys
import time

import gi

gi.require_version("GLibUnix", "2.0")
from gi.repository import Gio, GLib, GLibUnix  # noqa: E402

NAME = "org.freedesktop.login1"
MANAGER_PATH = "/org/freedesktop/login1"
SESSION_PATH = "/org/freedesktop/login1/session/_31"
TEST_PATH = "/org/lucerna/Test"
MANAGER = "org.freedesktop.login1.Manager"
SESSION = "org.freedesktop.login1.Session"
TEST = "org.lucerna.Test"
PROPERTIES = "org.freedesktop.DBus.Properties"
DELAY_MAX_USEC = 5_000_000
SLEEP_MS = 1000
# Os caminhos do barramento do sistema: o falso nunca fala neles.
SYSTEM_SOCKETS = ("/run/dbus/system_bus_socket", "/var/run/dbus/system_bus_socket")

XML = """
<node>
  <interface name="org.freedesktop.login1.Manager">
    <method name="GetSession">
      <arg name="session_id" type="s" direction="in"/>
      <arg name="object_path" type="o" direction="out"/>
    </method>
    <method name="CanHibernate">
      <arg name="result" type="s" direction="out"/>
    </method>
    <method name="Inhibit">
      <arg name="what" type="s" direction="in"/>
      <arg name="who" type="s" direction="in"/>
      <arg name="why" type="s" direction="in"/>
      <arg name="mode" type="s" direction="in"/>
      <arg name="pipe_fd" type="h" direction="out"/>
    </method>
    <signal name="PrepareForSleep">
      <arg name="start" type="b"/>
    </signal>
    <property name="LidClosed" type="b" access="read"/>
    <property name="Docked" type="b" access="read"/>
    <property name="InhibitDelayMaxUSec" type="t" access="read"/>
  </interface>
  <interface name="org.freedesktop.login1.Session">
    <method name="SetLockedHint">
      <arg name="locked" type="b" direction="in"/>
    </method>
    <signal name="Lock"/>
    <signal name="Unlock"/>
    <property name="LockedHint" type="b" access="read"/>
  </interface>
  <interface name="org.lucerna.Test">
    <method name="Suspend"/>
    <method name="LockSession"/>
    <method name="UnlockSession"/>
    <method name="SetLid">
      <arg name="closed" type="b" direction="in"/>
    </method>
    <method name="SetCanHibernate">
      <arg name="result" type="s" direction="in"/>
    </method>
    <method name="Status">
      <arg name="status" type="s" direction="out"/>
    </method>
  </interface>
</node>
"""


def log(text):
    print(f"logind-fake: {text}", file=sys.stderr, flush=True)


class Fake:
    def __init__(self, conn):
        self.conn = conn
        self.lid = False
        self.locked_hint = False
        # A resposta do CanHibernate: sem swap no container, "na".
        self.can_hibernate = "na"
        self.can_hibernate_asked = 0
        # fd da ponta de leitura → (what, who, why, mode, id do watch)
        self.inhibitors = {}
        self.last_sleep = None
        # O Suspend em andamento: a invocação (respondida no fim), o início
        # (monotônico), o id do prazo e a fase (asleep: já dormiu, até o wake_up).
        self.sleeping = None

    # Estado

    def delay_held(self):
        return sum(1 for what, _who, _why, mode, _w in self.inhibitors.values() if mode == "delay" and "sleep" in what)

    def status(self):
        return json.dumps(
            {
                "delayHeld": self.delay_held(),
                "lockedHint": self.locked_hint,
                "lid": self.lid,
                "lastSleep": self.last_sleep,
                "canHibernateAsked": self.can_hibernate_asked,
            }
        )

    def changed(self, path, iface, name, value):
        self.conn.emit_signal(
            None, path, PROPERTIES, "PropertiesChanged", GLib.Variant("(sa{sv}as)", (iface, {name: value}, []))
        )

    # Inibidores

    def inhibit(self, what, who, why, mode, invocation):
        if mode not in ("block", "delay"):
            invocation.return_dbus_error("org.freedesktop.DBus.Error.InvalidArgs", f"mode inválido: {mode}")
            return
        rfd, wfd = os.pipe()
        fds = Gio.UnixFDList.new()
        fds.append(wfd)
        os.close(wfd)
        watch = GLibUnix.fd_add_full(
            GLib.PRIORITY_DEFAULT, rfd, GLib.IOCondition.HUP | GLib.IOCondition.ERR, self.on_released
        )
        self.inhibitors[rfd] = (what, who, why, mode, watch)
        log(f"Inhibit what={what} who={who} why={why} mode={mode} (delay de sleep: {self.delay_held()})")
        invocation.return_value_with_unix_fd_list(GLib.Variant("(h)", (0,)), fds)

    def on_released(self, fd, _condition):
        what, who, _why, mode, _watch = self.inhibitors.pop(fd)
        os.close(fd)
        log(f"inibidor solto: what={what} who={who} mode={mode} (delay de sleep: {self.delay_held()})")
        # Só na espera: depois de dormir (o 1 s do sono), soltar um inibidor não
        # muda o ciclo em andamento.
        if self.sleeping is not None and not self.sleeping["asleep"] and self.delay_held() == 0:
            self.go_to_sleep(timed_out=False)
        return False

    # Suspender

    def suspend(self, invocation):
        if self.sleeping is not None:
            invocation.return_dbus_error("org.freedesktop.login1.OperationInProgress", "já suspendendo")
            return
        log(f"Suspend: PrepareForSleep(true), {self.delay_held()} inibidor(es) delay de sleep")
        self.sleeping = {"invocation": invocation, "start": time.monotonic(), "timeout": 0, "asleep": False}
        self.conn.emit_signal(None, MANAGER_PATH, MANAGER, "PrepareForSleep", GLib.Variant("(b)", (True,)))
        if self.delay_held() == 0:
            self.go_to_sleep(timed_out=False)
        else:
            self.sleeping["timeout"] = GLib.timeout_add(DELAY_MAX_USEC // 1000, self.on_delay_timeout)

    def on_delay_timeout(self):
        self.sleeping["timeout"] = 0
        log(f"Suspend: o prazo de {DELAY_MAX_USEC // 1000} ms passou com {self.delay_held()} inibidor(es) de pé")
        self.go_to_sleep(timed_out=True)
        return False

    def go_to_sleep(self, timed_out):
        # Dorme uma vez só por ciclo: a fase "asleep" vai até o wake_up.
        if self.sleeping is None or self.sleeping["asleep"]:
            return
        self.sleeping["asleep"] = True
        if self.sleeping["timeout"]:
            GLib.source_remove(self.sleeping["timeout"])
            self.sleeping["timeout"] = 0
        released_ms = round((time.monotonic() - self.sleeping["start"]) * 1000)
        self.last_sleep = {"releasedMs": released_ms, "timedOut": timed_out, "lockedHintAtSleep": self.locked_hint}
        log(f"Suspend: dormindo {json.dumps(self.last_sleep)}")
        GLib.timeout_add(SLEEP_MS, self.wake_up)

    def wake_up(self):
        log("Suspend: acordou, PrepareForSleep(false)")
        self.conn.emit_signal(None, MANAGER_PATH, MANAGER, "PrepareForSleep", GLib.Variant("(b)", (False,)))
        invocation = self.sleeping["invocation"]
        self.sleeping = None
        invocation.return_value(None)
        return False

    # D-Bus

    def on_method(self, _conn, sender, path, iface, method, params, invocation):
        args = params.unpack()
        log(f"{iface}.{method}{args} de {sender}")
        if iface == MANAGER and method == "GetSession":
            invocation.return_value(GLib.Variant("(o)", (SESSION_PATH,)))
        elif iface == MANAGER and method == "CanHibernate":
            self.can_hibernate_asked += 1
            invocation.return_value(GLib.Variant("(s)", (self.can_hibernate,)))
        elif iface == MANAGER and method == "Inhibit":
            self.inhibit(*args, invocation)
        elif iface == SESSION and method == "SetLockedHint":
            self.locked_hint = args[0]
            self.changed(SESSION_PATH, SESSION, "LockedHint", GLib.Variant("b", self.locked_hint))
            invocation.return_value(None)
        elif iface == TEST and method == "Suspend":
            self.suspend(invocation)
        elif iface == TEST and method in ("LockSession", "UnlockSession"):
            signal = "Lock" if method == "LockSession" else "Unlock"
            self.conn.emit_signal(None, SESSION_PATH, SESSION, signal, None)
            invocation.return_value(None)
        elif iface == TEST and method == "SetLid":
            self.lid = args[0]
            self.changed(MANAGER_PATH, MANAGER, "LidClosed", GLib.Variant("b", self.lid))
            invocation.return_value(None)
        elif iface == TEST and method == "SetCanHibernate":
            self.can_hibernate = args[0]
            invocation.return_value(None)
        elif iface == TEST and method == "Status":
            invocation.return_value(GLib.Variant("(s)", (self.status(),)))
        else:
            invocation.return_dbus_error("org.freedesktop.DBus.Error.UnknownMethod", f"{iface}.{method} em {path}")

    def on_get(self, _conn, _sender, _path, iface, prop):
        if iface == MANAGER and prop == "LidClosed":
            return GLib.Variant("b", self.lid)
        if iface == MANAGER and prop == "Docked":
            return GLib.Variant("b", False)
        if iface == MANAGER and prop == "InhibitDelayMaxUSec":
            return GLib.Variant("t", DELAY_MAX_USEC)
        if iface == SESSION and prop == "LockedHint":
            return GLib.Variant("b", self.locked_hint)
        return None


def main():
    parser = argparse.ArgumentParser(description="O logind falso, num barramento privado.")
    parser.add_argument("--address", required=True, help="unix:path=<socket> do dbus-daemon privado")
    address = parser.parse_args().address
    path = address.removeprefix("unix:path=")
    if path == address or not path.startswith("/") or os.path.realpath(path) in SYSTEM_SOCKETS:
        sys.exit(f"logind-fake: o endereço precisa ser unix:path=<socket privado>, fora do sistema; veio {address!r}")

    flags = Gio.DBusConnectionFlags.AUTHENTICATION_CLIENT | Gio.DBusConnectionFlags.MESSAGE_BUS_CONNECTION
    conn = Gio.DBusConnection.new_for_address_sync(address, flags, None, None)
    fake = Fake(conn)
    node = Gio.DBusNodeInfo.new_for_xml(XML)
    for obj_path, iface in ((MANAGER_PATH, MANAGER), (SESSION_PATH, SESSION), (TEST_PATH, TEST)):
        conn.register_object(obj_path, node.lookup_interface(iface), fake.on_method, fake.on_get, None)

    loop = GLib.MainLoop()

    def acquired(_conn, name):
        log(f"de pé em {address} como {name}")

    def lost(_conn, name):
        log(f"perdi o nome {name} (outro dono ou o barramento caiu); saindo")
        loop.quit()

    Gio.bus_own_name_on_connection(conn, NAME, Gio.BusNameOwnerFlags.DO_NOT_QUEUE, acquired, lost)
    loop.run()
    sys.exit(1)


if __name__ == "__main__":
    main()
