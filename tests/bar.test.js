// Testes da barra: só ficam a pílula e a ilha. Quem tinha um estilo que saiu
// ("strip", "islands") ou um valor desconhecido no config.json vê a pílula,
// na barra (BarState) e na página dela nas Configurações (SettingsState).
// O barStyle volta ao fim. E quando a pílula aparece: some com um painel
// centralizado, se funde à moldura com o painel superior ou a central, e
// flutua um instante ao descolar (o Frame, o Panels e o estado da barra voltam).
function run(t) {
    const B = t.BarState;
    const S = t.SettingsState;
    const C = t.Config;
    const F = t.Frame;
    const P = t.Panels;

    t.test("bar: os dois estilos que ficaram", () => {
        t.eq(S.barStyles.map(s => s.id), ["pill", "island"]);
    });

    t.test("bar: os estilos que saíram viram a pílula", () => {
        const style0 = C.barStyle;
        try {
            for (const [saved, shown] of [["pill", "pill"], ["island", "island"], ["strip", "pill"], ["islands", "pill"], ["", "pill"]]) {
                C.barStyle = saved;
                t.eq(B.style, shown, `na barra, com "${saved}"`);
                t.eq(S.barStyle, shown, `nas configurações, com "${saved}"`);
            }
        } finally {
            C.barStyle = style0;
        }
    });

    t.test("bar: escolher o estilo grava no config", () => {
        const style0 = C.barStyle;
        try {
            C.barStyle = "strip";
            S.setBarStyle("island");
            t.eq(C.barStyle, "island");
            t.eq(B.style, "island");
        } finally {
            C.barStyle = style0;
        }
    });

    // Roda o corpo com um painel da moldura (aberto ou não) na tela "A" e
    // devolve o Frame, os painéis e a visibilidade da barra.
    function withFrame(name, open, body) {
        t.test(name, () => {
            const blobs0 = F.blobs, opened0 = P.opened, revealed0 = B.revealedScreen, last0 = B.lastFused;
            try {
                F.blobs = [{ screen: "A", role: "panel", framed: true, open: open, progress: open ? 1 : 0, rect: Qt.rect(0, 0, 10, 10) }];
                body();
            } finally {
                F.blobs = blobs0;
                P.opened = opened0;
                B.revealedScreen = revealed0;
                B.lastFused = last0;
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

    withFrame("bar: ao descolar, flutua na tela onde estava", false, () => {
        B.revealedScreen = null;
        B.unfuse("A", null);
        t.eq(B.revealedScreen, "A", "descolou: à mostra, até o mouse sair");
        t.eq(B.lastFused, null);
        B.revealedScreen = null;
        B.unfuse(null, "A");
        t.eq(B.revealedScreen, null, "fundir não revela nada");
        t.eq(B.lastFused, "A");
        B.unfuse("A", "A");
        t.eq(B.revealedScreen, null, "a mesma tela: nada muda");
    });

    t.test("bar: o topo da pílula", () => {
        const gap = 8, h = 34;
        t.eq(B.pillY(gap, h, 1, 0), gap, "flutuando: a folga abaixo da borda");
        t.eq(B.pillY(gap, h, 1, 1), 0, "fundida: encostada na borda");
        t.eq(B.pillY(gap, h, 1, 0.5), gap / 2, "subindo junto com a moldura");
        t.eq(B.pillY(gap, h, 0, 0), gap - (h + gap * 2), "escondida: acima da tela");
        t.eq(B.pillY(gap, h, 1, 1.2), 0, "a mola da moldura não a passa da borda");
    });
}
