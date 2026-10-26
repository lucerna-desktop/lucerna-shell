// Testes de services/Web: o adaptador do módulo web do lucernad (o tópico
// web.status, o web.configure a cada conexão e a cada mudança, o web.refresh e
// o web.searchCity). A rede em si ficou no daemon, com os testes em Rust. Cada
// caso que conecta usa um cliente da fábrica t.lucernaClient() posto em
// W.client (o socket nunca abre: os pedidos ficam no pending), e os dados
// chegam pelo caminho real (a resposta pelo receive() e o sinal received).
function run(t) {
    const W = t.Web;

    // O estado de antes, restaurado e conferido no fim de cada caso (a suíte
    // roda no mesmo processo que as seguintes).
    const fields = ["client", "error", "moduleOnline", "offline", "vagalumeKey", "location", "refreshMinutes"];
    const original = {};
    for (const f of fields)
        original[f] = W[f];

    function restore() {
        // O client por último: as outras trocas ainda caem no cliente do caso.
        for (const f of fields)
            if (f !== "client")
                W[f] = original[f];
        W.client = original.client;
    }

    function restored() {
        return fields.every(f => f === "client" ? W.client === original.client : JSON.stringify(W[f]) === JSON.stringify(original[f]));
    }

    function ok(id, result) {
        return JSON.stringify({ jsonrpc: "2.0", id: id, result: result });
    }

    function ids(c) {
        return Object.keys(c.pending).map(Number);
    }

    function methods(c) {
        return ids(c).map(id => c.pending[id].method);
    }

    function idsOf(c, method) {
        return ids(c).filter(id => c.pending[id].method === method);
    }

    function last(c, method) {
        const list = idsOf(c, method);
        return list.length ? Object.assign({ id: list[list.length - 1] }, c.pending[list[list.length - 1]]) : null;
    }

    function hello(topics) {
        return { protocol: "1.0", app: "lucernad", version: "0.1.0", topics: topics, streams: [], methods: [] };
    }

    // Um cliente novo em W.client, com o socket "aberto" e o hello respondido.
    function wired() {
        const c = t.lucernaClient();
        W.client = c;
        c.opened();
        c.receive(ok(ids(c)[0], hello(["web.lyrics", "web.weather", "web.status"])));
        return c;
    }

    // Um caso com o cliente do wired() (ou um cru, sem `connect`), restaurado
    // e destruído no fim, mesmo com exceção.
    function withClient(name, body, connect) {
        t.test(name, () => {
            const c = connect === false ? t.lucernaClient() : wired();
            if (connect === false)
                W.client = c;
            try {
                body(c);
            } finally {
                restore();
                c.destroy();
                t.check(restored(), "estado original restaurado");
            }
        });
    }

    t.test("web: tópicos e configuração na conexão", () => {
        t.eq(W.wantedTopics(), ["web.status"]);
        const c = t.lucernaClient();
        W.client = c;
        try {
            W.offline = true;
            W.vagalumeKey = "";
            W.location = null;
            W.refreshMinutes = 30;
            c.opened();
            c.receive(ok(ids(c)[0], hello(["web.lyrics", "web.weather", "web.status"])));
            const subscribe = idsOf(c, "lucerna.subscribe").filter(id => Array.from(c.pending[id].params.topics).includes("web.status"));
            t.check(subscribe.length > 0, "assina o status");
            const configure = last(c, "web.configure");
            t.check(configure !== null, "a conexão configura");
            t.eq(configure.params, { offline: true, vagalumeKey: null, location: null, refresh: 30 });
        } finally {
            restore();
            c.destroy();
        }
        t.check(restored(), "estado original restaurado");
    });

    withClient("web: a configuração muda e vai de novo", c => {
        c.pending = {};
        W.location = { name: "Cacaulândia, RO, BR", latitude: -10.3, longitude: -62.9 };
        W.vagalumeKey = "abc";
        W.offline = false;
        t.eq(last(c, "web.configure").params.location, { name: "Cacaulândia, RO, BR", latitude: -10.3, longitude: -62.9 });
        t.eq(last(c, "web.configure").params.vagalumeKey, "abc");
        t.eq(last(c, "web.configure").params.offline, false);
        W.vagalumeKey = "";
        t.eq(last(c, "web.configure").params.vagalumeKey, null);
        W.refreshMinutes = 2;
        t.eq(last(c, "web.configure").params.refresh, null);
        W.refreshMinutes = 2000;
        t.eq(last(c, "web.configure").params.refresh, null);
        W.refreshMinutes = 60;
        t.eq(last(c, "web.configure").params.refresh, 60);
        c.pending = {};
        W.refresh();
        t.eq(methods(c), ["web.refresh"]);
    });

    withClient("web: estado pelo sinal real", c => {
        c.received("web.status", JSON.parse(JSON.stringify({ available: true, error: null, online: true })));
        t.eq([W.available, W.online, W.error], [true, true, ""]);
        c.received("web.status", JSON.parse(JSON.stringify({ available: false, error: "x", online: false })));
        t.eq([W.available, W.online, W.error], [false, false, "x"]);
        c.received("web.status", JSON.parse(JSON.stringify({ available: true, error: null, online: true })));
        W.connectionChanged(false);
        t.eq([W.online, W.error], [false, ""]);
    });

    withClient("web: busca de cidade pela resposta real", c => {
        let got = null;
        W.searchCity("Cacau", r => got = r);
        const call = last(c, "web.searchCity");
        t.eq(call.params, { query: "Cacau" });
        c.receive(ok(call.id, JSON.parse(JSON.stringify({ results: [{ name: "Cacaulândia" }, { name: "Cacau" }] }))));
        t.eq(Array.from(got.result.results).length, 2);
        c.lost();
        let failed = null;
        W.searchCity("x", r => failed = r);
        t.check(failed !== null && !!failed.error, "desconectado, o done recebe o erro na hora");
    });

    withClient("web: null e tópico desconhecido não mudam nada", c => {
        W.apply("web.status", null);
        W.apply("web.outro", { available: false, error: "y" });
        t.eq([W.error, W.moduleOnline], ["", false]);
    });

    t.test("web: estado original restaurado", () => {
        t.check(restored());
    });
}
