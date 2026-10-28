pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core.config
import qs.core.frame
import qs.core.panels
import qs.core.theme
import qs.services

// Papel de parede de cada monitor: de onde vem (o tema ativo ou o de outro
// tema), o modo (auto, animado ou estático) e se deve animar agora. Todos os
// sinais de pausa se juntam aqui, numa decisão por monitor; a ui só liga ou
// desliga a animação.
Singleton {
    id: root

    readonly property int fadeDuration: ThemeManager.anim.extraLarge
    readonly property var monitors: Config.wallpaperMonitors ?? {}

    function nameOf(screen: var): string {
        return screen?.name ?? "";
    }

    // Tema cujo papel o monitor usa (o ativo, se não escolheu outro).
    function sourceTheme(screen: var): string {
        const own = monitors[nameOf(screen)]?.source ?? "";
        return own && ThemeManager.themes.some(t => t.id === own) ? own : ThemeManager.current;
    }

    // { static, shader, fps } daquele monitor.
    function source(screen: var): var {
        return ThemeManager.wallpaperFor(sourceTheme(screen));
    }

    function mode(screen: var): string {
        return monitors[nameOf(screen)]?.mode ?? Config.wallpaperMode;
    }

    function setMonitor(name: string, fields: var): void {
        const all = Object.assign({}, monitors);
        const entry = Object.assign({}, all[name] ?? {}, fields);
        for (const k of Object.keys(entry)) {
            if (entry[k] === "" || entry[k] === null)
                delete entry[k];
        }
        if (Object.keys(entry).length)
            all[name] = entry;
        else
            delete all[name];
        Config.wallpaperMonitors = all;
    }

    // Se o animado (efeito ou vídeo) aparece, em vez da imagem parada: depende
    // do modo, de o papel ser animado e, no auto, de estar na tomada.
    function showsEffect(screen: var): bool {
        const m = mode(screen);
        const s = source(screen);
        if (m === "static" || (!s.shader && s.kind !== "video"))
            return false;
        if (m === "auto" && Config.wallpaperBatteryStatic && Battery.available && Battery.onBattery)
            return false;
        return true;
    }

    // Se o animado deve rodar agora. Pausado, o último quadro fica na tela e o
    // custo cai a zero (nada redesenha). Tela bloqueada, app em tela cheia ou
    // tela apagada pausam; no modo estrito, qualquer janela no workspace também.
    // Também pausa sob um painel desfocado (blurCovers) e, antes de tudo, no
    // modo jogo (gamePauses).
    function shouldAnimate(screen: var): bool {
        if (gamePauses(GameMode.active, Config.gameWallpaper))
            return false;
        if (!showsEffect(screen) || Session.locked)
            return false;
        if (blurCovers(screen, ThemeManager.transparency.enabled && ThemeManager.blur.enabled, Panels.surfaces, Frame.windows))
            return false;
        if (Hypr.hasFullscreen(screen) || Hypr.isDpmsOff(screen))
            return false;
        if (Config.wallpaperStrict && !Hypr.isScreenEmpty(screen))
            return false;
        return true;
    }

    // O modo jogo pausa o papel (o mesmo caminho das outras pausas: o último
    // quadro fica), se o item estiver ligado nas configurações.
    function gamePauses(active: bool, enabled: bool): bool {
        return active && enabled;
    }

    // Uma camada desfocada grande cobre a tela: um painel aberto (surfaces com
    // `screen` e `open`; a barra e as janelas de monitores também se registram
    // no Panels, mas não têm `open`) ou a janela da forma da moldura à mostra com algum pedaço além
    // da pílula da barra (windows, com `targetScreen` e `parts`). Só a pílula
    // não conta: com a barra na área de trabalho vazia (barOnEmpty), o papel
    // nunca andaria. Pausa, não baixa o FPS: cada quadro do papel suja o
    // fundo que o Hyprland guarda para o desfoque (o do xray) e o refaz na
    // tela inteira; parado, o custo é zero. Os popups de notificação e as
    // janelas de monitores não entram (pequenos e passageiros: o papel
    // piscaria).
    function blurCovers(screen: var, blurOn: bool, surfaces: var, windows: var): bool {
        if (!blurOn)
            return false;
        return surfaces.some(w => w.open === true && w.screen === screen && w.visible) || windows.some(w => w.targetScreen === screen && w.visible && (w.parts ?? []).some(p => p.role !== "pill"));
    }

    // Vídeos: cada tela toca a versão feita para ela (resolução, proporção,
    // ajuste e fps). Enquanto ela não fica pronta, toca a mais parecida.
    readonly property var variants: Config.videoVariants ?? {}

    // Os vídeos mantêm a taxa escolhida também na bateria: decodificados pela
    // GPU, o custo quase não muda, e trocar de versão na bateria exigiria
    // converter justo quando não se quer gastar.
    function targetFor(screen: var): var {
        return VideoWallpapers.targetFor(screen, Config.wallpaperFill !== "fit", chosenFps);
    }

    // A versão mais parecida com a tela: mesma forma de ajustar, proporção
    // mais próxima e, entre essas, o tamanho mais próximo (maior é melhor que menor).
    function closest(list: var, target: var): var {
        let best = null;
        let bestScore = Infinity;
        for (const key of Object.keys(list)) {
            const t = VideoWallpapers.parseKey(key);
            if (!t)
                continue;
            const aspect = Math.abs(Math.log((t.width / t.height) / (target.width / target.height)));
            const size = Math.log((t.width * t.height) / (target.width * target.height));
            const score = (t.crop === target.crop ? 0 : 10) + aspect * 4 + (size < 0 ? -size * 1.5 : size * 0.5);
            if (score < bestScore) {
                bestScore = score;
                best = list[key];
            }
        }
        return best;
    }

    function videoFor(screen: var): string {
        const s = source(screen);
        if (s.kind !== "video")
            return "";
        const list = variants[s.source] ?? {};
        const target = targetFor(screen);
        return (list[VideoWallpapers.keyOf(target)] ?? closest(list, target))?.video ?? "";
    }

    // Resoluções comuns, para a preparação antecipada (opcional).
    readonly property var commonTargets: [[1920, 1080], [2560, 1440], [3840, 2160], [2560, 1080], [3440, 1440], [1920, 1200], [2560, 1600]]

    // Vídeos que algum tema (que ainda existe) usa.
    readonly property var videoSources: Object.keys(Config.themeWallpapers ?? {}).filter(id => ThemeManager.themes.some(t => t.id === id)).map(id => Config.themeWallpapers[id]).filter(c => c?.kind === "video" && c.source).map(c => c.source)

    // Pede o que falta: a versão de cada tela que mostra vídeo e, com a
    // preparação antecipada ligada e na tomada, as das resoluções comuns.
    function ensure(): void {
        if (!VideoWallpapers.ffmpeg)
            return;
        const now = Date.now();
        const touched = {};
        for (const screen of Quickshell.screens) {
            const s = source(screen);
            if (s.kind !== "video")
                continue;
            const target = targetFor(screen);
            const key = VideoWallpapers.keyOf(target);
            if ((variants[s.source] ?? {})[key])
                (touched[s.source] = touched[s.source] ?? []).push(key);
            else
                VideoWallpapers.request(s.source, target, false);
        }
        if (Config.wallpaperVideoPrecache && !(Battery.available && Battery.onBattery)) {
            for (const src of videoSources) {
                for (const [w, h] of commonTargets) {
                    const target = { width: w, height: h, crop: Config.wallpaperFill !== "fit", fps: chosenFps };
                    if (!(variants[src] ?? {})[VideoWallpapers.keyOf(target)])
                        VideoWallpapers.request(src, target, true);
                }
            }
        }
        // Marca como usadas as versões à mostra (para a limpeza).
        if (Object.keys(touched).length) {
            const all = Object.assign({}, variants);
            for (const src of Object.keys(touched)) {
                all[src] = Object.assign({}, all[src]);
                for (const key of touched[src])
                    all[src][key] = Object.assign({}, all[src][key], { used: now });
            }
            Config.videoVariants = all;
        }
    }

    readonly property int maxVariants: 8

    // Guarda a versão pronta; cada vídeo fica com no máximo oito, saindo as
    // usadas há mais tempo.
    function store(src: string, key: string, video: string, poster: string): void {
        const all = Object.assign({}, variants);
        const list = Object.assign({}, all[src] ?? {});
        list[key] = { video, poster, used: Date.now() };
        const keys = Object.keys(list).sort((a, b) => (list[b].used ?? 0) - (list[a].used ?? 0));
        const drop = keys.slice(maxVariants);
        VideoWallpapers.remove(drop.reduce((files, k) => files.concat([list[k].video, list[k].poster]), []));
        for (const k of drop)
            delete list[k];
        all[src] = list;
        Config.videoVariants = all;
    }

    // Vídeos que nenhum tema usa mais saem do cache (e da fila).
    function cleanup(): void {
        const all = Object.assign({}, variants);
        let changed = false;
        for (const src of Object.keys(all)) {
            if (videoSources.includes(src))
                continue;
            VideoWallpapers.remove(Object.values(all[src]).reduce((files, v) => files.concat([v.video, v.poster]), []));
            VideoWallpapers.forget(src);
            delete all[src];
            changed = true;
        }
        if (changed)
            Config.videoVariants = all;
    }

    Connections {
        target: VideoWallpapers

        function onReady(source, key, video, poster) {
            root.store(source, key, video, poster);
        }

        function onFfmpegChanged() {
            ensureDelay.restart();
        }
    }

    // O que pode pedir versões novas: telas, papéis, ajuste, fps, bateria.
    Timer {
        id: ensureDelay

        interval: 400
        onTriggered: {
            root.cleanup();
            root.ensure();
        }
    }

    Connections {
        target: Quickshell

        function onScreensChanged() {
            ensureDelay.restart();
        }
    }

    Connections {
        target: Config

        function onThemeWallpapersChanged() {
            ensureDelay.restart();
        }

        function onWallpaperFillChanged() {
            ensureDelay.restart();
        }

        function onWallpaperFpsChanged() {
            ensureDelay.restart();
        }

        function onWallpaperVideoPrecacheChanged() {
            ensureDelay.restart();
        }

        function onWallpaperMonitorsChanged() {
            ensureDelay.restart();
        }

        function onThemeChanged() {
            ensureDelay.restart();
        }
    }

    Connections {
        target: Battery

        function onOnBatteryChanged() {
            ensureDelay.restart();
        }
    }

    Component.onCompleted: ensureDelay.restart()

    // Taxa escolhida: 30 ou 60 (configs antigas com 15 ou 24 contam como 30).
    readonly property int chosenFps: Config.wallpaperFps >= 45 ? 60 : 30

    // Taxa dos efeitos numa tela: a escolhida, 30 na bateria e nunca acima da
    // do monitor.
    function effectFps(screen: var): int {
        const wanted = chosenFps === 60 && Battery.available && Battery.onBattery ? 30 : chosenFps;
        const refresh = Monitors.monitors.find(m => m.name === screen?.name)?.refresh ?? 60;
        return Math.max(1, Math.min(wanted, Math.round(refresh)));
    }
    readonly property bool fullRes: Config.wallpaperFullRes
    readonly property int fill: Config.wallpaperFill === "fit" ? Image.PreserveAspectFit : Image.PreserveAspectCrop

    IpcHandler {
        target: "wallpaper"

        // Modo geral: auto, animated, static ou toggle (entre animado e estático).
        function mode(mode: string): void {
            if (mode === "toggle")
                Config.wallpaperMode = Config.wallpaperMode === "static" ? "animated" : "static";
            else if (["auto", "animated", "static"].includes(mode))
                Config.wallpaperMode = mode;
        }

        // Modo de um monitor (auto, animated, static; default volta ao geral).
        function modeFor(monitor: string, mode: string): void {
            root.setMonitor(monitor, { mode: ["auto", "animated", "static"].includes(mode) ? mode : "" });
        }

        function get(): string {
            return Config.wallpaperMode;
        }
    }
}
