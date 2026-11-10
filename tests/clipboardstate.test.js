// Testes de features/clipboard/state/ClipboardState: o painel sobre as páginas
// do daemon (o filtro Arquivos, o trecho marcado, o detalhe por tipo, o pedir
// mais no fim da lista e o texto de indisponível). Os dados chegam pelo caminho
// real: a resposta pelo receive() do cliente e a leitura pelo modelData.
function run(t) {
    const S = t.ClipboardState;
    const C = t.Clipboard;

    // O que os casos mexem, restaurado no fim de cada um.
    const fields = ["client", "items", "total", "error", "moduleAvailable", "count", "pinned", "kind", "query", "loading", "paging", "token"];
    const original = {};
    for (const f of fields)
        original[f] = C[f];
    const query0 = S.query;
    const filter0 = S.filter;
    const selected0 = S.selected;

    function restore() {
        for (const f of fields)
            if (f !== "client")
                C[f] = original[f];
        C.client = original.client;
        S.query = query0;
        S.filter = filter0;
        S.selected = selected0;
    }

    function ok(id, result) {
        return JSON.stringify({ jsonrpc: "2.0", id: id, result: result });
    }

    function ids(c) {
        return Object.keys(c.pending).map(Number);
    }

    function lastList(c) {
        const list = ids(c).filter(id => c.pending[id].method === "clipboard.list");
        return list.length ? Object.assign({ id: list[list.length - 1] }, c.pending[list[list.length - 1]]) : null;
    }

    // Um cliente da fábrica em C.client, com o hello respondido.
    function wired() {
        const c = t.lucernaClient();
        C.client = c;
        c.opened();
        c.receive(ok(ids(c)[0], { protocol: "1.0", app: "lucernad", version: "0.1.0", topics: ["clipboard.history", "clipboard.status"], streams: [], methods: [] }));
        return c;
    }

    function scenario(name, body, connect) {
        t.test(name, () => {
            const c = connect === false ? t.lucernaClient() : wired();
            if (connect === false)
                C.client = c;
            try {
                body(c);
            } finally {
                restore();
                c.destroy();
            }
        });
    }

    function texts(n) {
        return Array.from({ length: n }, (_, i) => ({ id: i + 1, kind: "text", preview: `item ${i}`, size: 6, lines: 1, created: 0, used: 0, pinned: false }));
    }

    t.test("clipboardstate: o filtro Arquivos", () => {
        t.eq(S.filters.map(f => f.value), ["all", "text", "image", "files"]);
        t.eq(S.filters[3].label, "Arquivos");
    });

    t.test("clipboardstate: o trecho marcado", () => {
        t.eq(S.marked("Uma Ação", [[4, 8]]), "Uma <b>Ação</b>");
        t.eq(S.marked("a<b>&", []), "a&lt;b&gt;&amp;");
        t.eq(S.marked("ab", [[1, 9]]), "a<b>b</b>");
        t.eq(S.marked("ab", [[5, 9], [1, 1]]), "ab", "fora do texto ou vazio, ignorado");
        t.eq(S.marked("a<b>c", [[1, 4]]), "a<b>&lt;b&gt;</b>c", "o escape vale dentro do marcado");
        t.eq(S.marked("abcd", [[2, 3], [0, 1]]), "<b>a</b>b<b>c</b>d", "fora de ordem");
        t.eq(S.marked("abcd", undefined), "abcd", "sem matches");
        t.eq(S.marked("abcd", [[-2, 1]]), "<b>a</b>bcd", "início negativo vira 0, sem repetir texto");
    });

    scenario("clipboardstate: o trecho marcado pelo modelData", c => {
        C.load("all", "ação");
        c.receive(ok(lastList(c).id, {
            items: [
                { id: 1, kind: "text", preview: "😀 Ação", matches: [[3, 7]], size: 6, lines: 1, created: 0, used: 0, pinned: false },
                { id: 2, kind: "files", preview: "a, b", uris: ["file:///a", "file:///b"], size: 20, created: 0, used: 0, pinned: false }
            ],
            total: 2
        }));
        const view = Qt.createQmlObject("import QtQuick\nInstantiator { delegate: QtObject { required property var modelData } }", t.object());
        try {
            view.model = S.items;
            t.eq(view.count, 2);
            const first = view.objectAt(0).modelData;
            t.eq(Array.from(first.matches).map(p => Array.from(p)), [[3, 7]]);
            t.eq(S.marked(S.preview(first), first.matches), "😀 <b>Ação</b>");
            t.check(S.detail(view.objectAt(1).modelData).endsWith("2 arquivos"), "o detalhe dos arquivos");
        } finally {
            view.destroy();
        }
    });

    t.test("clipboardstate: detalhe por tipo", () => {
        const base = { used: 0 };
        t.check(S.detail(Object.assign({ kind: "text", size: 12, lines: 2 }, base)).endsWith("12 caracteres · 2 linhas"));
        t.check(S.detail(Object.assign({ kind: "text", size: 12, lines: 1 }, base)).endsWith("12 caracteres"));
        t.check(S.detail(Object.assign({ kind: "image", width: 10, height: 5 }, base)).endsWith("10×5"));
        t.check(!S.detail(Object.assign({ kind: "image" }, base)).includes("×"), "sem dimensões, sem o 10×5");
        t.check(S.detail(Object.assign({ kind: "files", uris: ["a", "b"] }, base)).endsWith("2 arquivos"));
        t.check(S.detail(Object.assign({ kind: "files", uris: ["a"] }, base)).endsWith("1 arquivo"));
        t.check(S.detail(Object.assign({ kind: "files", uris: ["a"], urisTotal: 80 }, base)).endsWith("80 arquivos"), "o total do daemon");
        t.eq([S.preview({ kind: "image", preview: "x" }), S.preview({ kind: "files", preview: "a, b" }), S.preview({ kind: "text", preview: "oi" })], ["Imagem", "a, b", "oi"]);
    });

    scenario("clipboardstate: no fim da lista, pede mais", c => {
        C.items = texts(3);
        C.total = 10;
        S.selected = 2;
        c.pending = {};
        S.move(1);
        t.eq(S.selected, 2, "fica no último");
        t.eq(lastList(c).params, { offset: 3, limit: C.pageSize });
        const pending = ids(c).length;
        S.move(1);
        t.eq(ids(c).length, pending, "sem repetir o pedido em voo");
        S.selected = 0;
        S.move(-1);
        t.eq(S.selected, 0, "no começo de uma lista incompleta, não dá a volta");
        S.selected = 2;
        C.total = 3;
        S.move(1);
        t.eq(S.selected, 0, "com tudo carregado, dá a volta");
        S.move(-1);
        t.eq(S.selected, 2, "e volta ao fim");
        S.move(-1);
        t.eq(S.selected, 1);
    });

    // O painel chama reachedEnd() quando o atYEnd muda e quando a altura do
    // conteúdo muda: a página somada que ainda cabe inteira não muda o atYEnd.
    scenario("clipboardstate: a lista no fim pede mais, também quando ainda cabe", c => {
        C.items = texts(3);
        C.total = 10;
        c.pending = {};
        S.reachedEnd(false);
        t.eq(lastList(c), null, "longe do fim, nada");
        S.reachedEnd(true);
        t.eq(lastList(c).params, { offset: 3, limit: C.pageSize }, "no fim, a página seguinte");
        c.receive(ok(lastList(c).id, { items: texts(5).slice(3), total: 10 }));
        t.eq(C.items.length, 5);
        S.reachedEnd(true);
        t.eq(lastList(c).params, { offset: 5, limit: C.pageSize }, "a página somada coube: pede a outra sem o atYEnd mudar");
    });

    scenario("clipboardstate: a lista vazia não move", () => {
        C.items = [];
        S.selected = 0;
        S.move(1);
        t.eq([S.selected, S.current], [0, null]);
    });

    scenario("clipboardstate: indisponível diz por quê", () => {
        C.error = "Sem WAYLAND_DISPLAY: …";
        t.check(!C.client.connected);
        t.eq(S.unavailableText, "Indisponível: sem conexão com o lucernad.");
    }, false);

    scenario("clipboardstate: indisponível com o daemon de pé", () => {
        C.moduleAvailable = false;
        C.error = "o compositor não tem o protocolo";
        t.eq(S.unavailableText, "Indisponível: o compositor não tem o protocolo");
        C.error = "";
        t.eq(S.unavailableText, "Indisponível.");
    });

    scenario("clipboardstate: busca e filtro pedem a página depois de um instante", c => {
        c.pending = {};
        S.query = "pdf";
        S.filter = "files";
        t.eq(ids(c).length, 0, "ainda não");
        t.check(S.reload.running, "o timer de 150 ms");
        S.reload.triggered();
        t.eq(lastList(c).params, { kind: "files", query: "pdf", offset: 0, limit: C.pageSize });
    });

    scenario("clipboardstate: abrir o painel pede a página de tudo", c => {
        c.pending = {};
        S.query = "x";
        S.opened();
        t.eq([S.query, S.filter, S.selected], ["", "all", 0]);
        t.check(!S.reload.running, "a abertura não deixa o timer da busca");
        t.eq(lastList(c).params, { offset: 0, limit: C.pageSize });
    });

    scenario("clipboardstate: com o histórico desligado, abrir não pede página", c => {
        const before = t.Config.clipboardEnabled;
        try {
            t.Config.clipboardEnabled = false;
            c.pending = {};
            S.opened();
            t.eq(lastList(c), null);
        } finally {
            t.Config.clipboardEnabled = before;
        }
    });

    scenario("clipboardstate: desligado vem antes de indisponível", c => {
        t.eq([S.emptyState(false, false), S.emptyState(false, true), S.emptyState(true, false), S.emptyState(true, true)], ["off", "off", "unavailable", "empty"]);
        // O daemon com o histórico desligado (sem assinante): available falso,
        // error nulo. O shell trata como disponível.
        c.received("clipboard.status", JSON.parse(JSON.stringify({ available: false, error: null })));
        t.eq([C.available, S.available, S.emptyState(false, S.available)], [true, true, "off"]);
        c.received("clipboard.status", JSON.parse(JSON.stringify({ available: false, error: "O compositor não respondeu em 2 s." })));
        t.eq([S.available, S.emptyState(true, S.available), S.emptyState(false, S.available)], [false, "unavailable", "off"]);
    });

    scenario("clipboardstate: os contadores e as ações vão ao Clipboard", c => {
        C.count = 7;
        C.pinned = 3;
        t.eq([S.count, S.pinned, S.clearable], [7, 3, true]);
        C.pinned = 7;
        t.check(!S.clearable, "só fixados: nada a limpar");
        c.pending = {};
        S.remove({ id: 4 });
        S.togglePin({ id: 5, pinned: false });
        S.clear();
        const calls = ids(c).map(id => [c.pending[id].method, c.pending[id].params]);
        t.eq(calls, [["clipboard.remove", { id: 4 }], ["clipboard.pin", { id: 5, pinned: true }], ["clipboard.clear", { all: false }]]);
    });
}
