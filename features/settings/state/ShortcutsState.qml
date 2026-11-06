pragma Singleton

import QtQuick
import Quickshell
import qs.core.config
import qs.core.input
import qs.core.widgets
import qs.services

// View model de Configurações → Atalhos: as teclas do próprio shell. Clicar
// numa tecla captura outra no lugar; "+" acrescenta mais uma. Uma tecla que já
// era de outro atalho do shell ou da aba Teclado sai de lá; se era do
// hyprland.lua, o shell passa a ficar com ela (e avisa).
Singleton {
    id: root

    readonly property var groups: [
        { title: "Painéis e sessão", ids: ["launcher", "overview", "clipboard", "dashboard", "settings", "actions", "notifications", "central", "themes", "power", "lock", "dnd", "game", "bar"] },
        { title: "Apps", ids: ["terminal"] },
        { title: "Janelas", ids: ["close", "fullscreen", "focus-left", "focus-right", "focus-up", "focus-down", "move-left", "move-right", "move-up", "move-down", "drag", "resize"] },
        { title: "Áreas de trabalho", ids: [1, 2, 3, 4, 5, 6, 7, 8, 9].map(n => `workspace-${n}`).concat([1, 2, 3, 4, 5, 6, 7, 8, 9].map(n => `move-to-${n}`)) },
        { title: "Captura de tela", ids: ["capture", "capture-screen", "capture-window", "record"] },
        { title: "Som, mídia e brilho", ids: ["volume-up", "volume-down", "mute", "mic-mute", "play-pause", "next", "previous", "brightness-up", "brightness-down"] }
    ]

    // Os binds fixos da base do Hyprland (session/hypr/hyprland.lua): valem
    // mesmo sem o shell e não mudam aqui.
    readonly property var fixed: [
        { combo: "Ctrl + Alt + Delete", label: "Energia e sessão" },
        { combo: "Ctrl + Alt + Shift + Esc", label: "Sair da sessão" }
    ]

    readonly property var shortcuts: ShellShortcuts.effective(Config.shellShortcuts, HyprFile.layered)

    function shortcut(id: string): var {
        return shortcuts.find(s => s.id === id) ?? { id, keys: [], custom: false };
    }

    function label(id: string): string {
        return InputActions.find(id)?.label ?? id;
    }

    function icon(id: string): string {
        return InputActions.find(id)?.icon ?? "";
    }

    // Uma tecla legível: "Super + Espaço", "Super sozinho" (o modificador ao
    // soltar), "Super + Botão esquerdo".
    function pretty(k: var): string {
        const mods = ShellShortcuts.normalizeMods(k.mods);
        const alone = /^(SUPER|ALT|CTRL|SHIFT)_[LR]$/i.exec(String(k.trigger));
        if (k.release && alone)
            return `${InputActions.modNames[alone[1].toUpperCase()]} sozinho`;
        const button = /^mouse:(\d+)$/.exec(String(k.trigger));
        if (button) {
            const name = ({ 272: "Botão esquerdo", 273: "Botão direito" })[button[1]] ?? InputActions.buttonLabel(Number(button[1]));
            return (mods ? mods.split(" ") : []).map(m => InputActions.modNames[m] ?? m).concat([name]).join(" + ");
        }
        return InputActions.prettyCombo(mods, k.trigger);
    }

    // Os atalhos do mouse (arrastar, redimensionar) só mostram a tecla: a
    // captura daqui é de teclas, e os botões esquerdo e direito ficam fora
    // da captura do mouse.
    function editable(id: string): bool {
        return !(InputActions.find(id)?.mouse ?? false);
    }

    // Captura: { id, index } (index -1 = acrescentar) ou null.
    property var capturing: null
    // Aviso do último salvamento (tecla tirada de outro lugar).
    property string notice: ""

    function start(id: string, index: int): void {
        notice = "";
        capturing = { id, index };
        Input.refreshHyprBinds();
        Input.suspendBinds();
    }

    function cancel(): void {
        capturing = null;
        Input.resumeBinds();
    }

    function setKeys(id: string, keys: var): void {
        Config.shellShortcuts = ShellShortcuts.withKeys(Config.shellShortcuts, id, keys, HyprFile.layered);
    }

    // De quem é a combinação hoje, fora o próprio atalho: { kind: "shell", id },
    // { kind: "keyboard" }, { kind: "hypr" } ou null.
    function ownerOf(k: var, exceptId: string): var {
        const other = shortcuts.find(s => s.id !== exceptId && s.keys.some(o => ShellShortcuts.same(o, k)));
        if (other)
            return { kind: "shell", id: other.id };
        if ((Config.inputBinds ?? []).some(b => ShellShortcuts.same(b, k)))
            return { kind: "keyboard" };
        // Os binds do próprio Lucerna também aparecem no Hyprland; esses não contam.
        const ours = Input.binds.some(b => ShellShortcuts.same(ShellShortcuts.fromKey(b.key), k));
        if (!ours && Input.hyprBinds.some(b => !b.mouse && ShellShortcuts.same({ mods: ShellShortcuts.modsFromMask(b.modmask), trigger: b.key }, k)))
            return { kind: "hypr" };
        return null;
    }

    // Tecla pressionada na captura (`code` é o código xkb). Retorna se aceitou.
    function captured(qtKey: int, code: int, modifiers: int): bool {
        if (!capturing || InputActions.modifierKeys.includes(qtKey))
            return false;
        const trigger = Input.keySymbols[Input.keyNames[String(code)]] ?? "";
        if (!trigger)
            return false;
        const k = { mods: InputActions.modsFromQt(modifiers), trigger };
        const id = capturing.id;
        const index = capturing.index;
        const owner = ownerOf(k, id);

        if (owner?.kind === "shell")
            setKeys(owner.id, shortcut(owner.id).keys.filter(o => !ShellShortcuts.same(o, k)));
        else if (owner?.kind === "keyboard")
            Config.inputBinds = (Config.inputBinds ?? []).filter(b => !ShellShortcuts.same(b, k));

        const keys = shortcut(id).keys.filter((o, i) => i !== index && !ShellShortcuts.same(o, k));
        keys.splice(index < 0 ? keys.length : Math.min(index, keys.length), 0, k);
        setKeys(id, keys);

        notice = owner?.kind === "shell" ? `${pretty(k)} saiu de “${label(owner.id)}”.`
            : owner?.kind === "keyboard" ? `${pretty(k)} estava mapeada na aba Teclado e saiu de lá.`
            : owner?.kind === "hypr" ? `${pretty(k)} tinha um atalho no hyprland.lua; agora ela é do Lucerna (até tirar daqui).`
            : "";
        cancel();
        return true;
    }

    function removeKey(id: string, index: int): void {
        setKeys(id, shortcut(id).keys.filter((_, i) => i !== index));
        cancel();
    }

    function reset(id: string): void {
        setKeys(id, ShellShortcuts.defaultKeys(id, HyprFile.layered));
    }

    function resetAll(): void {
        Config.shellShortcuts = ({});
        notice = "";
    }

    readonly property bool anyCustom: shortcuts.some(s => s.custom)

    // Apps padrão: "Automático (o primeiro instalado)" e os instalados; o
    // escolhido que não está mais instalado continua na lista, marcado.
    readonly property var appKinds: [
        { kind: "terminal", label: "Terminal", icon: Icons.terminal },
        { kind: "browser", label: "Navegador", icon: "language" },
        { kind: "files", label: "Arquivos", icon: "folder" }
    ]

    readonly property var installedApps: LucernaSession.apps

    function detectApps(): void {
        LucernaSession.detectApps();
    }

    function currentApp(kind: string): string {
        return Config.defaultApps?.[kind] ?? "";
    }

    function appOptions(installed: var, current: string): var {
        const out = [{ label: `Automático (${installed[0] ?? "nenhum instalado"})`, value: "" }].concat(installed.map(app => ({ label: app, value: app })));
        if (current && !installed.includes(current))
            out.push({ label: current, value: current, detail: "não instalado" });
        return out;
    }

    function setApp(kind: string, app: string): void {
        const next = Object.assign({ terminal: "", browser: "", files: "" }, Config.defaultApps ?? {});
        next[kind] = app;
        Config.defaultApps = next;
        LucernaSession.writeApps(next);
    }
}
