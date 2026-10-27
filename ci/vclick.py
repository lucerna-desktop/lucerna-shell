#!/usr/bin/env python3
"""Um clique do botão esquerdo num ponto da tela, por um ponteiro virtual
(zwlr_virtual_pointer_v1, que o sway e o Hyprland têm), falando o protocolo
Wayland direto no socket: a fumaça e o roteiro de teste clicam na pílula da
barra sem ferramenta de fora. Só a biblioteca padrão. Com `move` no fim, só
leva o ponteiro até lá, sem clicar (o mouse encostado no topo). Com `--path`,
um caminho num ponteiro só: `X,Y` move, um número espera tantos segundos e
`click` clica onde está. No sway, o ponteiro some quando o processo sai (era
o único), e a janela embaixo dele recebe a saída do mouse: um hover que
precisa durar vai inteiro num `--path`.

    ci/vclick.py X Y [LARGURA ALTURA] [move]   (padrão 1920x1080, a saída da fumaça)
    ci/vclick.py --path 960,0 0.3 960,21 1 click
"""

import os
import socket
import struct
import sys
import time

W, H = 1920, 1080
# Os passos: ("move", x, y), ("wait", segundos) ou ("click",).
if sys.argv[1:2] == ["--path"]:
    steps = []
    for token in sys.argv[2:]:
        if token == "click":
            steps.append(("click",))
        elif "," in token:
            px, py = token.split(",")
            steps.append(("move", int(px), int(py)))
        else:
            steps.append(("wait", float(token)))
else:
    args = sys.argv[1:]
    only_move = args[-1:] == ["move"]
    if only_move:
        args = args[:-1]
    if len(args) > 3:
        W, H = int(args[2]), int(args[3])
    steps = [("move", int(args[0]), int(args[1]))] + ([] if only_move else [("click",)])

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



def now():
    return int(time.monotonic() * 1000) & 0xFFFFFFFF


for step in steps:
    if step[0] == "move":
        send(5, 1, struct.pack("<IIIII", now(), step[1], step[2], W, H))  # motion_absolute
        send(5, 4)  # frame
    elif step[0] == "wait":
        time.sleep(step[1])
    else:
        time.sleep(0.05)
        send(5, 2, struct.pack("<III", now(), 0x110, 1))  # BTN_LEFT pressionado
        send(5, 4)
        time.sleep(0.05)
        send(5, 2, struct.pack("<III", now(), 0x110, 0))  # solto
        send(5, 4)
send(1, 0, struct.pack("<I", 6))
read_events(6)
time.sleep(0.1)
