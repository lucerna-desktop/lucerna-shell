// Testes de services/Lyrics: o adaptador do tópico web.lyrics do lucernad
// (a faixa que vai pelo web.track, a letra que volta, a linha atual) e o aviso
// da aba Mídia. A busca em si (LRCLIB, Vagalume, cache) ficou no daemon. Cada
// caso que conecta usa um cliente da fábrica t.lucernaClient() posto no Web e
// no Lyrics; os dados chegam pelo caminho real (a resposta pelo receive() e o
// sinal received).
function run(t) {
    const L = t.Lyrics;
    const W = t.Web;
    const C = t.Config;

    const original = {
        client: L.client,
        webClient: W.client,
        active: L.active,
        offline: C.offline,
        webError: W.error
    };

    function restore() {
        L.active = original.active;
        L.clear();
        C.offline = original.offline;
        W.error = original.webError;
        L.client = original.client;
        W.client = original.webClient;
    }

    function restored() {
        return L.client === original.client && W.client === original.webClient && L.active === original.active && C.offline === original.offline && W.error === original.webError && L.lines.length === 0 && L.state === "";
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

    // Um cliente novo no Web e no Lyrics, conectado pelo hello respondido.
    function wired() {
        const c = t.lucernaClient();
        W.client = c;
        L.client = c;
        c.opened();
        c.receive(ok(ids(c)[0], hello(["web.lyrics", "web.weather", "web.status"])));
        return c;
    }

    function withClient(name, body, connect) {
        t.test(name, () => {
            const c = connect === false ? t.lucernaClient() : wired();
            if (connect === false) {
                W.client = c;
                L.client = c;
            }
            try {
                body(c);
            } finally {
                restore();
                c.destroy();
                t.check(restored(), "estado original restaurado");
            }
        });
    }

    function lyrics(data) {
        return JSON.parse(JSON.stringify(data));
    }

    withClient("lyrics: tópicos conforme a aba", c => {
        t.eq(L.wantedTopics(false), []);
        t.eq(L.wantedTopics(true), ["web.lyrics"]);
        L.active = false;
        c.pending = {};
        L.active = true;
        const subscribe = idsOf(c, "lucerna.subscribe").filter(id => Array.from(c.pending[id].params.topics).includes("web.lyrics"));
        t.check(subscribe.length > 0, "ligar active assina o web.lyrics");
    });

    withClient("lyrics: a faixa vai pelo fio", c => {
        t.eq(L.trackParams("T", "A", "Al", 201.4), { title: "T", artist: "A", album: "Al", duration: 201.4 });
        t.eq(L.trackParams("T", "A", "Al", 0).duration, null);
        c.pending = {};
        L.sendTrack();
        t.eq(methods(c), ["web.track"]);
    });

    withClient("lyrics: o configure vai antes da faixa na conexão", c => {
        const list = methods(c);
        const configure = list.indexOf("web.configure");
        const track = list.indexOf("web.track");
        t.check(configure >= 0 && track >= 0, `os dois foram: ${list}`);
        t.check(configure < track, `o configure antes da faixa: ${list}`);
    });

    withClient("lyrics: a letra sincronizada pelo sinal real", c => {
        c.received("web.lyrics", lyrics({ key: "k", state: "found", synced: true, lines: [{ time: 1, text: "a" }, { time: 3, text: "" }], source: "lrclib" }));
        t.eq(L.lines, [{ time: 1, text: "a" }, { time: 3, text: "" }]);
        t.eq([L.synced, L.loading, L.source, L.key], [true, false, "lrclib", "k"]);
        t.eq([L.lineAt(0.5), L.lineAt(1), L.lineAt(60)], [-1, 0, 1]);
        t.eq([0, 1, 2].map(i => L.lineRole(i, 1, true)), ["past", "current", "next"]);
        t.eq(L.lineRole(0, -1, true), "next", "antes da primeira, tudo por vir");
    });

    withClient("lyrics: o Vagalume, sem tempo e com o link", c => {
        c.received("web.lyrics", lyrics({ key: "k", state: "found", synced: false, lines: [{ time: null, text: "a" }], source: "vagalume", url: "https://www.vagalume.com.br/x.html" }));
        t.eq([L.lines[0].time, L.lineAt(10), L.lineRole(0, -1, false)], [-1, -1, "plain"]);
        t.eq([L.url, L.source], ["https://www.vagalume.com.br/x.html", "vagalume"]);
        c.received("web.lyrics", lyrics({ key: "k", state: "found", synced: false, lines: [{ time: null, text: "a" }], source: "vagalume", url: "javascript:x" }));
        t.eq(L.url, "");
    });

    withClient("lyrics: procurando, sem letra e erro", c => {
        c.received("web.lyrics", lyrics({ key: "k", state: "searching", synced: false, lines: [], source: "" }));
        t.eq([L.loading, L.lines], [true, []]);
        c.received("web.lyrics", lyrics({ key: "k", state: "none", synced: false, lines: [], source: "" }));
        t.eq(L.loading, false);
        c.received("web.lyrics", lyrics({ key: "k", state: "error", synced: false, lines: [], source: "", error: "e" }));
        t.eq([L.state, L.error], ["error", "e"]);
        L.connectionChanged(false);
        t.eq([L.state, L.error, L.lines, L.key, L.url, L.synced], ["", "", [], "", "", false]);
    });

    withClient("lyrics: o aviso da aba Mídia", c => {
        const M = t.MediaState;
        C.offline = true;
        t.eq(M.lyricsNote, "Modo offline: a letra não é buscada");
        C.offline = false;
        W.error = "";
        c.received("web.lyrics", lyrics({ key: "k", state: "searching", synced: false, lines: [], source: "" }));
        t.eq(M.lyricsNote, "Procurando a letra…");
        c.received("web.lyrics", lyrics({ key: "k", state: "none", synced: false, lines: [], source: "" }));
        t.eq(M.lyricsNote, "Sem letra");
        c.received("web.lyrics", lyrics({ key: "k", state: "error", synced: false, lines: [], source: "", error: "Sem conexão com a internet." }));
        t.eq(M.lyricsNote, "Sem conexão com a internet.");
        W.error = "quebrou";
        t.eq(M.lyricsNote, "Indisponível: quebrou");
        W.error = "";
        c.received("web.lyrics", lyrics({ key: "k", state: "found", synced: true, lines: [{ time: 1, text: "a" }], source: "lrclib" }));
        t.eq(M.lyricsNote, "");
        c.lost();
        t.eq(M.lyricsNote, "Indisponível: sem conexão com o lucernad.");
    });

    withClient("lyrics: null e tópico desconhecido não mudam nada", c => {
        L.apply("web.lyrics", null);
        L.apply("web.outro", { state: "found" });
        t.eq([L.state, L.lines], ["", []]);
    });

    t.test("lyrics: estado original restaurado", () => {
        t.check(restored());
    });
}
