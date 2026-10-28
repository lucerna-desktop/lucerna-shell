// Testes do OSD (features/osd/state): com a central aberta ele não aparece (sairia
// da mesma borda, por cima dela). O estado do OSD e os painéis voltam ao fim.
function run(t) {
    const O = t.OsdState;
    const P = t.Panels;

    t.test("osd: não aparece com a central aberta", () => {
        const armed0 = O.armed, shown0 = O.shown, kind0 = O.kind, opened0 = P.opened;
        try {
            O.armed = true;
            O.shown = false;
            P.opened = ["central"];
            O.show("brightness");
            t.check(!O.shown, "com a central: não");
            P.opened = ["dashboard"];
            O.show("brightness");
            t.check(O.shown, "com o painel superior: sim");
            t.eq(O.kind, "brightness");
        } finally {
            O.armed = armed0;
            O.shown = shown0;
            O.kind = kind0;
            P.opened = opened0;
        }
    });

    // O aviso do modo jogo: só numa troca vista (o GameMode emite o
    // changedByDaemon), com o item dos avisos ligado.
    function withOsd(name, body) {
        t.test(name, () => {
            const C = t.Config, G = t.GameMode;
            const was = { armed: O.armed, shown: O.shown, kind: O.kind, gameOn: O.gameOn, opened: P.opened, notices: C.gameNotices };
            try {
                O.armed = true;
                O.shown = false;
                P.opened = [];
                C.gameNotices = true;
                body(C, G);
            } finally {
                O.armed = was.armed;
                O.shown = was.shown;
                O.kind = was.kind;
                O.gameOn = was.gameOn;
                P.opened = was.opened;
                C.gameNotices = was.notices;
            }
            t.eq([O.armed, O.shown, O.kind, O.gameOn, C.gameNotices], [was.armed, was.shown, was.kind, was.gameOn, was.notices], "estado original restaurado");
        });
    }

    withOsd("osd: o aviso de entrar e sair do modo jogo", (C, G) => {
        G.changedByDaemon(true);
        t.eq([O.shown, O.kind, O.icon, O.text, O.value], [true, "game", "sports_esports", "Modo jogo ligado", 0]);
        O.shown = false;
        G.changedByDaemon(false);
        t.eq([O.shown, O.text], [true, "Modo jogo desligado"]);
    });

    withOsd("osd: sem aviso com o item desligado", (C, G) => {
        C.gameNotices = false;
        G.changedByDaemon(true);
        t.eq(O.shown, false);
    });

    withOsd("osd: o primeiro estado depois de conectar não avisa", (C, G) => {
        const client0 = G.client;
        const c = t.lucernaClient();
        try {
            G.client = c;
            c.opened();
            const hello = Object.keys(c.pending).map(Number)[0];
            c.receive(JSON.stringify({ jsonrpc: "2.0", id: hello, result: { protocol: "1.0", app: "lucernad", version: "0.1.0", topics: ["game.state"], streams: [], methods: [] } }));
            c.received("game.state", JSON.parse(JSON.stringify({ active: true, manual: null, reasons: ["fullscreen"], windows: [], since: 1792850000000, effects: {} })));
            t.eq([O.shown, t.NotificationsState.summary], [false, null], "nem OSD nem resumo");
            c.received("game.state", JSON.parse(JSON.stringify({ active: false, manual: null, reasons: [], windows: [], since: null, effects: {} })));
            t.eq([O.shown, O.text], [true, "Modo jogo desligado"], "a troca vista avisa");
        } finally {
            G.client = client0;
            G.active = false;
            G.since = 0;
            G.lastSince = 0;
            G.reasons = [];
            G.seenState = false;
            G.effects = G.offEffects();
            c.destroy();
            t.NotificationsState.dismissSummary();
        }
    });
}
