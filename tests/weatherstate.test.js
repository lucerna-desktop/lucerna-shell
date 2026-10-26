// Testes do WeatherState: o view model da aba Clima (as datas locais, os
// rótulos dos dias pela data, os cards e o aviso do rodapé). Os dados chegam
// ao Weather pelo caminho real (o sinal received de um cliente da fábrica
// t.lucernaClient(), posto no Web e no Weather); tudo volta ao fim.
function run(t) {
    const S = t.WeatherState;
    const W = t.Weather;
    const B = t.Web;
    const C = t.Config;

    const original = {
        client: W.client,
        webClient: B.client,
        webError: B.error,
        webOnline: B.moduleOnline,
        webRefresh: B.refreshMinutes,
        offline: C.offline,
        todayKey: S.todayKey,
        weather: JSON.stringify([W.current, W.daily, W.sunrise, W.sunset, W.updatedAt, W.state, W.error, W.location])
    };

    function snapshot() {
        return JSON.stringify([W.current, W.daily, W.sunrise, W.sunset, W.updatedAt, W.state, W.error, W.location]);
    }

    function restore() {
        W.clear();
        C.offline = original.offline;
        B.error = original.webError;
        B.moduleOnline = original.webOnline;
        B.refreshMinutes = original.webRefresh;
        S.todayKey = original.todayKey;
        W.client = original.client;
        B.client = original.webClient;
    }

    function restored() {
        return W.client === original.client && B.client === original.webClient && B.error === original.webError && B.moduleOnline === original.webOnline && B.refreshMinutes === original.webRefresh && C.offline === original.offline && S.todayKey === original.todayKey && snapshot() === original.weather;
    }

    function ok(id, result) {
        return JSON.stringify({ jsonrpc: "2.0", id: id, result: result });
    }

    function hello(topics) {
        return { protocol: "1.0", app: "lucernad", version: "0.1.0", topics: topics, streams: [], methods: [] };
    }

    function json(data) {
        return JSON.parse(JSON.stringify(data));
    }

    function wired() {
        const c = t.lucernaClient();
        B.client = c;
        W.client = c;
        c.opened();
        c.receive(ok(Number(Object.keys(c.pending)[0]), hello(["web.lyrics", "web.weather", "web.status"])));
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

    t.test("clima: as datas são locais", () => {
        const d = S.localDate("2026-10-25");
        t.eq([d.getFullYear(), d.getMonth(), d.getDate(), d.getHours()], [2026, 9, 25, 0]);
        t.eq(S.shortDate("2026-10-25"), "25 out");
        t.eq(S.shortDate("2026-01-01"), "1 jan");
    });

    t.test("clima: os rótulos dos dias pela data", () => {
        t.eq(S.dayLabel("2026-10-24", "2026-10-24"), "Hoje");
        t.eq(S.dayLabel("2026-10-25", "2026-10-24"), "Dom");
        t.eq(S.dayLabel("2026-10-23", "2026-10-24"), "Sex", "a previsão de ontem nunca vira Hoje");
    });

    withClient("clima: os cards", c => {
        S.todayKey = "2026-10-24";
        c.received("web.weather", json(t.weatherSample()));
        t.eq(S.days.length, 7);
        t.eq([S.days[0].label, S.days[0].date, S.days[0].range], ["Hoje", "24 out", "22° / 33°"]);
        t.eq(S.days[0].icon, "thunderstorm");
        t.eq(S.days[1].label, "Dom");
        t.eq(S.days[6].date, "30 out");
        t.eq([S.humidity, S.feels, S.wind], ["58%", "35°", "8 km/h"]);
        t.eq([S.temp, S.condition], ["31°", "Parcialmente nublado"]);
        t.eq([S.sunrise, S.sunset], ["05:41", "18:03"]);
        t.eq(S.today, "Sábado, 24 de outubro");
        W.clear();
        t.eq([S.sunrise, S.sunset, S.temp, S.days], ["--:--", "--:--", "—", []]);
    });

    withClient("clima: o aviso", c => {
        c.received("web.status", json({ available: true, error: null, online: true }));
        C.offline = false;
        t.eq(S.notice, "");
        C.offline = true;
        t.eq(S.notice, "Modo offline: sem atualização");
        C.offline = false;
        c.received("web.status", json({ available: true, error: null, online: false }));
        t.eq(S.notice, "Sem internet: mostrando a última previsão");
        c.received("web.status", json({ available: true, error: null, online: true }));
        c.received("web.weather", json(Object.assign(t.weatherSample(), { state: "error", error: "Sem conexão com a internet." })));
        t.eq(S.notice, "Sem conexão com a internet.");

        B.refreshMinutes = 30;
        const fresh = Math.floor(Date.now() / 1000);
        c.received("web.weather", json(Object.assign(t.weatherSample(), { updatedAt: fresh })));
        t.eq(S.updatedNote, "");
        const old = fresh - 2 * 3600;
        c.received("web.weather", json(Object.assign(t.weatherSample(), { updatedAt: old })));
        t.eq(S.updatedNote, `Atualizado às ${Qt.formatTime(new Date(old * 1000), "HH:mm")}`);
        c.received("web.weather", json(Object.assign(t.weatherSample(), { updatedAt: fresh, state: "error", error: "x" })));
        t.eq(S.updatedNote, `Atualizado às ${Qt.formatTime(new Date(fresh * 1000), "HH:mm")}`);

        // A primeira busca depois de escolher a cidade: nada guardado ainda.
        W.clear();
        c.received("web.weather", json({ location: t.weatherSample().location, state: "loading", updatedAt: null, current: null, daily: [] }));
        t.eq(S.notice, "Buscando a previsão…");
        c.received("web.weather", json(Object.assign(t.weatherSample(), { state: "loading" })));
        t.eq(S.notice, "");

        B.error = "quebrou";
        t.eq(S.notice, "Indisponível: quebrou");
        B.error = "";
        c.lost();
        t.eq(S.notice, "Indisponível: sem conexão com o lucernad.");
        t.eq(S.available, false);
    });

    t.test("clima: estado original restaurado", () => {
        t.check(restored());
    });
}
