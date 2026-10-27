// Testes da barra: só ficam a pílula e a ilha. Quem tinha um estilo que saiu
// ("strip", "islands") ou um valor desconhecido no config.json vê a pílula,
// na barra (BarState) e na página dela nas Configurações (SettingsState).
// O barStyle volta ao fim.
function run(t) {
    const B = t.BarState;
    const S = t.SettingsState;
    const C = t.Config;

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
}
