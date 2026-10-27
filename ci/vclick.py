#!/usr/bin/env python3
"""Um clique do botão esquerdo num ponto da tela, por um ponteiro virtual
(zwlr_virtual_pointer_v1, que o sway e o Hyprland têm), falando o protocolo
Wayland direto no socket: a fumaça e o roteiro de teste clicam na pílula da
barra sem ferramenta de fora. Só a biblioteca padrão. Com `move` no fim, só
leva o ponteiro até lá, sem clicar (o mouse encostado no topo).

    ci/vclick.py X Y [LARGURA ALTURA] [move]   (padrão 1920x1080, a saída da fumaça)
"""

import os
import socket
import struct
import sys
import time

args = sys.argv[1:]
only_move = args[-1:] == ["move"]
if only_move:
    args = args[:-1]
x, y = int(args[0]), int(args[1])
W, H = (int(args[2]), int(args[3])) if len(args) > 3 else (1920, 1080)

sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
sock.connect(os.path.join(os.environ["XDG_RUNTIME_DIR"], os.environ["WAYLAND_DISPLAY"]))


def wstr(s):
    b = s.encode() + b"\0"
    pad = (4 - len(b) % 4) % 4
    return struct.pack("<I", len(b)) + b + b"\0" * pad


def send(obj, op, payload=b""):
    sock.sendall(struct.pack("<II", obj, ((8 + len(payload)) << 16) | op) + payload)


buf = b""


def read_events(until_sync):
    """Lê os eventos até o `done` do wl_callback `until_sync`."""
    global buf
    events = []
    while True:
        while len(buf) < 8:
            buf += sock.recv(4096)
        obj, word = struct.unpack("<II", buf[:8])
        size, op = word >> 16, word & 0xFFFF
        while len(buf) < size:
            buf += sock.recv(4096)
        events.append((obj, op, buf[8:size]))
        buf = buf[size:]
        if obj == until_sync and op == 0:
            return events


send(1, 1, struct.pack("<I", 2))  # get_registry -> 2
send(1, 0, struct.pack("<I", 3))  # sync -> 3
manager = None
for obj, op, data in read_events(3):
    if obj == 2 and op == 0:
        name = struct.unpack("<I", data[:4])[0]
        n = struct.unpack("<I", data[4:8])[0]
        iface = data[8 : 8 + n - 1].decode()
        if iface == "zwlr_virtual_pointer_manager_v1":
            manager = name
if manager is None:
    sys.exit("sem zwlr_virtual_pointer_manager_v1")
send(2, 0, struct.pack("<I", manager) + wstr("zwlr_virtual_pointer_manager_v1") + struct.pack("<II", 1, 4))
send(4, 0, struct.pack("<II", 0, 5))  # create_virtual_pointer(seat nulo) -> 5
t = int(time.monotonic() * 1000) & 0xFFFFFFFF
send(5, 1, struct.pack("<IIIII", t, x, y, W, H))  # motion_absolute
send(5, 4)  # frame
if not only_move:
    time.sleep(0.05)
    send(5, 2, struct.pack("<III", t + 50, 0x110, 1))  # BTN_LEFT pressionado
    send(5, 4)
    time.sleep(0.05)
    send(5, 2, struct.pack("<III", t + 100, 0x110, 0))  # solto
    send(5, 4)
send(1, 0, struct.pack("<I", 6))
read_events(6)
time.sleep(0.1)
