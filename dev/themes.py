#!/usr/bin/env python3
"""Gera os temas embutidos: themes/<id>.json e o papel estático de cada um
(themes/wallpapers/<id>.jpg).

Cada tema parte da paleta oficial dele. O papel estático é um fundo liso com
brilhos radiais suaves nas cores do tema (e estrelas, em alguns); um pouco de
ruído evita faixas no degradê. O animado é um dos efeitos de themes/shaders/.
Requer Pillow.

    dev/themes.py            # todos
    dev/themes.py nord       # só um
    dev/themes.py --json PASTA [ids...]   # só os JSON, na pasta dada (sem Pillow)
"""

import json
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "themes"
W, H = 2560, 1440

# Paletas: base (fundo dos painéis), surface (cartões), raised (cartão sobre
# cartão), border, text, textMuted, textFaint, accent, accentText, danger,
# success, warning e track (trilho de medidores e sliders).
THEMES = {
    "catppuccin-mocha": {
        "name": "Catppuccin Mocha",
        "description": "Pastel escuro e aconchegante: azul, malva e rosa sobre grafite azulado.",
        "colors": {
            "base": "#1e1e2e",
            "surface": "#313244",
            "raised": "#45475a",
            "border": "#585b70",
            "text": "#cdd6f4",
            "textMuted": "#bac2de",
            "textFaint": "#7f849c",
            "accent": "#89b4fa",
            "accentText": "#11111b",
            "danger": "#f38ba8",
            "success": "#a6e3a1",
            "warning": "#f9e2af",
            "track": "#45475a",
        },
        "effect": "aurora",
        "wallpaper": (
            "#181825",
            [
                (0.22, 0.2, 0.55, "#45355f", 0.55),
                (0.25, 0.22, 0.18, "#8f76b8", 0.3),
                (0.85, 0.95, 0.55, "#1f3b5c", 0.55),
                (0.6, 0.6, 0.3, "#3a2f4f", 0.25),
            ],
            360,
        ),
    },
    "tokyo-night": {
        "name": "Tokyo Night",
        "description": "Azul de madrugada com luzes de neon: azul, roxo e ciano, limpo e tecnológico.",
        "colors": {
            "base": "#1a1b26",
            "surface": "#24283b",
            "raised": "#2f3549",
            "border": "#414868",
            "text": "#c0caf5",
            "textMuted": "#a9b1d6",
            "textFaint": "#565f89",
            "accent": "#7aa2f7",
            "accentText": "#16161e",
            "danger": "#f7768e",
            "success": "#9ece6a",
            "warning": "#e0af68",
            "track": "#3b4261",
        },
        "effect": "bokeh",
        "wallpaper": (
            "#16161e",
            [(0.8, 0.85, 0.5, "#28305a", 0.6), (0.15, 0.25, 0.4, "#3b2d5c", 0.45), (0.55, 1.05, 0.35, "#1d4d63", 0.4)],
            120,
        ),
    },
    "gruvbox-dark": {
        "name": "Gruvbox Dark",
        "description": "Retrô de terminal: marrom quente, laranja e amarelo, com contraste confortável.",
        "colors": {
            "base": "#282828",
            "surface": "#3c3836",
            "raised": "#504945",
            "border": "#665c54",
            "text": "#ebdbb2",
            "textMuted": "#d5c4a1",
            "textFaint": "#928374",
            "accent": "#fe8019",
            "accentText": "#1d2021",
            "danger": "#fb4934",
            "success": "#b8bb26",
            "warning": "#fabd2f",
            "track": "#504945",
        },
        "effect": "brasas",
        "wallpaper": (
            "#1d2021",
            [(0.2, 1.05, 0.5, "#4a2a0f", 0.6), (0.75, 1.1, 0.45, "#5a3a10", 0.45), (0.45, 1.08, 0.2, "#b85c12", 0.25)],
            0,
        ),
    },
    "rose-pine": {
        "name": "Rosé Pine",
        "description": "Elegante e sóbrio: íris, rosa e espuma sobre um roxo quase preto.",
        "colors": {
            "base": "#191724",
            "surface": "#1f1d2e",
            "raised": "#26233a",
            "border": "#403d52",
            "text": "#e0def4",
            "textMuted": "#908caa",
            "textFaint": "#6e6a86",
            "accent": "#c4a7e7",
            "accentText": "#191724",
            "danger": "#eb6f92",
            "success": "#9ccfd8",
            "warning": "#f6c177",
            "track": "#403d52",
        },
        "effect": "luar",
        "wallpaper": (
            "#13111c",
            [(0.8, 0.18, 0.45, "#3a2f4f", 0.6), (0.8, 0.18, 0.06, "#ebbcba", 0.3), (0.2, 0.95, 0.5, "#1d3440", 0.45)],
            220,
        ),
    },
    "nord": {
        "name": "Nord",
        "description": "Frio e minimalista: azuis de gelo e cinzas do Ártico.",
        "colors": {
            "base": "#2e3440",
            "surface": "#3b4252",
            "raised": "#434c5e",
            "border": "#4c566a",
            "text": "#eceff4",
            "textMuted": "#d8dee9",
            "textFaint": "#7b88a1",
            "accent": "#88c0d0",
            "accentText": "#2e3440",
            "danger": "#bf616a",
            "success": "#a3be8c",
            "warning": "#ebcb8b",
            "track": "#4c566a",
        },
        "effect": "neve",
        "wallpaper": ("#242933", [(0.3, 0.1, 0.6, "#3b4a60", 0.55), (0.85, 0.9, 0.5, "#35505c", 0.45)], 90),
    },
    "everforest": {
        "name": "Everforest",
        "description": "Natural e calmo: verde de floresta e marrom de terra, fácil para os olhos.",
        "colors": {
            "base": "#2d353b",
            "surface": "#343f44",
            "raised": "#3d484d",
            "border": "#4f585e",
            "text": "#d3c6aa",
            "textMuted": "#9da9a0",
            "textFaint": "#7a8478",
            "accent": "#a7c080",
            "accentText": "#232a2e",
            "danger": "#e67e80",
            "success": "#83c092",
            "warning": "#dbbc7f",
            "track": "#475258",
        },
        "effect": "vagalumes",
        "wallpaper": (
            "#232a2e",
            [(0.5, 1.15, 0.6, "#3a4a36", 0.6), (0.15, 0.2, 0.4, "#2f3d38", 0.5), (0.8, 0.3, 0.3, "#44503a", 0.3)],
            0,
        ),
    },
    "kanagawa": {
        "name": "Kanagawa",
        "description": "Inspirado na grande onda de Hokusai: azul de tinta, papel envelhecido e dourado.",
        "colors": {
            "base": "#1f1f28",
            "surface": "#2a2a37",
            "raised": "#363646",
            "border": "#54546d",
            "text": "#dcd7ba",
            "textMuted": "#c8c093",
            "textFaint": "#727169",
            "accent": "#7e9cd8",
            "accentText": "#16161d",
            "danger": "#e46876",
            "success": "#98bb6c",
            "warning": "#e6c384",
            "track": "#363646",
        },
        "effect": "ondas",
        "wallpaper": (
            "#16161d",
            [(0.72, 0.28, 0.2, "#6b5d3a", 0.4), (0.3, 1.05, 0.6, "#223249", 0.6), (0.8, 1.1, 0.4, "#2d4f67", 0.4)],
            0,
        ),
    },
    "dracula": {
        "name": "Dracula",
        "description": "Alto contraste da madrugada: roxo, rosa e ciano sobre um cinza-azulado escuro.",
        "colors": {
            "base": "#282a36",
            "surface": "#343746",
            "raised": "#44475a",
            "border": "#6272a4",
            "text": "#f8f8f2",
            "textMuted": "#d6d6e0",
            "textFaint": "#6272a4",
            "accent": "#bd93f9",
            "accentText": "#21222c",
            "danger": "#ff5555",
            "success": "#50fa7b",
            "warning": "#f1fa8c",
            "track": "#44475a",
        },
        "effect": "aurora",
        "wallpaper": (
            "#1e1f29",
            [(0.2, 0.25, 0.5, "#4a3570", 0.55), (0.85, 0.85, 0.45, "#5c2e55", 0.45), (0.6, 0.15, 0.25, "#1f4a55", 0.3)],
            260,
        ),
    },
    "matte-black": {
        "name": "Matte Black",
        "description": "Monocromático e discreto: preto fosco e cinzas, sem cor que distraia.",
        "colors": {
            "base": "#0f0f0f",
            "surface": "#1a1a1a",
            "raised": "#242424",
            "border": "#333333",
            "text": "#e6e6e6",
            "textMuted": "#a8a8a8",
            "textFaint": "#6e6e6e",
            "accent": "#d0d0d0",
            "accentText": "#0f0f0f",
            "danger": "#cf6a6a",
            "success": "#9db38e",
            "warning": "#d6b56d",
            "track": "#2e2e2e",
        },
        "effect": "papel",
        "wallpaper": ("#0a0a0a", [(0.3, 0.3, 0.6, "#1c1c1c", 0.6), (0.8, 0.85, 0.45, "#161616", 0.5)], 0),
    },
    "decay-green": {
        "name": "Decay Green",
        "description": "Terminal hacker: verde fósforo sobre quase preto.",
        "colors": {
            "base": "#0c1210",
            "surface": "#131b18",
            "raised": "#1a2521",
            "border": "#27372f",
            "text": "#c6dccf",
            "textMuted": "#8fae9c",
            "textFaint": "#5c7a69",
            "accent": "#78dba9",
            "accentText": "#08100c",
            "danger": "#e05f65",
            "success": "#78dba9",
            "warning": "#f1cf8a",
            "track": "#22322b",
        },
        "effect": "chuva",
        "wallpaper": ("#080d0b", [(0.5, 0.5, 0.7, "#10251b", 0.6), (0.5, 0.5, 0.25, "#1a3d2c", 0.35)], 0),
    },
    "catppuccin-latte": {
        "name": "Catppuccin Latte",
        "description": "A versão clara do Catppuccin: azul e malva vivos sobre um branco-acinzentado suave.",
        "dark": False,
        "colors": {
            "base": "#eff1f5",
            "surface": "#e6e9ef",
            "raised": "#dce0e8",
            "border": "#bcc0cc",
            "text": "#4c4f69",
            "textMuted": "#5c5f77",
            "textFaint": "#8c8fa1",
            "accent": "#1e66f5",
            "accentText": "#eff1f5",
            "danger": "#d20f39",
            "success": "#40a02b",
            "warning": "#df8e1d",
            "track": "#ccd0da",
        },
        "effect": "ondas",
        "wallpaper": (
            "#e6e9ef",
            [(0.2, 0.2, 0.55, "#d6d0f5", 0.6), (0.85, 0.9, 0.55, "#cfe3f5", 0.6), (0.6, 0.35, 0.3, "#f3d9ee", 0.35)],
            0,
        ),
    },
    "rose-pine-dawn": {
        "name": "Rosé Pine Dawn",
        "description": "O Rosé Pine ao amanhecer: íris, rosa e pinho sobre um creme quente.",
        "dark": False,
        "colors": {
            "base": "#faf4ed",
            "surface": "#fffaf3",
            "raised": "#f2e9e1",
            "border": "#cecacd",
            "text": "#575279",
            "textMuted": "#797593",
            "textFaint": "#9893a5",
            "accent": "#907aa9",
            "accentText": "#faf4ed",
            "danger": "#b4637a",
            "success": "#286983",
            "warning": "#ea9d34",
            "track": "#dfdad9",
        },
        "effect": "papel",
        "wallpaper": (
            "#f4ede8",
            [(0.8, 0.18, 0.45, "#efd6d2", 0.6), (0.2, 0.9, 0.5, "#f5e3c8", 0.5), (0.5, 0.5, 0.35, "#e6dcec", 0.35)],
            0,
        ),
    },
}

