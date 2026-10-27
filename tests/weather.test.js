// Testes de services/Weather: o adaptador do tópico web.weather do lucernad
// (a previsão que chega, a busca de cidade, a escolha) e a chave do Vagalume
// nas configurações. A rede em si ficou no daemon. Cada caso que conecta usa um
// cliente da fábrica t.lucernaClient() posto no Web e no Weather; os dados
// chegam pelo caminho real (a resposta pelo receive() e o sinal received).
function run(t) {
    const W = t.Weather;
    const B = t.Web;
    const C = t.Config;

    const fields = ["active", "current", "daily", "sunrise", "sunset", "updatedAt", "state", "error", "location", "results", "searching", "searchError", "lastQuery", "searchSeq"];
    const original = {
        client: W.client,
        webClient: B.client,
        webError: B.error,
        webOnline: B.moduleOnline,
        webRefresh: B.refreshMinutes,
        offline: C.offline,
        weatherLocation: C.weatherLocation,
        vagalumeKey: C.vagalumeKey
    };
    for (const f of fields)
        original[f] = W[f];

    function restore() {
        W.active = original.active;
        W.clear();
        for (const f of fields)
            if (f !== "active")
                W[f] = original[f];
        C.offline = original.offline;
        C.weatherLocation = original.weatherLocation;
        C.vagalumeKey = original.vagalumeKey;
        B.error = original.webError;
        B.moduleOnline = original.webOnline;
        B.refreshMinutes = original.webRefresh;
        W.client = original.client;
        B.client = original.webClient;
    }

    function restored() {
        return W.client === original.client && B.client === original.webClient && B.error === original.webError && B.moduleOnline === original.webOnline && B.refreshMinutes === original.webRefresh && C.offline === original.offline && JSON.stringify(C.weatherLocation) === JSON.stringify(original.weatherLocation) && C.vagalumeKey === original.vagalumeKey && fields.every(f => JSON.stringify(W[f]) === JSON.stringify(original[f]));
    }

    function ok(id, result) {
        return JSON.stringify({ jsonrpc: "2.0", id: id, result: result });
    }

    function fail(id, code, message) {
        return JSON.stringify({ jsonrpc: "2.0", id: id, error: { code: code, message: message } });
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

    function hello(topics) {
        return { protocol: "1.0", app: "lucernad", version: "0.1.0", topics: topics, streams: [], methods: [] };
    }

    function wired() {
        const c = t.lucernaClient();
        B.client = c;
        W.client = c;
        c.opened();
        c.receive(ok(ids(c)[0], hello(["web.lyrics", "web.weather", "web.status"])));
        return c;
    }

    function withClient(name, body) {
        t.test(name, () => {
            const c = wired();
            try {
                body(c);
            } finally {
                restore();
                c.destroy();
                t.check(restored(), "estado original restaurado");
            }
        });
    }

    function json(data) {
        return JSON.parse(JSON.stringify(data));
    }

    const cities = {
        results: [
            { name: "Cacaulândia", state: "Rondônia", country: "Brasil", countryCode: "BR", latitude: -10.3375, longitude: -62.8986 },
            { name: "Cacau", state: "", country: "Brasil", countryCode: "BR", latitude: -1.5, longitude: -50.5 },
            { name: "Cacaú", state: "Bahia", country: "", countryCode: "", latitude: -12, longitude: -40 }
        ]
    };

    withClient("weather: tópicos conforme quem mostra", c => {
        t.eq(W.wantedTopics(false), []);
        t.eq(W.wantedTopics(true), ["web.weather"]);
        W.active = false;
        c.pending = {};
        W.active = true;
        const subscribe = idsOf(c, "lucerna.subscribe").filter(id => Array.from(c.pending[id].params.topics).includes("web.weather"));
        t.check(subscribe.length > 0, "ligar active assina o web.weather");
        c.pending = {};
        W.refresh();
        t.eq(methods(c), ["web.refresh"]);
    });

    withClient("weather: a previsão pelo sinal real", c => {
        c.received("web.weather", json(t.weatherSample()));
        t.eq(W.current, { temp: 31.2, feels: 35, humidity: 58, wind: 7.6, code: 2, isDay: true });
        t.eq(W.daily.length, 7);
        t.eq(W.daily[0], { date: "2026-10-24", max: 33.4, min: 22.1, code: 95, rainChance: 80 });
        t.eq([W.sunrise, W.sunset], ["05:41", "18:03"]);
        t.eq(W.updatedAt.getTime(), 1792847400000);
        t.eq([W.state, W.error, W.loading], ["ready", "", false]);
        t.eq([W.location.name, W.location.latitude, W.location.longitude], ["Cacaulândia, Rondônia, BR", -10.3375, -62.8986]);
    });

    withClient("weather: sem cidade, carregando e erro com dados", c => {
        c.received("web.weather", json(t.weatherSample()));
        c.received("web.weather", json({ location: null, state: "none", updatedAt: null, current: null, daily: [], sunrise: null, sunset: null }));
        t.eq([W.current, W.daily, W.state, W.updatedAt, W.sunrise, W.location], [null, [], "none", null, "", null]);
        const sample = t.weatherSample();
        c.received("web.weather", json(Object.assign({}, sample, { state: "loading" })));
        t.eq(W.loading, true);
        c.received("web.weather", json(Object.assign({}, sample, { state: "error", error: "x" })));
        t.eq([W.state, W.error, W.current.temp], ["error", "x", 31.2]);
        W.clear();
        t.eq([W.current, W.daily, W.state, W.error, W.sunrise, W.sunset, W.updatedAt, W.location], [null, [], "", "", "", "", null, null]);
    });

    withClient("weather: a busca de cidade pela resposta real", c => {
        W.search("   ");
        t.eq(idsOf(c, "web.searchCity").length, 0, "vazio não sai");
        W.search("Cacau");
        const first = idsOf(c, "web.searchCity");
        t.eq(first.length, 1);
        t.eq(c.pending[first[0]].params, { query: "Cacau" });
        t.eq([W.searching, W.lastQuery], [true, "Cacau"]);
        c.receive(ok(first[0], json(cities)));
        t.eq(W.searching, false);
        t.eq(W.results.length, 3);
        t.eq(W.results[0], { name: "Cacaulândia, Rondônia, BR", label: "Cacaulândia · Rondônia · Brasil", latitude: -10.3375, longitude: -62.8986 });
        t.eq(W.results[1].name, "Cacau, BR");
        t.eq(W.results[2], { name: "Cacaú, Bahia", label: "Cacaú · Bahia", latitude: -12, longitude: -40 });
        t.eq(W.searchError, "");

        // Duas buscas seguidas: a resposta da primeira, chegando depois, é ignorada.
        W.search("Recife");
        const second = idsOf(c, "web.searchCity").filter(id => id !== first[0])[0];
        W.search("Lisboa");
        const third = idsOf(c, "web.searchCity").filter(id => id !== first[0] && id !== second)[0];
        c.receive(ok(third, json({ results: [{ name: "Lisboa", countryCode: "PT", country: "Portugal", latitude: 38.7, longitude: -9.1 }] })));
        c.receive(ok(second, json({ results: [{ name: "Recife", countryCode: "BR", country: "Brasil", latitude: -8, longitude: -34.9 }] })));
        t.eq(W.results.map(r => r.name), ["Lisboa, PT"]);

        // A mesma busca repetida: só a resposta da última vale.
        W.search("Cacau");
        const again1 = idsOf(c, "web.searchCity").filter(id => ![first[0], second, third].includes(id))[0];
        W.search("Cacau");
        const again2 = idsOf(c, "web.searchCity").filter(id => ![first[0], second, third, again1].includes(id))[0];
        c.receive(ok(again1, json(cities)));
        t.eq([W.results.map(r => r.name), W.searching], [["Lisboa, PT"], true], "a resposta velha da mesma busca é ignorada");
        c.receive(ok(again2, json({ results: [] })));
        t.eq(W.searchError, 'Não encontrei "Cacau"');

        W.search("Cacau");
        const empty = idsOf(c, "web.searchCity").filter(id => ![first[0], second, third, again1, again2].includes(id))[0];
        c.receive(ok(empty, json({ results: [] })));
        t.eq([W.results, W.searchError], [[], 'Não encontrei "Cacau"']);

        W.search("Cacau");
        const bad = idsOf(c, "web.searchCity").filter(id => ![first[0], second, third, again1, again2, empty].includes(id))[0];
        c.receive(fail(bad, 1001, "Modo offline ligado: a busca de cidade usa a internet."));
        t.eq([W.results, W.searchError, W.searching], [[], "Modo offline ligado: a busca de cidade usa a internet.", false]);
    });

    withClient("weather: escolher salva a cidade", c => {
        W.search("Cacau");
        c.receive(ok(idsOf(c, "web.searchCity")[0], json(cities)));
        const seen = [];
        const listener = place => seen.push(place);
        W.located.connect(listener);
        t.eq(W.choose(5), "");
        t.eq(W.choose(-1), "");
        t.eq(seen.length, 0);
        t.eq(W.choose(0), "Cacaulândia, Rondônia, BR");
        t.eq(seen.map(p => [p.name, p.latitude, p.longitude]), [["Cacaulândia, Rondônia, BR", -10.3375, -62.8986]]);
        t.eq(W.results, []);
        W.located.disconnect(listener);
    });

    t.test("weather: previsão velha", () => {
        const before = W.updatedAt;
        const minutes = B.refreshMinutes;
        try {
            W.updatedAt = null;
            t.check(W.isStale(), "sem previsão");
            W.updatedAt = new Date();
            t.check(!W.isStale(), "de agora");
            B.refreshMinutes = 30;
            W.updatedAt = new Date(Date.now() - 2 * 3600 * 1000);
            t.check(W.isStale(), "de 2 h atrás");
        } finally {
            W.updatedAt = before;
            B.refreshMinutes = minutes;
        }
    });

    t.test("weather: relógio do nascer e do pôr", () => {
        t.eq(W.clock("2026-10-24T05:41"), "05:41");
        t.eq(W.clock(""), "");
        t.eq(W.clock("x"), "");
    });

    t.test("weather: a chave nas configurações", () => {
        const S = t.SettingsState;
        const key = C.vagalumeKey;
        try {
            t.eq(S.setVagalumeKey(" abc-1_2 "), "");
            t.eq(C.vagalumeKey, "abc-1_2");
            t.eq(S.vagalumeKey, "abc-1_2");
            const message = "A chave só tem letras, números, - e _ (até 128).";
            t.eq(S.setVagalumeKey("tem espaço"), message);
            t.eq(C.vagalumeKey, "abc-1_2");
            t.eq(S.setVagalumeKey("a".repeat(129)), message);
            t.eq(C.vagalumeKey, "abc-1_2");
            t.eq(S.setVagalumeKey(""), "");
            t.eq(C.vagalumeKey, "");
        } finally {
            C.vagalumeKey = key;
        }
    });

    withClient("weather: as configurações e o resumo", c => {
        const S = t.SettingsState;
        const O = t.OverviewState;
        B.error = "";
        t.eq(S.webNote, "");
        B.error = "quebrou";
        t.eq(S.webNote, "Indisponível: quebrou");
        B.error = "";
        c.lost();
        t.eq(S.webNote, "Indisponível: sem conexão com o lucernad.");
        const c2 = wired();
        try {
            c2.received("web.weather", json(t.weatherSample()));
            S.refreshWeather();
            t.eq(methods(c2).filter(m => m === "web.refresh").length, 1);
            t.eq([S.cityResults, S.citySearching, S.citySearchError], [[], false, ""]);
            S.searchCity("Cacau");
            t.eq(S.citySearching, true);
            c2.receive(ok(idsOf(c2, "web.searchCity")[0], json(cities)));
            t.eq(S.cityResults.length, 3);
            const place = Config.weatherLocation;
            try {
                S.chooseCity(1);
                t.eq(W.results, []);
            } finally {
                Config.weatherLocation = place;
            }
            // O resumo da aba Painel.
            c2.received("web.status", json({ available: true, error: null, online: true }));
            const offline = C.offline;
            try {
                C.offline = true;
                t.eq(O.weatherText, "Modo offline");
                C.offline = false;
                t.eq(O.weatherText, "Parcialmente nublado");
                t.eq(O.weatherTemp, t.WeatherState.temperature(31.2));
                W.clear();
                const was = C.weatherLocation;
                try {
                    C.weatherLocation = null;
                    t.eq(O.weatherText, "Escolha a cidade nas configurações");
                    C.weatherLocation = { name: "A", latitude: 0, longitude: 0 };
                    t.eq(O.weatherText, "Carregando…");
                } finally {
                    C.weatherLocation = was;
                }
                B.error = "x";
                t.eq(O.weatherText, "Indisponível");
            } finally {
                C.offline = offline;
                B.error = "";
            }
        } finally {
            W.client = c;
            B.client = c;
            c2.destroy();
        }
    });

    withClient("weather: null e tópico desconhecido não mudam nada", c => {
        W.apply("web.weather", null);
        W.apply("web.outro", { state: "ready" });
        t.eq([W.state, W.current, W.daily], ["", null, []]);
    });

    t.test("weather: estado original restaurado", () => {
        t.check(restored());
    });
}
