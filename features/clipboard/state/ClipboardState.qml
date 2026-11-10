pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core.config
import qs.core.format
import qs.core.panels
import qs.services

// View model do histórico da área de transferência: busca, filtro (tudo,
// textos, imagens, arquivos), seleção e colar. Os fixados vêm primeiro.
// Escolher põe a entrada na área de transferência, fecha o painel e, se
// ligado, cola na janela em foco.
Singleton {
    id: root

    readonly property bool open: Panels.isOpen("clipboard")
    readonly property var screen: Hypr.focusedScreen
    readonly property bool enabled: Config.clipboardEnabled
    readonly property bool available: Clipboard.available

    property string query: ""
    property string filter: "all"
    property int selected: 0

    readonly property var filters: [
        { label: "Tudo", value: "all" },
        { label: "Textos", value: "text" },
        { label: "Imagens", value: "image" },
        { label: "Arquivos", value: "files" }
    ]

    // A página que o daemon montou para esta busca e este filtro (os fixados
    // primeiro); a busca e o filtro são dele.
    readonly property var items: Clipboard.items
    readonly property var current: items[Math.min(selected, items.length - 1)] ?? null
    readonly property int count: Clipboard.count
    readonly property int pinned: Clipboard.pinned
    // Limpar tira tudo menos os fixados: só há o que limpar se sobra algo.
    readonly property bool clearable: count > pinned
    readonly property alias reload: reloadTimer

    // Por que o histórico não está disponível.
    readonly property string unavailableText: {
        if (!Clipboard.client.connected)
            return "Indisponível: sem conexão com o lucernad.";
        return Clipboard.error ? `Indisponível: ${Clipboard.error}` : "Indisponível.";
    }
    // O que a lista vazia mostra: "off" (o histórico desligado; vem antes,
    // para o motivo não esconder o caminho de religar), "unavailable" ou
    // "empty".
    readonly property string emptyKind: emptyState(enabled, available)

    function emptyState(enabled: bool, available: bool): string {
        if (!enabled)
            return "off";
        return available ? "empty" : "unavailable";
    }

    onItemsChanged: selected = Math.max(0, Math.min(selected, items.length - 1))
    onQueryChanged: {
        selected = 0;
        reloadTimer.restart();
    }
    onFilterChanged: {
        selected = 0;
        reloadTimer.restart();
    }

    onOpenChanged: {
        if (open)
            opened();
    }

    // O painel abriu: busca e filtro zerados, e a primeira página de tudo.
    function opened(): void {
        query = "";
        filter = "all";
        selected = 0;
        now = new Date();
        reloadTimer.stop();
        if (enabled)
            Clipboard.load("all", "");
    }

    // Digitar ou trocar o filtro espera um instante antes de pedir.
    Timer {
        id: reloadTimer

        interval: 150
        onTriggered: Clipboard.load(root.filter, root.query)
    }

    // Relógio para "há 5 min", só enquanto aberto.
    property var now: new Date()

    Timer {
        running: root.open
        repeat: true
        interval: 30000
        onTriggered: root.now = new Date()
    }

    function since(entry: var): string {
        return Format.since(new Date(entry.used), now);
    }

    // Texto de uma linha para a lista (o daemon já junta os espaços).
    function preview(entry: var): string {
        return entry.kind === "image" ? "Imagem" : String(entry.preview ?? "");
    }

    function detail(entry: var): string {
        if (entry.kind === "image")
            return entry.width && entry.height ? `${since(entry)} · ${entry.width}×${entry.height}` : since(entry);
        if (entry.kind === "files") {
            const n = Number(entry.urisTotal ?? entry.uris?.length ?? 0);
            return `${since(entry)} · ${n} ${n === 1 ? "arquivo" : "arquivos"}`;
        }
        const lines = entry.lines ?? 1;
        return `${since(entry)} · ${Format.number(entry.size ?? 0, 0)} caracteres${lines > 1 ? ` · ${lines} linhas` : ""}`;
    }

    // O texto escapado para StyledText, com cada trecho de `matches` (pares
    // [início, fim) em UTF-16, os índices do JavaScript) entre <b> e </b>; o
    // que cai fora do texto é ignorado.
    function marked(text: string, matches: var): string {
        const escape = piece => piece.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
        const ranges = Array.from(matches ?? []).map(pair => Array.from(pair)).map(([from, to]) => [Math.max(0, from), Math.min(to, text.length)]).filter(([from, to]) => from < to).sort((a, b) => a[0] - b[0]);
        let out = "";
        let at = 0;
        for (const [from, to] of ranges) {
            if (from < at)
                continue;
            out += escape(text.slice(at, from)) + "<b>" + escape(text.slice(from, to)) + "</b>";
            at = to;
        }
        return out + escape(text.slice(at));
    }

    // A lista chegou ao fim: a página seguinte do daemon.
    function more(): void {
        Clipboard.more();
    }

    // O painel no fim da lista (`atEnd`, o atYEnd dela) pede a página
    // seguinte. Ele chama também quando a altura do conteúdo muda: a página
    // somada que ainda cabe inteira não muda o atYEnd, e o "mais" ficaria só
    // pelas setas.
    function reachedEnd(atEnd: bool): void {
        if (atEnd)
            more();
    }

    // Circular só com tudo carregado; no fim de uma lista que tem mais, pede a
    // página seguinte e fica no último.
    function move(step: int): void {
        if (!items.length)
            return;
        const next = selected + step;
        if (next >= items.length && items.length < Clipboard.total) {
            selected = items.length - 1;
            more();
            return;
        }
        if (next < 0 && items.length < Clipboard.total) {
            selected = 0;
            return;
        }
        selected = (next + items.length) % items.length;
    }

    function select(index: int): void {
        selected = index;
    }

    function activate(entry: var): void {
        if (!entry)
            return;
        Clipboard.copy(entry.id);
        Panels.close();
        if (Config.clipboardPaste)
            Clipboard.paste();
    }

    function remove(entry: var): void {
        if (entry)
            Clipboard.remove(entry.id);
    }

    function togglePin(entry: var): void {
        if (entry)
            Clipboard.pin(entry.id, !entry.pinned);
    }

    // Tira tudo menos os fixados.
    function clear(): void {
        Clipboard.clear(false);
    }

    function close(): void {
        Panels.dismiss("clipboard");
    }

    function openSettings(): void {
        Config.settingsTopic = "clipboard";
        Panels.open("settings");
    }

    // Nesta ordem: o limite e a persistência chegam ao daemon (configure)
    // antes da assinatura do histórico.
    Binding {
        target: Clipboard
        property: "limit"
        value: Config.clipboardLimit
    }

    Binding {
        target: Clipboard
        property: "persist"
        value: Config.clipboardPersist
    }

    Binding {
        target: Clipboard
        property: "watching"
        value: Config.clipboardEnabled
    }

    IpcHandler {
        target: "clipboard"

        function toggle(): void {
            Panels.toggle("clipboard");
        }

        function open(): void {
            Panels.open("clipboard");
        }

        // Tira tudo menos os fixados.
        function clear(): void {
            root.clear();
        }

        function count(): int {
            return root.count;
        }
    }
}