DEFAULT = "catppuccin-mocha"


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) for i in (0, 2, 4))


def render(tid, base, glows, stars, seed):
    """glows: (cx, cy, raio, cor, intensidade), posições em fração da tela."""
    from PIL import Image  # só o papel estático precisa do Pillow

    rng = random.Random(seed)
    base = hex_rgb(base)
    glows = [(cx * W, cy * H, r * W, hex_rgb(c), k) for cx, cy, r, c, k in glows]
    # Calcula numa grade reduzida e amplia: o degradê é suave, não perde nada.
    sw, sh = W // 4, H // 4
    small = Image.new("RGB", (sw, sh))
    px = small.load()
    for y in range(sh):
        for x in range(sw):
            r, g, b = base
            for cx, cy, rad, col, k in glows:
                dx, dy = x * 4 - cx, y * 4 - cy
                t = max(0.0, 1.0 - (dx * dx + dy * dy) ** 0.5 / rad)
                t = t * t * (3 - 2 * t) * k
                r += (col[0] - r) * t
                g += (col[1] - g) * t
                b += (col[2] - b) * t
            px[x, y] = (int(r), int(g), int(b))
    img = small.resize((W, H), Image.BICUBIC)
    big = img.load()
    for y in range(H):
        for x in range(W):
            n = rng.randint(-2, 2)
            r, g, b = big[x, y]
            big[x, y] = (max(0, min(255, r + n)), max(0, min(255, g + n)), max(0, min(255, b + n)))
    for _ in range(stars):
        x, y = rng.randrange(W), rng.randrange(int(H * 0.7))
        v = rng.randint(90, 200)
        big[x, y] = (v, v, min(255, v + 20))
    img.save(ROOT / "wallpapers" / f"{tid}.jpg", quality=90, optimize=True)


