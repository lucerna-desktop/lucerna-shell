// Testes de services/LucernaClient: as mensagens, as linhas, o seq e o aperto
// de mão, sem socket. Cada cliente vem da fábrica t.lucernaClient() (app
// "teste", sem socketPath: o socket nunca conecta, e os pedidos ficam só no
// pending) e é destruído no fim do caso.
function run(t) {
    // A resposta JSON-RPC de sucesso, numa linha.
    function ok(id, result) {
        return JSON.stringify({ jsonrpc: "2.0", id: id, result: result });
    }

    // As chaves de c.pending, como números.
    function ids(c) {
        return Object.keys(c.pending).map(Number);
    }

    // Os métodos pendentes, na ordem dos ids.
    function methods(c) {
        return ids(c).map(id => c.pending[id].method);
    }

    // A resposta do hello de um app que oferece esses tópicos e fluxos.
    function hello(topics, streams) {
        return { protocol: "1.0", app: "teste", version: "0.1.0", topics: topics, streams: streams, methods: [] };
    }

    // Um cliente com os tópicos pedidos, o socket "aberto" e o hello respondido
    // (o app oferece os tópicos a, b e c e o fluxo x).
    function ready(topics) {
        const c = t.lucernaClient();
        c.setTopics(topics);
        c.opened();
        c.receive(ok(ids(c)[0], hello(["a", "b", "c"], ["x"])));
        return c;
    }

    // Os tópicos de cada subscribe pendente, na ordem dos ids.
    function subscribes(c) {
        return ids(c).filter(id => c.pending[id].method === "lucerna.subscribe").map(id => c.pending[id].params.topics);
    }

    // Um caso com um cliente novo, destruído no fim (mesmo com exceção); com
    // `topics`, o cliente vem do ready(topics), já conectado.
    function withClient(name, body, topics) {
        t.test(name, () => {
            const c = topics === undefined ? t.lucernaClient() : ready(topics);
            try {
                body(c);
            } finally {
                c.destroy();
            }
        });
    }

    withClient("lucernaclient: espera crescente até 5 s", c => {
        t.eq([0, 1, 2, 5, 6, 20].map(a => c.backoff(a)), [100, 200, 400, 3200, 5000, 5000]);
        c.maxBackoff = 30000;
        t.eq([6, 8, 9, 20].map(a => c.backoff(a)), [6400, 25600, 30000, 30000], "com o teto de 30 s");
    });

    withClient("lucernaclient: pedido e notificação numa linha de JSON", c => {
        t.eq(c.encode(3, "system.configure", { interval_ms: 1000 }), '{"jsonrpc":"2.0","id":3,"method":"system.configure","params":{"interval_ms":1000}}\n');
        t.eq(c.encode(null, "x.y", null), '{"jsonrpc":"2.0","method":"x.y"}\n', "notificação sem params");
        t.eq(c.helloParams(), { protocol: "1.0", client: "shell", app: "teste" });
    });

    withClient("lucernaclient: linha que não é objeto JSON vira null", c => {
        t.eq(["lixo", "", "[1]", "3"].map(l => c.parse(l)), [null, null, null, null]);
        t.eq(c.parse('{"a":1}'), { a: 1 }, "um objeto passa");
        c.receive("lixo");
        t.eq(c.states, {});
    });

    withClient("lucernaclient: seq velho é descartado; o retrato vale com seq igual", c => {
        t.eq([[2, false], [2, false], [1, false], [2, true], [3, false]].map(([seq, snapshot]) => c.accept("a", seq, snapshot)), [true, false, false, true, true]);
    });

    withClient("lucernaclient: o aperto de mão conecta, assina e o retrato avisa", c => {
        const got = [];
        c.received.connect((topic, data) => got.push([topic, data]));
        c.setTopics(["system.info"]);
        t.eq(ids(c), [], "desconectado, não assina");
        t.eq(c.wanted, ["system.info"]);
        c.opened();
        t.eq(methods(c), ["lucerna.hello"]);
        c.receive(ok(ids(c)[0], { protocol: "1.0", app: "teste" }));
        t.eq([c.connected, c.attempt, c.error], [true, 0, ""]);
        t.eq(methods(c), ["lucerna.subscribe"]);
        c.receive(ok(ids(c)[0], { states: [{ topic: "system.info", seq: 0, data: { hostname: "maquina" } }] }));
        t.eq(c.states["system.info"], { hostname: "maquina" });
        t.eq(got, [["system.info", { hostname: "maquina" }]], "o retrato emite received");
        t.eq(ids(c), [], "o subscribe saiu do pending");
    });

    withClient("lucernaclient: lucerna.state atualiza o tópico e descarta o repetido", c => {
        const got = [];
        c.received.connect((topic, data) => got.push([topic, data]));
        for (const [seq, data] of [[1, "a"], [1, "b"], [2, "c"]])
            c.receive(JSON.stringify({ jsonrpc: "2.0", method: "lucerna.state", params: { topic: "x", seq: seq, data: data } }));
        t.eq(got, [["x", "a"], ["x", "c"]]);
        t.eq(c.states.x, "c");
    }, []);

    withClient("lucernaclient: estado sem seq numérico é ignorado", c => {
        const got = [];
        c.received.connect((topic, data) => got.push([topic, data]));
        for (const seq of [undefined, null, "1", NaN, Infinity])
            c.store({ topic: "x", seq: seq, data: "ruim" }, false);
        c.subscribed({ result: { states: [{ topic: "y", data: "sem seq" }] } }, ["y"]);
        t.eq([got, c.states, c.seqs], [[], {}, {}]);
    }, []);

    withClient("lucernaclient: reconectar zera os seq vistos", c => {
        t.check(c.accept("a", 5, false));
        c.lost();
        c.opened();
        t.eq(c.seqs, {});
        t.check(c.accept("a", 1, false), "o seq 1 do daemon novo vale");
    });

    withClient("lucernaclient: erro no hello não conecta e guarda a mensagem", c => {
        c.opened();
        c.receive(JSON.stringify({ jsonrpc: "2.0", id: ids(c)[0], error: { code: -32010, message: "Versão do protocolo incompatível." } }));
        t.eq([c.connected, c.error], [false, "Versão do protocolo incompatível."]);
        t.eq([c.attempt, ids(c)], [1, []], "o cliente fecha e agenda a nova tentativa, com a espera");
        c.open();
        c.opened();
        t.eq(c.error, "", "uma conexão nova limpa o erro velho");
    });

    withClient("lucernaclient: queda durante o hello conta uma tentativa só", c => {
        c.opened();
        c.lost();
        t.eq([c.connected, c.attempt, ids(c)], [false, 1, []]);
        t.eq(c.error, "Sem conexão com o teste.");
    });

    withClient("lucernaclient: a espera só zera depois de 1 s conectado", c => {
        c.attempt = 3;
        c.opened();
        c.receive(ok(ids(c)[0], { protocol: "1.0", app: "teste" }));
        t.eq([c.connected, c.attempt, c.settling], [true, 3, true], "logo depois do hello, a espera continua");
        c.lost();
        t.eq([c.attempt, c.settling], [4, false], "caiu antes de 1 s: a espera cresce");
        c.open();
        c.opened();
        c.receive(ok(ids(c)[0], { protocol: "1.0", app: "teste" }));
        c.settled();
        t.eq(c.attempt, 0, "durou 1 s: zera");
    });

    withClient("lucernaclient: trocar os tópicos assina o novo e larga o velho", c => {
        c.receive(ok(ids(c)[0], { states: [] }));
        t.eq(ids(c), []);
        c.setTopics(["b"]);
        t.eq(methods(c), ["lucerna.subscribe", "lucerna.unsubscribe"]);
        t.eq(c.wanted, ["b"]);
    }, ["a"]);

    withClient("lucernaclient: a união dos tópicos sem repetir", c => {
        t.eq(c.union([["a", "b"], ["b", "c"], []]), ["a", "b", "c"]);
        t.eq(c.union([]), []);
    });

    withClient("lucernaclient: dois donos somam os tópicos e um não larga o do outro", c => {
        c.want("x", ["a", "b"]);
        c.want("y", ["b", "c"]);
        t.eq(c.wanted, ["a", "b", "c"]);
        c.want("x", []);
        t.eq(c.wanted, ["b", "c"]);

        const r = ready([]);
        try {
            r.want("y", ["c"]);
            r.want("x", ["a"]);
            r.want("x", []);
            const last = ids(r).map(id => r.pending[id]).pop();
            t.eq([last.method, last.params], ["lucerna.unsubscribe", { topics: ["a"] }]);
            t.eq(methods(r).filter(m => m === "lucerna.unsubscribe").length, 1, "o c do outro dono fica");
        } finally {
            r.destroy();
        }
    });

    withClient("lucernaclient: só assina o que o hello oferece", c => {
        t.eq(c.offeredTopics(hello(["s.a"], ["s.b"])), ["s.a", "s.b"]);
        t.eq(c.offeredTopics({ protocol: "1.0" }), null, "hello sem as listas: nada filtrado");
        c.want("system", ["system.info", "system.stats"]);
        c.want("spectrum", ["spectrum.status", "spectrum.bands"]);
        c.opened();
        c.receive(ok(ids(c)[0], hello(["system.info", "system.status"], ["system.stats"])));
        t.eq(subscribes(c), [["system.info", "system.stats"]], "sem o módulo spectrum, só os system.*");
        c.want("spectrum", ["spectrum.status"]);
        t.eq(subscribes(c).length, 1, "tópico que o app não tem não vira pedido");
        t.eq(c.subscribable(["system.status", "x"]), ["system.status"]);
    });

    withClient("lucernaclient: reconectar assina a união dos donos, filtrada", c => {
        c.want("system", ["a", "nao.existe"]);
        c.want("spectrum", ["x", "b"]);
        c.lost();
        c.open();
        c.opened();
        t.eq(c.offered, null, "o hello novo é que diz o que o app oferece");
        c.receive(ok(ids(c)[0], hello(["a", "b", "c"], ["x"])));
        t.eq(subscribes(c), [["a", "x", "b"]]);
    }, []);

    withClient("lucernaclient: assinatura recusada não grava nada", c => {
        c.subscribed({ error: { code: -32012, message: "tópico desconhecido" } }, ["a"]);
        c.subscribed({ error: { code: -1, message: "Sem conexão com o teste." } }, ["a"]);
        t.eq([c.states, c.seqs], [{}, {}]);
    }, []);

    withClient("lucernaclient: chamada sem conexão responde erro na hora", c => {
        let got = null;
        t.eq(c.call("x.y", {}, r => got = r), -1);
        t.eq(got, { error: { code: -1, message: "Sem conexão com o teste." } });
        t.eq(c.call("x.y", {}, null), -1, "sem callback");
        t.eq(ids(c), []);
    });

    withClient("lucernaclient: a resposta de uma chamada chega a quem pediu", c => {
        let got = null;
        const id = c.call("system.configure", { interval_ms: 1000 }, r => got = r);
        t.check(id > 0, "um id de verdade");
        t.eq(c.pending[id].method, "system.configure");
        c.receive(ok(id, {}));
        t.eq(got.result, {});
        t.check(!(id in c.pending), "o id saiu do pending");
    }, []);

    withClient("lucernaclient: chamada sem callback não quebra", c => {
        const id = c.call("x.y", {}, null);
        c.receive(ok(id, {}));
        c.call("x.y", {}, null);
        c.lost();
        t.eq(ids(c), []);
    }, []);

    withClient("lucernaclient: conexão perdida falha os pedidos e agenda nova tentativa", c => {
        let got = null;
        c.call("x.y", {}, r => got = r);
        c.lost();
        t.eq([c.connected, ids(c)], [false, []]);
        t.eq(got.error.message, "Sem conexão com o teste.");
        t.eq(c.attempt, 1);
        c.lost();
        t.eq(c.attempt, 1, "a mesma queda não conta duas vezes");
        c.open();
        c.lost();
        t.eq(c.attempt, 2);
        c.open();
        t.eq([c.connected, ids(c)], [false, []], "sem socketPath, o open() não conecta");
    }, []);

    // A subida do serviço: um cliente com o binário do app e o log, e o
    // ServeLauncher sem rodar nada (o `launched` só anota).
    // Recebe o cliente e a lista de comandos rodados.
    function withServe(name, body) {
        t.test(name, () => {
            const L = t.ServeLauncher;
            const runs = [];
            const note = argv => runs.push(argv);
            L.live = false;
            L.launched.connect(note);
            L.starting = ({});
            const c = t.lucernaClient();
            c.command = "lucerna-teste";
            c.serveLog = "/s/lucerna/teste/serve.log";
            try {
                body(c, runs);
            } finally {
                c.destroy();
                L.launched.disconnect(note);
                L.live = true;
                L.starting = ({});
            }
        });
    }

    // Os códigos do QLocalSocket::LocalSocketError.
    const REFUSED = 0, NOT_FOUND = 2, ACCESS = 3;

    // Uma tentativa que falha com `code` (o retry, a abertura e o erro).
    function fail(c, code) {
        c.open();
        c.failed(code);
    }

    withClient("lucernaclient: ninguém ouvindo é socket ausente ou recusado", c => {
        t.eq([REFUSED, 1, NOT_FOUND, ACCESS, -1].map(code => c.nobodyListening(code)), [true, false, true, false, false]);
        t.eq([0, 1, 2, 3, 4, 5, 9].map(n => c.spawnDelay(n)), [10, 20, 40, 80, 160, 200, 200], "a espera do SDK, até 200 ms");
    });

    withServe("lucernaclient: sem o binário, a recusa só tenta de novo", (c, runs) => {
        c.command = "";
        c.failed(NOT_FOUND);
        t.eq([runs, c.serveState, c.retryDelay, c.attempt], [[], "", 100, 1]);
    });

    withServe("lucernaclient: socket ausente sobe o serviço e espera crescente", (c, runs) => {
        c.failed(NOT_FOUND);
        t.eq(runs.length, 1, "subiu uma vez");
        t.eq(runs[0].slice(1), ["lucerna-teste", "/s/lucerna/teste/serve.log"]);
        t.eq([c.serveState, c.retryDelay], ["starting", 10]);
        const delays = [];
        for (let i = 0; i < 6; i++) {
            fail(c, REFUSED);
            delays.push(c.retryDelay);
        }
        t.eq(delays, [20, 40, 80, 160, 200, 200]);
        t.eq([runs.length, c.serveState, c.attempt], [1, "starting", 0], "não sobe de novo nem conta a espera normal");
    });

    withServe("lucernaclient: a espera não passa dos 2 s", (c, runs) => {
        c.failed(REFUSED);
        c.spawnedAt = Date.now() - 1950;
        c.spawnAttempt = 9;
        fail(c, REFUSED);
        t.check(c.retryDelay > 0 && c.retryDelay <= 50, `espera ${c.retryDelay}`);
    });

    withServe("lucernaclient: sem atender em 2 s, erro com o log e sem subir de novo", (c, runs) => {
        c.failed(NOT_FOUND);
        c.spawnedAt = Date.now() - 2001;
        fail(c, REFUSED);
        t.eq(c.serveState, "failed");
        t.eq(c.error, "O serviço do teste não subiu em 2 s. Veja o log em /s/lucerna/teste/serve.log.");
        t.eq([c.retryDelay, c.attempt], [100, 1], "segue tentando com a espera normal");
        fail(c, NOT_FOUND);
        t.eq([runs.length, c.serveState, c.attempt], [1, "failed", 2], "não sobe de novo");
        t.check(c.error.includes("/s/lucerna/teste/serve.log"), "o erro fica");
    });

    withServe("lucernaclient: outro erro do socket não sobe nada", (c, runs) => {
        c.failed(ACCESS);
        t.eq([runs, c.serveState], [[], ""]);
    });

    withServe("lucernaclient: sem log, não sobe", (c, runs) => {
        c.serveLog = "";
        c.failed(NOT_FOUND);
        t.eq([runs, c.serveState], [[], ""]);
    });

    withServe("lucernaclient: conectar zera a subida e a queda seguinte sobe de novo", (c, runs) => {
        c.failed(NOT_FOUND);
        c.open();
        c.opened();
        c.receive(ok(ids(c)[0], hello([], [])));
        t.eq([c.connected, c.serveState, c.error], [true, "", ""]);
        c.lost();
        fail(c, NOT_FOUND);
        t.eq([runs.length, c.serveState], [2, "starting"], "o serviço caiu: o próximo cliente sobe");
    });

    withServe("lucernaclient: a queda do serviço conectado (fim do socket) sobe de novo", (c, runs) => {
        c.opened();
        c.receive(ok(ids(c)[0], hello([], [])));
        c.failed(1);
        t.eq([runs.length, c.serveState], [0, ""], "o fim da conexão não é recusa");
        fail(c, REFUSED);
        t.eq([runs.length, c.serveState], [1, "starting"]);
    });

    withServe("lucernaclient: o hello recusado não sobe outro serviço", (c, runs) => {
        c.failed(NOT_FOUND);
        c.open();
        c.opened();
        c.receive(JSON.stringify({ jsonrpc: "2.0", id: ids(c)[0], error: { code: -32010, message: "Versão do protocolo incompatível." } }));
        t.eq([runs.length, c.serveState, c.error], [1, "", "Versão do protocolo incompatível."], "alguém atendeu: a subida acabou");
    });

    withServe("lucernaclient: dois clientes do mesmo app sobem um serviço só", (c, runs) => {
        const d = t.lucernaClient();
        try {
            d.command = c.command;
            d.serveLog = c.serveLog;
            c.failed(NOT_FOUND);
            d.failed(NOT_FOUND);
            t.eq([runs.length, c.serveState, d.serveState], [1, "starting", "starting"], "o segundo espera o primeiro");
        } finally {
            d.destroy();
        }
    });
}
