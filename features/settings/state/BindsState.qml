pragma Singleton

import QtQuick
import Quickshell
import qs.core.config
import qs.core.input
import qs.services

// Botões do mouse e teclas mapeados para ações (Configurações → Mouse e
// Teclado). Um mapeamento: { trigger: "mouse:275" | "F13" | "code:191",
// mods: "SUPER", label, action: { id, mods?, key?, command? } }.
//
// Adicionar ou editar passa por um rascunho: capturar o botão/tecla, escolher
// a ação e salvar. Enquanto captura, os binds do Lucerna saem do ar (senão um
// botão já mapeado não chegaria até aqui).
Singleton {
    id: root

    readonly property var all: Config.inputBinds ?? []
    readonly property var mouse: all.filter(b => b.trigger.startsWith("mouse:"))
    readonly property var keys: all.filter(b => !b.trigger.startsWith("mouse:"))

    function describeTrigger(entry: var): string {
        if (entry.trigger.startsWith("mouse:")) {
            const name = InputActions.buttonLabel(Number(entry.trigger.slice(6)));
            const mods = (entry.mods ?? "").split(/\s+/).filter(m => m).map(m => InputActions.modNames[m] ?? m);
            return mods.concat([name]).join(" + ");
        }
        return entry.label || InputActions.prettyCombo(entry.mods, entry.trigger);
    }

    // Rascunho: "mouse" ou "key" diz o que se captura; null = editor fechado.
    property string mode: ""
    property var draft: null
    // O que está sendo capturado agora: "trigger" (o botão/tecla) ou
    // "shortcut" (a combinação que a ação envia).
    property string capturing: ""

    readonly property bool editing: draft !== null

    function startNew(kind: string): void {
        mode = kind;
        draft = { trigger: "", mods: "", label: "", action: { id: kind === "mouse" ? "workspace-next" : "launcher" } };
        capture("trigger");
    }

    function edit(entry: var): void {
        mode = entry.trigger.startsWith("mouse:") ? "mouse" : "key";
        draft = JSON.parse(JSON.stringify(entry));
        // Um bind salvo com o nome antigo de uma ação mostra a ação nova.
        if (draft.action?.id)
            draft.action.id = InputActions.renamed[draft.action.id] ?? draft.action.id;
        original = entry;
    }

    property var original: null

    function capture(what: string): void {
        capturing = what;
        Input.suspendBinds();
    }

    function stopCapture(): void {
        capturing = "";
        Input.resumeBinds();
    }

    function cancel(): void {
        stopCapture();
        draft = null;
        original = null;
        mode = "";
    }

    function change(fields: var): void {
        draft = Object.assign({}, draft, fields);
    }

    function setAction(id: string): void {
        change({ action: Object.assign({}, draft.action, { id }) });
    }

    function setCommand(command: string): void {
        change({ action: Object.assign({}, draft.action, { command }) });
    }

    // Botão do Qt pressionado na área de captura (com os modificadores).
    function capturedButton(qtButton: int, modifiers: int): bool {
        const button = InputActions.buttonFromQt(qtButton);
        if (!button)
            return false;
        change({ trigger: `mouse:${button.code}`, mods: InputActions.modsFromQt(modifiers), label: button.label });
        stopCapture();
        return true;
    }

    // Tecla pressionada: `code` é o código xkb (nativeScanCode no Wayland).
    // Só modificadores não fecham a captura. Retorna se aceitou.
    function capturedKey(qtKey: int, code: int, modifiers: int): bool {
        if (InputActions.modifierKeys.includes(qtKey))
            return false;
        const sym = Input.keySymbols[Input.keyNames[String(code)]] ?? "";
        const mods = InputActions.modsFromQt(modifiers);
        if (capturing === "shortcut") {
            if (!sym)
                return false;
            change({ action: Object.assign({}, draft.action, { mods, key: sym }) });
        } else {
            change({ trigger: sym || `code:${code}`, mods, label: InputActions.prettyCombo(mods, sym || `Tecla ${code}`) });
        }
        stopCapture();
        return true;
    }

    readonly property bool canSave: {
        if (!draft || !draft.trigger || capturing)
            return false;
        const a = InputActions.find(draft.action.id);
        if (a?.kind === "shortcut")
            return !!draft.action.key;
        if (a?.kind === "command")
            return !!(draft.action.command ?? "").trim();
        return !!a;
    }

    function same(a: var, b: var): bool {
        return a.trigger === b.trigger && (a.mods ?? "") === (b.mods ?? "");
    }

    // Salvar substitui o que estava no mesmo botão/tecla.
    function save(): void {
        if (!canSave)
            return;
        const rest = all.filter(b => !same(b, draft) && !(original && same(b, original)));
        Config.inputBinds = rest.concat([draft]);
        cancel();
    }

    function remove(entry: var): void {
        Config.inputBinds = all.filter(b => !same(b, entry));
    }

    // Ações para o seletor, agrupadas. As de seguir o mouse (arrastar,
    // redimensionar) ficam só nos atalhos do shell.
    readonly property var actionOptions: InputActions.actions.filter(a => !a.mouse).map(a => ({ label: a.label, detail: a.group, value: a.id }))
}
