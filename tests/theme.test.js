// Testes das funções de core/theme/ThemeManager com o tema padrão
// (catppuccin-mocha). O que muda na Config volta ao padrão no fim de cada caso.
function run(t) {
    const T = t.ThemeManager;
    const C = t.Config;

    t.test("theme: tokens do tema padrão", () => {
        t.eq(T.current, "catppuccin-mocha");
        t.eq(String(T.token("accent")), "#89b4fa");
        t.eq(String(T.token("nada")), "#ff00ff", "token que falta vira magenta");
        t.eq(String(T.colors.base), "#1e1e2e");
        t.eq([T.font.sans, T.font.normal, T.radius.large, T.spacing.large, T.barHeight], ["Rubik", 13, 22, 20, 44]);
    });

    t.test("theme: a escala interna multiplica as medidas", () => {
        try {
            t.eq([T.scale, T.px(34), T.spacing.normal, T.font.normal], [1, 34, 12, 13], "escala 1: os valores do tema");
            C.shellScale = 1.25;
            t.eq(T.scale, 1.25);
            t.eq([T.spacing.normal, T.font.normal, T.px(34)], [15, 16, 43]);
            t.eq([T.radius.large, T.barHeight, T.px(0), T.px(1)], [28, 55, 0, 1], "os outros tokens também; 0 e 1 ficam");
            C.scaleMode = "apps";
            t.eq(T.scale, 1.25 * 1.25, "no modo pelos apps, a escala dos apps entra junto");
        } finally {
            C.shellScale = 1;
            C.scaleMode = "monitor";
        }
        t.eq([T.scale, T.spacing.normal, T.font.normal], [1, 12, 13], "restaurado");
    });

    t.test("theme: a escala interna fica entre 0,5 e 3", () => {
        t.eq([T.clampScale(1.25), T.clampScale(0), T.clampScale(-2), T.clampScale(7), T.clampScale(NaN)], [1.25, 0.5, 0.5, 3, 1]);
        const apps = C.appsScale;
        try {
            C.shellScale = 0;
            t.eq([T.scale, T.px(34)], [0.5, 17], "um shellScale 0 não zera as medidas");
            C.shellScale = -1;
            t.eq(T.scale, 0.5, "nem um negativo");
            C.shellScale = 2;
            C.scaleMode = "apps";
            C.appsScale = 2;
            t.eq(T.scale, 3, "nem passa de 3");
        } finally {
            C.shellScale = 1;
            C.scaleMode = "monitor";
            C.appsScale = apps;
        }
        t.eq(T.scale, 1, "restaurado");
    });

    t.test("theme: o eixo de peso da fonte variável", () => {
        t.eq([T.fontAxes(Font.Normal), T.fontAxes(Font.DemiBold), T.fontAxes(300)], [{ wght: 400 }, { wght: 600 }, { wght: 300 }]);
    });

    t.test("theme: cor com opacidade", () => {
        const c = T.alpha(Qt.rgba(1, 0, 0, 1), 0.5);
        t.near(c.a, 0.5, 0.01);
        t.near(c.r, 1, 0.01);
    });

    t.test("theme: contraste do texto sobre uma cor", () => {
        t.near(T.luminance(Qt.rgba(1, 1, 1, 1)), 1, 1e-9, "branco");
        t.near(T.luminance(Qt.rgba(0, 0, 0, 1)), 0, 1e-9, "preto");
        t.near(T.contrast(Qt.rgba(1, 1, 1, 1), Qt.rgba(0, 0, 0, 1)), 21, 1e-9, "o máximo, em qualquer ordem");
        t.near(T.contrast(Qt.rgba(0, 0, 0, 1), Qt.rgba(1, 1, 1, 1)), 21, 1e-9);
        // O aviso do latte: o texto claro dá ~2,3:1; o escuro, ~3,05:1 (o
        // mínimo para texto grande).
        t.near(T.contrast("#df8e1d", "#eff1f5"), 2.32, 0.01, "aviso do latte com o texto claro");
        t.near(T.contrast("#df8e1d", "#4c4f69"), 3.05, 0.01, "aviso do latte com o texto escuro");
        // No mocha: accentText #11111b, text #cdd6f4, base #1e1e2e.
        t.eq(String(T.onColor(T.colors.warning)), "#11111b", "aviso do mocha: o accentText");
        t.eq(String(T.onColor(Qt.rgba(1, 1, 1, 1))), "#11111b", "branco: o mais escuro");
        t.eq(String(T.onColor(Qt.rgba(0, 0, 0, 1))), "#cdd6f4", "preto: o texto claro");
    });

    // As cores que importam aqui, copiadas dos 12 themes/*.json (o runner não
    // lê arquivos). Se um tema mudar de cor, atualizar a linha dele.
    const themes = {
        "catppuccin-latte": { dark: false, accent: "#1e66f5", base: "#eff1f5", surface: "#e6e9ef", raised: "#dce0e8", text: "#4c4f69", danger: "#d20f39", success: "#40a02b", warning: "#df8e1d", track: "#ccd0da" },
        "catppuccin-mocha": { dark: true, accent: "#89b4fa", base: "#1e1e2e", surface: "#313244", raised: "#45475a", text: "#cdd6f4", danger: "#f38ba8", success: "#a6e3a1", warning: "#f9e2af", track: "#45475a" },
        "decay-green": { dark: true, accent: "#78dba9", base: "#0c1210", surface: "#131b18", raised: "#1a2521", text: "#c6dccf", danger: "#e05f65", success: "#78dba9", warning: "#f1cf8a", track: "#22322b" },
        "dracula": { dark: true, accent: "#bd93f9", base: "#282a36", surface: "#343746", raised: "#44475a", text: "#f8f8f2", danger: "#ff5555", success: "#50fa7b", warning: "#f1fa8c", track: "#44475a" },
        "everforest": { dark: true, accent: "#a7c080", base: "#2d353b", surface: "#343f44", raised: "#3d484d", text: "#d3c6aa", danger: "#e67e80", success: "#83c092", warning: "#dbbc7f", track: "#475258" },
        "gruvbox-dark": { dark: true, accent: "#fe8019", base: "#282828", surface: "#3c3836", raised: "#504945", text: "#ebdbb2", danger: "#fb4934", success: "#b8bb26", warning: "#fabd2f", track: "#504945" },
        "kanagawa": { dark: true, accent: "#7e9cd8", base: "#1f1f28", surface: "#2a2a37", raised: "#363646", text: "#dcd7ba", danger: "#e46876", success: "#98bb6c", warning: "#e6c384", track: "#363646" },
        "matte-black": { dark: true, accent: "#d0d0d0", base: "#0f0f0f", surface: "#1a1a1a", raised: "#242424", text: "#e6e6e6", danger: "#cf6a6a", success: "#9db38e", warning: "#d6b56d", track: "#2e2e2e" },
        "nord": { dark: true, accent: "#88c0d0", base: "#2e3440", surface: "#3b4252", raised: "#434c5e", text: "#eceff4", danger: "#bf616a", success: "#a3be8c", warning: "#ebcb8b", track: "#4c566a" },
        "rose-pine-dawn": { dark: false, accent: "#907aa9", base: "#faf4ed", surface: "#fffaf3", raised: "#f2e9e1", text: "#575279", danger: "#b4637a", success: "#286983", warning: "#ea9d34", track: "#dfdad9" },
        "rose-pine": { dark: true, accent: "#c4a7e7", base: "#191724", surface: "#1f1d2e", raised: "#26233a", text: "#e0def4", danger: "#eb6f92", success: "#9ccfd8", warning: "#f6c177", track: "#403d52" },
        "tokyo-night": { dark: true, accent: "#7aa2f7", base: "#1a1b26", surface: "#24283b", raised: "#2f3549", text: "#c0caf5", danger: "#f7768e", success: "#9ece6a", warning: "#e0af68", track: "#3b4261" }
    };

    t.test("theme: mistura de duas cores", () => {
        const a = Qt.rgba(1, 0, 0, 1);
        const b = Qt.rgba(0, 0, 1, 1);
        t.eq(String(T.mix(a, b, 0)), String(a), "0: a primeira");
        t.eq(String(T.mix(a, b, 1)), String(b), "1: a segunda");
        const half = T.mix(a, b, 0.5);
        t.near(half.r, 0.5, 0.01, "no meio");
        t.near(half.b, 0.5, 0.01);
    });

    t.test("theme: contêiner do destaque em todos os temas", () => {
        t.eq(Object.keys(themes).length, 12);
        for (const [id, x] of Object.entries(themes)) {
            for (const name of ["accent", "danger", "success", "warning"]) {
                const c = T.containerOf(x[name], x.base, x.text, x.dark);
                const on = T.onContainerOf(c, x.text, x.base);
                const where = `${id} ${name}: ${c} / ${on}`;
                t.check(T.contrast(on, c) >= 4.5, `${where}: texto ${T.contrast(on, c).toFixed(2)}`);
                // A tela desenha em 8 bits: o contraste vale também com a cor
                // arredondada para #rrggbb.
                t.check(T.contrast(String(on), String(c)) >= 4.5, `${where}: texto em 8 bits ${T.contrast(String(on), String(c)).toFixed(4)}`);
                t.check(T.contrast(c, x.raised) >= 1.2, `${where}: com o raised ${T.contrast(c, x.raised).toFixed(2)}`);
                if (x.dark)
                    t.check(T.luminance(c) < T.luminance(x[name]), `${where}: mais escuro que a cor`);
                else
                    t.check(T.luminance(c) > T.luminance(x[name]), `${where}: mais claro que a cor`);
            }
        }
    });

    t.test("theme: ícone, hover e barra de nível sobre o contêiner", () => {
        for (const [id, x] of Object.entries(themes)) {
            const d = T.derivedColors({ dark: x.dark, colors: x });
            const where = `${id}: ${d.accentIcon} / ${d.accentContainer}`;
            t.check(T.contrast(String(d.accentIcon), String(d.accentContainer)) >= 3, `${where}: ícone ${T.contrast(String(d.accentIcon), String(d.accentContainer)).toFixed(2)}`);
            for (const name of ["accent", "danger", "success", "warning"]) {
                const c = T.containerOf(x[name], x.base, x.text, x.dark);
                const on = T.onContainerOf(c, x.text, x.base);
                const icon = T.iconOn(x[name], c, x.dark);
                const at = `${id} ${name}`;
                t.check(T.contrast(String(icon), String(c)) >= 3, `${at}: ícone ${icon} ${T.contrast(String(icon), String(c)).toFixed(2)}`);
                // O véu do Clickable ativo é o base a 8% (hover), 12%
                // (pressão) e 16% (onda): o texto continua a 4,5:1.
                for (const veil of [0.08, 0.12, 0.16]) {
                    const lit = T.mix(c, x.base, veil);
                    t.check(T.contrast(String(on), String(lit)) >= 4.5, `${at}: texto com o véu ${veil} ${T.contrast(String(on), String(lit)).toFixed(2)}`);
                }
                // O cartão da bateria: trilho no contêiner, preenchimento a
                // 3:1 do trilho; o raio (no preenchimento) a 3:1 do contêiner.
                const track = T.trackOn(c, on);
                const fill = T.iconOn(x[name], track, x.dark);
                t.check(T.contrast(String(fill), String(track)) >= 3, `${at}: barra ${fill} / ${track} ${T.contrast(String(fill), String(track)).toFixed(2)}`);
                t.check(T.contrast(String(fill), String(c)) >= 3, `${at}: raio ${T.contrast(String(fill), String(c)).toFixed(2)}`);
                t.check(T.contrast(String(on), String(c)) >= 4.5, `${at}: texto no card`);
            }
        }
    });

    t.test("theme: o ícone sobre um fundo", () => {
        t.eq(String(T.iconOn("#89b4fa", "#1e1e2e", true)), "#89b4fa", "a cor pura, quando passa");
        const lighter = T.iconOn("#45475a", "#313244", true);
        t.check(T.luminance(lighter) > T.luminance("#45475a") && T.contrast(lighter, "#313244") >= 3, `no escuro, clareia: ${lighter}`);
        const darker = T.iconOn("#dddddd", "#eeeeee", false);
        t.check(T.luminance(darker) < T.luminance("#dddddd") && T.contrast(darker, "#eeeeee") >= 3, `no claro, escurece: ${darker}`);
        const other = T.iconOn("#d0d0d0", "#e0e0e0", true);
        t.check(T.luminance(other) < T.luminance("#d0d0d0") && T.contrast(other, "#e0e0e0") >= 3, `sem o branco passar, o outro lado: ${other}`);
        t.eq(String(T.trackOn("#000000", "#ffffff")), String(T.mix("#000000", "#ffffff", 0.25)));
    });

    t.test("theme: o texto sobre o contêiner", () => {
        const text = "#cdd6f4";
        const base = "#1e1e2e";
        t.eq(String(T.onContainerOf("#1e1e2e", text, base)), text, "o texto do tema, quando passa");
        const on = T.onContainerOf("#a0a0a0", text, base);
        t.check(T.contrast(on, "#a0a0a0") >= 4.5, `senão, o que der mais contraste: ${on}`);
        t.eq(String(T.containerOf("#202030", base, "#202030", true)), base, "sem mistura que passe (cor e texto quase iguais ao base), o próprio base");
    });

    t.test("theme: preenchimento das barras", () => {
        for (const [id, x] of Object.entries(themes)) {
            const fill = T.fillOf(x.accent, x.surface, x.track);
            t.check(T.contrast(fill, x.track) >= 3, `${id}: preenchimento ${fill} ${T.contrast(fill, x.track).toFixed(2)}`);
            const danger = T.fillOf(x.danger, x.surface, x.track);
            t.check(T.contrast(danger, x.track) >= 3, `${id}: perigo ${danger} ${T.contrast(danger, x.track).toFixed(2)}`);
            t.check(T.contrast(String(fill), x.track) >= 3 && T.contrast(String(danger), x.track) >= 3, `${id}: em 8 bits`);
        }
        // Um trilho cinza-médio (tema do usuário), com a cor igual a ele: o
        // preenchimento vai até o preto ou o branco se precisar.
        for (const gray of ["#5a5a5a", "#767676", "#777777", "#8a8a8a"]) {
            const fill = T.fillOf(gray, gray, gray);
            t.check(T.contrast(String(fill), gray) >= 3, `trilho ${gray}: ${fill} ${T.contrast(String(fill), gray).toFixed(2)}`);
        }
        t.eq(String(T.fillOf("#89b4fa", "#313244", "#45475a")), String(T.mix("#89b4fa", "#313244", 0.15)), "o destaque levemente misturado ao surface");
    });

    t.test("theme: tokens do contêiner do tema padrão", () => {
        const x = themes["catppuccin-mocha"];
        const c = T.containerOf(x.accent, x.base, x.text, true);
        t.eq(String(T.colors.accentContainer), String(c));
        t.eq(String(T.colors.onAccentContainer), String(T.onContainerOf(c, x.text, x.base)));
        t.eq(String(T.colors.accentFill), String(T.fillOf(x.accent, x.surface, x.track)));
        t.eq(String(T.container(T.colors.danger)), String(T.containerOf(x.danger, x.base, x.text, true)), "atalho com o tema ativo");
        t.eq(String(T.onContainer(T.colors.danger)), String(T.onContainerOf(T.container(T.colors.danger), x.text, x.base)));
        t.eq(String(T.colors.accentIcon), String(T.iconOn(x.accent, c, true)));
        t.eq(String(T.containerIcon(T.colors.danger)), String(T.iconOn(x.danger, T.container(T.colors.danger), true)), "o ícone do estado com o tema ativo");
    });

    t.test("theme: sobrescrita pelo JSON", () => {
        const x = themes["catppuccin-mocha"];
        const own = T.derivedColors({ dark: true, colors: Object.assign({}, x, { accentContainer: "#3a3f5a" }) });
        t.eq(String(own.accentContainer), "#3a3f5a", "o contêiner do tema");
        t.check(T.contrast(own.onAccentContainer, own.accentContainer) >= 4.5, `o texto calculado: ${own.onAccentContainer}`);
        t.eq(String(own.track), x.track);
        const all = T.derivedColors({ dark: true, colors: Object.assign({}, x, { accentContainer: "#3a3f5a", onAccentContainer: "#ffffff", accentFill: "#ff0000" }) });
        t.eq([String(all.onAccentContainer), String(all.accentFill)], ["#ffffff", "#ff0000"], "os três podem vir do JSON");
        t.eq(String(T.derivedColors({ dark: true, colors: Object.assign({}, x, { accentIcon: "#00ff00" }) }).accentIcon), "#00ff00", "e o ícone também");
        const light = T.derivedColors({ dark: false, colors: { raised: "#eeeeee", border: "#bbbbbb" } });
        t.eq(String(light.track), "#bbbbbb", "sem track: border no claro");
        t.eq(String(T.derivedColors({ colors: { raised: "#eeeeee", border: "#bbbbbb" } }).track), "#eeeeee", "e raised no escuro");
    });

    t.test("theme: JSON do tema", () => {
        t.eq(T.parse(""), {});
        t.eq(T.parse('{"a": 1}'), { a: 1 });
        t.eq(T.parse("{x"), {}, "JSON inválido vira objeto vazio");
    });

    t.test("theme: caminhos relativos a themes/", () => {
        t.eq(T.resolvePath(""), "");
        t.eq(T.resolvePath("/abs/a.jpg"), "/abs/a.jpg");
        t.eq(T.resolvePath("wallpapers/a.jpg"), `${T.directory}/wallpapers/a.jpg`);
        const home = T.resolvePath("~/a.jpg");
        t.check(home.endsWith("/a.jpg") && !home.startsWith("~"), home);
    });

    t.test("theme: campo wallpaper do tema", () => {
        t.eq(T.normalizeWallpaper("wallpapers/a.jpg"), { static: `${T.directory}/wallpapers/a.jpg`, shader: "" });
        t.eq(T.normalizeWallpaper(null), { static: "", shader: "" });
        t.eq(T.normalizeWallpaper({ static: "a.jpg", shader: "shaders/b.qsb" }), { static: `${T.directory}/a.jpg`, shader: `${T.directory}/shaders/b.qsb` });
    });

    t.test("theme: vidro nos painéis e nos cartões", () => {
        const c = Qt.rgba(0, 0, 0, 1);
        t.near(T.glass(c, 0).a, 0.85, 0.01, "painel com a transparência do tema");
        t.near(T.glass(c, 1).a, 0.45, 0.01, "cartão");
        T.setTransparency("enabled", false);
        t.check(T.transparency.customized, "ajuste do usuário");
        t.near(T.glass(c, 0).a, 1, 0.01, "sem transparência, a cor passa igual");
        T.resetGlass();
        t.check(!T.transparency.customized, "restaurado");
    });

    t.test("theme: desfoque ajustado pelo usuário", () => {
        t.eq([T.blur.size, T.blur.passes], [8, 2]);
        T.setBlur("size", 10);
        t.eq(T.blur.size, 10);
        t.check(T.blur.customized, "ajuste do usuário");
        T.resetGlass();
        t.eq(T.blur.size, 8);
    });

    t.test("theme: nível do desfoque, do tema e do usuário", () => {
        try {
            t.eq([T.blur.mode, T.blur.enabled], ["performance", true], "padrão");
            T.setBlurMode("full");
            t.eq([T.blur.mode, T.blur.customized], ["full", true]);
            T.setBlurMode("off");
            t.eq([T.blur.mode, T.blur.enabled], ["off", false]);
            T.setBlurMode("performance");
            t.eq([T.blur.mode, T.blur.customized, C.blurOverride], ["performance", false, null], "o nível do tema não é ajuste");
            T.setBlur("size", 10);
            T.setBlurMode("full");
            T.setBlurMode("performance");
            t.eq(C.blurOverride, { size: 10 }, "volta ao do tema sem perder o size");
        } finally {
            T.resetGlass();
        }
    });

    t.test("theme: o enabled antigo vira o nível desligado", () => {
        t.eq(T.modeFrom({ enabled: false, size: 10 }, {}), "off");
        t.eq(T.modeFrom({ enabled: true }, { blurMode: "full" }), "full");
        t.eq(T.modeFrom({}, { blur: false }), "off");
        t.eq(T.modeFrom({ mode: "full", enabled: false }, {}), "full", "o mode novo vence");
        t.eq(T.modeFrom({ mode: "xray" }, { blurMode: "nada" }), "performance", "valores desconhecidos caem no padrão");
        t.eq(T.modeFrom({}, {}), "performance");
        try {
            C.blurOverride = { enabled: false, size: 10 };
            t.eq([T.blur.mode, T.blur.enabled, T.blur.size], ["off", false, 10], "config antigo");
            T.setBlurMode("full");
            t.eq([C.blurOverride.mode, C.blurOverride.size, T.blur.enabled], ["full", 10, true], "o nível novo não perde o size");
        } finally {
            T.resetGlass();
        }
    });

    t.test("theme: nível desconhecido não muda nada", () => {
        try {
            T.setBlurMode("full");
            T.setBlurMode("xray");
            T.setBlurMode("");
            t.eq(T.blur.mode, "full");
        } finally {
            T.resetGlass();
        }
    });

    t.test("theme: modo leve encurta as animações e tira o vidro", () => {
        t.eq(T.anim.normal, 400);
        T.lightMode = true;
        t.eq(T.anim.normal, 240);
        t.check(!T.transparency.enabled, "sem transparência no modo leve");
        T.lightMode = false;
        t.eq(T.anim.normal, 400);
    });

    t.test("theme: papel de parede do tema e a escolha do usuário", () => {
        const own = T.wallpaperFor(T.current);
        t.eq([own.kind, own.custom], ["theme", false]);
        t.check(own.static.endsWith("/themes/wallpapers/catppuccin-mocha.jpg"), own.static);
        t.check(own.shader.endsWith("/themes/shaders/aurora.qsb"), own.shader);
        C.themeWallpapers = { "catppuccin-mocha": { kind: "theme-image" } };
        t.eq([T.wallpaperFor(T.current).shader, T.wallpaperFor(T.current).custom], ["", true]);
        C.themeWallpapers = { "catppuccin-mocha": { kind: "effect", effect: "neve" } };
        t.eq(T.wallpaperFor(T.current).kind, "effect");
        C.themeWallpapers = { "catppuccin-mocha": { kind: "image", image: "/tmp/x.jpg" } };
        t.eq(T.wallpaperFor(T.current).static, "/tmp/x.jpg");
        C.videoVariants = { "/v.mp4": { "1920x1080-c-30": { poster: "/p.jpg" } } };
        C.themeWallpapers = { "catppuccin-mocha": { kind: "video", source: "/v.mp4" } };
        const video = T.wallpaperFor(T.current);
        t.eq([video.kind, video.static, video.source], ["video", "/p.jpg", "/v.mp4"]);
        C.themeWallpapers = {};
        C.videoVariants = {};
    });

    // Por último: trocar de tema anima as cores, e os casos acima leem cores.
    t.test("theme: lista de temas e troca de tema", () => {
        T.rebuildList();
        t.check(Array.isArray(T.themes), "themes é uma lista");
        T.apply("nord");
        t.eq(T.current, "nord");
        T.apply("catppuccin-mocha");
        t.eq(T.current, "catppuccin-mocha");
    });
}
