pragma Singleton

import QtQuick
import Quickshell
import qs.core.config
import qs.services

// View model de Configurações → Modo jogo. O estado é do lucernad (pelo
// GameMode); aqui, o que a página mostra (a linha do estado e o efeito de cada
// item) e as preferências game* do Config, que o GameMode manda ao daemon.
Singleton {
    id: root

    readonly property bool available: GameMode.available
    readonly property bool active: GameMode.active
    readonly property string statusLine: statusLineOf(GameMode.available, GameMode.active, GameMode.since, GameMode.reasons, GameMode.unavailableNote)
    readonly property var effectRows: effectRowsOf(GameMode.effects)
    readonly property var always: Config.gameAlways ?? []
    readonly property var never: Config.gameNever ?? []
    // As classes das janelas abertas que ainda não estão em nenhuma lista.
    readonly property var openClasses: openClassesOf(Hypr.toplevels, always, never)

    // As preferências que a página liga e desliga.
    readonly property var keys: ["gameAutoFullscreen", "gameAutoGames", "gameEffects", "gameVrr", "gameTearing", "gameProfile", "gameGamemode", "gameLight", "gameWallpaper", "gameQuiet", "gameBar", "gameIdle", "gameNotices"]

    readonly property var effectLabels: [
        { id: "compositor", label: "Desfoque, sombras e animações" },
        { id: "vrr", label: "VRR em tela cheia" },
        { id: "tearing", label: "Tearing" },
        { id: "profile", label: "Perfil de desempenho" },
        { id: "gamemode", label: "GameMode da Feral" },
        { id: "light", label: "lucernad mais leve" }
    ]

    // "Ligado desde 21:14 — tela cheia, jogo", "Desligado" ou o aviso de
    // indisponível.
    function statusLineOf(isAvailable: bool, isActive: bool, since: real, reasons: var, note: string): string {
        if (!isAvailable)
            return note;
        if (!isActive)
            return "Desligado";
        const when = since > 0 ? ` desde ${Qt.formatTime(new Date(since), "HH:mm")}` : "";
        const why = GameMode.reasonsText(reasons);
        return `Ligado${when}${why ? ` — ${why}` : ""}`;
    }

    // O estado de um item, em pt-BR: "ok", "off", "unavailable" (o GameMode
    // ausente é "não instalado") ou "error: <texto>".
    function stateText(id: string, raw: string): string {
        if (raw === "ok")
            return "ativo";
        if (raw === "off")
            return "desligado";
        if (raw === "unavailable")
            return id === "gamemode" ? "não instalado" : "indisponível";
        if (raw.startsWith("error:"))
            return `erro: ${raw.slice(6).trim()}`;
        return raw;
    }

    function effectRowsOf(effects: var): var {
        return effectLabels.map(e => ({
                    id: e.id,
                    label: e.label,
                    state: stateText(e.id, String(effects?.[e.id] ?? "off"))
                }));
    }

    // Puro: as classes (minúsculas, sem repetir, em ordem) das janelas dadas,
    // menos as que já estão nas listas.
    function openClassesOf(toplevels: var, alwaysList: var, neverList: var): var {
        const listed = GameMode.cleanClasses(Array.from(alwaysList ?? []).concat(Array.from(neverList ?? [])));
        const out = [];
        for (const t of Array.from(toplevels ?? [])) {
            const cls = String(t?.lastIpcObject?.class || t?.wayland?.appId || "").trim().toLowerCase();
            if (cls !== "" && !listed.includes(cls) && !out.includes(cls))
                out.push(cls);
        }
        return out.sort();
    }

    // Renova as classes das janelas (o lastIpcObject vem do Hyprland).
    function refreshWindows(): void {
        Hypr.refreshToplevels();
    }

    function configKey(list: string): string {
        return list === "always" ? "gameAlways" : "gameNever";
    }

    // Acrescenta a classe à lista ("always" ou "never"), tirando-a da outra;
    // limpa como o daemon aceita (vazia, longa ou além de 100 não entra).
    function addClass(list: string, cls: string): void {
        const clean = GameMode.cleanClasses([cls]);
        if (clean.length === 0)
            return;
        const c = clean[0];
        const other = configKey(list === "always" ? "never" : "always");
        const target = configKey(list);
        const otherList = Array.from(Config[other] ?? []);
        if (otherList.includes(c))
            Config[other] = otherList.filter(x => x !== c);
        const current = GameMode.cleanClasses(Config[target]);
        if (!current.includes(c) && current.length < GameMode.maxClasses)
            Config[target] = current.concat([c]);
    }

    function removeClass(list: string, cls: string): void {
        const target = configKey(list);
        Config[target] = Array.from(Config[target] ?? []).filter(x => x !== cls);
    }

    // Uma preferência game* da página (outra chave não muda nada).
    function set(key: string, on: bool): void {
        if (keys.includes(key))
            Config[key] = on;
    }

    function toggleNow(): void {
        GameMode.toggle();
    }
}
