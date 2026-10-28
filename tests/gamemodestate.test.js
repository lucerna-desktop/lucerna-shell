// Testes de features/settings/state/GameModeState: a página Modo jogo das
// Configurações (a linha do estado, o efeito de cada item, as listas sempre e
// nunca e as preferências). As listas e as chaves do Config voltam ao fim.
function run(t) {
    const S = t.GameModeState;
    const C = t.Config;
    const G = t.GameMode;

    function withConfig(name, body) {
        t.test(name, () => {
            const was = { always: C.gameAlways, never: C.gameNever, tearing: C.gameTearing, bar: C.gameBar };
            try {
                body();
            } finally {
                C.gameAlways = was.always;
                C.gameNever = was.never;
                C.gameTearing = was.tearing;
                C.gameBar = was.bar;
            }
            t.eq([C.gameAlways, C.gameNever, C.gameTearing, C.gameBar], [was.always, was.never, was.tearing, was.bar], "estado original restaurado");
        });
    }

    t.test("gamemodestate: a linha do estado", () => {
        const since = new Date(2026, 9, 27, 21, 14).getTime();
        t.eq(S.statusLineOf(true, true, since, ["fullscreen", "game"], ""), "Ligado desde 21:14 — tela cheia, jogo");
        t.eq(S.statusLineOf(true, true, 0, [], ""), "Ligado");
        t.eq(S.statusLineOf(true, false, 0, [], ""), "Desligado");
        t.eq(S.statusLineOf(false, false, 0, [], "Indisponível: sem conexão com o lucernad."), "Indisponível: sem conexão com o lucernad.");
    });

    t.test("gamemodestate: o efeito de cada item em pt-BR", () => {
        const rows = S.effectRowsOf({ compositor: "ok", vrr: "off", tearing: "unavailable", profile: "error: sem permissão", gamemode: "unavailable" });
        t.eq(rows.map(r => r.state), ["ativo", "desligado", "indisponível", "erro: sem permissão", "não instalado", "desligado"]);
        t.eq(rows.map(r => r.id), ["compositor", "vrr", "tearing", "profile", "gamemode", "light"]);
        t.eq(S.stateText("vrr", "outro"), "outro");
        t.eq(S.effectRows.length, 6, "a lista viva");
    });

    t.test("gamemodestate: as janelas abertas sem as das listas", () => {
        const wins = [{ lastIpcObject: { class: "Steam" } }, { lastIpcObject: { class: "kitty" } }, { wayland: { appId: "mpv" } }, { lastIpcObject: { class: "steam" } }, { lastIpcObject: {} }, null];
        t.eq(S.openClassesOf(wins, ["kitty"], ["MPV"]), ["steam"]);
        t.eq(S.openClassesOf(wins, [], []), ["kitty", "mpv", "steam"]);
        S.refreshWindows();
    });

    withConfig("gamemodestate: acrescentar a sempre tira da nunca", () => {
        C.gameAlways = [];
        C.gameNever = ["mpv", "vlc"];
        S.addClass("always", " MPV ");
        t.eq([C.gameAlways, C.gameNever], [["mpv"], ["vlc"]]);
        S.addClass("never", "mpv");
        t.eq([C.gameAlways, C.gameNever], [[], ["vlc", "mpv"]]);
    });

    withConfig("gamemodestate: acrescentar limpa e não repete", () => {
        C.gameAlways = ["steam"];
        S.addClass("always", "Steam");
        S.addClass("always", "   ");
        S.addClass("always", "x".repeat(129));
        t.eq(C.gameAlways, ["steam"]);
        const full = [];
        for (let i = 0; i < 100; i++)
            full.push(`app${i}`);
        C.gameAlways = full;
        S.addClass("always", "outro");
        t.eq(C.gameAlways.length, 100, "no máximo 100");
    });

    withConfig("gamemodestate: remover", () => {
        C.gameNever = ["mpv", "vlc"];
        S.removeClass("never", "mpv");
        t.eq(C.gameNever, ["vlc"]);
        t.eq(S.never, ["vlc"], "a página acompanha");
    });

    withConfig("gamemodestate: as preferências vão ao Config", () => {
        C.gameTearing = false;
        S.set("gameTearing", true);
        t.eq(C.gameTearing, true);
        S.set("theme", true);
        t.eq(typeof C.theme, "string", "outra chave não muda");
        S.set("gameBar", false);
        t.eq(C.gameBar, false);
    });

    t.test("gamemodestate: ligar agora chama o daemon", () => {
        const client0 = G.client;
        const c = t.lucernaClient();
        try {
            G.client = c;
            c.opened();
            const hello = Object.keys(c.pending).map(Number)[0];
            c.receive(JSON.stringify({ jsonrpc: "2.0", id: hello, result: { protocol: "1.0", app: "lucernad", version: "0.1.0", topics: ["game.state"], streams: [], methods: [] } }));
            t.eq([S.available, S.active], [true, false]);
            c.pending = {};
            S.toggleNow();
            t.eq(Object.values(c.pending).map(p => p.method), ["game.toggle"]);
        } finally {
            G.client = client0;
            c.destroy();
        }
        t.check(G.client === client0, "estado original restaurado");
    });
}
