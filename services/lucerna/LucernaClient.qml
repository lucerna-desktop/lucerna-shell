import QtQuick
import Quickshell
import Quickshell.Io

// Cliente do protocolo do Lucerna (JSON-RPC 2.0, uma mensagem por linha, num
// socket Unix), genérico: serve ao lucernad e, depois, aos apps. Conecta ao
// socket do `app`, faz o aperto de mão (lucerna.hello), assina a união dos
// tópicos que cada serviço pede por want(dono, tópicos) (só os que o hello diz
// que o app oferece: um tópico desconhecido falharia a assinatura inteira),
// guarda o último estado de cada um em `states` (descartando o lucerna.state
// de seq velho) e avisa em `received`; call() chama um método e entrega a
// resposta a quem pediu. Quando a conexão cai, ou o socket ainda não existe,
// falha os pedidos pendentes e tenta de novo com espera crescente (a mesma
// regra do SDK, com o teto em `maxBackoff`). O cliente escreve no log ao
// conectar, ao perder a conexão e quando o app recusa uma assinatura; o Socket
// do Quickshell, à parte, avisa (WARN quickshell.io.socket) a cada tentativa
// que falha.
// Com o `command` (o binário do app, o `app.tui` do manifesto), um socket que
// não existe ou recusa a conexão sobe o serviço (`<command> serve`, pelo
// ServeLauncher) e tenta de novo com a espera do SDK (10 ms × 2^n, até
// 200 ms) por até 2 s; sem atender, `serveState` vira "failed" e o `error`
// diz o caminho do log, e o cliente segue tentando com a espera normal, sem
// subir de novo até conectar. Sem `command` (o lucernad), só tenta de novo.
Scope {
    id: root

    // O id do app (o nome do socket).
    property string app
    // ${XDG_RUNTIME_DIR}/lucerna/<app>.sock; vazio sem XDG_RUNTIME_DIR (aí
    // nunca conecta).
    property string socketPath: {
        const dir = Quickshell.env("XDG_RUNTIME_DIR");
        return dir ? `${dir}/lucerna/${app}.sock` : "";
    }
    readonly property string protocol: "1.0"
    readonly property string clientName: "shell"
    // O binário do app, que sobe o serviço com `serve`; vazio: não sobe nada.
    property string command: ""
    // O log do serviço subido pelo cliente; vazio: não sobe nada.
    property string serveLog: ServeLauncher.logPath(Quickshell.env("XDG_STATE_HOME") ?? "", Quickshell.env("HOME") ?? "", app)
    // A subida do serviço: "" (nenhuma), "starting" (esperando o socket) ou
    // "failed" (não atendeu em 2 s; o `error` diz o log).
    property string serveState: ""
    // Quando a subida que este cliente espera começou (Date.now()).
    property real spawnedAt: 0
    // Tentativas na espera da subida, para a espera crescente do SDK.
    property int spawnAttempt: 0
    // O QLocalSocket::LocalSocketError da última tentativa; -1 sem erro.
    property int lastError: -1
    // A espera agendada antes da próxima tentativa, em ms.
    readonly property alias retryDelay: retry.interval
    // O aperto de mão foi feito (não só o socket aberto).
    property bool connected: false
    // A mensagem do último erro do aperto de mão; vazia depois de conectar.
    property string error: ""
    // Tópico → o último `data` recebido.
    property var states: ({})
    // Tópico → o último seq aceito, zerado a cada conexão nova (o seq do
    // serviço volta a 0 quando ele reinicia).
    property var seqs: ({})
    // Os tópicos que quem usa quer assinados; reassinados a cada conexão.
    property var wanted: []
    // Dono → os tópicos que ele quer (o `wanted` é a união).
    property var owners: ({})
    // Os tópicos e fluxos que o app oferece (o `topics` e o `streams` da
    // resposta do hello); null antes do hello ou se ele não os listar (aí
    // nada é filtrado).
    property var offered: null
    // Id → { method, params, done }: os pedidos sem resposta.
    property var pending: ({})
    property int nextId: 1
    // Tentativas falhas seguidas, para a espera crescente.
    property int attempt: 0
    // O teto da espera entre tentativas, em ms.
    property int maxBackoff: 5000
    // Conectado há menos de 1 s: a espera ainda não zerou (uma conexão que cai
    // logo depois do aperto de mão não recomeça do 100 ms).
    readonly property alias settling: settle.running

    signal received(string topic, var data)

    // A espera antes da próxima tentativa: min(100 ms × 2^tentativa, maxBackoff).
    function backoff(attempt: int): int {
        return Math.min(100 * 2 ** attempt, root.maxBackoff);
    }

    // Ninguém ouvindo no socket: ConnectionRefusedError (0) ou
    // ServerNotFoundError (2), como o `nobody_listening` do SDK.
    function nobodyListening(code: int): bool {
        return code === 0 || code === 2;
    }

    // A espera na subida: min(10 ms × 2^n, 200 ms), a do SDK.
    function spawnDelay(n: int): int {
        return Math.min(10 * 2 ** n, 200);
    }

    // Uma mensagem JSON-RPC numa linha: com `id` null, uma notificação; com
    // `params` null, sem a chave.
    function encode(id: var, method: string, params: var): string {
        const message = {
            jsonrpc: "2.0"
        };
        if (id !== null && id !== undefined)
            message.id = id;
        message.method = method;
        if (params !== null && params !== undefined)
            message.params = params;
        return `${JSON.stringify(message)}\n`;
    }

    function helloParams(): var {
        return {
            protocol: root.protocol,
            client: root.clientName,
            app: root.app
        };
    }

    // O objeto JSON da linha, ou null para o que não é um objeto.
    function parse(line: string): var {
        try {
            const value = JSON.parse(line);
            return value !== null && typeof value === "object" && !Array.isArray(value) ? value : null;
        } catch (e) {
            return null;
        }
    }

    // O estado vale? O retrato (resposta do subscribe) vale com seq igual ao
    // último; o lucerna.state, só com seq maior. Atualiza o último aceito.
    function accept(topic: string, seq: real, snapshot: bool): bool {
        const last = seqs[topic];
        const fresh = last === undefined || (snapshot ? seq >= last : seq > last);
        if (fresh) {
            const next = Object.assign({}, seqs);
            next[topic] = seq;
            seqs = next;
        }
        return fresh;
    }

    // Grava um estado ({ topic, seq, data }) aceito e avisa em `received`,
    // também para o retrato da assinatura.
    function store(state: var, snapshot: bool): void {
        if (!state || typeof state.topic !== "string" || !Number.isFinite(state.seq) || !accept(state.topic, Number(state.seq), snapshot))
            return;
        const next = Object.assign({}, states);
        next[state.topic] = state.data;
        states = next;
        root.received(state.topic, state.data);
    }

    // Uma linha do socket: a resposta vai para quem pediu; o lucerna.state,
    // para o store().
    function receive(line: string): void {
        const message = parse(line);
        if (!message)
            return;
        if (message.method === "lucerna.state") {
            store(message.params, false);
            return;
        }
        const entry = message.id === undefined || message.id === null ? undefined : pending[message.id];
        if (!entry)
            return;
        const next = Object.assign({}, pending);
        delete next[message.id];
        pending = next;
        entry.done?.(message);
    }

    // Escreve uma linha, só com o socket aberto.
    function send(line: string): bool {
        if (!socket.connected)
            return false;
        socket.write(line);
        socket.flush();
        return true;
    }

    // Manda um pedido e guarda o `done` para a resposta; devolve o id.
    function request(method: string, params: var, done: var): int {
        const id = nextId++;
        const next = Object.assign({}, pending);
        next[id] = {
            method: method,
            params: params,
            done: done
        };
        pending = next;
        send(encode(id, method, params));
        return id;
    }

    function handshake(): void {
        request("lucerna.hello", helloParams(), response => root.greeted(response));
    }

    // A resposta do hello: no sucesso, conectado e reassina (a espera só zera
    // depois de 1 s conectado, no settled()); no erro, guarda a mensagem,
    // fecha o socket e segue para a nova tentativa, com a espera (sem contar
    // com o serviço fechar a conexão).
    function greeted(response: var): void {
        // Alguém atendeu: a subida acabou, com ou sem o hello aceito.
        serveState = "";
        ServeLauncher.release(app);
        if (response.error) {
            error = String(response.error.message);
            socket.connected = false;
            lost();
            return;
        }
        offered = offeredTopics(response.result);
        connected = true;
        error = "";
        settle.restart();
        console.info(`lucerna: conectado ao ${app}`);
        resubscribe();
    }

    // Os tópicos e fluxos do resultado do hello, numa lista; null se ele não
    // trouxer nenhuma das duas listas.
    function offeredTopics(result: var): var {
        const topics = Array.isArray(result?.topics) ? result.topics : null;
        const streams = Array.isArray(result?.streams) ? result.streams : null;
        if (topics === null && streams === null)
            return null;
        return union([topics ?? [], streams ?? []]);
    }

    // Só os tópicos que o app oferece (todos, sem a lista do hello): o SDK
    // recusa a assinatura inteira por um tópico desconhecido (-32012), e um
    // app sem um módulo derrubaria os tópicos dos outros.
    function subscribable(topics: var): var {
        const list = Array.from(topics);
        if (offered === null)
            return list;
        const known = Array.from(offered);
        return list.filter(topic => known.includes(topic));
    }

    // Os tópicos que quem usa quer: assina os novos e larga os que saíram
    // (com a conexão feita; senão, só guarda, para o resubscribe()).
    function setTopics(topics: var): void {
        const next = Array.from(topics);
        const added = next.filter(topic => !wanted.includes(topic));
        const removed = wanted.filter(topic => !next.includes(topic));
        wanted = next;
        if (!connected)
            return;
        if (added.length > 0)
            subscribeNow(added);
        if (removed.length > 0)
            unsubscribeNow(removed);
    }

    // Os tópicos de todas as listas, sem repetir, na ordem em que aparecem.
    function union(lists: var): var {
        const all = [];
        for (const list of lists)
            for (const topic of list)
                if (!all.includes(topic))
                    all.push(topic);
        return all;
    }

    // Cada serviço (dono) diz os tópicos dele; o cliente assina a união.
    function want(owner: string, topics: var): void {
        const next = Object.assign({}, owners);
        next[owner] = Array.from(topics);
        owners = next;
        setTopics(union(Object.values(owners)));
    }

    // Assina os tópicos que o app oferece; nada a mandar sem nenhum.
    function subscribeNow(topics: var): void {
        const list = subscribable(topics);
        if (list.length === 0)
            return;
        request("lucerna.subscribe", {
            topics: list
        }, response => root.subscribed(response, list));
    }

    function unsubscribeNow(topics: var): void {
        const list = subscribable(topics);
        if (list.length === 0)
            return;
        request("lucerna.unsubscribe", {
            topics: list
        }, null);
    }

    // A resposta do subscribe: o retrato de cada tópico. Um erro do app vai
    // para o log; o da conexão que caiu (código -1, do failPending) não, que
    // a queda já foi contada.
    function subscribed(response: var, topics: var): void {
        const failure = response.error;
        if (failure && failure.code !== -1)
            console.warn(`lucerna: o ${app} recusou a assinatura de ${Array.from(topics ?? []).join(", ")}: ${failure.code} ${failure.message}`);
        for (const state of response.result?.states ?? [])
            store(state, true);
    }

    // A conexão durou 1 s: a próxima queda recomeça a espera do 100 ms.
    function settled(): void {
        attempt = 0;
    }

    // Reassina tudo o que os donos querem (e o app oferece) numa conexão nova.
    function resubscribe(): void {
        subscribeNow(wanted);
    }

    // Chama um método do app. O `done` (opcional) recebe a resposta inteira
    // ({ result } ou { error }); sem conexão, recebe o erro na hora e o id é -1.
    function call(method: string, params: var, done: var): int {
        if (!connected) {
            done?.({
                error: {
                    code: -1,
                    message: `Sem conexão com o ${app}.`
                }
            });
            return -1;
        }
        return request(method, params, done);
    }

    // (Re)abre o socket, se houver caminho.
    function open(): void {
        retry.stop();
        if (!socketPath)
            return;
        socket.connected = false;
        // Fechar um socket aberto passa pelo lost(), que agendaria outra
        // tentativa: quem abre agora é este open().
        retry.stop();
        socket.connected = true;
    }

    // O socket abriu: um serviço novo recomeça o seq, e o aperto de mão vem
    // antes de tudo.
    function opened(): void {
        seqs = ({});
        offered = null;
        error = "";
        lastError = -1;
        handshake();
    }

    // A conexão caiu ou não abriu. A mesma queda chega pelo `error` e pelo
    // connectionStateChanged; a segunda volta aqui, com a tentativa já agendada.
    // A tentativa é agendada antes de falhar os pedidos: o hello falhado chama
    // o greeted(), que volta aqui e não pode contar a queda de novo.
    function lost(): void {
        if (retry.running)
            return;
        settle.stop();
        if (connected)
            console.info(`lucerna: sem conexão com o ${app}`);
        const wasConnected = connected;
        connected = false;
        retry.interval = wasConnected ? backoff(attempt++) : nextDelay();
        retry.start();
        failPending(`Sem conexão com o ${app}.`);
    }

    // O socket deu erro (o código do QLocalSocket): guarda e segue pela queda.
    function failed(code: int): void {
        lastError = code;
        lost();
    }

    // A espera antes da próxima tentativa que falhou sem conexão: sobe o
    // serviço se ninguém ouve e há como; esperando a subida, a espera do SDK
    // até os 2 s; passou deles, o erro com o log; fora isso, a normal.
    function nextDelay(): int {
        const now = Date.now();
        if (serveState === "" && command && serveLog && nobodyListening(lastError)) {
            ServeLauncher.launch(app, command, serveLog, now);
            serveState = "starting";
            spawnedAt = now;
            spawnAttempt = 0;
        }
        if (serveState === "starting") {
            const left = ServeLauncher.wait - (now - spawnedAt);
            if (left > 0)
                return Math.min(spawnDelay(spawnAttempt++), left);
            // O erro antes do estado: quem olha o "failed" já acha o log.
            error = `O serviço do ${app} não subiu em 2 s. Veja o log em ${serveLog}.`;
            serveState = "failed";
            console.warn(`lucerna: ${error}`);
        }
        return backoff(attempt++);
    }

    // Responde com erro a todos os pedidos pendentes.
    function failPending(message: string): void {
        const failed = pending;
        pending = ({});
        for (const id of Object.keys(failed))
            failed[id].done?.({
                error: {
                    code: -1,
                    message: message
                }
            });
    }

    Timer {
        id: retry

        repeat: false
        onTriggered: root.open()
    }

    Timer {
        id: settle

        interval: 1000
        repeat: false
        onTriggered: root.settled()
    }

    Socket {
        id: socket

        path: root.socketPath
        parser: SplitParser {
            onRead: line => root.receive(line)
        }
        onConnectionStateChanged: socket.connected ? root.opened() : root.lost()
        onError: code => root.failed(code)
    }

    Component.onCompleted: open()
}
