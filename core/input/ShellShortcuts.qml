pragma Singleton

import QtQuick
import Quickshell

// Os atalhos do próprio shell: os padrões e o que o usuário mudou
// (Config.shellShortcuts: { <id da ação>: [{ mods, trigger }] }; lista vazia = sem
// atalho). Só dados: a feature input aplica e as configurações editam.
// No ambiente de desenvolvimento o Mod é Alt (o Hyprland de fora fica com o Super).
Singleton {
    id: root

    readonly property string mod: Quickshell.env("LUCERNA_DEV") === "1" ? "ALT" : "SUPER"

    readonly property var defaults: [
        { id: "launcher", keys: [{ mods: mod, trigger: "space" }] },
        { id: "dashboard", keys: [{ mods: mod, trigger: "d" }] },
        { id: "settings", keys: [{ mods: mod, trigger: "s" }] },
        { id: "actions", keys: [{ mods: mod, trigger: "a" }] },
        { id: "notifications", keys: [{ mods: mod, trigger: "n" }] },
        { id: "central", keys: [{ mods: mod, trigger: "c" }] },
        { id: "overview", keys: [{ mods: mod, trigger: "Tab" }] },
        { id: "clipboard", keys: [{ mods: mod, trigger: "v" }] },
        { id: "themes", keys: [{ mods: mod, trigger: "t" }] },
        { id: "capture", keys: [{ mods: "", trigger: "Print" }] },
        { id: "capture-screen", keys: [{ mods: "SHIFT", trigger: "Print" }] },
        { id: "capture-window", keys: [{ mods: "CTRL", trigger: "Print" }] },
        { id: "record", keys: [{ mods: mod, trigger: "Print" }] },
        { id: "power", keys: [{ mods: mod, trigger: "Escape" }] },
        { id: "lock", keys: [{ mods: mod, trigger: "l" }] },
        { id: "dnd", keys: [] },
        { id: "game", keys: [] },
        { id: "bar", keys: [] },
        { id: "volume-up", keys: [{ mods: "", trigger: "XF86AudioRaiseVolume" }] },
        { id: "volume-down", keys: [{ mods: "", trigger: "XF86AudioLowerVolume" }] },
        { id: "mute", keys: [{ mods: "", trigger: "XF86AudioMute" }] },
        { id: "mic-mute", keys: [{ mods: "", trigger: "XF86AudioMicMute" }] },
        { id: "play-pause", keys: [{ mods: "", trigger: "XF86AudioPlay" }] },
        { id: "next", keys: [{ mods: "", trigger: "XF86AudioNext" }] },
        { id: "previous", keys: [{ mods: "", trigger: "XF86AudioPrev" }] },
        { id: "brightness-up", keys: [{ mods: "", trigger: "XF86MonBrightnessUp" }] },
        { id: "brightness-down", keys: [{ mods: "", trigger: "XF86MonBrightnessDown" }] }
    ]

    // Ids que mudaram de nome (o novo → o antigo): a tecla que o usuário
    // salvou no antigo vale no novo até ele mudar a do novo.
    readonly property var renamed: ({ central: "sidebar" })

    // [{ id, keys, custom }] com as mudanças do usuário por cima dos padrões.
    function effective(overrides: var): var {
        const own = overrides ?? {};
        return defaults.map(d => {
            const mine = own[d.id] ?? own[renamed[d.id]];
            return { id: d.id, keys: mine ?? d.keys, custom: mine !== undefined };
        });
    }

    // As mudanças do usuário com as teclas novas de um atalho: as padrão
    // apagam a mudança (restaurar), as outras ficam no id. A chave do nome
    // antigo sai sempre, senão o `effective` voltaria a lê-la.
    function withKeys(overrides: var, id: string, keys: var): var {
        const all = Object.assign({}, overrides ?? {});
        const old = renamed[id];
        if (old)
            delete all[old];
        const defaults = defaultKeys(id);
        if (keys.length === defaults.length && keys.every((k, i) => same(k, defaults[i])))
            delete all[id];
        else
            all[id] = keys;
        return all;
    }

    function defaultKeys(id: string): var {
        return defaults.find(d => d.id === id)?.keys ?? [];
    }

    // Modificadores em ordem fixa, para comparar e para montar a tecla do bind.
    function normalizeMods(mods: string): string {
        const set = String(mods ?? "").toUpperCase().split(/[\s+]+/).filter(m => m);
        return ["SUPER", "CTRL", "ALT", "SHIFT"].filter(m => set.includes(m)).join(" ");
    }

    function same(a: var, b: var): bool {
        return normalizeMods(a.mods) === normalizeMods(b.mods) && String(a.trigger).toLowerCase() === String(b.trigger).toLowerCase();
    }

    // "SUPER + SHIFT + q" → { mods: "SUPER SHIFT", trigger: "q" }.
    function fromKey(key: string): var {
        const parts = String(key).split(" + ");
        return { mods: parts.slice(0, -1).join(" "), trigger: parts[parts.length - 1] };
    }

    // Bits do Hyprland (modmask em `hyprctl binds -j`).
    function modsFromMask(mask: int): string {
        const out = [];
        if (mask & 64)
            out.push("SUPER");
        if (mask & 4)
            out.push("CTRL");
        if (mask & 8)
            out.push("ALT");
        if (mask & 1)
            out.push("SHIFT");
        return out.join(" ");
    }
}
