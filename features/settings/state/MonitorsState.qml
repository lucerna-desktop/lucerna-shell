pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core.config
import qs.core.panels
import qs.services

// View model de Configurações → Monitores. As mudanças vão para um rascunho
// (`draft`) até aplicar; aplicado, o arranjo fica valendo por um prazo e volta
// ao anterior se não for confirmado (uma tela que não liga não prende ninguém).
// Confirmado, é salvo para o conjunto de monitores conectado.
Singleton {
    id: root

    readonly property var live: Monitors.monitors
    readonly property string setup: Monitors.setup

    property var draft: []
    property string selected: ""
    // O usuário mexeu no rascunho desde a última sincronização.
    property bool editing: false

    readonly property var current: draft.find(m => m.name === selected) ?? draft[0] ?? null
    readonly property var placed: draft.filter(m => m.enabled && !m.mirror)
    readonly property bool dirty: editing && JSON.stringify(draft.map(fieldsOf)) !== JSON.stringify(live.map(fieldsOf))
    readonly property int enabledCount: draft.filter(m => m.enabled).length

    readonly property var fields: ["enabled", "width", "height", "refresh", "x", "y", "scale", "transform", "vrr", "tenBit", "mirror"]

    function fieldsOf(spec: var): var {
        const out = { name: spec.name };
        for (const f of fields)
            out[f] = spec[f];
        return out;
    }

    function copy(list: var): var {
        return list.map(m => Object.assign({}, m));
    }

    function sync(): void {
        draft = copy(live);
        editing = false;
        if (!draft.some(m => m.name === selected))
            selected = (draft.find(m => m.focused) ?? draft[0])?.name ?? "";
    }

    onLiveChanged: {
        if (!editing)
            sync();
    }
    onSetupChanged: sync()

    function select(name: string): void {
        selected = name;
    }

    // Número de cada monitor (o mesmo no canvas e em "Identificar").
    function numberOf(name: string): int {
        return draft.findIndex(m => m.name === name) + 1;
    }

    function rectOf(spec: var): var {
        const size = Monitors.logicalSize(spec);
        return { x: spec.x, y: spec.y, w: size.width, h: size.height };
    }

    // Área ocupada pelos monitores posicionados, para o canvas enquadrar.
    readonly property var bounds: {
        const rects = placed.map(rectOf);
        if (!rects.length)
            return { x: 0, y: 0, w: 1920, h: 1080 };
        const x = Math.min(...rects.map(r => r.x));
        const y = Math.min(...rects.map(r => r.y));
        return { x, y, w: Math.max(...rects.map(r => r.x + r.w)) - x, h: Math.max(...rects.map(r => r.y + r.h)) - y };
    }

    function update(name: string, changes: var): void {
        draft = draft.map(m => m.name === name ? Object.assign({}, m, changes) : m);
        editing = true;
    }

    // Leva o arranjo para começar em 0,0.
    function normalize(): void {
        const rects = placed.map(rectOf);
        if (!rects.length)
            return;
        const dx = Math.min(...rects.map(r => r.x));
        const dy = Math.min(...rects.map(r => r.y));
        if (dx || dy)
            draft = draft.map(m => m.enabled && !m.mirror ? Object.assign({}, m, { x: m.x - dx, y: m.y - dy }) : m);
    }

    function overlaps(a: var, b: var): bool {
        return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h;
    }

    // Encaixe: a posição mais próxima de (x, y) colada numa borda de outro
    // monitor, sem sobrepor nenhum. Perto de um alinhamento (topo, base ou
    // centro), puxa para ele. `pull` é a distância do puxão, em pixels lógicos.
    // `targets`: a quem pode colar (nomes); sem isso, qualquer outro.
    function snap(name: string, x: real, y: real, pull: real, targets: var): var {
        const me = draft.find(m => m.name === name);
        if (!me)
            return { x, y };
        const size = Monitors.logicalSize(me);
        const others = placed.filter(m => m.name !== name).map(rectOf);
        const edges = targets ? placed.filter(m => targets.includes(m.name)).map(rectOf) : others;
        if (!edges.length)
            return { x: 0, y: 0 };

        // Ao longo da borda: puxa para os alinhamentos e mantém um bom trecho em comum.
        function along(pos: real, start: real, length: real, own: real): real {
            for (const v of [start, start + length - own, start + (length - own) / 2]) {
                if (Math.abs(pos - v) <= pull)
                    return v;
            }
            const keep = Math.min(length, own) / 4;
            return Math.max(start - own + keep, Math.min(pos, start + length - keep));
        }

        const candidates = [];
        for (const o of edges) {
            const ay = along(y, o.y, o.h, size.height);
            const ax = along(x, o.x, o.w, size.width);
            candidates.push({ x: o.x + o.w, y: ay }, { x: o.x - size.width, y: ay }, { x: ax, y: o.y + o.h }, { x: ax, y: o.y - size.height });
        }
        const free = candidates.filter(c => !others.some(o => overlaps({ x: c.x, y: c.y, w: size.width, h: size.height }, o)));
        const pool = free.length ? free : candidates;
        pool.sort((a, b) => Math.hypot(a.x - x, a.y - y) - Math.hypot(b.x - x, b.y - y));
        return { x: Math.round(pool[0].x), y: Math.round(pool[0].y) };
    }

    function drop(name: string, x: real, y: real, pull: real): void {
        const pos = snap(name, x, y, pull, null);
        update(name, pos);
        attach(name);
    }

    function touches(a: var, b: var): bool {
        const side = (a.x + a.w === b.x || b.x + b.w === a.x) && a.y < b.y + b.h && b.y < a.y + a.h;
        const stacked = (a.y + a.h === b.y || b.y + b.h === a.y) && a.x < b.x + b.w && b.x < a.x + a.w;
        return side || stacked;
    }

    // Mantém a disposição num bloco só: partindo de `anchor`, quem ficou solto
    // (sem encostar em ninguém do grupo) é colado na borda mais próxima dele.
    // Sem isso, o mouse não passa de uma tela para a outra.
    function attach(anchor: string): void {
        const names = placed.map(m => m.name);
        if (!names.length)
            return;
        const group = [names.includes(anchor) ? anchor : names[0]];
        let rest = names.filter(n => n !== group[0]);
        const rect = n => rectOf(draft.find(m => m.name === n));
        while (rest.length) {
            const near = rest.find(n => group.some(g => touches(rect(n), rect(g))));
            if (near) {
                group.push(near);
                rest = rest.filter(n => n !== near);
                continue;
            }
            // O mais próximo do grupo vai até ele.
            const dist = n => Math.min(...group.map(g => Math.hypot(rect(n).x - rect(g).x, rect(n).y - rect(g).y)));
            const next = rest.slice().sort((a, b) => dist(a) - dist(b))[0];
            const r = rect(next);
            update(next, snap(next, r.x, r.y, 0, group));
            group.push(next);
            rest = rest.filter(n => n !== next);
        }
        normalize();
    }

    // Mudou o tamanho de um monitor (modo, escala ou rotação): quem estava à
    // direita ou abaixo dele anda junto, para não abrir buraco nem sobrepor.
    function resize(name: string, changes: var): void {
        const before = draft.find(m => m.name === name);
        if (!before)
            return;
        const old = rectOf(before);
        update(name, changes);
        const now = rectOf(draft.find(m => m.name === name));
        const dw = now.w - old.w;
        const dh = now.h - old.h;
        if (before.enabled && !before.mirror && (dw || dh)) {
            draft = draft.map(m => {
                if (m.name === name || !m.enabled || m.mirror)
                    return m;
                return Object.assign({}, m, {
                    x: m.x >= old.x + old.w ? m.x + dw : m.x,
                    y: m.y >= old.y + old.h ? m.y + dh : m.y
                });
            });
        }
        attach(name);
    }

    // Opções do monitor selecionado
    readonly property var resolutions: {
        const seen = {};
        return (current?.modes ?? []).filter(m => {
            const k = `${m.width}x${m.height}`;
            if (seen[k])
                return false;
            seen[k] = true;
            return true;
        }).sort((a, b) => b.width * b.height - a.width * a.height).map(m => ({ label: `${m.width} × ${m.height}`, value: `${m.width}x${m.height}` }));
    }
    readonly property var refreshRates: (current?.modes ?? []).filter(m => m.width === current.width && m.height === current.height).map(m => m.refresh).filter((r, i, all) => all.indexOf(r) === i).sort((a, b) => b - a).map(r => ({ label: `${Number.isInteger(r) ? r : r.toFixed(2)} Hz`, value: r }))
    readonly property var scaleOptions: {
        const base = [1, 1.25, 1.5, 1.75, 2];
        if (current && !base.includes(current.scale))
            base.push(current.scale);
        return base.sort((a, b) => a - b).map(s => ({ label: `${Math.round(s * 100)}%`, value: s }));
    }
    readonly property var mirrorOptions: [{ label: "Não espelhar", value: "" }].concat(draft.filter(m => m.name !== current?.name && m.enabled && !m.mirror).map(m => ({ label: `${numberOf(m.name)} · ${m.label}`, value: m.name })))

    function setEnabled(on: bool): void {
        if (!current || (!on && enabledCount <= 1))
            return;
        if (on) {
            // Entra à direita de todos.
            const right = placed.length ? Math.max(...placed.map(m => rectOf(m).x + rectOf(m).w)) : 0;
            update(current.name, { enabled: true, mirror: "", x: right, y: placed.length ? Math.min(...placed.map(m => m.y)) : 0 });
        } else {
            // Quem espelhava este passa a não espelhar nada.
            const name = current.name;
            update(name, { enabled: false });
            draft = draft.map(m => m.mirror === name ? Object.assign({}, m, { mirror: "" }) : m);
        }
        attach(current.name);
    }

    function setResolution(value: string): void {
        const [w, h] = value.split("x").map(Number);
        const rates = current.modes.filter(m => m.width === w && m.height === h).map(m => m.refresh);
        resize(current.name, { width: w, height: h, refresh: rates.length ? Math.max(...rates) : current.refresh });
    }

    function setRefresh(value: real): void {
        update(current.name, { refresh: value });
    }

    function setScale(value: real): void {
        resize(current.name, { scale: value });
    }

    function setTransform(value: int): void {
        resize(current.name, { transform: value });
    }

    function setVrr(value: int): void {
        update(current.name, { vrr: value });
    }

    function setTenBit(on: bool): void {
        update(current.name, { tenBit: on });
    }

    function setMirror(value: string): void {
        if (value) {
            update(current.name, { mirror: value });
        } else {
            const right = Math.max(...placed.map(m => rectOf(m).x + rectOf(m).w));
            update(current.name, { mirror: "", x: right, y: 0 });
        }
        attach(current.name);
    }

    function discard(): void {
        sync();
    }

    // Aplicar e confirmar
    readonly property int confirmSeconds: 15
    property var previous: []
    property bool pending: false
    property int countdown: 0

    function apply(): void {
        previous = copy(live);
        Monitors.apply(draft);
        editing = false;
        pending = true;
        countdown = confirmSeconds;
        confirmTimer.restart();
    }

    function keep(): void {
        confirmTimer.stop();
        pending = false;
        save(draft, appsMode);
    }

    // Salva um arranjo para o conjunto conectado. O do modo "Escala pelos
    // apps" fica à parte (Monitors.setupKey): o da escala do monitor fica
    // para a volta.
    function save(specs: var, apps: bool): void {
        const saved = Object.assign({}, Config.monitorSetups ?? {});
        const entry = {};
        for (const m of specs)
            entry[m.key] = fieldsOf(m);
        saved[Monitors.setupKey(setup, apps)] = entry;
        Config.monitorSetups = saved;
    }

    // O modo de escala: "monitor" (o Hyprland escala cada monitor) ou "apps"
    // (os monitores em 1 e cada toolkit aumenta os apps: AppsScale). O
    // arranjo do modo novo vem pelo DisplaysState, que acompanha o
    // Config.scaleMode. Ao entrar no modo dos apps sem um arranjo salvo, o de
    // agora é salvo antes: é a ele que a volta retorna.
    readonly property string scaleMode: Config.scaleMode
    readonly property bool appsMode: scaleMode === "apps"
    readonly property real appsScale: Config.appsScale
    readonly property var scaleModeOptions: [
        { label: "Escala do monitor", value: "monitor" },
        { label: "Escala pelos apps", value: "apps" }
    ]
    readonly property var appsScaleOptions: [1, 1.25, 1.5, 1.75, 2].map(s => ({ label: `${Math.round(s * 100)}%`, value: s }))
    readonly property string appsNotice: "Um fator só para todos os monitores. Os apps abertos antes continuam como estavam até serem reabertos, e o ambiente da sessão vale por inteiro depois de sair e entrar. O Firefox tem ajuste próprio (layout.css.devPixelsPerPx); apps que não seguem nenhum desses ajustes ficam pequenos."
        + (AppsScale.hasXrdb ? "" : " Sem o xrdb, os apps X11 ficam sem o ajuste das fontes.")

    function setScaleMode(mode: string): void {
        if (mode === Config.scaleMode || (mode !== "apps" && mode !== "monitor"))
            return;
        if (pending)
            revert();
        if (mode === "apps") {
            if (setup && !(Config.monitorSetups ?? {})[setup] && live.length)
                save(live, false);
            Config.scaleMode = "apps";
            AppsScale.apply(Config.appsScale);
        } else {
            Config.scaleMode = "monitor";
            AppsScale.restore();
        }
    }

    function setAppsScale(value: real): void {
        if (value === Config.appsScale)
            return;
        Config.appsScale = value;
        if (appsMode)
            AppsScale.apply(value);
    }

    function revert(): void {
        confirmTimer.stop();
        pending = false;
        Monitors.apply(previous);
    }

    Timer {
        id: confirmTimer

        interval: 1000
        repeat: true
        onTriggered: {
            root.countdown -= 1;
            if (root.countdown <= 0)
                root.revert();
        }
    }

    // A confirmação aparece numa janela própria em cada tela; clicar nela não
    // deve fechar as configurações.
    function registerSurface(window: var): void {
        Panels.register(window);
    }

    function unregisterSurface(window: var): void {
        Panels.unregister(window);
    }

    // Número grande em cada tela por um instante.
    property bool identifying: false

    function identify(): void {
        identifying = true;
        identifyTimer.restart();
    }

    Timer {
        id: identifyTimer

        interval: 2500
        onTriggered: root.identifying = false
    }

    IpcHandler {
        target: "monitors"

        // Mostra o número de cada monitor na própria tela.
        function identify(): void {
            root.identify();
        }

        // O modo de escala: "monitor" ou "apps" (o mesmo da página).
        function setScaleMode(mode: string): void {
            root.setScaleMode(mode);
        }

        // O fator do modo "Escala pelos apps" (1, 1.25, 1.5, 1.75 ou 2).
        function setAppsScale(value: string): void {
            const f = Number(value);
            if (root.appsScaleOptions.some(o => o.value === f))
                root.setAppsScale(f);
        }
    }

    // Desde o login: o arranjo vai também para um arquivo que o hyprland.lua
    // inclui. Na sessão Lucerna, ele já vale desde o login (pelo arquivo do
    // shell, HyprFile) e a opção some da página.
    readonly property bool layered: HyprFile.layered
    readonly property bool atLogin: Config.monitorsAtLogin
    readonly property bool loginIncluded: Monitors.loginIncluded
    readonly property string includeLine: Monitors.includeLine

    function setAtLogin(on: bool): void {
        Config.monitorsAtLogin = on;
        Monitors.checkLoginIncluded();
    }

    function checkLogin(): void {
        Monitors.checkLoginIncluded();
    }

    function copyIncludeLine(): void {
        Quickshell.clipboardText = includeLine;
    }
}
