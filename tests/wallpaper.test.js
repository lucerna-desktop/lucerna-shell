// Testes da decisão de pausar o papel de parede animado sob as camadas
// desfocadas (features/wallpaper/state): telas e janelas de mentira, sem
// Hyprland nem janela de verdade.
function run(t) {
    const W = t.WallpaperState;
    const a = { name: "A" }, b = { name: "B" };

    t.test("wallpaper: painel aberto pausa a tela dele", () => {
        t.eq(W.blurCovers(a, true, [{ screen: a, visible: true }], []), true);
    });

    const panel = [{ role: "pill" }, { role: "panel" }];
    t.test("wallpaper: a forma da moldura à mostra pausa", () => {
        t.eq(W.blurCovers(a, true, [], [{ targetScreen: a, visible: true, parts: panel }]), true);
    });

    t.test("wallpaper: só a pílula da barra não pausa", () => {
        t.eq(W.blurCovers(a, true, [], [{ targetScreen: a, visible: true, parts: [{ role: "pill" }] }]), false);
    });

    t.test("wallpaper: pausa só a tela coberta", () => {
        t.eq(W.blurCovers(b, true, [{ screen: a, visible: true }], [{ targetScreen: a, visible: true, parts: panel }]), false);
    });

    t.test("wallpaper: janela escondida não pausa", () => {
        t.eq(W.blurCovers(a, true, [{ screen: a, visible: false }], [{ targetScreen: a, visible: false, parts: panel }]), false);
    });

    t.test("wallpaper: sem desfoque, não pausa", () => {
        t.eq(W.blurCovers(a, false, [{ screen: a, visible: true }], [{ targetScreen: a, visible: true, parts: panel }]), false);
    });
}
