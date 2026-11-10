// Testes de services/GameMode: o adaptador do módulo game do lucernad (os
// tópicos game.state e game.status, o game.configure a cada conexão e a cada
// mudança, a lista "nunca" de fábrica pelo game.defaults, o game.set e o
// game.toggle). A decisão em si ficou no daemon, com
// os testes em Rust. Cada caso usa um cliente da fábrica t.lucernaClient()
// posto em G.client (o socket nunca abre), e os dados chegam pelo caminho real
// (a resposta pelo receive() e o sinal received).
function run(t) {
    const G = t.GameMode;

    const fields = ["client", "error", "active", "manual", "reasons", "windows", "since", "lastSince", "effects", "seenState",
        "autoFullscreen", "autoGames", "always", "never", "effectsOn", "vrr", "tearing", "profile", "gamemode", "light", "factoryNever"];
    const original = {};
    for (const f of fields)
        original[f] = G[f];

    function restore() {
        for (const f of fields)
            if (f !== "client")
                G[f] = original[f];
        G.client = original.client;
    }

    function restored() {
        return fields.every(f => f === "client" ? G.client === original.client : JSON.stringify(G[f]) === JSON.stringify(original[f]));
    }

    function ok(id, result) {
        return JSON.stringify({ jsonrpc: "2.0", id: id, result: result });
    }

    function ids(c) {
        return Object.keys(c.pending).map(Number);
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

    function wired() {
        const c = t.lucernaClient();
        G.client = c;
        c.opened();
        c.receive(ok(ids(c)[0], hello(["game.state", "game.status"])));
        return c;
    }

    function state(fields) {
        return JSON.parse(JSON.stringify(Object.assign({
            active: false, manual: null, reasons: [], windows: [], since: null,
            effects: { compositor: "off", vrr: "off", tearing: "off", profile: "off", gamemode: "off", light: "off" }
        }, fields)));
    }

    function on(fields) {
        return state(Object.assign({ active: true, reasons: ["fullscreen", "game"], since: 1792850000000,
            effects: { compositor: "ok", vrr: "ok", tearing: "off", profile: "ok", gamemode: "unavailable", light: "ok" } }, fields));
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

    t.test("gamemode: os tópicos", () => {
        t.eq(G.wantedTopics(), ["game.state", "game.status"]);
    });

    withClient("gamemode: configura na conexão e a cada mudança", c => {
        const first = last(c, "game.configure");
        t.check(first !== null, "a conexão configura");
        t.check(idsOf(c, "lucerna.subscribe").some(id => Array.from(c.pending[id].params.topics).includes("game.state")), "assina o estado");
        c.pending = {};
        G.tearing = !G.tearing;
        t.eq(last(c, "game.configure"), null, "espera o fim do turno");
        G.flushConfigure();
        const after = last(c, "game.configure");
        t.check(after !== null, "a mudança configura de novo");
        t.eq(Object.keys(after.params), ["auto", "always", "compositor", "system"], "o objeto inteiro, sem a nunca do usuário");
        t.eq(after.params.compositor.tearing, G.tearing);
        c.pending = {};
        G.autoFullscreen = false;
        G.light = false;
        G.never = ["x"];
        G.flushConfigure();
        G.flushConfigure();
        t.eq(idsOf(c, "game.configure").length, 1, "três mudanças no mesmo turno, um configure");
        const p = last(c, "game.configure").params;
        t.eq([p.auto.fullscreen, p.system.light, p.never], [false, false, ["x"]]);
        t.eq(Object.keys(p), ["auto", "always", "never", "compositor", "system"], "com a nunca do usuário, o objeto inteiro");
    });

    withClient("gamemode: a nunca de fábrica pelo game.defaults", c => {
        const asked = last(c, "game.defaults");
        t.check(asked !== null, "a conexão pede a de fábrica");
        t.eq(asked.params, {});
        G.never = null;
        t.eq([G.factoryNever, G.effectiveNever], [null, []], "antes da resposta, vazia");
        c.receive(ok(asked.id, { auto: { fullscreen: true, games: true }, always: [], never: [" MPV ", "vlc", "mpv"], compositor: {}, system: {} }));
        t.eq([G.factoryNever, G.effectiveNever], [["mpv", "vlc"], ["mpv", "vlc"]], "limpa");
        G.never = ["steam"];
        t.eq(G.effectiveNever, ["steam"], "a do usuário vence");
        c.lost();
        t.eq(G.factoryNever, ["mpv", "vlc"], "a conexão que cai não esquece");
        c.opened();
        c.receive(ok(idsOf(c, "lucerna.hello")[0], hello(["game.state", "game.status"])));
        t.check(last(c, "game.defaults").id !== asked.id, "a conexão nova lê de novo");
    });

    withClient("gamemode: um lucernad sem o game.defaults", c => {
        G.factoryNever = ["mpv"];
        c.receive(JSON.stringify({ jsonrpc: "2.0", id: last(c, "game.defaults").id, error: { code: -32601, message: "método desconhecido" } }));
        t.eq(G.factoryNever, null, "a de fábrica fica desconhecida");
        G.factoryNever = ["mpv"];
        G.applyDefaults({ error: { code: -1, message: "Sem conexão com o lucernad." } });
        t.eq(G.factoryNever, ["mpv"], "sem conexão não muda nada");
        G.applyDefaults(null);
        t.eq(G.factoryNever, ["mpv"]);
        c.pending = {};
        G.never = null;
        G.flushConfigure();
        G.configure();
        t.eq(Object.keys(last(c, "game.configure").params).includes("never"), false, "o configure sem a nunca: o daemon usa a dele");
        c.lost();
        c.pending = {};
        G.readDefaults();
        t.eq(last(c, "game.defaults"), null, "sem conexão não pede");
    });

    withClient("gamemode: a nunca do Config igual à de fábrica volta a null", c => {
        const C = t.Config;
        const was = C.gameNever;
        try {
            C.gameNever = ["vlc", "MPV"];
            G.applyDefaults({ result: { never: ["mpv", "vlc"] } });
            t.eq(C.gameNever, null, "a cópia antiga passa a acompanhar o daemon");
            C.gameNever = ["vlc"];
            G.applyDefaults({ result: { never: ["mpv", "vlc"] } });
            t.eq(C.gameNever, ["vlc"], "a lista personalizada fica");
            C.gameNever = null;
            G.applyDefaults({ result: { never: ["mpv", "vlc"] } });
            t.eq(C.gameNever, null);
        } finally {
            C.gameNever = was;
        }
        t.eq(C.gameNever, was, "Config restaurado");
    });

    t.test("gamemode: as mesmas classes e a nunca guardada", () => {
        const was = G.factoryNever;
        try {
            t.check(G.sameClasses(["MPV", "vlc"], ["vlc", "mpv", "mpv"]), "a ordem, maiúsculas e repetidas não contam");
            t.check(!G.sameClasses(["mpv"], ["mpv", "vlc"]), "falta uma");
            t.check(!G.sameClasses(["mpv", "x"], ["mpv", "vlc"]), "outra classe");
            G.factoryNever = null;
            t.eq(G.storedNever(["mpv"]), ["mpv"], "sem a de fábrica, a própria lista");
            G.factoryNever = ["mpv", "vlc"];
            t.eq(G.storedNever(["vlc", "mpv"]), null);
            t.eq(G.storedNever(["vlc"]), ["vlc"]);
            t.eq(G.storedNever([]), [], "a vazia é do usuário");
        } finally {
            G.factoryNever = was;
        }
        t.eq(G.factoryNever, was, "estado original restaurado");
    });

    withClient("gamemode: as listas vão limpas", c => {
        const many = [];
        for (let i = 0; i < 120; i++)
            many.push(`app${i}`);
        G.always = [" Steam ", "steam", "", "x".repeat(129), "  ", "Heroic"].concat(many);
        G.flushConfigure();
        const sent = Array.from(last(c, "game.configure").params.always);
        t.eq(sent.slice(0, 3), ["steam", "heroic", "app0"]);
        t.eq(sent.length, 100);
        G.never = ["MPV", "mpv"];
        G.flushConfigure();
        t.eq(last(c, "game.configure").params.never, ["mpv"]);
        t.eq(G.cleanClasses(null), []);
    });

    withClient("gamemode: o estado pelo sinal real", c => {
        c.received("game.status", JSON.parse(JSON.stringify({ available: true, error: null })));
        c.received("game.state", on({ manual: "on", reasons: ["manual"] }));
        t.eq([G.available, G.active, G.manual, G.reasons, G.since], [true, true, "on", ["manual"], 1792850000000]);
        t.eq(G.effects.gamemode, "unavailable");
        t.eq(G.reasonsText(["fullscreen", "game", "always", "manual", "x"]), "tela cheia, jogo, lista sempre, manual, x");
        c.received("game.state", state({}));
        t.eq([G.active, G.manual, G.since, G.lastSince], [false, "", 0, 1792850000000], "o since da sessão que acabou fica");
    });

    withClient("gamemode: null e tópico desconhecido não mudam nada", c => {
        c.received("game.state", on({}));
        G.apply("game.state", null);
        G.apply("game.outro", { active: false });
        t.eq(G.active, true);
    });

    withClient("gamemode: erro no status deixa indisponível", c => {
        c.received("game.status", JSON.parse(JSON.stringify({ available: false, error: "sem hyprland" })));
        t.eq([G.available, G.unavailableNote], [false, "Indisponível: sem hyprland"]);
        c.received("game.status", JSON.parse(JSON.stringify({ available: false, error: null })));
        t.eq(G.available, false, "indisponível sem texto também conta");
        c.received("game.status", JSON.parse(JSON.stringify({ available: true, error: null })));
        t.eq([G.available, G.unavailableNote], [true, ""]);
        c.lost();
        t.eq(G.unavailableNote, "Indisponível: sem conexão com o lucernad.");
    });

    withClient("gamemode: a conexão que cai desliga em silêncio", c => {
        let signals = 0;
        const counter = () => signals++;
        G.changedByDaemon.connect(counter);
        try {
            c.received("game.state", on({}));
            c.lost();
            t.eq([G.active, G.since, G.reasons, G.windows, G.effects.compositor], [false, 0, [], [], "off"]);
            t.eq(signals, 0, "sem aviso");
        } finally {
            G.changedByDaemon.disconnect(counter);
        }
    });

    withClient("gamemode: o aviso só depois do primeiro estado", c => {
        const seen = [];
        const record = a => seen.push(a);
        G.changedByDaemon.connect(record);
        try {
            c.received("game.state", on({}));
            t.eq(seen, [], "o primeiro estado (o shell reiniciou no meio do jogo) não avisa");
            c.received("game.state", on({ reasons: ["game"] }));
            t.eq(seen, [], "sem troca de active, sem aviso");
            c.received("game.state", state({}));
            c.received("game.state", on({}));
            t.eq(seen, [false, true]);
            c.lost();
            c.opened();
            c.receive(ok(idsOf(c, "lucerna.hello")[0], hello(["game.state", "game.status"])));
            t.check(c.connected, "reconectado");
            c.received("game.state", state({}));
            t.eq(seen, [false, true], "o primeiro estado depois de reconectar também não");
        } finally {
            G.changedByDaemon.disconnect(record);
        }
    });

    withClient("gamemode: ligar, desligar e alternar chamam o daemon", c => {
        c.pending = {};
        G.set(true);
        t.eq(last(c, "game.set").params, { on: true });
        G.set(false);
        t.eq(last(c, "game.set").params, { on: false });
        G.toggle();
        t.check(last(c, "game.toggle") !== null, "pediu o toggle");
    });

    t.test("gamemode: o texto do IPC game get", () => {
        t.eq(G.statusText(true, true, ["manual"]), "ligado (manual)");
        t.eq(G.statusText(true, true, ["fullscreen", "game"]), "ligado (tela cheia, jogo)");
        t.eq(G.statusText(true, true, []), "ligado");
        t.eq(G.statusText(true, false, ["game"]), "desligado");
        t.eq(G.statusText(false, true, ["game"]), "indisponível");
    });
}
