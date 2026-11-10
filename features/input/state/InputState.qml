pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core.config
import qs.core.input
import qs.core.panels
import qs.services

// Aplica os ajustes de mouse e teclado das configurações por cima do
// hyprland.lua: opções de entrada, velocidade por mouse, layouts e opções do
// teclado, teclas remapeadas e botões/teclas mapeados para ações. Reaplica ao
// iniciar, quando a config muda e depois de um reload do Hyprland (fora da
// sessão Lucerna: nela, o arquivo do shell, HyprFile, já vale no reload).
// Sem interface própria; tudo se monta em Configurações → Mouse e Teclado.
// No modo de segurança, nada é aplicado: o Hyprland fica com o que já tinha.
Singleton {
    id: root

    // As opções do arquivo só são conhecidas depois da primeira leitura.
    readonly property bool ready: Object.keys(Input.options).length > 0
    readonly property bool applies: !Config.safeMode

    onReadyChanged: {
        if (ready)
            applyAll();
    }

    function applyAll(): void {
        if (!applies)
            return;
        applyOptions();
        applyDevices();
        applyKeyboard();
        applyBinds();
    }

    function applyOptions(): void {
        if (!applies)
            return;
        Input.setOptions(Config.inputOptions ?? {});
        writeInput();
    }

    function applyDevices(): void {
        if (!applies)
            return;
        const devices = Config.mouseDevices ?? {};
        for (const name of Object.keys(devices))
            Input.setDevice(name, devices[name]);
        writeInput();
    }

    // A seção "input" do arquivo do shell: as opções e os dispositivos.
    function writeInput(): void {
        const devices = Config.mouseDevices ?? {};
        HyprFile.setSection("input", [Input.optionsLua(Config.inputOptions ?? {})].concat(Object.keys(devices).map(name => Input.deviceLua(name, devices[name]))).filter(l => l).join("\n"));
    }

    // Layouts do arquivo (quando não foram mudados aqui): "br,us" + ",intl".
    function fileLayouts(): var {
        const layouts = String(Input.option("input.kb_layout") ?? "us").split(",");
        const variants = String(Input.option("input.kb_variant") ?? "").split(",");
        return layouts.map((l, i) => ({ layout: l.trim(), variant: (variants[i] ?? "").trim() }));
    }

    function fileOptions(): var {
        return String(Input.option("input.kb_options") ?? "").split(",").map(o => o.trim()).filter(o => o);
    }

    // Remapeamentos válidos (uma entrada quebrada na config não derruba o resto).
    readonly property var remaps: (Config.keyRemaps ?? []).filter(r => r?.from && r?.to?.kind)
    readonly property bool keyboardChanged: Config.keyboardLayouts !== null || Config.keyboardOptions !== null || remaps.length > 0

    // Sem nada mudado aqui, só lê o keymap do arquivo (para nomear as teclas).
    function applyKeyboard(): void {
        if (!ready || !applies)
            return;
        const layouts = Config.keyboardLayouts ?? fileLayouts();
        const options = Config.keyboardOptions ?? fileOptions();
        (keyboardChanged ? Input.setKeyboard : Input.inspectKeyboard)({
            layouts: layouts.map(l => l.layout).join(","),
            variants: layouts.map(l => l.variant ?? "").join(","),
            options: options.join(","),
            model: String(Input.option("input.kb_model") ?? ""),
            rules: String(Input.option("input.kb_rules") ?? "")
        }, remaps);
    }

    // Um bind do Lucerna: ações do shell passam pelo IPC "action".
    function bindFor(entry: var): var {
        const action = InputActions.find(entry.action?.id ?? "");
        if (!action)
            return null;
        const key = ShellShortcuts.keyOf(entry);
        let lua = "hl.dsp.no_op()";
        if (action.kind === "shell")
            lua = `hl.dsp.exec_cmd(${Input.luaString(`qs -p ${Quickshell.shellPath("shell.qml")} ipc call ${action.ipc ?? `action run ${action.id}`}`)})`;
        else if (action.kind === "hypr")
            lua = action.lua;
        else if (action.kind === "shortcut")
            lua = `hl.dsp.send_shortcut({ mods = ${Input.luaString(entry.action.mods ?? "")}, key = ${Input.luaString(entry.action.key ?? "")} })`;
        else if (action.kind === "command")
            lua = `hl.dsp.exec_cmd(${Input.luaString(entry.action.command ?? "")})`;
        return { key, lua, repeating: action.repeating ?? false, locked: action.locked ?? false, release: entry.release ?? false, mouse: action.mouse ?? false };
    }

    // Os atalhos do shell viram binds como os outros. Uma tecla mapeada na aba
    // Teclado vence o atalho do shell na mesma tecla. Fora da sessão Lucerna
    // valem os padrões de antes: as teclas de janela e área de trabalho ficam
    // com o hyprland.lua da pessoa.
    function shellEntries(layered: bool): var {
        const own = Config.inputBinds ?? [];
        const out = [];
        for (const shortcut of ShellShortcuts.effective(Config.shellShortcuts, layered)) {
            for (const k of shortcut.keys) {
                if (!own.some(b => ShellShortcuts.same(b, k)) && !out.some(e => ShellShortcuts.same(e, k)))
                    out.push({ trigger: k.trigger, mods: ShellShortcuts.normalizeMods(k.mods), release: k.release ?? false, action: { id: shortcut.id } });
            }
        }
        return out;
    }

    // As teclas da base do Hyprland que um atalho do shell substitui (o
    // terminal): saem sempre, no eval e no arquivo. Sem mudança, o shell põe
    // a mesma tecla de volta com o bind dele (no arquivo, carregado depois da
    // base, sem o unbind ela ficaria com dois binds e abriria dois
    // terminais); mudada ou tirada, a da base não abre mais nada. Fora da
    // sessão Lucerna não há base: a tecla seria a do hyprland.lua da pessoa.
    function baseUnbinds(layered: bool): var {
        return layered ? ShellShortcuts.baseKeys().map(k => ({ key: ShellShortcuts.keyOf(k) })) : [];
    }

    function applyBinds(): void {
        if (!applies)
            return;
        const list = shellEntries(HyprFile.layered).concat(Config.inputBinds ?? []).map(bindFor).filter(b => b);
        const base = baseUnbinds(HyprFile.layered);
        Input.setBinds(list, base);
        HyprFile.setSection("binds", [Input.unbindLua(base), Input.bindLua(list)].filter(l => l).join("\n"));
    }

    // Mudanças em sequência (arrastar um slider) viram uma aplicação só.
    Timer {
        id: optionsDelay

        interval: 120
        onTriggered: root.applyOptions()
    }

    Timer {
        id: keyboardDelay

        interval: 200
        onTriggered: root.applyKeyboard()
    }

    Connections {
        target: Config

        function onInputOptionsChanged() {
            optionsDelay.restart();
        }

        function onMouseDevicesChanged() {
            root.applyDevices();
        }

        function onKeyboardLayoutsChanged() {
            keyboardDelay.restart();
        }

        function onKeyboardOptionsChanged() {
            keyboardDelay.restart();
        }

        function onKeyRemapsChanged() {
            keyboardDelay.restart();
        }

        function onInputBindsChanged() {
            root.applyBinds();
        }

        function onShellShortcutsChanged() {
            root.applyBinds();
        }
    }

    // O reload volta tudo ao hyprland.lua (e tira os binds do Lucerna). Na
    // sessão Lucerna, o arquivo do shell é carregado antes do hyprland.lua do
    // usuário: as opções, os dispositivos e o teclado não são reaplicados (o
    // do usuário, lido depois, vence). Os binds são a exceção: a tecla de um
    // atalho do shell é do shell, como hoje (muda-se em Configurações), e sem
    // o unbind de novo o bind do hyprland.lua na mesma tecla dispararia junto.
    function reloadPlan(layered: bool): string {
        return layered ? "binds" : "all";
    }

    Connections {
        target: Hypr

        function onConfigReloaded() {
            reloadDelay.restart();
        }
    }

    Timer {
        id: reloadDelay

        interval: 300
        onTriggered: {
            if (!root.applies)
                return;
            Input.binds = [];
            if (root.reloadPlan(HyprFile.layered) === "binds")
                root.applyBinds();
            else
                root.applyAll();
        }
    }

    // As ações do shell que os binds chamam.
    function run(name: string): void {
        // `action run sidebar` de um hyprland.lua antigo segue valendo.
        const id = InputActions.renamed[name] ?? name;
        switch (id) {
        case "launcher":
        case "dashboard":
        case "settings":
        case "themes":
        case "power":
        case "clipboard":
        case "capture":
        case "overview":
            Panels.toggle(id);
            break;
        case "central":
            Panels.toggleCentral("");
            break;
        case "actions":
            Panels.toggleActions("");
            break;
        case "notifications":
            Panels.toggleNotifications();
            break;
        case "lock":
            Session.lock();
            break;
        case "dnd":
            Config.doNotDisturb = !Config.doNotDisturb;
            break;
        case "game":
            GameMode.toggle();
            break;
        case "bar":
            Panels.requestBarToggle(Hypr.focusedScreen);
            break;
        case "play-pause":
            Media.togglePlaying();
            break;
        case "next":
            Media.next();
            break;
        case "previous":
            Media.previous();
            break;
        case "volume-up":
            Audio.changeVolume(0.05);
            break;
        case "volume-down":
            Audio.changeVolume(-0.05);
            break;
        case "mute":
            Audio.toggleMute();
            break;
        case "mic-mute":
            Audio.toggleMicMute();
            break;
        case "brightness-up":
            Brightness.change(0.05);
            break;
        case "brightness-down":
            Brightness.change(-0.05);
            break;
        }
    }

    // O modo jogo pelo terminal: `qs -c lucerna ipc call game
    // toggle|on|off|get|defaults` (o defaults: a lista "nunca" de fábrica lida
    // do lucernad, separada por espaços, vazia se não veio; para a fumaça).
    IpcHandler {
        target: "game"

        function toggle(): void {
            GameMode.toggle();
        }

        function on(): void {
            GameMode.set(true);
        }

        function off(): void {
            GameMode.set(false);
        }

        function get(): string {
            return GameMode.statusText(GameMode.available, GameMode.active, GameMode.reasons);
        }

        function defaults(): string {
            return Array.from(GameMode.factoryNever ?? []).join(" ");
        }
    }

    IpcHandler {
        target: "action"

        // Roda uma ação do shell (a lista está em core/input/InputActions).
        function run(id: string): void {
            root.run(id);
        }
    }
}
