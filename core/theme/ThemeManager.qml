pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs.core.config

// Único ponto de verdade do visual. Carrega o tema ativo de themes/<id>.json
// e expõe os tokens; nenhum componente usa cor ou tamanho fixo. Cada grupo de
// tokens tem um tipo declarado (ColorTokens, FontTokens...), para o qmllint
// conhecer ThemeManager.colors.accent e os outros; os valores vêm nas
// instâncias, logo abaixo das declarações.
Singleton {
    id: root

    component ColorTokens: QtObject {
        property color base
        property color surface
        property color raised
        property color border
        property color text
        property color textMuted
        property color textFaint
        property color accent
        property color accentText
        property color danger
        property color success
        property color warning
        property color track
    }

    component FontTokens: QtObject {
        property string sans
        property string mono
        property string icon
        property int small
        property int normal
        property int large
        property int huge
    }

    component RadiusTokens: QtObject {
        property int small
        property int normal
        property int large
    }

    component SpacingTokens: QtObject {
        property int tiny
        property int small
        property int normal
        property int large
    }

    // Durações e curvas do Material 3; só a escala vem de fora.
    component MotionTokens: QtObject {
        property real baseScale: 1
        property real scale: 1

        readonly property int small: 200 * scale
        readonly property int normal: 400 * scale
        readonly property int large: 600 * scale
        readonly property int extraLarge: 1000 * scale
        readonly property int fastSpatial: 350 * scale
        readonly property int spatial: 500 * scale
        readonly property int slowSpatial: 650 * scale
        readonly property int fastEffects: 150 * scale
        readonly property int effects: 200 * scale
        readonly property int slowEffects: 300 * scale

        readonly property var standard: [0.2, 0, 0, 1, 1, 1]
        readonly property var standardAccel: [0.3, 0, 1, 1, 1, 1]
        readonly property var standardDecel: [0, 0, 0, 1, 1, 1]
        readonly property var emphasized: [0.05, 0, 2 / 15, 0.06, 1 / 6, 0.4, 5 / 24, 0.82, 0.25, 1, 1, 1]
        readonly property var emphasizedAccel: [0.3, 0, 0.8, 0.15, 1, 1]
        readonly property var emphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]
        readonly property var fastSpatialCurve: [0.42, 1.67, 0.21, 0.9, 1, 1]
        readonly property var spatialCurve: [0.38, 1.21, 0.22, 1, 1, 1]
        readonly property var slowSpatialCurve: [0.39, 1.29, 0.35, 0.98, 1, 1]
        readonly property var fastEffectsCurve: [0.31, 0.94, 0.34, 1, 1, 1]
        readonly property var effectsCurve: [0.34, 0.8, 0.34, 1, 1, 1]
        readonly property var slowEffectsCurve: [0.34, 0.88, 0.34, 1, 1, 1]
    }

    component TransparencyTokens: QtObject {
        property var custom: ({})
        property var theme: ({})
        property bool enabled
        property real base: 1
        property real layers: 1
        property bool customized
    }

    component BlurTokens: QtObject {
        property var custom: ({})
        property string mode
        property bool enabled
        property int size
        property int passes
        property bool customized
    }

    // Um arquivo da lista de temas (o delegate do themeFiles), com tipo
    // declarado para o rebuildList ler themeId, loaded e text sem o qmllint
    // reclamar do objectAt, que devolve QObject.
    component ThemeFile: FileView {
        required property string filePath
        required property string fileBaseName
        readonly property string themeId: fileBaseName
    }

    readonly property string defaultTheme: "catppuccin-mocha"
    readonly property string directory: Quickshell.shellPath("themes")
    readonly property string current: Config.theme

    // Temas disponíveis, para o seletor: { id, name, description, dark, colors,
    // wallpaper, shader } (wallpaper é a imagem; shader, o animado, se houver).
    property var themes: []

    readonly property var data: parse(activeFile.text())
    readonly property bool dark: data.dark ?? true
    // Logo do Lucerna na versão que se lê sobre o tema: estrela clara no escuro, escura no claro.
    readonly property string logo: `file://${Quickshell.shellPath(dark ? "themes/logo.svg" : "themes/logo-claro.svg")}`
    // Papel de parede do tema ativo, já com a escolha do usuário (wallpaperFor).
    readonly property var activeWallpaper: wallpaperFor(current)
    readonly property string wallpaper: activeWallpaper.static
    readonly property string wallpaperShader: activeWallpaper.shader
    readonly property var hyprland: data.hyprland ?? ({})

    readonly property ColorTokens colors: ColorTokens {
        base: root.token("base")
        surface: root.token("surface")
        raised: root.token("raised")
        border: root.token("border")
        text: root.token("text")
        textMuted: root.token("textMuted")
        textFaint: root.token("textFaint")
        accent: root.token("accent")
        accentText: root.token("accentText")
        danger: root.token("danger")
        success: root.token("success")
        warning: root.token("warning")
        // Trilho de medidores e barras. O tema pode definir; senão, "raised" no
        // escuro e "border" no claro (onde "raised" some sobre o cartão).
        track: root.data.colors?.track ?? (root.dark ? raised : border)

        Behavior on track { ColorAnimation { duration: root.anim.large; easing.type: Easing.BezierSpline; easing.bezierCurve: root.anim.standard } }

        Behavior on base { ColorAnimation { duration: root.anim.large; easing.type: Easing.BezierSpline; easing.bezierCurve: root.anim.standard } }
        Behavior on surface { ColorAnimation { duration: root.anim.large; easing.type: Easing.BezierSpline; easing.bezierCurve: root.anim.standard } }
        Behavior on raised { ColorAnimation { duration: root.anim.large; easing.type: Easing.BezierSpline; easing.bezierCurve: root.anim.standard } }
        Behavior on border { ColorAnimation { duration: root.anim.large; easing.type: Easing.BezierSpline; easing.bezierCurve: root.anim.standard } }
        Behavior on text { ColorAnimation { duration: root.anim.large; easing.type: Easing.BezierSpline; easing.bezierCurve: root.anim.standard } }
        Behavior on textMuted { ColorAnimation { duration: root.anim.large; easing.type: Easing.BezierSpline; easing.bezierCurve: root.anim.standard } }
        Behavior on textFaint { ColorAnimation { duration: root.anim.large; easing.type: Easing.BezierSpline; easing.bezierCurve: root.anim.standard } }
        Behavior on accent { ColorAnimation { duration: root.anim.large; easing.type: Easing.BezierSpline; easing.bezierCurve: root.anim.standard } }
        Behavior on accentText { ColorAnimation { duration: root.anim.large; easing.type: Easing.BezierSpline; easing.bezierCurve: root.anim.standard } }
        Behavior on danger { ColorAnimation { duration: root.anim.large; easing.type: Easing.BezierSpline; easing.bezierCurve: root.anim.standard } }
        Behavior on success { ColorAnimation { duration: root.anim.large; easing.type: Easing.BezierSpline; easing.bezierCurve: root.anim.standard } }
        Behavior on warning { ColorAnimation { duration: root.anim.large; easing.type: Easing.BezierSpline; easing.bezierCurve: root.anim.standard } }
    }

    readonly property FontTokens font: FontTokens {
        sans: root.data.font?.sans ?? "sans-serif"
        mono: root.data.font?.mono ?? "monospace"
        icon: root.data.font?.icon ?? "monospace"
        small: root.data.font?.size?.small ?? 11
        normal: root.data.font?.size?.normal ?? 13
        large: root.data.font?.size?.large ?? 16
        huge: root.data.font?.size?.huge ?? 44
    }

    readonly property RadiusTokens radius: RadiusTokens {
        small: root.data.radius?.small ?? 6
        normal: root.data.radius?.normal ?? 10
        large: root.data.radius?.large ?? 16
    }

    readonly property SpacingTokens spacing: SpacingTokens {
        tiny: root.data.spacing?.tiny ?? 4
        small: root.data.spacing?.small ?? 8
        normal: root.data.spacing?.normal ?? 12
        large: root.data.spacing?.large ?? 20
    }

    // Tokens de movimento do Material 3 (as mesmas curvas do Caelestia). O tema
    // só ajusta a velocidade geral com "animation.scale" (1 = padrão, 0 = sem animação).
    // Use pelos componentes Anim e ColorAnim, não direto.
    readonly property MotionTokens anim: MotionTokens {
        baseScale: Config.animationScale >= 0 ? Config.animationScale : (root.data.animation?.scale ?? 1)
        // No modo leve as animações ficam mais curtas.
        scale: root.lightMode ? Math.min(baseScale, 0.6) : baseScale
    }

    readonly property int barHeight: data.bar?.height ?? 34

    // Modo leve (em tempo de execução, não é salvo): sem transparência e
    // desfoque, e animações mais curtas. Ligado pela feature de energia quando
    // o notebook está na bateria e o usuário pediu.
    property bool lightMode: false

    // Contorno fino nos cartões e painéis. O padrão é sem contorno: os cartões
    // se destacam pelo tom, como no Material 3. O usuário pode ligar (Config).
    readonly property bool outlines: Config.outlines ?? data.surfaces?.outline ?? false

    // Transparência dos painéis: o tema dá o padrão e o usuário pode ajustar
    // (Config.transparencyOverride, pela tela de configurações).
    //   base:   fundo dos painéis (barra, painel superior, launcher, menus)
    //   layers: cartões dentro de um painel
    readonly property TransparencyTokens transparency: TransparencyTokens {
        custom: Config.transparencyOverride ?? {}
        theme: root.data.transparency ?? {}
        enabled: (custom.enabled ?? theme.enabled ?? false) && !root.lightMode
        base: custom.base ?? theme.base ?? 1
        layers: custom.layers ?? theme.layers ?? 1
        customized: Object.keys(custom).length > 0
    }

    // Desfoque atrás dos painéis, feito pelo Hyprland (regra de camada aplicada
    // pelo seletor de temas). Só tem efeito com a transparência ligada. O nível
    // (blurModes): "performance" desfoca só o fundo (xray), "full" tudo o que
    // está atrás, "off" nada.
    readonly property var blurModes: ["performance", "full", "off"]
    readonly property BlurTokens blur: BlurTokens {
        custom: Config.blurOverride ?? {}
        mode: root.modeFrom(custom, root.data.hyprland ?? {})
        enabled: mode !== "off"
        size: custom.size ?? root.data.hyprland?.blurSize ?? 8
        passes: custom.passes ?? root.data.hyprland?.blurPasses ?? 2
        customized: Object.keys(custom).length > 0
    }

    function setTransparency(key: string, value: var): void {
        const next = Object.assign({}, Config.transparencyOverride ?? {});
        next[key] = value;
        Config.transparencyOverride = next;
    }

    function setBlur(key: string, value: var): void {
        const next = Object.assign({}, Config.blurOverride ?? {});
        next[key] = value;
        Config.blurOverride = next;
    }

    // O nível do desfoque: o do usuário (mode; o enabled: false de antes vale
    // "off", sem reescrever o arquivo), o do tema (blurMode; blur: false vale
    // "off") ou "performance". Valor desconhecido é ignorado.
    function modeFrom(custom: var, theme: var): string {
        if (blurModes.includes(custom.mode))
            return custom.mode;
        if (custom.enabled === false)
            return "off";
        if (blurModes.includes(theme.blurMode))
            return theme.blurMode;
        return theme.blur === false ? "off" : "performance";
    }

    // Grava o nível no ajuste do usuário, sem perder size e passes; tira o
    // enabled antigo, que o mode substitui. O nível que o tema já dá não é
    // ajuste: sai do override (e o "Restaurar padrões do tema" não aparece).
    function setBlurMode(mode: string): void {
        if (!blurModes.includes(mode))
            return;
        const next = Object.assign({}, Config.blurOverride ?? {});
        delete next.enabled;
        if (mode === modeFrom({}, data.hyprland ?? {}))
            delete next.mode;
        else
            next.mode = mode;
        Config.blurOverride = Object.keys(next).length ? next : null;
    }

    // Volta transparência e desfoque aos valores do tema.
    function resetGlass(): void {
        Config.transparencyOverride = null;
        Config.blurOverride = null;
    }

    // Cor com a transparência do tema. level 0 = fundo de painel, 1 = cartão.
    // Cartões translúcidos clareiam um pouco (proporcional à transparência)
    // para continuar se destacando do painel sem precisar de contorno.
    // O eixo de peso de uma fonte variável (a Rubik dos temas), que o Qt não
    // tira do font.weight sozinho: `font.variableAxes: ThemeManager.fontAxes(Font.DemiBold)`
    // junto do mesmo `font.weight`. Numa fonte estática, o eixo é ignorado.
    function fontAxes(weight: int): var {
        return { wght: weight };
    }

    function glass(c: color, level: int): color {
        if (!transparency.enabled)
            return c;
        if (level === 0)
            return Qt.rgba(c.r, c.g, c.b, c.a * transparency.base);
        const lift = (1 - transparency.layers) * (dark ? 0.09 : 0.04);
        const t = Qt.tint(c, Qt.rgba(colors.text.r, colors.text.g, colors.text.b, lift));
        return Qt.rgba(t.r, t.g, t.b, c.a * transparency.layers);
    }

    function apply(id: string): void {
        Config.theme = id;
    }

    function token(name: string): color {
        return data.colors?.[name] ?? "#ff00ff";
    }

    // Cor com opacidade, para véus e realces: ThemeManager.alpha(colors.accent, 0.2).
    function alpha(c: color, a: real): color {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    // Luminância relativa (WCAG) de uma cor, de 0 (preto) a 1 (branco).
    function luminance(c: color): real {
        const lin = v => v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
        return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
    }

    // Contraste (WCAG) entre duas cores, de 1 a 21.
    function contrast(a: color, b: color): real {
        const la = luminance(a);
        const lb = luminance(b);
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
    }

    // O texto sobre uma cor cheia (aviso, erro, sucesso): accentText, text
    // ou base, o que der mais contraste com ela (no empate, o primeiro).
    function onColor(c: color): color {
        return [colors.accentText, colors.text, colors.base].reduce((best, x) => contrast(c, x) > contrast(c, best) ? x : best);
    }

    function parse(text: string): var {
        if (!text)
            return {};
        try {
            return JSON.parse(text);
        } catch (e) {
            console.warn("ThemeManager: JSON inválido:", e);
            return {};
        }
    }

    function resolvePath(path: string): string {
        if (!path)
            return "";
        if (path.startsWith("~/"))
            return Quickshell.env("HOME") + path.slice(1);
        if (path.startsWith("/"))
            return path;
        return `${directory}/${path}`;
    }

    // O campo "wallpaper" do tema: um caminho (só a imagem) ou
    // { static, shader }. Caminhos relativos a themes/. A taxa de quadros é do
    // usuário (Config.wallpaperFps), não do tema.
    function normalizeWallpaper(value: var): var {
        if (typeof value === "string" || !value)
            return { static: resolvePath(value ?? ""), shader: "" };
        return { static: resolvePath(value.static ?? ""), shader: resolvePath(value.shader ?? "") };
    }

    // Efeitos animados prontos (themes/shaders/effects.json), usáveis por
    // qualquer tema: as cores vêm do tema que os usa.
    readonly property var effects: parse(effectsFile.text() || "[]").map(e => ({ id: e.id, name: e.name, description: e.description ?? "", shader: resolvePath(e.shader) }))

    // Papel de parede de um tema: o do próprio tema ou o que o usuário escolheu
    // para ele (Config.themeWallpapers[id]):
    //   { kind: "theme-image" }            a imagem do tema, parada
    //   { kind: "effect", effect: "luar" } um efeito animado (nas cores do tema)
    //   { kind: "image", image: "/..." }   uma imagem do usuário
    //   { kind: "video", source }          um vídeo ou GIF do usuário; as versões
    //                                      convertidas, uma por tela, ficam em
    //                                      Config.videoVariants[source]
    // Devolve { static, shader, kind, custom } (e source, no vídeo). Qual
    // versão cada tela toca é decidido pelo wallpaper.
    function wallpaperFor(id: string): var {
        const theme = id === current ? Object.assign({ id }, normalizeWallpaper(data.wallpaper)) : themes.find(t => t.id === id);
        const own = { static: theme?.static ?? theme?.wallpaper ?? "", shader: theme?.shader ?? "" };
        const choice = (Config.themeWallpapers ?? {})[id];
        own.video = "";
        if (!choice)
            return Object.assign(own, { kind: "theme", custom: false });
        if (choice.kind === "video") {
            // Capa: a de qualquer versão pronta; sem nenhuma, a imagem do tema.
            const variants = Object.values((Config.videoVariants ?? {})[choice.source] ?? {});
            return { static: variants[0]?.poster || own.static, shader: "", video: "", kind: choice.kind, source: choice.source, custom: true };
        }
        if (choice.kind === "theme-image")
            return { static: own.static, shader: "", video: "", kind: choice.kind, custom: true };
        if (choice.kind === "effect") {
            const effect = effects.find(e => e.id === choice.effect);
            return { static: own.static, shader: effect?.shader ?? own.shader, video: "", kind: choice.kind, effect: choice.effect, custom: true };
        }
        if (choice.kind === "image")
            return { static: resolvePath(choice.image ?? "") || own.static, shader: "", video: "", kind: choice.kind, image: choice.image, custom: true };
        return Object.assign(own, { kind: "theme", custom: false });
    }

    function rebuildList(): void {
        const list = [];
        for (let i = 0; i < themeFiles.count; i++) {
            const file = themeFiles.objectAt(i) as ThemeFile;
            if (!file?.loaded)
                continue;
            const d = parse(file.text());
            const wp = normalizeWallpaper(d.wallpaper);
            list.push({
                id: file.themeId,
                name: d.name ?? file.themeId,
                description: d.description ?? "",
                dark: d.dark ?? true,
                colors: d.colors ?? {},
                wallpaper: wp.static,
                static: wp.static,
                shader: wp.shader
            });
        }
        list.sort((a, b) => a.id === defaultTheme ? -1 : b.id === defaultTheme ? 1 : a.name.localeCompare(b.name));
        themes = list;
    }

    // Fontes que o tema traz em themes/ (ex.: "fonts/Rubik[wght].ttf"), carregadas
    // sem instalar nada no sistema.
    Instantiator {
        model: root.data.fonts ?? []

        delegate: FontLoader {
            required property string modelData

            source: `file://${root.resolvePath(modelData)}`
        }
    }

    IpcHandler {
        target: "theme"

        function set(id: string): void {
            root.apply(id);
        }

        function get(): string {
            return root.current;
        }

        function list(): string {
            return root.themes.map(t => t.id).join("\n");
        }
    }

    IpcHandler {
        target: "blur"

        function set(mode: string): void {
            root.setBlurMode(mode);
        }

        function get(): string {
            return root.blur.mode;
        }
    }

    FileView {
        id: effectsFile

        path: `${root.directory}/shaders/effects.json`
        printErrors: false
    }

    FileView {
        id: activeFile

        path: `${root.directory}/${root.current}.json`
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoadFailed: {
            console.warn(`ThemeManager: tema "${root.current}" não encontrado, voltando para "${root.defaultTheme}"`);
            if (root.current !== root.defaultTheme)
                Config.theme = root.defaultTheme;
        }
    }

    FolderListModel {
        id: folder

        folder: `file://${root.directory}`
        nameFilters: ["*.json"]
        showDirs: false
    }

    Instantiator {
        id: themeFiles

        model: folder
        onObjectAdded: root.rebuildList()
        onObjectRemoved: root.rebuildList()

        delegate: ThemeFile {
            id: themeFile

            path: themeFile.filePath
            watchChanges: true
            onFileChanged: themeFile.reload()
            onLoaded: root.rebuildList()
        }
    }
}
