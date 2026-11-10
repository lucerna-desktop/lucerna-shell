// Testes de features/settings/state/GameModeState: a página Modo jogo das
// Configurações (a linha do estado, o efeito de cada item, as listas sempre e
// nunca e as preferências). As listas e as chaves do Config voltam ao fim.
function run(t) {
    const S = t.GameModeState;
    const C = t.Config;
    const G = t.GameMode;

    function withConfig(name, body) {
        t.test(name, () => {
            const was = { always: C.gameAlways, never: C.gameNever, tearing: C.gameTearing, bar: C.gameBar, factory: G.factoryNever };
            try {
                body();
            } finally {
                G.factoryNever = was.factory;
                C.gameAlways = was.always;
                C.gameNever = was.never;
                C.gameTearing = was.tearing;
                C.gameBar = was.bar;
            }
            t.eq([C.gameAlways, C.gameNever, C.gameTearing, C.gameBar, G.factoryNever], [was.always, was.never, was.tearing, was.bar, was.factory], "estado original restaurado");
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

    withConfig("gamemodestate: a nunca de fábrica até a primeira mudança", () => {
        G.factoryNever = ["mpv", "vlc"];
        C.gameAlways = [];
        C.gameNever = null;
        t.eq(S.never, ["mpv", "vlc"], "a página mostra a de fábrica");
        S.addClass("never", "Steam");
        t.eq(C.gameNever, ["mpv", "vlc", "steam"], "a mudança grava a lista inteira");
        S.removeClass("never", "steam");
        t.eq(C.gameNever, null, "igual à de fábrica, volta a acompanhá-la");
        S.addClass("always", "mpv");
        t.eq([C.gameAlways, C.gameNever], [["mpv"], ["vlc"]], "tirar da de fábrica também grava");
        S.removeClass("never", "outro");
        t.eq(C.gameNever, ["vlc"], "remover o que não está não muda nada");
        S.addClass("never", "mpv");
        t.eq([C.gameAlways, C.gameNever], [[], null]);
    });

    withConfig("gamemodestate: sem a de fábrica, a nunca de fábrica fica", () => {
        G.factoryNever = null;
        C.gameAlways = [];
        C.gameNever = null;
        t.eq(S.never, [], "não há o que mostrar");
        t.eq(S.neverKnown, false);
        t.eq(S.emptyText("never", S.neverKnown), "A de fábrica do lucernad (players e navegadores); atualize o lucernad para ver e editar", "a página diz por quê");
        t.eq(S.emptyText("always", false), "Nenhum app");
        t.eq(S.emptyText("never", true), "Nenhum app");
        S.addClass("never", "steam");
        t.eq(C.gameNever, null, "não grava uma lista sem as de fábrica");
        S.addClass("always", "mpv");
        t.eq([C.gameAlways, C.gameNever], [["mpv"], null], "a sempre muda");
        S.removeClass("never", "mpv");
        t.eq(C.gameNever, null);
        C.gameNever = ["vlc"];
        S.addClass("never", "mpv");
        t.eq([C.gameAlways, C.gameNever], [[], ["vlc", "mpv"]], "com a lista do usuário, edita normal");
        t.eq(S.neverKnown, true);
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
