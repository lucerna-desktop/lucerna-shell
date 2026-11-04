pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Mouse, touchpad e teclado no Hyprland: opções de entrada (hl.config), por
// dispositivo (hl.device), binds (hl.bind/hl.unbind) e o keymap. Remapear uma
// tecla de verdade (vale em qualquer app, até para modificadores) é gerar um
// keymap com o xkbcli, trocar os símbolos da tecla e entregar via kb_file.
Singleton {
    id: root

    // Opções lidas do Hyprland: "input.sensitivity" → { value, set }.
    // `set` diz se o hyprland.lua (ou o Lucerna) definiu a opção.
    property var options: ({})
    readonly property var optionNames: [
        "input.sensitivity", "input.accel_profile", "input.left_handed", "input.natural_scroll",
        "input.scroll_factor", "input.follow_mouse",
        "input.touchpad.tap_to_click", "input.touchpad.natural_scroll", "input.touchpad.disable_while_typing",
        "input.touchpad.clickfinger_behavior", "input.touchpad.scroll_factor", "input.touchpad.middle_button_emulation",
        "input.touchpad.drag_lock", "input.touchpad.tap_and_drag",
        "input.kb_layout", "input.kb_variant", "input.kb_options", "input.kb_model", "input.kb_rules",
        "input.repeat_rate", "input.repeat_delay", "input.numlock_by_default"
    ]

    function option(name: string): var {
        return options[name]?.value;
    }

    // Dispositivos: { mice: [{ name, speed }], keyboards: [{ name, layout, keymap, main }] }
    property var mice: []
    property var keyboards: []
    readonly property var touchpads: mice.filter(m => /touchpad|trackpad|synaptics|elan|glidepoint/i.test(m.name))

    function refresh(): void {
        optionReader.running = true;
        deviceReader.running = true;
    }

    // Lua
    function luaString(text: string): string {
        return `"${String(text).replace(/\\/g, "\\\\").replace(/"/g, "\\\"").replace(/\n/g, "\\n")}"`;
    }

    function luaValue(value: var): string {
        if (typeof value === "string")
            return luaString(value);
        if (typeof value === "boolean" || typeof value === "number")
            return String(value);
        if (Array.isArray(value))
            return `{ ${value.map(luaValue).join(", ")} }`;
        return `{ ${Object.keys(value).map(k => `${/^[a-z_][a-z0-9_]*$/i.test(k) ? k : `[${luaString(k)}]`} = ${luaValue(value[k])}`).join(", ")} }`;
    }

    // { "input.touchpad.tap_to_click": true } → { input = { touchpad = { tap_to_click = true } } }
    function nest(flat: var): var {
        const out = {};
        for (const name of Object.keys(flat)) {
            const parts = name.split(".");
            let node = out;
            for (const p of parts.slice(0, -1))
                node = node[p] = node[p] ?? {};
            node[parts[parts.length - 1]] = flat[name];
        }
        return out;
    }

    // Executa Lua gerado aqui na config em uso (hyprctl eval); os textos que
    // vêm de fora (comandos, nomes) passam por luaString.
    function evalLua(lua: string): void {
        Quickshell.execDetached(["hyprctl", "eval", lua]);
    }

    // O Lua das opções, de um dispositivo e dos layouts: o mesmo no eval e no
    // arquivo do shell (HyprFile), que o Hyprland carrega na sessão Lucerna.
    function optionsLua(flat: var): string {
        return Object.keys(flat).length ? `hl.config(${luaValue(nest(flat))})` : "";
    }

    function deviceLua(name: string, fields: var): string {
        return `hl.device(${luaValue(Object.assign({ name }, fields))})`;
    }

    function setOptions(flat: var): void {
        const lua = optionsLua(flat);
        if (!lua)
            return;
        evalLua(lua);
        settle.restart();
    }

    function setDevice(name: string, fields: var): void {
        evalLua(deviceLua(name, fields));
    }

    // Recarrega o hyprland.lua: é como uma opção volta ao valor do arquivo.
    // Quem aplica ajustes por cima (as features) reaplica ao ouvir o reload;
    // na sessão Lucerna, o reload espera o arquivo do shell (HyprFile).
    function reload(): void {
        HyprFile.reload();
    }

    // Binds do Lucerna: [{ key: "SUPER + mouse:275", lua: "hl.dsp....", repeating, locked }].
    // Trocar a lista tira os anteriores e o que o hyprland.lua tiver nas mesmas
    // teclas (senão a ação rodaria duas vezes); suspender tira todos por um
    // tempo (para capturar uma tecla ou botão que já está mapeado).
    property var binds: []
    property bool suspended: false

    function unbindLua(list: var): string {
        return list.map(b => `hl.unbind(${luaString(b.key)})`).join("\n");
    }

    function bindLua(list: var): string {
        return list.map(b => {
            const opts = [];
            if (b.repeating)
                opts.push("repeating = true");
            if (b.locked)
                opts.push("locked = true");
            return `hl.bind(${luaString(b.key)}, ${b.lua}${opts.length ? `, { ${opts.join(", ")} }` : ""})`;
        }).join("\n");
    }

    function setBinds(list: var): void {
        const keys = binds.concat(list).filter((b, i, all) => all.findIndex(o => o.key.toLowerCase() === b.key.toLowerCase()) === i);
        const lua = [unbindLua(keys), suspended ? "" : bindLua(list)].filter(l => l).join("\n");
        binds = list;
        if (lua)
            evalLua(lua);
    }

    function suspendBinds(): void {
        if (suspended)
            return;
        suspended = true;
        if (binds.length)
            evalLua(unbindLua(binds));
    }

    function resumeBinds(): void {
        if (!suspended)
            return;
        suspended = false;
        if (binds.length)
            evalLua(bindLua(binds));
    }

    // Todos os binds ativos no Hyprland (`hyprctl binds -j`), para achar
    // conflitos: [{ mods: "SUPER SHIFT", key: "Q", mouse }].
    property var hyprBinds: []

    function refreshHyprBinds(): void {
        bindsProbe.running = true;
    }

    Process {
        id: bindsProbe

        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.hyprBinds = JSON.parse(text).map(b => ({ modmask: b.modmask, key: b.key, mouse: b.mouse }));
                } catch (e) {
                    root.hyprBinds = [];
                }
            }
        }
    }

    // Keymap
    // Teclas do keymap atual: código xkb → nome ("66" → "CAPS") e nome →
    // primeiro símbolo ("CAPS" → "Caps_Lock"). Serve para nomear o que foi
    // capturado e para copiar uma tecla ao remapear.
    property var keyNames: ({})
    property var keySymbols: ({})
    property string baseKeymap: ""
    readonly property string keymapPath: Quickshell.statePath("keymap.xkb")

    // Monta o keymap de layouts/opções; sem remapeamentos, só passa os
    // layouts ao Hyprland; com eles, grava o keymap trocado e usa kb_file.
    // layout: { layouts: "br,us", variants: ",intl", options: "grp:...", model, rules }
    property var pendingLayout: null
    property var pendingRemaps: []
    // Só lê o keymap (para nomear teclas), sem aplicar nada.
    property bool inspecting: false

    function setKeyboard(layout: var, remaps: var): void {
        inspecting = false;
        compile(layout, remaps);
    }

    // Sem nada mudado nas configurações, o teclado é o do hyprland.lua: a
    // seção "keyboard" do arquivo fica vazia.
    function inspectKeyboard(layout: var): void {
        HyprFile.setSection("keyboard", "");
        inspecting = true;
        compile(layout, []);
    }

    function compile(layout: var, remaps: var): void {
        pendingLayout = layout;
        pendingRemaps = remaps;
        compiler.command = ["xkbcli", "compile-keymap", "--layout", layout.layouts || "us", "--variant", layout.variants || "", "--options", layout.options || ""].concat(layout.model ? ["--model", layout.model] : []).concat(layout.rules ? ["--rules", layout.rules] : []);
        compiler.running = true;
    }

    function parseKeymap(text: string): void {
        const names = {};
        const codes = /<([A-Z0-9+\-]+)>\s*=\s*(\d+);/g;
        const keycodes = text.slice(0, text.indexOf("xkb_types"));
        let m;
        while ((m = codes.exec(keycodes)))
            names[m[2]] = m[1];
        // Apelidos (alias <LatA> = <AC01>) não interessam aqui.
        const syms = {};
        const symbols = text.slice(text.indexOf("xkb_symbols"));
        const keys = /key <([A-Z0-9+\-]+)>\s*\{([\s\S]*?)\};/g;
        while ((m = keys.exec(symbols))) {
            // "symbols[1]= [ Caps_Lock ]" ou só "[ Caps_Lock ]".
            const first = /symbols\[1\]\s*=\s*\[\s*([A-Za-z0-9_]+)/.exec(m[2]) ?? /^\s*\[\s*([A-Za-z0-9_]+)/.exec(m[2]);
            if (first)
                syms[m[1]] = first[1];
        }
        keyNames = names;
        keySymbols = syms;
    }

    // Trecho "key <NAME> { ... };" do keymap, com as chaves balanceadas.
    function keyBlock(text: string, name: string): var {
        const start = text.search(new RegExp(`\\n\\s*key <${name.replace(/[+\-]/g, "\\$&")}>\\s*\\{`));
        if (start < 0)
            return null;
        let depth = 0;
        for (let i = text.indexOf("{", start); i < text.length; i++) {
            if (text[i] === "{")
                depth++;
            else if (text[i] === "}" && --depth === 0) {
                const end = text.indexOf(";", i) + 1;
                return { start, end, text: text.slice(start, end) };
            }
        }
        return null;
    }

    // remaps: [{ from: "CAPS", to: { kind: "key", value: "ESC" } | { kind: "sym", value: "XF86AudioPlay" } | { kind: "none" } }]
    function patchKeymap(text: string, remaps: var): string {
        const s0 = text.indexOf("xkb_symbols");
        let symbols = text.slice(s0);
        const base = symbols;
        const extra = [];
        const modmaps = [];
        for (const r of remaps) {
            const own = keyBlock(symbols, r.from);
            if (own)
                symbols = symbols.slice(0, own.start) + symbols.slice(own.end);
            // A tecla sai dos modificadores que tinha (Caps em Lock, Ctrl em Control…).
            symbols = symbols.replace(/modifier_map\s+(\w+)\s*\{([^}]*)\};/g, (all, mod, list) => {
                const rest = list.split(",").map(k => k.trim()).filter(k => k && k !== `<${r.from}>`);
                return rest.length ? `modifier_map ${mod} { ${rest.join(", ")} };` : "";
            });
            if (r.to.kind === "key") {
                const target = keyBlock(base, r.to.value);
                if (target)
                    extra.push(target.text.replace(`<${r.to.value}>`, `<${r.from}>`).trim());
                // Se o alvo é modificador, esta tecla passa a ser também.
                const mod = new RegExp(`modifier_map\\s+(\\w+)\\s*\\{[^}]*<${r.to.value}>`).exec(base);
                if (mod)
                    modmaps.push(`modifier_map ${mod[1]} { <${r.from}> };`);
            } else if (r.to.kind === "sym") {
                extra.push(`key <${r.from}> { type= "ONE_LEVEL", symbols[1]= [ ${r.to.value} ] };`);
            } else {
                extra.push(`key <${r.from}> { type= "ONE_LEVEL", symbols[1]= [ NoSymbol ] };`);
            }
        }
        // O fim da seção xkb_symbols é o penúltimo "};" (o último fecha o keymap).
        const close = symbols.lastIndexOf("};", symbols.lastIndexOf("};") - 1);
        symbols = symbols.slice(0, close) + "\n\t" + extra.concat(modmaps).join("\n\t") + "\n" + symbols.slice(close);
        return text.slice(0, s0) + symbols;
    }

    Process {
        id: compiler

        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.includes("xkb_symbols"))
                    return;
                root.baseKeymap = text;
                root.parseKeymap(text);
                if (root.inspecting)
                    return;
                const l = root.pendingLayout;
                if (root.pendingRemaps.length) {
                    // O carimbo faz o arquivo mudar sempre: com o mesmo texto, o
                    // FileView não regrava e o onSaved não vem.
                    keymapFile.setText(`// Gerado pelo Lucerna em ${new Date().toISOString()}\n` + root.patchKeymap(text, root.pendingRemaps));
                } else {
                    root.applyLayouts(l);
                }
            }
        }
    }

    // O Hyprland aplica uma opção de cada vez e recusa combinações inválidas
    // no meio do caminho (dois layouts com uma variante, uma variante para
    // dois layouts). Em etapas, cada passo é válido.
    function layoutLua(l: var): string {
        return [
            { kb_file: "", kb_variant: "", kb_options: "" },
            { kb_layout: l.layouts },
            { kb_variant: l.variants, kb_options: l.options }
        ].map(step => `hl.config(${luaValue({ input: step })})`).join("\n");
    }

    // O keymap trocado (com os remapeamentos) já traz layouts e opções.
    function keymapFileLua(path: string): string {
        return `hl.config(${luaValue({ input: { kb_file: path } })})`;
    }

    // A seção "keyboard" do arquivo acompanha o que foi aplicado.
    function applyLayouts(l: var): void {
        const lua = layoutLua(l);
        evalLua(lua);
        HyprFile.setSection("keyboard", lua);
        settle.restart();
    }

    // O keymap trocado vai para um rascunho e só é entregue ao Hyprland se
    // compilar: um keymap quebrado deixaria o teclado sem funcionar.
    readonly property string draftPath: Quickshell.statePath("keymap.draft.xkb")
    property string keymapError: ""

    FileView {
        id: keymapFile

        path: root.draftPath
        atomicWrites: true
        printErrors: false
        onSaved: validator.running = true
    }

    Process {
        id: validator

        command: ["sh", "-c", `xkbcli compile-keymap --keymap "$1" > /dev/null && cp "$1" "$2"`, "sh", root.draftPath, root.keymapPath]
        stderr: StdioCollector {
            id: validatorErrors
        }
        onExited: code => {
            if (code !== 0) {
                root.keymapError = validatorErrors.text.trim() || "O keymap gerado não compilou";
                console.warn(`Lucerna: keymap não aplicado: ${root.keymapError}`);
                return;
            }
            root.keymapError = "";
            const lua = root.keymapFileLua(root.keymapPath);
            root.evalLua(lua);
            HyprFile.setSection("keyboard", lua);
            settle.restart();
        }
    }

    // Catálogo do xkb: layouts, variantes e opções, com a descrição (em inglês).
    property var layoutCatalog: []    // [{ name, description }]
    property var variantCatalog: ({}) // layout → [{ name, description }]
    property var optionCatalog: []    // [{ name, group, description }]

    FileView {
        path: "/usr/share/X11/xkb/rules/evdev.lst"
        printErrors: false
        onLoaded: {
            const layouts = [];
            const variants = {};
            const opts = [];
            let section = "";
            for (const line of text().split("\n")) {
                if (line.startsWith("! ")) {
                    section = line.slice(2).trim();
                    continue;
                }
                const m = /^\s+(\S+)\s+(.*)$/.exec(line);
                if (!m)
                    continue;
                if (section === "layout") {
                    layouts.push({ name: m[1], description: m[2] });
                } else if (section === "variant") {
                    const v = /^(\S+):\s*(.*)$/.exec(m[2]);
                    if (v)
                        (variants[v[1]] = variants[v[1]] ?? []).push({ name: m[1], description: v[2] });
                } else if (section === "option" && m[1].includes(":")) {
                    opts.push({ name: m[1], group: m[1].split(":")[0], description: m[2] });
                }
            }
            root.layoutCatalog = layouts.sort((a, b) => a.description.localeCompare(b.description));
            root.variantCatalog = variants;
            root.optionCatalog = opts;
        }
    }

    // O Hyprland leva um instante para aplicar.
    Timer {
        id: settle

        interval: 400
        onTriggered: root.refresh()
    }

    Process {
        id: optionReader

        running: true
        command: ["sh", "-c", root.optionNames.map(n => `hyprctl getoption ${n.replace(/\./g, ":")} -j; echo`).join("; ")]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = {};
                for (const line of text.split("\n")) {
                    if (!line.trim().startsWith("{"))
                        continue;
                    try {
                        const o = JSON.parse(line);
                        // Texto vazio vem como "[[EMPTY]]".
                        const raw = o.int ?? o.float ?? o.str ?? o.bool ?? o.custom;
                        const value = raw === "[[EMPTY]]" ? "" : raw;
                        out[o.option.replace(/:/g, ".")] = { value, set: o.set };
                    } catch (e) {}
                }
                root.options = out;
            }
        }
    }

    Process {
        id: deviceReader

        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    root.mice = (d.mice ?? []).map(m => ({ name: m.name, speed: m.defaultSpeed }));
                    root.keyboards = (d.keyboards ?? []).map(k => ({ name: k.name, layout: k.layout, keymap: k.active_keymap, main: k.main }));
                } catch (e) {}
            }
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "configreloaded")
                settle.restart();
        }
    }
}