def theme_json(tid, t):
    c = t["colors"]
    return {
        "name": t["name"],
        "description": t["description"],
        "dark": t.get("dark", True),
        "colors": c,
        "font": {
            "sans": "Rubik",
            "mono": "CaskaydiaCove Nerd Font",
            "icon": "Material Symbols Rounded",
            "size": {"small": 11, "normal": 13, "large": 16, "huge": 44},
        },
        "radius": {"small": 8, "normal": 14, "large": 22},
        "spacing": {"tiny": 4, "small": 8, "normal": 12, "large": 20},
        "animation": {"scale": 1},
        "bar": {"height": 44},
        "wallpaper": {"static": f"wallpapers/{tid}.jpg", "shader": f"shaders/{t['effect']}.qsb"},
        "hyprland": {
            "activeBorder": c["accent"],
            "inactiveBorder": c["border"],
            "borderSize": 2,
            "rounding": 12,
            "blurSize": 6,
            "blurPasses": 2,
        },
        "transparency": {"enabled": True, "base": 0.85, "layers": 0.45},
        "surfaces": {"outline": False},
        "fonts": ["fonts/Rubik[wght].ttf"],
    }


def write_json(folder, tid):
    text = json.dumps(theme_json(tid, THEMES[tid]), indent=4, ensure_ascii=False) + "\n"
    (folder / f"{tid}.json").write_text(text, encoding="utf-8")


def main():
    args = sys.argv[1:]
    if args[:1] == ["--json"]:
        if len(args) < 2:
            sys.exit("uso: dev/themes.py --json PASTA [ids...]")
        folder, only = Path(args[1]), args[2:] or list(THEMES)
        folder.mkdir(parents=True, exist_ok=True)
        for tid in THEMES:
            if tid in only:
                write_json(folder, tid)
        return
    only = args or list(THEMES)
    (ROOT / "wallpapers").mkdir(exist_ok=True)
    for i, tid in enumerate(THEMES):
        if tid not in only:
            continue
        write_json(ROOT, tid)
        base, glows, stars = THEMES[tid]["wallpaper"]
        render(tid, base, glows, stars, seed=i + 3)
        print("ok", tid)


if __name__ == "__main__":
    main()
