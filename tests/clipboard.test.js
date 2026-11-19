// Testes de services/Clipboard: o adaptador do módulo clipboard do lucernad
// (os tópicos clipboard.history e clipboard.status, a configuração antes da
// assinatura, as páginas do clipboard.list e os métodos). A observação, o
// histórico e a cópia de volta ficaram no daemon, com os testes em Rust. Cada
// caso que conecta usa um cliente da fábrica t.lucernaClient() posto em
// C.client (o socket nunca abre: os pedidos ficam no pending), e os dados
// chegam pelo caminho real (a resposta pelo receive() e o sinal received).
function run(t) {
    const C = t.Clipboard;

    // O estado de antes, restaurado e conferido no fim de cada caso (a suíte
    // roda no mesmo processo que as seguintes).
    const fields = ["client", "watching", "limit", "persist", "items", "total", "moduleAvailable", "error", "revision", "count", "pinned", "kind", "query", "loading", "paging"];
    const original = {};
    for (const f of fields)
        original[f] = C[f];

    function restore() {
        // O client por último: as outras trocas ainda caem no cliente do caso.
        for (const f of fields)
            if (f !== "client")
                C[f] = original[f];
        C.client = original.client;
    }

    function restored() {
        return fields.every(f => f === "client" ? C.client === original.client : JSON.stringify(C[f]) === JSON.stringify(original[f]));
    }

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

    // Os ids pendentes de um método, na ordem.
    function idsOf(c, method) {
        return ids(c).filter(id => c.pending[id].method === method);
    }

    // O último pedido pendente de um método.
    function last(c, method) {
        const list = idsOf(c, method);
        return list.length ? Object.assign({ id: list[list.length - 1] }, c.pending[list[list.length - 1]]) : null;
    }

    // A resposta do hello do lucernad com o módulo clipboard.
    function hello(topics) {
        return { protocol: "1.0", app: "lucernad", version: "0.1.0", topics: topics, streams: [], methods: [] };
    }

    // Um cliente novo em C.client, com o socket "aberto" e o hello respondido
    // pelo receive() (o greeted() de verdade liga o connected).
    function wired() {
        const c = t.lucernaClient();
        C.client = c;
        c.opened();
        c.receive(ok(ids(c)[0], hello(["clipboard.history", "clipboard.status"])));
        return c;
    }

    // Um caso com o cliente do wired() (ou um cru, sem `connect`), restaurado
    // e destruído no fim, mesmo com exceção.
    function withClient(name, body, connect) {
        t.test(name, () => {
            const c = connect === false ? t.lucernaClient() : wired();
            if (connect === false)
                C.client = c;
            try {
                body(c);
            } finally {
                restore();
                c.destroy();
                t.check(restored(), "estado original restaurado");
            }
        });
    }

    // Itens de texto com esses ids, como no clipboard.list.
    function texts(list) {
        return list.map(id => ({ id: id, kind: "text", preview: `item ${id}`, size: 6, lines: 1, created: id, used: id, pinned: false }));
    }

    // Os ids dos itens mostrados.
    function shown() {
        return Array.from(C.items).map(item => item.id);
    }

    t.test("clipboard: tópicos conforme o pedido", () => {
        t.eq(C.wantedTopics(false), ["clipboard.status"]);
        t.eq(C.wantedTopics(true), ["clipboard.status", "clipboard.history"]);
    });

    t.test("clipboard: parâmetros do configure e da lista", () => {
        t.eq(C.configureParams(50, false, ""), { limit: 50, persist: false });
        t.eq(C.configureParams(100, true, "wayland-1"), { limit: 100, persist: true, waylandDisplay: "wayland-1" });
        t.eq(C.listParams("all", "  ", 0, 50), { offset: 0, limit: 50 });
        t.eq(C.listParams("files", "pdf", 50, 50), { kind: "files", query: "pdf", offset: 50, limit: 50 });
        t.eq(C.listParams("text", " ação ", 0, 200), { kind: "text", query: " ação ", offset: 0, limit: 200 }, "a busca vai como digitada");
    });

    withClient("clipboard: configurar vem antes de assinar", c => {
        C.watching = true;
        t.eq(c.owners.clipboard, ["clipboard.status", "clipboard.history"], "sem conexão, só guarda");
        t.eq(methods(c), [], "sem conexão, nada é pedido");
        c.opened();
        c.receive(ok(ids(c)[0], hello(["clipboard.history", "clipboard.status"])));
        t.check(c.connected, "o hello conectou");
        const configure = last(c, "clipboard.configure");
        t.check(configure !== null, "a conexão configura");
        t.eq(configure.params, C.configureParams(C.limit, C.persist, C.display));
        const history = idsOf(c, "lucerna.subscribe").filter(id => Array.from(c.pending[id].params.topics).includes("clipboard.history"));
        t.check(history.length > 0, "assina o histórico");
        t.check(configure.id < Math.min(...history), `o configure (${configure.id}) antes do subscribe (${history})`);
    }, false);

    withClient("clipboard: na partida com o cliente já conectado, configura antes de assinar", idle => {
        // O Component.onCompleted chama o start(). O watching muda num cliente
        // sem conexão (nada sai); o conectado entra depois, sem o sinal de
        // conexão, como no serviço criado depois do hello.
        C.watching = true;
        const c = t.lucernaClient();
        try {
            c.opened();
            c.receive(ok(ids(c)[0], hello(["clipboard.history", "clipboard.status"])));
            t.check(c.connected, "o hello conectou");
            t.eq(methods(c), [], "nada pendente antes da partida");
            C.client = c;
            C.start();
            t.eq(methods(c), ["clipboard.configure", "lucerna.subscribe"]);
            t.eq(c.pending[ids(c)[0]].params, C.configureParams(C.limit, C.persist, C.display));
            t.eq(Array.from(c.pending[ids(c)[1]].params.topics), ["clipboard.status", "clipboard.history"]);
        } finally {
            C.client = idle;
            c.destroy();
        }
    }, false);

    withClient("clipboard: as configurações mandam o configure de novo", c => {
        c.pending = {};
        C.limit = 25;
        t.eq(last(c, "clipboard.configure").params, C.configureParams(25, C.persist, C.display));
        C.persist = !C.persist;
        t.eq(last(c, "clipboard.configure").params, C.configureParams(25, C.persist, C.display));
    });

    withClient("clipboard: a página pelo fio", c => {
        c.pending = {};
        C.load("all", "");
        t.eq(methods(c), ["clipboard.list"]);
        const first = last(c, "clipboard.list");
        t.eq(first.params, { offset: 0, limit: C.pageSize });
        t.check(C.loading, "a troca fica em voo");
        c.receive(ok(first.id, { items: texts([30, 29, 28]), total: 120 }));
        t.eq([shown(), C.total, C.loading], [[30, 29, 28], 120, false]);

        C.more();
        const next = last(c, "clipboard.list");
        t.eq(next.params, { offset: 3, limit: C.pageSize });
        t.check(!C.loading, "somar não é troca");
        c.receive(ok(next.id, { items: texts([28, 27, 26]), total: 121 }));
        t.eq([shown(), C.total], [[30, 29, 28, 27, 26], 121], "soma sem repetir o 28");

        // Uma troca vence a anterior: a resposta velha não muda nada.
        C.load("text", "a");
        const old = last(c, "clipboard.list");
        t.eq(old.params, { kind: "text", query: "a", offset: 0, limit: C.pageSize });
        C.load("text", "ab");
        const current = last(c, "clipboard.list");
        c.receive(ok(old.id, { items: texts([1]), total: 1 }));
        t.eq([shown(), C.loading], [[30, 29, 28, 27, 26], true], "o token velho não vale");

        // Com a troca em voo, more() não pede nada; a resposta da troca vale.
        const before = ids(c).length;
        C.more();
        t.eq(ids(c).length, before, "more() espera a troca");
        c.receive(ok(current.id, { items: texts([9, 8]), total: 2 }));
        t.eq([shown(), C.total, C.loading, C.kind, C.query], [[9, 8], 2, false, "text", "ab"]);

        // No fim da lista, more() não pede nada.
        C.more();
        t.eq(ids(c).length, 0, "nada além do total");

        // Erro na troca: a lista fica, a espera acaba.
        C.load("all", "");
        c.receive(JSON.stringify({ jsonrpc: "2.0", id: last(c, "clipboard.list").id, error: { code: -32602, message: "x" } }));
        t.eq([shown(), C.loading], [[9, 8], false]);
    });

    withClient("clipboard: a rolagem não repete o pedido de mais", c => {
        C.items = texts([9, 8, 7]);
        C.total = 10;
        c.pending = {};
        C.more();
        C.more();
        C.more();
        t.eq(idsOf(c, "clipboard.list").length, 1, "um pedido só enquanto a página não chega");
        const page = last(c, "clipboard.list");
        c.receive(ok(page.id, { items: texts([6, 5]), total: 10 }));
        C.more();
        t.eq(last(c, "clipboard.list").params, { offset: 5, limit: C.pageSize }, "chegou: pode pedir a seguinte");
        // Erro também libera.
        const failing = last(c, "clipboard.list");
        c.receive(JSON.stringify({ jsonrpc: "2.0", id: failing.id, error: { code: -32602, message: "x" } }));
        C.more();
        t.check(last(c, "clipboard.list").id > failing.id, "o erro libera o pedido");
        // Uma troca de página e a queda da conexão também.
        C.load("all", "");
        t.check(!C.paging, "a troca zera");
        C.more();
        C.connectionChanged(false);
        t.check(!C.paging, "a queda zera");
    });

    withClient("clipboard: a revisão pelo sinal real repagina", c => {
        C.watching = true;
        C.items = texts([5, 4, 3]);
        C.total = 3;
        c.pending = {};
        // A mesma passagem dos dados do daemon: o JSON vira objeto do QML.
        c.received("clipboard.history", JSON.parse(JSON.stringify({ revision: 4, count: 9, pinned: 2 })));
        t.eq([C.revision, C.count, C.pinned], [4, 9, 2]);
        t.eq(methods(c), ["clipboard.list"]);
        const page = last(c, "clipboard.list");
        t.eq(page.params, { offset: 0, limit: Math.max(C.pageSize, 3) });
        c.received("clipboard.history", JSON.parse(JSON.stringify({ revision: 4, count: 9, pinned: 2 })));
        t.eq(ids(c).length, 1, "a mesma revisão não pede de novo");
        c.receive(ok(page.id, JSON.parse(JSON.stringify({ items: texts([6, 5, 4, 3]), total: 9 }))));
        t.eq([shown(), C.total], [[6, 5, 4, 3], 9]);
        c.received("clipboard.history", JSON.parse(JSON.stringify({ revision: 5, count: 10, pinned: 2 })));
        t.eq([ids(c).length, C.count], [1, 10], "revisão nova pede de novo");
    });

    withClient("clipboard: a repaginação vem em páginas de até 200", c => {
        const many = n => Array.from({ length: n }, (_, i) => 1000 - i);
        C.items = texts(many(250));
        C.total = 400;
        c.pending = {};
        c.received("clipboard.history", JSON.parse(JSON.stringify({ revision: 7, count: 400, pinned: 0 })));
        const first = last(c, "clipboard.list");
        t.eq(first.params, { offset: 0, limit: 200 }, "nunca mais de 200");
        // Uma cópia nova entrou: tudo desce um, e o 801 vem de novo na segunda.
        c.receive(ok(first.id, { items: texts([1001].concat(many(199))), total: 401 }));
        t.eq([shown().length, shown()[0], C.loading], [250, 1000, true], "a lista velha fica até a última página");
        C.more();
        const second = last(c, "clipboard.list");
        t.eq(second.params, { offset: 200, limit: 50 }, "a segunda continua de onde parou; more() não entra");
        c.receive(ok(second.id, { items: texts(many(250).slice(198, 248)), total: 401 }));
        const list = shown();
        t.eq([list.length, list[0], list[199], list[200], list[list.length - 1], C.total, C.loading], [249, 1001, 802, 801, 753, 401, false], "soma sem repetir nem pular");
        t.eq(new Set(list).size, list.length, "sem repetidos");
    });

    withClient("clipboard: estado do módulo e queda", c => {
        c.received("clipboard.status", JSON.parse(JSON.stringify({ available: true, error: null })));
        t.eq([C.moduleAvailable, C.error, C.available], [true, "", true]);
        c.received("clipboard.status", JSON.parse(JSON.stringify({ available: false, error: "O compositor não respondeu em 2 s." })));
        t.eq([C.moduleAvailable, C.error, C.available], [false, "O compositor não respondeu em 2 s.", false]);
        C.applyStatus({ available: true, error: null });
        C.items = texts([1]);
        C.total = 1;
        C.revision = 3;
        // A queda pelo caminho real: o cliente perde a conexão.
        c.lost();
        t.eq([C.moduleAvailable, shown(), C.total, C.revision, C.loading], [false, [], 0, -1, false]);
        t.eq(c.owners.clipboard, C.wantedTopics(C.watching), "a assinatura fica guardada para a volta");
        C.connectionChanged(false);
        t.eq(shown(), [], "cair de novo não muda nada");
    });

    withClient("clipboard: disponível é conectado e sem error", c => {
        // Sem assinante: available falso e error nulo no daemon; o shell usa.
        c.received("clipboard.status", JSON.parse(JSON.stringify({ available: false, error: null })));
        t.eq([C.moduleAvailable, C.available], [false, true]);
        c.received("clipboard.status", JSON.parse(JSON.stringify({ available: false, error: "Sem WAYLAND_DISPLAY: o lucernad não sabe qual sessão observar." })));
        t.check(!C.available, "com error, indisponível");
        c.received("clipboard.status", JSON.parse(JSON.stringify({ available: true, error: null })));
        c.lost();
        t.check(!C.available, "sem conexão, indisponível");
    });

    withClient("clipboard: o resultado do copyImage sai pela resposta", c => {
        const got = [];
        const record = (path, error) => got.push([path, error]);
        C.imageCopied.connect(record);
        try {
            c.pending = {};
            C.copyImage("/tmp/a.png");
            C.copyImage("/tmp/b.png");
            t.eq(got, [], "nada antes da resposta");
            const [a, b] = ids(c);
            c.receive(ok(a, { id: 0 }));
            c.receive(JSON.stringify({ jsonrpc: "2.0", id: b, error: { code: 1002, message: "Não consegui ler a imagem: /tmp/b.png não é uma imagem." } }));
            t.eq(got, [["/tmp/a.png", ""], ["/tmp/b.png", "Não consegui ler a imagem: /tmp/b.png não é uma imagem."]]);
            c.receive(ok(a, { id: 0 }));
            t.eq(got.length, 2, "uma resposta repetida não avisa de novo");
            C.copyImage("/tmp/c.png");
            c.lost();
            t.eq(got[2], ["/tmp/c.png", "Sem conexão com o teste."], "a queda falha o pedido em voo");
            C.copyImage("/tmp/d.png");
            t.eq(got[3], ["/tmp/d.png", "Sem conexão com o teste."], "sem conexão, falha na hora");
            t.eq([C.copyResult(null), C.copyResult({ result: { id: 3 } }), C.copyResult({ error: {} })], ["o lucernad não respondeu.", "", "erro desconhecido."]);
        } finally {
            C.imageCopied.disconnect(record);
        }
    });

    withClient("clipboard: os métodos saem com os parâmetros", c => {
        c.pending = {};
        C.copy(7);
        C.remove(7);
        C.pin(7, true);
        C.clear(false);
        C.copyImage("/tmp/a.png");
        C.watching = true;
        C.copyImage("/tmp/b.png");
        const sent = ids(c).filter(id => c.pending[id].method.startsWith("clipboard.")).map(id => [c.pending[id].method, c.pending[id].params]);
        t.eq(sent, [
            ["clipboard.copy", { id: 7 }],
            ["clipboard.remove", { id: 7 }],
            ["clipboard.pin", { id: 7, pinned: true }],
            ["clipboard.clear", { all: false }],
            ["clipboard.copyImage", { path: "/tmp/a.png", store: false }],
            ["clipboard.copyImage", { path: "/tmp/b.png", store: true }]
        ], "com o histórico desligado, a imagem não é guardada");
        // Respondidos, os copyImage não deixam o prazo correndo depois do caso.
        for (const id of ids(c).filter(id => c.pending[id].method === "clipboard.copyImage"))
            c.receive(ok(id, { id: 0 }));
    });

    withClient("clipboard: null e tópico desconhecido não mudam nada", c => {
        C.watching = true;
        c.pending = {};
        C.apply("clipboard.history", null);
        C.apply("clipboard.status", null);
        C.apply("clipboard.xyz", { available: true, revision: 9 });
        t.eq([C.revision, C.count, C.moduleAvailable, ids(c).length], [original.revision, original.count, false, 0]);
    });
}
