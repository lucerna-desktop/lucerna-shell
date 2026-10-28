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

    N.popups = original.popups;
    N.receivedAt = original.receivedAt;

    t.test("notifications: estado original restaurado", () => {
        t.eq([N.popups, N.receivedAt], [original.popups, original.receivedAt]);
    });
}
