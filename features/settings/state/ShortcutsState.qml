pragma Singleton

import QtQuick
import Quickshell
import qs.core.config
import qs.core.input
import qs.services

// View model de Configurações → Atalhos: as teclas do próprio shell. Clicar
// numa tecla captura outra no lugar; "+" acrescenta mais uma. Uma tecla que já
// era de outro atalho do shell ou da aba Teclado sai de lá; se era do
// hyprland.lua, o shell passa a ficar com ela (e avisa).
Singleton {
    id: root

    readonly property var groups: [
        { title: "Painéis e sessão", ids: ["launcher", "overview", "clipboard", "dashboard", "settings", "actions", "notifications", "central", "themes", "power", "lock", "dnd", "game", "bar"] },
        { title: "Captura de tela", ids: ["capture", "capture-screen", "capture-window", "record"] },
        { title: "Som, mídia e brilho", ids: ["volume-up", "volume-down", "mute", "mic-mute", "play-pause", "next", "previous", "brightness-up", "brightness-down"] }
    ]

    readonly property var shortcuts: ShellShortcuts.effective(Config.shellShortcuts)

    function shortcut(id: string): var {
        return shortcuts.find(s => s.id === id) ?? { id, keys: [], custom: false };
    }

    function label(id: string): string {
        return InputActions.find(id)?.label ?? id;
    }

    function icon(id: string): string {
        return InputActions.find(id)?.icon ?? "";
    }

    function pretty(k: var): string {
        return InputActions.prettyCombo(ShellShortcuts.normalizeMods(k.mods), k.trigger);
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
        Config.shellShortcuts = ShellShortcuts.withKeys(Config.shellShortcuts, id, keys);
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
        setKeys(id, ShellShortcuts.defaultKeys(id));
    }

    function resetAll(): void {
        Config.shellShortcuts = ({});
        notice = "";
    }

    readonly property bool anyCustom: shortcuts.some(s => s.custom)
}
