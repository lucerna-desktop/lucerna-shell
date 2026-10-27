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
