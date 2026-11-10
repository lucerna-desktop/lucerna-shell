pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs.core.config

// Único ponto de verdade do visual. Carrega o tema ativo de themes/<id>.json
// e expõe os tokens; nenhum componente usa cor ou tamanho fixo (as medidas
// passam pela escala interna, px). Cada grupo de tokens tem um tipo declarado
// (ColorTokens, FontTokens...), para o qmllint conhecer
// ThemeManager.colors.accent e os outros; os valores vêm nas instâncias, logo
// abaixo das declarações.
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
        property color accentContainer
        property color onAccentContainer
        property color accentIcon
        property color accentFill
        property color mutedFill
        property color fillIcon
        property color mutedFillIcon
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

    // A escala interna do shell: o tamanho escolhido pelo usuário (Config.shellScale)
    // e, no modo "Escala pelos apps" (o monitor fica em 1), também a escala
    // dos apps. Toda medida do shell passa por px(): os tokens daqui já vêm
    // multiplicados, e as medidas próprias de um componente usam
    // ThemeManager.px(n). Não usa o QT_SCALE_FACTOR: o texto e as bordas
    // continuam no pixel lógico inteiro. Fica entre 0,5 e 3 (clampScale): um
    // shellScale 0 ou negativo num config.json editado à mão zeraria todas as
    // medidas, até o campo de senha da tela de bloqueio.
    readonly property real scale: clampScale(Config.shellScale * (Config.scaleMode === "apps" ? Config.appsScale : 1))

    // A escala dentro de [0,5, 3]; um valor que não é número vira 1.
    function clampScale(n: real): real {
        return Number.isFinite(n) ? Math.min(3, Math.max(0.5, n)) : 1;
    }

    readonly property var data: parse(activeFile.text())
    readonly property bool dark: data.dark ?? true
    // Logo do Lucerna na versão que se lê sobre o tema: estrela clara no escuro, escura no claro.
    readonly property string logo: `file://${Quickshell.shellPath(dark ? "themes/logo.svg" : "themes/logo-claro.svg")}`
    // Papel de parede do tema ativo, já com a escolha do usuário (wallpaperFor).
    readonly property var activeWallpaper: wallpaperFor(current)
    readonly property string wallpaper: activeWallpaper.static
    readonly property string wallpaperShader: activeWallpaper.shader
    readonly property var hyprland: data.hyprland ?? ({})

    // As cores derivadas do tema ativo, calculadas das cores de destino (não
    // das animadas): a troca de tema anima o resultado, sem refazer a conta a
    // cada quadro.
    readonly property var derived: derivedColors(data)

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
        // Os derivados (derivedColors): trilho, contêiner do destaque e
        // preenchimento das barras.
        track: root.derived.track
        accentContainer: root.derived.accentContainer
        onAccentContainer: root.derived.onAccentContainer
        accentIcon: root.derived.accentIcon
        accentFill: root.derived.accentFill
        // A barra de porcentagem (levelColorsOf): o preenchimento do mudo e o
        // ícone sobre a parte cheia, normal e no mudo.
        mutedFill: root.derived.mutedFill
        fillIcon: root.derived.fillIcon
        mutedFillIcon: root.derived.mutedFillIcon

        Behavior on track { ColorAnimation { duration: root.anim.large; easing.type: Easing.BezierSpline; easing.bezierCurve: root.anim.standard } }
        Behavior on accentContainer { ColorAnimation { duration: root.anim.large; easing.type: Easing.BezierSpline; easing.bezierCurve: root.anim.standard } }
        Behavior on onAccentContainer { ColorAnimation { duration: root.anim.large; easing.type: Easing.BezierSpline; easing.bezierCurve: root.anim.standard } }
        Behavior on accentIcon { ColorAnimation { duration: root.anim.large; easing.type: Easing.BezierSpline; easing.bezierCurve: root.anim.standard } }
        Behavior on accentFill { ColorAnimation { duration: root.anim.large; easing.type: Easing.BezierSpline; easing.bezierCurve: root.anim.standard } }
        Behavior on mutedFill { ColorAnimation { duration: root.anim.large; easing.type: Easing.BezierSpline; easing.bezierCurve: root.anim.standard } }
        Behavior on fillIcon { ColorAnimation { duration: root.anim.large; easing.type: Easing.BezierSpline; easing.bezierCurve: root.anim.standard } }
        Behavior on mutedFillIcon { ColorAnimation { duration: root.anim.large; easing.type: Easing.BezierSpline; easing.bezierCurve: root.anim.standard } }

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
        small: root.px(root.data.font?.size?.small ?? 11)
        normal: root.px(root.data.font?.size?.normal ?? 13)
        large: root.px(root.data.font?.size?.large ?? 16)
        huge: root.px(root.data.font?.size?.huge ?? 44)
    }

    readonly property RadiusTokens radius: RadiusTokens {
        small: root.px(root.data.radius?.small ?? 6)
        normal: root.px(root.data.radius?.normal ?? 10)
        large: root.px(root.data.radius?.large ?? 16)
    }

    readonly property SpacingTokens spacing: SpacingTokens {
        tiny: root.px(root.data.spacing?.tiny ?? 4)
        small: root.px(root.data.spacing?.small ?? 8)
        normal: root.px(root.data.spacing?.normal ?? 12)
        large: root.px(root.data.spacing?.large ?? 20)
    }

    // Tokens de movimento do Material 3 (as mesmas curvas do Caelestia). O tema
    // só ajusta a velocidade geral com "animation.scale" (1 = padrão, 0 = sem animação).
    // Use pelos componentes Anim e ColorAnim, não direto.
    readonly property MotionTokens anim: MotionTokens {
        baseScale: Config.animationScale >= 0 ? Config.animationScale : (root.data.animation?.scale ?? 1)
        // No modo leve as animações ficam mais curtas.
        scale: root.lightMode ? Math.min(baseScale, 0.6) : baseScale
    }

    readonly property int barHeight: px(data.bar?.height ?? 34)

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

    // Uma medida do shell (em pixels lógicos na escala 1) na escala interna,
    // arredondada ao pixel lógico inteiro (0 fica 0; 1 fica 1 abaixo de 1,5).
    function px(v: real): int {
        return Math.round(v * scale);
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

    // Mistura duas cores; t é o peso de b (0 dá a, 1 dá b). Cada canal sai
    // arredondado para 8 bits, como a tela desenha: o contraste medido sobre o
    // resultado é o que se vê (sem isso, 4,5:1 em ponto flutuante vira 4,48:1
    // no #rrggbb).
    function mix(a: color, b: color, t: real): color {
        const m = (x, y) => Math.round((x + (y - x) * t) * 255) / 255;
        return Qt.rgba(m(a.r, b.r), m(a.g, b.g), m(a.b, b.b), m(a.a, b.a));
    }

    // O tom de contêiner de uma cor cheia (destaque, aviso, erro, sucesso): o
    // fundo das superfícies grandes ativas, com o texto do tema por cima. É a
    // cor misturada ao base (no escuro, um tom escuro da cor; no claro, um tom
    // claro tingido), com o máximo de cor que ainda deixa o texto a 4,5:1:
    // parte de 60% da cor no escuro e 50% no claro e desce de 1 em 1% rumo ao
    // base. Sem mistura que passe, o próprio base.
    function containerOf(c: color, base: color, text: color, dark: bool): color {
        for (let i = dark ? 60 : 50; i > 0; i--) {
            const r = mix(base, c, i / 100);
            if (contrast(text, r) >= 4.5)
                return r;
        }
        return base;
    }

    // O texto sobre um contêiner: o texto do tema, se passa de 4,5:1; senão, o
    // que der mais contraste entre ele, o base, o preto e o branco.
    function onContainerOf(bg: color, text: color, base: color): color {
        if (contrast(text, bg) >= 4.5)
            return text;
        return [text, base, Qt.rgba(0, 0, 0, 1), Qt.rgba(1, 1, 1, 1)].reduce((best, x) => contrast(bg, x) > contrast(bg, best) ? x : best);
    }

    // Os atalhos com o tema ativo, para as cores de estado:
    // ThemeManager.container(colors.danger) e onContainer(colors.danger).
    function container(c: color): color {
        return containerOf(c, colors.base, colors.text, dark);
    }

    function onContainer(c: color): color {
        return onContainerOf(container(c), colors.text, colors.base);
    }

    // A cor c levada rumo a cada extremo de `aways` (o preto ou o branco), de
    // 5 em 5% e intercalando os extremos a cada passo, até ficar a 3:1 de bg:
    // a primeira mistura que passa (a própria c, se já passa). Nenhuma: null.
    // A base do iconOn, do fillOf e do nearestOn.
    function towardContrast(c: color, bg: color, aways: var): var {
        for (let i = 0; i <= 20; i++) {
            for (const away of aways) {
                const f = i === 0 ? c : mix(c, away, i / 20);
                if (contrast(f, bg) >= 3)
                    return f;
            }
        }
        return null;
    }

    // Um ícone (ou uma marca sem texto) na cor c sobre o fundo bg, a 3:1 dele:
    // a cor pura, se passa; senão, clareada (tema escuro) ou escurecida (claro)
    // de 5 em 5% até passar. Se nem o branco (ou o preto) passa, o outro lado,
    // que chega lá: o melhor entre preto e branco dá pelo menos ~4,6:1.
    function iconOn(c: color, bg: color, dark: bool): color {
        const black = Qt.rgba(0, 0, 0, 1);
        const white = Qt.rgba(1, 1, 1, 1);
        const [first, second] = dark ? [white, black] : [black, white];
        return towardContrast(c, bg, [first]) ?? towardContrast(c, bg, [second]) ?? c;
    }

    // Um ícone na cor c sobre bg, a 3:1 dele, com o mínimo de mistura: a cada
    // passo de 5% tenta os dois extremos (primeiro o que contrasta mais com
    // bg). Para fundos de luminância média (o preenchimento cinza do mudo),
    // onde o iconOn clarearia o vermelho até quase o branco: aqui ele só
    // escurece o bastante e continua vermelho.
    function nearestOn(c: color, bg: color): color {
        const black = Qt.rgba(0, 0, 0, 1);
        const white = Qt.rgba(1, 1, 1, 1);
        const aways = contrast(black, bg) >= contrast(white, bg) ? [black, white] : [white, black];
        return towardContrast(c, bg, aways) ?? aways[0];
    }

    // O ícone de uma cor de estado sobre o contêiner dela, com o tema ativo:
    // ThemeManager.containerIcon(colors.danger).
    function containerIcon(c: color): color {
        return iconOn(c, container(c), dark);
    }

    // O preenchimento de uma barra: a cor levemente misturada ao surface (15%),
    // a 3:1 do trilho para a barra se ler. Se a mistura não passa, a cor pura;
    // se nem ela passa, a cor afastada do trilho rumo ao preto ou ao branco (o
    // que contrastar mais com ele) de 5 em 5% até passar. O extremo sempre
    // passa: o melhor entre preto e branco dá pelo menos ~4,6:1 com qualquer
    // trilho.
    function fillOf(accent: color, surface: color, track: color): color {
        const soft = mix(accent, surface, 0.15);
        if (contrast(soft, track) >= 3)
            return soft;
        const black = Qt.rgba(0, 0, 0, 1);
        const white = Qt.rgba(1, 1, 1, 1);
        const away = contrast(black, track) > contrast(white, track) ? black : white;
        return towardContrast(accent, track, [away]) ?? away;
    }

    // As cores da barra de porcentagem (LevelSlider) além do trilho e do
    // preenchimento: o preenchimento do mudo (o textFaint a 3:1 do trilho, um
    // cinza) e o ícone dentro da barra, que fica sempre sobre a parte cheia
    // (ela nunca é menor que o círculo da ponta), a 3:1 dela. Com valor
    // normal, o base ou o texto (o que contrastar mais com o preenchimento);
    // no mudo, o perigo sobre o cinza pelo nearestOn (o iconOn o levaria
    // quase ao branco em vários temas escuros).
    function levelColorsOf(c: var, track: color, fill: color, dark: bool): var {
        const mutedFill = c.mutedFill ?? fillOf(c.textFaint, c.surface, track);
        const ink = contrast(c.base, fill) >= contrast(c.text, fill) ? c.base : c.text;
        return {
            mutedFill: mutedFill,
            fillIcon: c.fillIcon ?? iconOn(ink, fill, dark),
            mutedFillIcon: c.mutedFillIcon ?? nearestOn(c.danger, mutedFill)
        };
    }

    // As cores derivadas de um tema (o data dele): o trilho e os tokens do
    // contêiner (fundo, texto e ícone) e do preenchimento. Cada um pode vir do JSON (colors.track,
    // colors.accentContainer...); sem ele, calculado. O trilho calculado é o
    // raised no escuro e o border no claro (onde o raised some sobre o cartão).
    function derivedColors(d: var): var {
        const own = d.colors ?? {};
        const dark = d.dark ?? true;
        const get = name => own[name] ?? "#ff00ff";
        const track = own.track ?? get(dark ? "raised" : "border");
        const accentContainer = own.accentContainer ?? containerOf(get("accent"), get("base"), get("text"), dark);
        const accentFill = own.accentFill ?? fillOf(get("accent"), get("surface"), track);
        const named = ["base", "surface", "text", "textFaint", "danger"].reduce((o, k) => Object.assign(o, { [k]: get(k) }), {});
        const level = levelColorsOf(Object.assign({}, own, named), track, accentFill, dark);
        return Object.assign({
            track: track,
            accentContainer: accentContainer,
            onAccentContainer: own.onAccentContainer ?? onContainerOf(accentContainer, get("text"), get("base")),
            accentIcon: own.accentIcon ?? iconOn(get("accent"), accentContainer, dark),
            accentFill: accentFill
        }, level);
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
