pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Monitores do Hyprland: o que está conectado (ativo ou não), com os modos que
// cada um aceita, e a aplicação de um arranjo via hl.monitor. Um arranjo é
// uma lista de specs, uma por monitor:
//   { name, enabled, width, height, refresh, x, y, scale, transform, vrr,
//     tenBit, mirror }
// Aplicar manda sempre todos os monitores com posição explícita: um que fique
// em "auto" é rearranjado pelo Hyprland quando outro muda.
Singleton {
    id: root

    // Monitores na ordem do Hyprland (por id), já normalizados:
    //   { name, key, label, description, enabled, width, height, refresh, x, y,
    //     scale, transform, vrr, tenBit, mirror, focused, modes: [{ width, height, refresh }] }
    property var monitors: []
    // Identifica o conjunto conectado (independe da ordem e das portas).
    readonly property string setup: monitors.map(m => m.key).sort().join(" | ")

    // Chave estável de um monitor: fabricante, modelo e série; sem isso, a porta.
    function keyOf(raw: var): string {
        const parts = [raw.make, raw.model, raw.serial].filter(p => p);
        return parts.length ? parts.join(" ") : raw.name;
    }

    function parseMode(text: string): var {
        const m = /^(\d+)x(\d+)@([\d.]+)/.exec(text);
        return m ? { width: +m[1], height: +m[2], refresh: +m[3] } : null;
    }

    // `names`: id → nome (o mirrorOf do Hyprland vem pelo id).
    function normalize(raw: var, names: var): var {
        const modes = (raw.availableModes ?? []).map(parseMode).filter(m => m);
        const current = { width: raw.width, height: raw.height, refresh: Math.round(raw.refreshRate * 100) / 100 };
        if (!modes.some(m => m.width === current.width && m.height === current.height && Math.abs(m.refresh - current.refresh) < 0.5))
            modes.unshift(current);
        const label = [raw.make, raw.model].filter(p => p).join(" ");
        return {
            name: raw.name,
            key: keyOf(raw),
            label: label || raw.name,
            description: raw.description ?? "",
            enabled: !raw.disabled,
            width: current.width,
            height: current.height,
            refresh: current.refresh,
            x: raw.x,
            y: raw.y,
            scale: Math.round(raw.scale * 100) / 100,
            transform: raw.transform % 4,
            vrr: raw.vrr ? 1 : 0,
            tenBit: /2101010/.test(raw.currentFormat ?? ""),
            mirror: raw.mirrorOf && raw.mirrorOf !== "none" ? (names[raw.mirrorOf] ?? raw.mirrorOf) : "",
            focused: raw.focused,
            modes: modes
        };
    }

    // Tamanho na área de trabalho (em pixels lógicos): gira com a rotação e
    // encolhe com a escala.
    function logicalSize(spec: var): var {
        const turned = spec.transform % 2 === 1;
        return {
            width: Math.round((turned ? spec.height : spec.width) / spec.scale),
            height: Math.round((turned ? spec.width : spec.height) / spec.scale)
        };
    }

    // A chave do arranjo salvo (Config.monitorSetups): o modo "Escala pelos
    // apps" (os monitores em 1) guarda o seu à parte, e o da escala do
    // monitor fica intacto para a volta.
    function setupKey(setup: string, apps: bool): string {
        return apps ? `apps: ${setup}` : setup;
    }

    // O arranjo com todos os monitores na escala `s`. Os tamanhos lógicos
    // mudam: quem encostava na borda direita (ou de baixo) de outro continua
    // encostado, quem se alinhava a outro continua alinhado; o resto anda na
    // proporção do próprio tamanho.
    function atScale(specs: var, s: real): var {
        const out = specs.map(m => Object.assign({}, m, { scale: s }));
        const placed = specs.map((m, i) => i).filter(i => specs[i].enabled && !specs[i].mirror);
        const before = specs.map(m => logicalSize(m));
        const after = out.map(m => logicalSize(m));
        for (const [pos, size] of [["x", "width"], ["y", "height"]]) {
            const done = [];
            for (const i of placed.slice().sort((a, b) => specs[a][pos] - specs[b][pos])) {
                const old = specs[i][pos];
                const aligned = done.find(j => specs[j][pos] === old);
                const touching = done.find(j => Math.abs(specs[j][pos] + before[j][size] - old) <= 1);
                if (aligned !== undefined)
                    out[i][pos] = out[aligned][pos];
                else if (touching !== undefined)
                    out[i][pos] = out[touching][pos] + after[touching][size];
                else
                    out[i][pos] = Math.round(old * after[i][size] / before[i][size]);
                done.push(i);
            }
        }
        return out;
    }

    function refresh(): void {
        reader.running = true;
    }

    function luaFor(spec: var): string {
        if (!spec.enabled)
            return `hl.monitor({ output = ${JSON.stringify(spec.name)}, disabled = true })`;
        // O Hyprland mescla as regras de um monitor: "disabled" e "mirror" vão
        // sempre, senão um valor antigo continua valendo.
        const fields = [
            `output = ${JSON.stringify(spec.name)}`,
            `disabled = false`,
            `mode = "${spec.width}x${spec.height}@${spec.refresh}"`,
            `position = "${Math.round(spec.x)}x${Math.round(spec.y)}"`,
            `scale = ${spec.scale}`,
            `transform = ${spec.transform}`,
            `vrr = ${spec.vrr}`,
            `bitdepth = ${spec.tenBit ? 10 : 8}`,
            `mirror = ${JSON.stringify(spec.mirror ?? "")}`
        ];
        return `hl.monitor({ ${fields.join(", ")} })`;
    }

    // Código Lua de um arranjo inteiro (também serve para gravar num arquivo).
    function lua(specs: var): string {
        return specs.map(luaFor).join("\n");
    }

    function apply(specs: var): void {
        if (!specs.length)
            return;
        Quickshell.execDetached(["hyprctl", "eval", lua(specs)]);
        settle.restart();
    }

    // O que fazer com a tampa: { disable, enable, lock }. `monitors` traz
    // { name, enabled } (os normalizados ou as specs de um arranjo). Interno é
    // o painel do notebook (eDP, LVDS, DSI); sem ele (desktop), nada.
    // - Fechada com outro monitor ativo: desliga o interno; bloqueia só com a
    //   opção (lockOnDocked). O logind não suspende com monitor externo.
    // - Fechada sem outro: nada (o logind decide; ao dormir, a Session bloqueia).
    // - Aberta, ou sem nenhum monitor ativo sobrando com o interno desligado
    //   (o externo saiu com a tampa fechada): religa o interno.
    function lidPlan(lidClosed: bool, monitors: var, lockOnDocked: bool): var {
        const isInternal = m => /^(eDP|LVDS|DSI)-/.test(m.name);
        const internal = monitors.filter(isInternal);
        const othersOn = monitors.some(m => !isInternal(m) && m.enabled);
        const plan = { disable: [], enable: [], lock: false };
        if (!internal.length)
            return plan;
        if (lidClosed && othersOn) {
            plan.disable = internal.filter(m => m.enabled).map(m => m.name);
            plan.lock = lockOnDocked;
        } else if (!lidClosed || !internal.some(m => m.enabled)) {
            plan.enable = internal.filter(m => !m.enabled).map(m => m.name);
        }
        return plan;
    }

    // Um passo da tampa (DisplaysState.followLid): { send, last }. `last` é o
    // último plano mandado (o texto, ou "" depois de um plano vazio). Sem o
    // bloqueio, o mesmo plano de novo não vai: o Hyprland que recusa a mudança
    // não vira laço a cada leitura dos monitores. Com ele (a virada da tampa),
    // vai sempre.
    function lidStep(plan: var, last: string, withLock: bool): var {
        const text = JSON.stringify([plan.disable, plan.enable]);
        if (!withLock && text === last)
            return { send: false, last: last };
        return { send: true, last: plan.disable.length || plan.enable.length ? text : "" };
    }

    // O arranjo que o restore aplica: com a tampa fechada e um externo ativo
    // no arranjo, o interno vai desligado (senão acenderia e apagaria a cada
    // monitor que entra); senão, o arranjo como está.
    function withLid(specs: var, lidClosed: bool): var {
        const off = lidPlan(lidClosed, specs, false).disable;
        return specs.map(s => off.includes(s.name) ? Object.assign({}, s, { enabled: false }) : s);
    }

    // Liga ou desliga um monitor só pelo "disabled" (o Hyprland mescla as
    // regras: o resto do monitor fica como estava). Quem liga reaplica o
    // arranjo salvo depois (DisplaysState.restore).
    function setEnabled(name: string, on: bool): void {
        Quickshell.execDetached(["hyprctl", "eval", `hl.monitor({ output = ${JSON.stringify(name)}, disabled = ${!on} })`]);
        settle.restart();
    }

    // Arranjo no login: um arquivo Lua que o hyprland.lua inclui, para o arranjo
    // valer desde o início da sessão (antes, só depois que o shell sobe).
    readonly property string configDir: `${Quickshell.env("XDG_CONFIG_HOME") || `${Quickshell.env("HOME")}/.config`}/hypr`
    readonly property string loginFile: `${configDir}/lucerna-monitors.lua`
    readonly property string includeLine: `pcall(dofile, os.getenv("HOME") .. "/.config/hypr/lucerna-monitors.lua")`
    // Algum .lua da pasta do Hyprland já inclui o arquivo?
    property bool loginIncluded: false

    function writeLoginFile(text: string): void {
        loginWriter.command = ["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf "%s" "$2" > "$1"', "sh", loginFile, text];
        loginWriter.running = true;
    }

    function checkLoginIncluded(): void {
        includeProbe.running = true;
    }

    Process {
        id: loginWriter
    }

    Process {
        id: includeProbe

        command: ["sh", "-c", 'grep -rlsF --include="*.lua" "lucerna-monitors.lua" "$1" | grep -vq "/lucerna-monitors.lua$"', "sh", root.configDir]
        onExited: code => root.loginIncluded = code === 0
    }

    // O Hyprland leva um instante para reconfigurar as saídas.
    Timer {
        id: settle

        interval: 600
        onTriggered: root.refresh()
    }

    Process {
        id: reader

        running: true
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const list = JSON.parse(text).sort((a, b) => a.id - b.id);
                    const names = {};
                    for (const m of list)
                        names[String(m.id)] = m.name;
                    root.monitors = list.map(m => root.normalize(m, names));
                } catch (e) {}
            }
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (["monitoradded", "monitoraddedv2", "monitorremoved", "monitorremovedv2", "configreloaded"].includes(event.name))
                settle.restart();
        }
    }
}
