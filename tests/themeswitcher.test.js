// Testes do fluxo do seletor de temas (features/themeSwitcher/state): abrir,
// girar com a espera, confirmar e desfazer. A espera de 300 ms não corre
// aqui: `pending` diz se ela está armada e `flush()` a dispara na hora. Cada
// caso usa uma fila de três temas e devolve Config.theme, a lista de temas e
// os painéis abertos ao que eram. Fica por último no runner: trocar de tema
// anima as cores, e as outras suítes leem cores.
function run(t) {
    const S = t.ThemeSwitcherState;
    const T = t.ThemeManager;
    const C = t.Config;
    const P = t.Panels;
    const theme0 = C.theme;
    const themes0 = T.themes;
    const opened0 = P.opened;
    const three = [{ id: "catppuccin-mocha", name: "Catppuccin Mocha" }, { id: "dracula", name: "Dracula" }, { id: "nord", name: "Nord" }];

    // Aplica `id`, abre o seletor com a fila de três e roda o corpo; no fim,
    // mesmo com exceção, fecha e restaura.
    function scenario(name, id, body) {
        t.test(name, () => {
            T.themes = three;
            T.apply(id);
            P.open("themes");
            try {
                body();
            } finally {
                P.close();
                C.theme = theme0;
                T.themes = themes0;
                P.opened = opened0;
            }
        });
    }

    scenario("themeswitcher: abrir guarda o tema e centra a fila nele", "dracula", () => {
        t.eq([S.open, S.openedWith, S.index, S.pending], [true, "dracula", 1, false]);
    });

    scenario("themeswitcher: girar espera antes de aplicar e aplica só onde parou", "catppuccin-mocha", () => {
        S.step(1);
        t.eq([S.index, S.pending, T.current], [1, true, "catppuccin-mocha"], "a espera armada, nada aplicado");
        S.step(1);
        S.step(1);
        t.eq(S.index, 0, "depois do último vem o primeiro");
        S.step(-1);
        t.eq([S.index, T.current], [2, "catppuccin-mocha"], "antes do primeiro vem o último");
        S.flush();
        t.eq([S.pending, T.current, S.open], [false, "nord", true], "só o tema onde a fila parou");
    });

    scenario("themeswitcher: Enter aplica o que falta e mantém", "catppuccin-mocha", () => {
        S.step(1);
        S.confirm();
        t.eq([S.open, S.pending, T.current], [false, false, "dracula"]);
    });

    scenario("themeswitcher: Enter sem girar mantém o tema da abertura", "nord", () => {
        S.confirm();
        t.eq([S.open, T.current], [false, "nord"]);
    });

    scenario("themeswitcher: Enter sem girar mantém um tema trocado por fora", "catppuccin-mocha", () => {
        T.apply("nord");
        S.confirm();
        t.eq([S.open, T.current], [false, "nord"], "o theme set externo não é sobrescrito");
    });

    scenario("themeswitcher: Enter sem girar, com a abertura fora da lista, não aplica o primeiro card", "gruvbox-dark", () => {
        S.confirm();
        t.eq([S.open, T.current], [false, "gruvbox-dark"]);
    });

    scenario("themeswitcher: Esc para a espera e volta ao tema da abertura", "catppuccin-mocha", () => {
        S.step(1);
        S.flush();
        S.step(1);
        t.eq([T.current, S.pending], ["dracula", true]);
        S.cancel();
        t.eq([S.open, S.pending, T.current], [false, false, "catppuccin-mocha"]);
    });

    scenario("themeswitcher: fechar por outro caminho também desfaz", "catppuccin-mocha", () => {
        S.step(-1);
        S.flush();
        t.eq(T.current, "nord");
        P.open("launcher");
        t.eq([S.open, T.current], [false, "catppuccin-mocha"], "outro painel modal");
        P.open("themes");
        S.step(1);
        P.toggle("themes");
        t.eq([S.open, S.pending, T.current], [false, false, "catppuccin-mocha"], "o atalho de novo, com a espera armada");
    });

    scenario("themeswitcher: clique num card lateral gira até ele; no central, confirma", "catppuccin-mocha", () => {
        S.pick(2);
        t.eq([S.index, S.pending, T.current], [2, true, "catppuccin-mocha"], "gira pelo lado mais curto, com a espera");
        S.pick(2);
        t.eq([S.open, S.pending, T.current], [false, false, "nord"]);
    });

    scenario("themeswitcher: tema da abertura fora da lista", "gruvbox-dark", () => {
        t.eq([S.openedWith, S.index], ["gruvbox-dark", 0]);
        S.step(1);
        S.flush();
        t.eq(T.current, "dracula");
        S.cancel();
        t.eq(T.current, "gruvbox-dark");
    });

    scenario("themeswitcher: lista que muda com o seletor aberto", "nord", () => {
        t.eq([S.index, S.centerId], [2, "nord"]);
        T.themes = [three[2], three[0], three[1]];
        t.eq([S.index, S.centerId], [0, "nord"], "recentra pelo id do centro");
        T.themes = three.slice(0, 2);
        t.eq([S.index, S.centerId], [0, "catppuccin-mocha"], "sem o tema do centro, a volta do índice");
        T.themes = [three[1], three[0]];
        t.eq([S.index, S.centerId], [1, "catppuccin-mocha"]);
        T.themes = [];
        S.step(1);
        t.eq([S.index, S.pending], [0, false], "fila vazia não gira");
        S.confirm();
        t.eq([S.open, T.current], [false, "nord"], "vazia, o Enter só fecha");
    });

    // Conta as trocas de Config.theme (é o que o ThemeManager.apply grava):
    // desfazer sem nada aplicado, ou girar e voltar antes da espera, não
    // reaplica o tema. Hoje reaplicar o mesmo tema não tem efeito, e por isso
    // o teste observa só o Config.theme; se o ThemeManager.apply ganhar efeito
    // próprio (recarregar, trocar o papel), o teste passa a observar esse efeito.
    scenario("themeswitcher: Esc sem girar, ou girando e voltando, não reaplica", "dracula", () => {
        let applied = 0;
        const count = () => applied++;
        C.themeChanged.connect(count);
        try {
            S.cancel();
            t.eq([S.open, T.current, applied], [false, "dracula", 0], "Esc sem girar");
            P.open("themes");
            S.step(1);
            S.step(-1);
            t.eq([S.index, S.pending], [1, true], "de volta ao centro, com a espera armada");
            S.flush();
            t.eq([T.current, applied], ["dracula", 0], "a espera no tema da abertura não aplica");
            S.step(-1);
            S.step(1);
            S.cancel();
            t.eq([S.open, S.pending, T.current, applied], [false, false, "dracula", 0], "Esc depois de ir e voltar");
        } finally {
            C.themeChanged.disconnect(count);
        }
    });

    t.test("themeswitcher: seletor fechado não gira nem fecha outro painel", () => {
        T.themes = three;
        P.open("launcher");
        try {
            const index = S.index;
            S.step(1);
            S.pick(index + 1);
            t.eq([S.index, S.pending], [index, false], "nada gira nem arma a espera");
            S.confirm();
            t.eq(P.opened, ["launcher"], "o confirm perdido não fecha o launcher");
            S.cancel();
            t.eq(P.opened, ["launcher"], "o clique fora perdido também não");
            t.eq(T.current, theme0, "nada aplicado");
        } finally {
            P.close();
            C.theme = theme0;
            T.themes = themes0;
            P.opened = opened0;
        }
    });

    t.test("themeswitcher: flush com o seletor fechado não aplica nada", () => {
        const index0 = S.index;
        const centerId0 = S.centerId;
        T.themes = three;
        try {
            S.center(three.findIndex(x => x.id !== C.theme));
            S.flush();
            t.check(S.centerId !== C.theme, "o card central não é o tema aplicado");
            t.eq([S.open, C.theme], [false, theme0]);
        } finally {
            C.theme = theme0;
            T.themes = themes0;
            S.index = index0;
            S.centerId = centerId0;
        }
    });

    t.test("themeswitcher: os painéis da moldura sem o esmaecer de camada", () => {
        const rule = S.noAnimLua();
        t.check(rule.startsWith("hl.layer_rule("), "uma regra de camada");
        t.check(rule.includes("no_anim = true"), "sem animação");
        t.check(rule.includes('"^lucerna-(panel-frame|frame-.*)$"'), "a janela da forma e os painéis que ainda saem da moldura em janela própria");
    });

    t.test("themeswitcher: desempenho é desfoque com xray", () => {
        const r = S.blurLua("performance", true);
        t.check(r.startsWith("hl.layer_rule(") && r.includes('"^lucerna-panel-.*"'), "regra de camada nos painéis");
        t.check(r.includes("blur = true") && r.includes("xray = true") && r.includes("ignore_alpha = 0.45"), r);
        t.check(S.blurLua("full", true).includes("blur = true") && S.blurLua("full", true).includes("xray = false"), "completo sem xray");
        t.check(S.blurLua("off", true).includes("blur = false"), "desligado");
    });

    t.test("themeswitcher: sem transparência, sem desfoque", () => {
        t.check(S.blurLua("performance", false).includes("blur = false"));
        t.check(S.blurLua("full", false).includes("blur = false"));
    });

    t.test("themeswitcher: a config do desfoque garante vfr, otimizações e popups", () => {
        const c = S.blurConfigLua(12, 1);
        for (const part of ["size = 12", "passes = 1", "new_optimizations = true", "popups = false", "debug = { vfr = true }"])
            t.check(c.includes(part), part);
        t.check(!c.includes("misc"), "misc:vfr não existe no 0.56");
        t.check(!c.includes("enabled"), "nunca desliga o desfoque do Hyprland");
    });

    t.test("themeswitcher: janelas sem desfoque nunca desfazem regra do usuário", () => {
        const w = S.windowBlurLua();
        t.check(w.startsWith("hl.window_rule(") && w.includes("no_blur = true") && w.includes('class = ".*"'), w);
        t.check(!w.includes("no_blur = false"));
    });

    t.test("themeswitcher: religar o desfoque das janelas recarrega, desligar manda a regra", () => {
        t.eq(S.windowRuleAction(S.windowBlurLua(), false), "eval", "desligar");
        t.eq(S.windowRuleAction("", true), "reload", "religar depois de enviada");
        t.eq(S.windowRuleAction("", false), "", "nada enviado, nada a desfazer");
    });

    t.test("themeswitcher: o reload reenvia as regras do desfoque", () => {
        const windows0 = C.blurWindows;
        try {
            C.blurWindows = false;
            const sent = S.rules(true);
            for (const lua of [S.blurLua(T.blur.mode, T.transparency.enabled), S.blurConfigLua(T.blur.size, T.blur.passes), S.windowBlurLua(), S.noAnimLua()])
                t.check(sent.includes(lua), lua);
            C.blurWindows = true;
            t.check(!S.rules(true).includes(S.windowBlurLua()), "janelas com desfoque: sem a regra");
            t.eq(S.rules(false), [], "sem Lua, nada");
        } finally {
            C.blurWindows = windows0;
        }
    });
}
