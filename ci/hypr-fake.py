#!/usr/bin/env python3
"""O Hyprland falso da fumaça (ci/smoke.sh), para a fase "modo jogo".

Serve os dois sockets de uma instância do Hyprland em
<pasta>/hypr/fumaca/ (o .socket.sock dos pedidos e o .socket2.sock dos
eventos, que só aceita a conexão e nunca manda nada). O lucernad chega aqui
pelo XDG_RUNTIME_DIR=<pasta> e HYPRLAND_INSTANCE_SIGNATURE=fumaca, só no
ambiente dele: o shell no sway não vê este Hyprland. Só a biblioteca padrão;
roda com `python3 -I`.

  ci/hypr-fake.py <pasta>

O estado são as cinco opções que o modo jogo mexe, começando como um
Hyprland de fábrica (desfoque, sombras e animações ligados, VRR em 0, tearing
desligado). Pedidos:

- `j/getoption <nome>` de uma das cinco → {"option", "bool"|"int", "set"};
  outro nome → "no such option".
- `eval hl.config({...})`: aplica as cinco opções que aparecem na tabela (o
  resto é ignorado) e responde "ok"; outro `eval` (o set_prop do tearing) →
  "ok" sem mudar nada.
- `j/clients` → []; `j/monitors` → um monitor no workspace 1; `j/version` →
  a versão 0.56.2.
- Outro pedido → "unknown request".

Cada pedido vai numa linha para stderr (o log da fumaça), e o estado atual é
gravado em <pasta>/hypr/fumaca/estado.json (escrita atômica) no começo e a
cada mudança.
"""

import json
import os
import socket
import sys
import threading

OPTIONS = {
    "decoration:blur:enabled": ("bool", True),
    "decoration:shadow:enabled": ("bool", True),
    "animations:enabled": ("bool", True),
    "misc:vrr": ("int", 0),
    "general:allow_tearing": ("bool", False),
}


class LuaError(ValueError):
    pass


def tokens(text):
    """Os tokens de uma tabela Lua simples: { } = , nomes, ["chave"],
    números, true/false e strings entre aspas."""
    out = []
    i = 0
    while i < len(text):
        c = text[i]
        if c.isspace():
            i += 1
        elif c in "{}=,":
            out.append(c)
            i += 1
        elif c == "[":
            end = text.index("]", i)
            out.append(("name", json.loads(text[i + 1 : end])))
            i = end + 1
        elif c == '"':
            end = i + 1
            while text[end] != '"':
                end += 2 if text[end] == "\\" else 1
            out.append(("value", text[i + 1 : end]))
            i = end + 1
        else:
            end = i
            while end < len(text) and (text[end].isalnum() or text[end] in "_.-"):
                end += 1
            if end == i:
                raise LuaError(f"caractere inesperado: {c!r}")
            word = text[i:end]
            if word in ("true", "false"):
                out.append(("value", word == "true"))
            elif word[0].isdigit() or word[0] in "-.":
                out.append(("value", float(word) if "." in word else int(word)))
            else:
                out.append(("name", word))
            i = end
    return out


def table(toks, pos):
    """A tabela que começa em toks[pos] ('{'): (dicionário, posição depois)."""
    if toks[pos] != "{":
        raise LuaError("esperava {")
    pos += 1
    out = {}
    while toks[pos] != "}":
        kind, key = toks[pos]
        if kind != "name" or toks[pos + 1] != "=":
            raise LuaError("esperava nome =")
        pos += 2
        if toks[pos] == "{":
            value, pos = table(toks, pos)
        else:
            value = toks[pos][1]
            pos += 1
        out[key] = value
        if toks[pos] == ",":
            pos += 1
    return out, pos + 1


def flatten(tree, prefix=""):
    for key, value in tree.items():
        name = f"{prefix}{key}"
        if isinstance(value, dict):
            yield from flatten(value, name + ":")
        else:
            yield name, value


class Fake:
    def __init__(self, folder):
        self.dir = os.path.join(folder, "hypr", "fumaca")
        os.makedirs(self.dir, exist_ok=True)
        self.state = {name: value for name, (_, value) in OPTIONS.items()}
        self.lock = threading.Lock()
        self.save()

    def save(self):
        path = os.path.join(self.dir, "estado.json")
        with open(path + ".tmp", "w", encoding="utf-8") as f:
            json.dump(self.state, f, sort_keys=True)
        os.replace(path + ".tmp", path)

    def answer(self, command):
        if command.startswith("j/getoption "):
            name = command[len("j/getoption ") :].strip()
            if name not in OPTIONS:
                return "no such option"
            kind = OPTIONS[name][0]
            with self.lock:
                return json.dumps({"option": name, kind: self.state[name], "set": True})
        if command.startswith("eval "):
            lua = command[len("eval ") :].strip()
            if not (lua.startswith("hl.config(") and lua.endswith(")")):
                return "ok"
            try:
                toks = tokens(lua[len("hl.config(") : -1])
                tree, _ = table(toks, 0)
            except (LuaError, ValueError, IndexError, TypeError) as e:
                return f"error: Lua inválido ({e})"
            with self.lock:
                changed = False
                for name, value in flatten(tree):
                    if name in OPTIONS:
                        kind = OPTIONS[name][0]
                        self.state[name] = bool(value) if kind == "bool" else int(value)
                        changed = True
                if changed:
                    self.save()
            return "ok"
        if command == "j/clients":
            return "[]"
        if command == "j/monitors":
            return json.dumps(
                [{"id": 0, "name": "FUMACA-1", "activeWorkspace": {"id": 1}, "specialWorkspace": {"id": 0}}]
            )
        if command == "j/version":
            return json.dumps({"version": "0.56.2", "tag": "v0.56.2"})
        return "unknown request"

    def serve_requests(self, server):
        while True:
            conn, _ = server.accept()
            with conn:
                data = b""
                while True:
                    chunk = conn.recv(65536)
                    if not chunk:
                        break
                    data += chunk
                command = data.decode("utf-8", "replace")
                reply = self.answer(command)
                print(f"pedido: {command} -> {reply}", file=sys.stderr, flush=True)
                conn.sendall(reply.encode("utf-8"))

    def serve_events(self, server):
        # Os eventos: aceita e segura as conexões abertas, sem mandar nada.
        held = []
        while True:
            conn, _ = server.accept()
            held.append(conn)


def listen(path):
    if os.path.exists(path):
        os.unlink(path)
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.bind(path)
    s.listen(16)
    return s


def main():
    if len(sys.argv) != 2:
        print("uso: ci/hypr-fake.py <pasta>", file=sys.stderr)
        return 64
    fake = Fake(sys.argv[1])
    requests = listen(os.path.join(fake.dir, ".socket.sock"))
    events = listen(os.path.join(fake.dir, ".socket2.sock"))
    threading.Thread(target=fake.serve_events, args=(events,), daemon=True).start()
    print(f"Hyprland falso em {fake.dir}", file=sys.stderr, flush=True)
    fake.serve_requests(requests)
    return 0


if __name__ == "__main__":
    sys.exit(main())
