// Testes de services/Notifications: popups e prazos (sem o servidor D-Bus).
function run(t) {
    const N = t.Notifications;
    const e = t.enums;

    // hidePopup()/clearPopups() gravam popups; o teste também grava popups e
    // receivedAt diretamente. Guarda o estado de antes para restaurar no fim
    // (a suíte roda no mesmo processo que as seguintes).
    const original = {
        popups: N.popups,
        receivedAt: N.receivedAt
    };

    t.test("notifications: tirar e limpar os popups", () => {
        N.popups = ["a", "b", "c"];
        N.hidePopup("b");
        t.eq(N.popups, ["a", "c"]);
        N.clearPopups();
        t.eq(N.popups, []);
    });

    t.test("notifications: tempo do popup na tela", () => {
        t.eq(N.timeoutFor({ urgency: e.urgencyCritical, expireTimeout: 3000 }), 0, "crítica fica até fechar");
        t.eq(N.timeoutFor({ urgency: e.urgencyNormal, expireTimeout: 3000 }), 3000, "prazo do app");
        t.eq(N.timeoutFor({ urgency: e.urgencyNormal, expireTimeout: 0 }), N.defaultTimeout, "sem prazo, o padrão");
        t.eq(N.timeoutFor({ urgency: e.urgencyNormal, expireTimeout: -1 }), N.defaultTimeout);
    });

    t.test("notifications: horário de chegada guardado", () => {
        N.receivedAt = { 7: 1767225600000 };
        t.eq(N.timeOf({ id: 7 }).getTime(), 1767225600000);
    });

    t.test("notifications: o não perturbe segue o modo jogo e o usuário", () => {
        const S = t.NotificationsState;
        t.eq([S.quietFor(false, false, true), S.quietFor(false, true, true), S.quietFor(false, true, false), S.quietFor(true, false, false)], [false, true, false, true]);
    });

    // O modo jogo liga e desliga pelo GameMode.active (o caminho do daemon) e
    // o Config.doNotDisturb nunca muda (D2).
    function withGame(name, body) {
        t.test(name, () => {
            const S = t.NotificationsState, G = t.GameMode, C = t.Config;
            const was = { active: G.active, dnd: C.doNotDisturb, quiet: C.gameQuiet };
            try {
                C.gameQuiet = true;
                body(S, G, C);
            } finally {
                G.active = was.active;
                C.doNotDisturb = was.dnd;
                C.gameQuiet = was.quiet;
            }
            t.eq([G.active, C.doNotDisturb, C.gameQuiet, N.doNotDisturb], [was.active, was.dnd, was.quiet, was.dnd || (was.active && was.quiet)], "estado original restaurado");
        });
    }

    withGame("notifications: o modo jogo nunca grava o não perturbe", (S, G, C) => {
        C.doNotDisturb = false;
        G.active = true;
        t.eq([N.doNotDisturb, C.doNotDisturb, S.doNotDisturb], [true, false, false], "silencioso, sem gravar");
        G.active = false;
        t.eq([N.doNotDisturb, C.doNotDisturb], [false, false]);
        C.gameQuiet = false;
        G.active = true;
        t.eq(N.doNotDisturb, false, "com o item desligado, não silencia");
    });

    withGame("notifications: o não perturbe do usuário sobrevive à saída do jogo", (S, G, C) => {
        C.doNotDisturb = false;
        G.active = true;
        S.toggleDoNotDisturb();
        G.active = false;
        t.eq([N.doNotDisturb, C.doNotDisturb], [true, true], "o usuário ligou durante o jogo: continua");
    });

    // O resumo do modo jogo.
    const since = 1792850000000;
    function item(app, at, critical) {
        return { app: app, at: since + at, critical: critical === true };
    }

    t.test("notifications: o resumo conta as não críticas desde o since", () => {
        const S = t.NotificationsState;
        const items = [item("Discord", -1000), item("Discord", 10), item("Steam", 20), item("Discord", 30), item("Sistema", 40, true)];
        t.eq(S.summaryOf(items, since, since + 100), { count: 3, apps: ["Discord", "Steam"], more: 0 });
        t.eq(S.summaryTextOf(S.summaryOf(items, since, since + 100)), "Enquanto você jogava: 3 notificações — Discord e Steam");
    });

    t.test("notifications: o resumo agrupa os apps, com e mais N", () => {
        const S = t.NotificationsState;
        const items = [item("Discord", 1), item("Steam", 2), item("Telegram", 3), item("Slack", 4), item("", 5)];
        const s = S.summaryOf(items, since, since + 100);
        t.eq(s, { count: 5, apps: ["Discord", "Steam", "Telegram"], more: 2 });
        t.eq(S.summaryTextOf(s), "Enquanto você jogava: 5 notificações — Discord, Steam, Telegram e mais 2");
        t.eq(S.summaryTextOf({ count: 1, apps: ["Discord"], more: 0 }), "Enquanto você jogava: 1 notificação — Discord");
    });

    t.test("notifications: sem notificação, sem resumo", () => {
        const S = t.NotificationsState;
        t.eq(S.summaryOf([], since, since + 100), null);
        t.eq(S.summaryOf([item("Sistema", 5, true)], since, since + 100), null, "só a crítica: nada");
        S.gameChanged(false, []);
        t.eq(S.summary, null);
    });

    t.test("notifications: a crítica vira popup no modo jogo e não entra no resumo", () => {
        const G = t.GameMode, C = t.Config;
        const was = { active: G.active, quiet: C.gameQuiet };
        try {
            C.gameQuiet = true;
            G.active = true;
            t.eq([N.popsUp({ urgency: e.urgencyCritical }), N.popsUp({ urgency: e.urgencyNormal })], [true, false]);
        } finally {
            G.active = was.active;
            C.gameQuiet = was.quiet;
        }
        t.eq(N.popsUp({ urgency: e.urgencyNormal }), !N.doNotDisturb, "fora do jogo, como antes");
        t.eq(t.NotificationsState.summaryOf([item("Sistema", 5, true), item("Discord", 6)], since, since + 100).count, 1);
    });

    // O shell reiniciado no meio do jogo: o horário de chegada vem do
    // PersistentProperties (receivedAt) e o since, do tópico depois de
    // reconectar; ao sair, conta também as de antes do reinício.
    t.test("notifications: o resumo conta desde o since depois de um reinício", () => {
        const S = t.NotificationsState, G = t.GameMode, C = t.Config;
        const client0 = G.client, notices0 = C.gameNotices, received0 = N.receivedAt;
        const c = t.lucernaClient();
        try {
            C.gameNotices = true;
            G.client = c;
            c.opened();
            const hello = Object.keys(c.pending).map(Number)[0];
            c.receive(JSON.stringify({ jsonrpc: "2.0", id: hello, result: { protocol: "1.0", app: "lucernad", version: "0.1.0", topics: ["game.state"], streams: [], methods: [] } }));
            const now = Date.now();
            N.receivedAt = { 1: now - 60000, 2: now - 1000, 3: now - 3600000 };
            const list = [{ id: 1, appName: "Discord", urgency: e.urgencyNormal }, { id: 2, appName: "Steam", urgency: e.urgencyNormal }, { id: 3, appName: "Velha", urgency: e.urgencyNormal }];
            c.received("game.state", JSON.parse(JSON.stringify({ active: true, manual: null, reasons: ["game"], windows: [], since: now - 120000, effects: {} })));
            t.eq(S.summary, null, "o primeiro estado não mostra nada");
            c.received("game.state", JSON.parse(JSON.stringify({ active: false, manual: null, reasons: [], windows: [], since: null, effects: {} })));
            t.eq(G.lastSince, now - 120000, "o since de antes de zerar");
            S.gameChanged(false, list);
            t.eq(S.summary, { count: 2, apps: ["Discord", "Steam"], more: 0 }, "as duas do jogo, sem a de antes");
            S.openSummary();
            t.eq(S.summary, null, "o clique tira o cartão");
            C.gameNotices = false;
            S.gameChanged(false, list);
            t.eq(S.summary, null, "com o item dos avisos desligado, nada");
        } finally {
            G.client = client0;
            G.active = false;
            G.since = 0;
            G.lastSince = 0;
            G.reasons = [];
            G.seenState = false;
            G.effects = G.offEffects();
            C.gameNotices = notices0;
            N.receivedAt = received0;
            t.Panels.opened = [];
            t.Panels.setCentral(false, false);
            S.dismissSummary();
            c.destroy();
        }
        t.eq(S.summary, null, "estado original restaurado");
    });

    N.popups = original.popups;
    N.receivedAt = original.receivedAt;

    t.test("notifications: estado original restaurado", () => {
        t.eq([N.popups, N.receivedAt], [original.popups, original.receivedAt]);
    });
}
