pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// O histórico da área de transferência, vindo do módulo clipboard do lucernad:
// o daemon observa, guarda e copia de volta; aqui só os tópicos, a página que o
// painel mostra e o colar sozinho (que depende do Hyprland). Sem o daemon,
// `available` fica falso.
Singleton {
    id: root

    // Não é readonly: os testes trocam por um cliente da fábrica e restauram.
    property var client: Lucernad.client

    // Quem usa decide (as Bindings do ClipboardState, nesta ordem: limit,
    // persist, watching; o persist já certo quando a assinatura sai).
    property bool watching: false
    property int limit: 100
    property bool persist: true

    // O clipboard.status do daemon: o módulo pode estar indisponível com o
    // daemon de pé (sem Wayland, o compositor sem o protocolo).
    property bool moduleAvailable: false
    property string error: ""
    // Disponível é conectado e sem `error`: com o histórico desligado (sem
    // assinante), o daemon fica com `available` falso e `error` nulo enquanto
    // não tenta a sessão, e o painel, as configurações e a cópia funcionam.
    readonly property bool available: client.connected && error === ""

    // O clipboard.history: a revisão muda a cada mudança do histórico.
    property int revision: -1
    property int count: 0
    property int pinned: 0

    // A página mostrada: os itens do clipboard.list, já na ordem do daemon
    // (fixados primeiro), com o filtro e a busca que a pediram.
    property var items: []
    property int total: 0
    property string kind: "all"
    property string query: ""
    readonly property int pageSize: 50
    // O clipboard.list aceita no máximo 200 por pedido.
    readonly property int maxPage: 200
    // Cada troca da página (append falso) ganha um token: a resposta de uma
    // troca anterior chega com o token velho e é ignorada.
    property int token: 0
    // Uma troca em voo; as páginas dela juntam em `buffer` até a última.
    property bool loading: false
    property var buffer: []
    // Uma página de somar (more) em voo: a rolagem não pede outra até ela chegar.
    property bool paging: false

    // A sessão Wayland que o shell vê: o daemon usa a dele, se tiver.
    readonly property string display: Quickshell.env("WAYLAND_DISPLAY") ?? ""

    // Os tópicos a assinar: o estado sempre; o histórico só com `watching`.
    function wantedTopics(watching: bool): var {
        const topics = ["clipboard.status"];
        if (watching)
            topics.push("clipboard.history");
        return topics;
    }

    function sync(): void {
        client.want("clipboard", wantedTopics(watching));
    }

    function configureParams(limit: int, persist: bool, display: string): var {
        const params = {
            limit: limit,
            persist: persist
        };
        if (display !== "")
            params.waylandDisplay = display;
        return params;
    }

    // Diz ao daemon o limite, a persistência e a sessão, só com a conexão
    // feita; vem antes do sync(), para o daemon ter o configure antes do
    // assinante.
    function configure(): void {
        if (client.connected)
            client.call("clipboard.configure", configureParams(limit, persist, display), null);
    }

    // Sem `kind` para "all"; sem `query` vazia ou só de espaços.
    function listParams(kind: string, query: string, offset: int, limit: int): var {
        const params = {};
        if (kind !== "all")
            params.kind = kind;
        if (query.trim() !== "")
            params.query = query;
        params.offset = offset;
        params.limit = limit;
        return params;
    }

    // Uma página nova do começo, com esse filtro e essa busca.
    function load(kind: string, query: string): void {
        root.kind = kind;
        root.query = query;
        fetch(0, pageSize, false);
    }

    // Mais uma página no fim da lista; nada com uma troca ou outra página em
    // voo (a troca vence) ou com a lista toda.
    function more(): void {
        if (loading || paging || items.length >= total)
            return;
        paging = true;
        fetch(items.length, pageSize, true);
    }

    // Uma troca (append falso) ganha token novo e põe a lista em espera; somar
    // usa o token de agora, sem trocá-lo (uma troca que vier depois vence).
    function fetch(offset: int, limit: int, append: bool): void {
        if (!append) {
            token++;
            loading = true;
            paging = false;
            buffer = [];
        }
        request(token, offset, limit, append);
    }

    // Pede até `limit` itens a partir de `offset`, de 200 em 200.
    function request(t: int, offset: int, limit: int, append: bool): void {
        const n = Math.min(limit, maxPage);
        client.call("clipboard.list", listParams(kind, query, offset, n), response => root.applyPage(t, append, response, offset, limit));
    }

    // Os itens de `page` cujo id não está em `list`, somados ao fim dela.
    function merge(list: var, page: var): var {
        const seen = new Set(list.map(item => item.id));
        return list.concat(page.filter(item => !seen.has(item.id)));
    }

    // A resposta de um clipboard.list pedido com o token `t`, a partir de
    // `offset`, de um total de `limit`. Token velho não muda nada; erro só
    // acaba a espera. Somar junta a página à lista, pulando os ids que já estão;
    // a troca junta as páginas e só troca a lista na última.
    function applyPage(t: int, append: bool, response: var, offset: int, limit: int): void {
        if (t !== token)
            return;
        const result = response?.result;
        if (append)
            paging = false;
        if (!result || response.error) {
            if (!append) {
                loading = false;
                buffer = [];
            }
            return;
        }
        const page = result.items ? Array.from(result.items) : [];
        const n = Math.min(limit, maxPage);
        if (append) {
            items = merge(Array.from(items), page);
            total = Number(result.total ?? 0);
            return;
        }
        buffer = merge(Array.from(buffer), page);
        if (limit > n && page.length === n) {
            request(t, offset + n, limit - n, false);
            return;
        }
        items = buffer;
        total = Number(result.total ?? 0);
        buffer = [];
        loading = false;
    }

    // Um estado recebido do daemon; `null` (o tópico ainda sem estado) e
    // tópico desconhecido não mudam nada.
    function apply(topic: string, data: var): void {
        if (data === null || data === undefined)
            return;
        switch (topic) {
        case "clipboard.history":
            applyHistory(data);
            break;
        case "clipboard.status":
            applyStatus(data);
            break;
        }
    }

    // Uma revisão nova repede do começo o tanto que já estava na tela.
    function applyHistory(data: var): void {
        count = Number(data.count ?? 0);
        pinned = Number(data.pinned ?? 0);
        const next = Number(data.revision ?? -1);
        if (next === revision)
            return;
        revision = next;
        fetch(0, Math.max(pageSize, items.length), false);
    }

    function applyStatus(data: var): void {
        moduleAvailable = data.available === true;
        error = data.error ? String(data.error) : "";
    }

    // A conexão com o daemon mudou: ao cair, o módulo e a página somem (a
    // revisão volta a −1, para a próxima repaginar); nos dois casos, a
    // configuração e a assinatura vão de novo, nessa ordem.
    function connectionChanged(connected: bool): void {
        if (!connected) {
            moduleAvailable = false;
            items = [];
            total = 0;
            revision = -1;
            token++;
            loading = false;
            paging = false;
            buffer = [];
        }
        start();
    }

    // Os métodos, sem esperar resposta (o histórico novo chega pelo tópico).
    function copy(id: int): void {
        client.call("clipboard.copy", {
            id: id
        }, null);
    }

    function remove(id: int): void {
        client.call("clipboard.remove", {
            id: id
        }, null);
    }

    function pin(id: int, pinned: bool): void {
        client.call("clipboard.pin", {
            id: id,
            pinned: pinned
        }, null);
    }

    // Limpa o histórico; `all` leva junto os fixados.
    function clear(all: bool): void {
        client.call("clipboard.clear", {
            all: all
        }, null);
    }

    // A resposta do copyImage chega aqui: `error` vazio se a imagem foi para a
    // área de transferência; senão, o motivo.
    signal imageCopied(string path, string error)
    // Sem resposta nesse prazo, o copyImage é dado como falho.
    property int copyTimeout: 3000

    // O motivo de um copyImage não ter ido, pela resposta (vazio se foi).
    function copyResult(response: var): string {
        if (!response)
            return "o lucernad não respondeu.";
        if (response.error)
            return String(response.error.message ?? "erro desconhecido.");
        return "";
    }

    // Uma imagem do disco na área de transferência (a captura de tela); com o
    // histórico desligado, ela não entra nele. O resultado sai uma vez só, em
    // `imageCopied`: pela resposta ou pelo prazo, o que vier primeiro.
    function copyImage(path: string): void {
        let settled = false;
        const deadline = deadlineTimer.createObject(root, {
            interval: copyTimeout
        }) as Timer;
        const finish = text => {
            if (settled)
                return;
            settled = true;
            deadline.stop();
            deadline.destroy();
            root.imageCopied(path, text);
        };
        deadline.triggered.connect(() => finish(`o lucernad não respondeu em ${Math.round(copyTimeout / 1000)} s.`));
        deadline.start();
        client.call("clipboard.copyImage", {
            path: path,
            store: watching
        }, response => finish(copyResult(response)));
    }

    Component {
        id: deadlineTimer

        Timer {
            repeat: false
        }
    }

    onWatchingChanged: sync()
    onLimitChanged: configure()
    onPersistChanged: configure()

    Connections {
        target: root.client

        function onReceived(topic: string, data: var): void {
            root.apply(topic, data);
        }

        function onConnectedChanged(): void {
            root.connectionChanged(root.client.connected);
        }
    }

    // A partida e cada conexão: o configure vai antes da assinatura, para o
    // daemon ter o configure antes do assinante.
    function start(): void {
        configure();
        sync();
    }

    Component.onCompleted: start()

    // Cola na janela em foco: Ctrl+V, ou Ctrl+Shift+V num terminal. Com um
    // atraso, para o painel fechar e o foco voltar para a janela.
    function paste(): void {
        pasteDelay.restart();
    }

    readonly property var terminals: ["kitty", "foot", "footclient", "alacritty", "org.wezfurlong.wezterm", "com.mitchellh.ghostty", "org.kde.konsole", "konsole", "org.gnome.terminal", "gnome-terminal-server", "org.gnome.ptyxis", "xterm", "st-256color", "tilix", "terminator"]

    Timer {
        id: pasteDelay

        interval: 180
        onTriggered: activeWindow.running = true
    }

    Process {
        id: activeWindow

        command: ["hyprctl", "activewindow", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let cls = "";
                try {
                    cls = String(JSON.parse(text).class ?? "").toLowerCase();
                } catch (e) {}
                const mods = root.terminals.includes(cls) ? "CTRL SHIFT" : "CTRL";
                Hypr.dispatch(`hl.dsp.send_shortcut({ mods = "${mods}", key = "V" })`);
            }
        }
    }
}
