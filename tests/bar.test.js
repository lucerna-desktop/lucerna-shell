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
            try {
                F.blobs = [{ screen: "A", role: "panel", framed: true, open: open, progress: open ? 1 : 0, rect: Qt.rect(0, 0, 10, 10) }];
                body();
            } finally {
                F.blobs = blobs0;
                P.opened = opened0;
                B.revealedScreen = revealed0;
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

    t.test("bar: o topo da barra desce com a moldura", () => {
        const h = 34;
        t.eq(B.pillY(h, 1), 0, "aberta: encostada na borda de cima");
        t.eq(B.pillY(h, 0.5), -h / 2, "no meio do caminho");
        t.eq(B.pillY(h, 0), -h, "escondida: acima da tela");
    });
}
