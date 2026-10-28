// Testes da barra: um modelo só, a aba fundida à moldura. Quando ela aparece:
// some com um painel centralizado, fica à mostra com o painel superior ou a
// central, e desce junto com a moldura (o Frame, o Panels e o estado da barra
// voltam ao fim).
function run(t) {
    const B = t.BarState;
    const F = t.Frame;
    const P = t.Panels;

    // Roda o corpo com um painel da moldura (aberto ou não) na tela "A" e
    // devolve o Frame, os painéis e a visibilidade da barra.
    function withFrame(name, open, body) {
        t.test(name, () => {
            const blobs0 = F.blobs, opened0 = P.opened, revealed0 = B.revealedScreen;
            const peeking0 = B.peeking, hovering0 = B.hovering, pinned0 = B.pinnedScreen;
            try {
                F.blobs = [{ screen: "A", role: "panel", framed: true, open: open, progress: open ? 1 : 0, rect: Qt.rect(0, 0, 10, 10) }];
                body();
            } finally {
                F.blobs = blobs0;
                P.opened = opened0;
                B.revealedScreen = revealed0;
                B.peeking = peeking0;
                B.hovering = hovering0;
                B.pinnedScreen = pinned0;
            }
        });
    }

    withFrame("bar: com um painel da moldura aberto, a pílula fica fundida e à mostra", true, () => {
        P.opened = ["dashboard"];
        t.check(B.shownOn("A"), "fundida na tela do painel, mesmo com um painel aberto");
    });

    withFrame("bar: com um painel centralizado, a pílula some", false, () => {
        P.opened = ["launcher"];
        B.revealedScreen = "A";
        t.check(!B.shownOn("A"), "o mouse no topo não traz a pílula por cima do launcher");
        B.peek("A");
        t.eq(B.revealedScreen, "A", "a troca de workspace não mexe nela com um painel aberto");
    });

    withFrame("bar: o mouse no topo traz a barra; a troca de workspace também", false, () => {
        const onEmpty0 = t.Config.barOnEmpty;
        try {
            t.Config.barOnEmpty = false;
            P.opened = [];
            B.reveal("A");
            t.check(B.shownOn("A") && !B.peeking, "o mouse no topo");
            t.check(!B.shownOn("B"), "só na tela onde encostou");
            // Uma tela de verdade: a tela cheia é lida do Hyprland (fora dele, nenhuma).
            const screen = t.screens[0];
            B.peek(screen);
            t.check(B.peeking && B.shownOn(screen), "a troca de workspace, sem tela cheia");
            B.setHovering(true);
            t.check(!B.peeking, "o mouse em cima dela durante a troca: passa a valer o mouse");
            B.peek(screen);
            t.check(!B.peeking && B.shownOn(screen), "a troca com o mouse em cima dela (a roda nos workspaces): vale o mouse");
        } finally {
            t.Config.barOnEmpty = onEmpty0;
        }
    });

    t.test("bar: a regra de quando ela aparece", () => {
        const base = { fused: false, panelOpen: false, revealed: false, peeking: false, empty: false, fullscreen: false };
        const at = over => B.decide(Object.assign({}, base, over));
        t.check(!at({}), "sem motivo, escondida");
        t.check(at({ revealed: true }), "o mouse no topo");
        t.check(at({ revealed: true, fullscreen: true }), "o mouse no topo, mesmo sobre a tela cheia");
        t.check(at({ revealed: true, peeking: true }), "a troca de workspace");
        t.check(!at({ revealed: true, peeking: true, fullscreen: true }), "a troca de workspace não cobre a tela cheia");
        t.check(at({ empty: true }) && !at({ empty: true, fullscreen: true }), "o workspace vazio, fora da tela cheia");
        t.check(!at({ revealed: true, panelOpen: true }), "um painel centralizado aberto esconde");
        t.check(at({ fused: true, panelOpen: true, fullscreen: true }), "fundida a um painel da moldura, sempre");
    });

    withFrame("bar: ao abrir o painel superior, o mouse conta como fora", true, () => {
        P.opened = [];
        B.setHovering(true);
        P.opened = ["dashboard"];
        t.check(!B.hovering, "a barra virou o painel e não vê a saída do mouse");
    });

    t.test("bar: o topo da barra desce com a moldura", () => {
        const h = 34;
        t.eq(B.pillY(h, 1), 0, "aberta: encostada na borda de cima");
        t.eq(B.pillY(h, 0.5), -h / 2, "no meio do caminho");
        t.eq(B.pillY(h, 0), -h, "escondida: acima da tela");
    });

    t.test("bar: no modo jogo, o mouse e a troca de workspace não trazem", () => {
        const base = { fused: false, panelOpen: false, revealed: false, peeking: false, pinned: false, gameLocked: true, empty: false, fullscreen: true };
        const at = over => B.decide(Object.assign({}, base, over));
        t.check(!at({ revealed: true }), "o mouse no topo, preso");
        t.check(!at({ revealed: true, peeking: true, fullscreen: false }), "a troca de workspace, presa");
        t.check(at({ empty: true, fullscreen: false }), "o workspace vazio continua");
        t.check(at({ fused: true }), "fundida a um painel da moldura, sempre");
    });

    t.test("bar: a ação bar revela, também no modo jogo", () => {
        const base = { fused: false, panelOpen: false, revealed: false, peeking: false, pinned: true, gameLocked: true, empty: false, fullscreen: true };
        const at = over => B.decide(Object.assign({}, base, over));
        t.check(at({}), "no modo jogo, sobre a tela cheia");
        t.check(at({ gameLocked: false }), "fora do modo jogo");
        t.check(!at({ panelOpen: true }), "um painel centralizado ainda esconde");
    });

    t.test("bar: fora do modo jogo, a regra de sempre", () => {
        const base = { fused: false, panelOpen: false, revealed: false, peeking: false, pinned: false, gameLocked: false, empty: false, fullscreen: false };
        const at = over => B.decide(Object.assign({}, base, over));
        t.check(at({ revealed: true, fullscreen: true }), "o mouse no topo sobre a tela cheia");
        t.check(at({ revealed: true, peeking: true }), "a troca de workspace");
    });

    withFrame("bar: a ação bar alterna pelo Panels, e o modo jogo prende o mouse", false, () => {
        const G = t.GameMode, C = t.Config;
        const was = { active: G.active, bar: C.gameBar };
        try {
            P.opened = [];
            B.revealedScreen = null;
            B.pinnedScreen = null;
            P.requestBarToggle("A");
            t.eq(B.pinnedScreen, "A", "o pedido chega à barra");
            t.check(B.shownOn("A"), "à mostra");
            P.requestBarToggle("A");
            t.eq(B.pinnedScreen, null, "o segundo toque esconde");
            B.togglePinned("A");
            B.togglePinned("B");
            t.eq(B.pinnedScreen, "B", "noutra tela, muda de tela");
            B.pinnedScreen = null;
            C.gameBar = true;
            G.active = true;
            t.check(B.gameLocked, "presa no modo jogo");
            B.reveal("A");
            B.peek("A");
            t.eq(B.revealedScreen, null, "nem o mouse nem a troca de workspace");
            C.gameBar = false;
            t.check(!B.gameLocked, "com o item desligado, solta");
        } finally {
            G.active = was.active;
            C.gameBar = was.bar;
        }
        t.eq([G.active, C.gameBar], [was.active, was.bar], "estado original restaurado");
    });

    t.test("bar: o ícone do modo jogo e o clique que desliga", () => {
        const G = t.GameMode;
        const was = { client: G.client, active: G.active, reasons: G.reasons };
        const c = t.lucernaClient();
        try {
            G.active = false;
            t.eq([B.gameIcon, B.gameTooltip], [false, ""]);
            G.active = true;
            G.reasons = ["fullscreen", "game"];
            t.eq([B.gameIcon, B.gameTooltip], [true, "Modo jogo ligado: tela cheia, jogo. Clique para desligar."]);
            G.reasons = [];
            t.eq(B.gameTooltip, "Modo jogo ligado. Clique para desligar.");
            G.client = c;
            c.opened();
            const hello = Object.keys(c.pending).map(Number)[0];
            c.receive(JSON.stringify({ jsonrpc: "2.0", id: hello, result: { protocol: "1.0", app: "lucernad", version: "0.1.0", topics: ["game.state"], streams: [], methods: [] } }));
            c.pending = {};
            B.stopGame();
            t.eq(Object.values(c.pending).map(p => [p.method, p.params]), [["game.set", { on: false }]]);
        } finally {
            G.client = was.client;
            G.active = was.active;
            G.reasons = was.reasons;
            G.seenState = false;
            c.destroy();
        }
        t.eq([G.active, G.reasons], [was.active, was.reasons], "estado original restaurado");
    });
}
