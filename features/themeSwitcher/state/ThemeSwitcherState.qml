pragma Singleton

import QtQuick
import Quickshell
import qs.core.carousel
import qs.core.panels
import qs.core.theme
import qs.services

// View model do seletor de temas em carrossel. Ao abrir, guarda o tema
// aplicado (openedWith) e centra a fila nele. Girar (step) aplica o tema do
// card central depois de uma espera, para setas seguidas aplicarem só o
// último; confirm aplica o que faltar (só com a espera correndo) e fecha mantendo; qualquer outro
// fechamento (Esc, clique fora, o atalho de novo, outro painel) volta ao tema
// da abertura. Também mantém as bordas do Hyprland em sintonia com o tema
// ativo, inclusive na inicialização.
Singleton {
    id: root

    readonly property bool open: Panels.isOpen("themes")
    readonly property var screen: Hypr.focusedScreen
    readonly property var themes: ThemeManager.themes

    // O card central (o índice e o id, para reencontrá-lo quando a lista
    // muda) e o tema aplicado quando o seletor abriu.
    property int index: 0
    property string centerId: ""
    property string openedWith: ""
    // A espera está armada: o card central ainda não foi aplicado.
    readonly property bool pending: applyDelay.running
    // Ligado pelo confirm: o fechamento mantém o tema em vez de desfazer.
    property bool keep: false

    // A fila foi centrada ao abrir: a tela começa a cascata de entrada.
    signal opened

    onOpenChanged: {
        if (open)
            begin();
        else
            finish();
    }

    // Uma troca na lista (tema novo em themes/) mantém o mesmo tema no centro;
    // se ele saiu da lista, vale a volta do índice.
    onThemesChanged: {
        const i = themes.findIndex(t => t.id === centerId);
        center(i >= 0 ? i : Carousel.wrap(index, themes.length));
    }

    function center(i: int): void {
        index = i;
        centerId = themes[i]?.id ?? "";
    }

    function begin(): void {
        openedWith = ThemeManager.current;
        center(Math.max(0, themes.findIndex(t => t.id === openedWith)));
        keep = false;
        opened();
    }

    function finish(): void {
        applyDelay.stop();
        if (!keep && openedWith && ThemeManager.current !== openedWith)
            ThemeManager.apply(openedWith);
        keep = false;
    }

    function step(delta: int): void {
        if (!open || !themes.length)
            return;
        center(Carousel.wrap(index + delta, themes.length));
        applyDelay.restart();
    }

    function pick(i: int): void {
        if (!open)
            return;
        if (i === index)
            confirm();
        else
            step(Carousel.offset(i, index, themes.length));
    }

    function flush(): void {
        if (!open)
            return;
        applyDelay.stop();
        const id = themes[index]?.id ?? "";
        if (id && id !== ThemeManager.current)
            ThemeManager.apply(id);
    }

    function confirm(): void {
        if (!open)
            return;
        if (pending)
            flush();
        keep = true;
        Panels.close();
    }

    function cancel(): void {
        if (!open)
            return;
        Panels.close();
    }

    Timer {
        id: applyDelay

        interval: 300
        onTriggered: root.flush()
    }

    // Integração com o Hyprland
    readonly property string hyprlandConfig: Hypr.usingLua ? toLua(ThemeManager.hyprland) : ""
    readonly property string blurRule: Hypr.usingLua ? blurLua(ThemeManager.transparency.enabled && ThemeManager.blur.enabled) : ""
    readonly property string blurConfig: Hypr.usingLua ? `hl.config({ decoration = { blur = { size = ${ThemeManager.blur.size}, passes = ${ThemeManager.blur.passes} } } })` : ""

    onHyprlandConfigChanged: {
        if (hyprlandConfig)
            Hypr.evalLua(hyprlandConfig);
    }

    // Cada layer_rule é acumulada pelo Hyprland; só reenvia quando muda.
    onBlurRuleChanged: {
        if (blurRule)
            Hypr.evalLua(blurRule);
    }

    // Intensidade do desfoque: com atraso, para não mandar um comando por
    // quadro enquanto o usuário arrasta o controle.
    onBlurConfigChanged: blurDelay.restart()

    Timer {
        id: blurDelay

        interval: 120
        onTriggered: {
            if (root.blurConfig)
                Hypr.evalLua(root.blurConfig);
        }
    }

    // Os painéis que saem da moldura não ganham o esmaecer de camada do
    // Hyprland: a forma deles (na janela da barra) e o conteúdo (na janela de
    // cada um) entram juntos, sem a camada inteira começar transparente.
    readonly property string frameRule: Hypr.usingLua ? noAnimLua() : ""

    Component.onCompleted: {
        blurDelay.start();
        if (frameRule)
            Hypr.evalLua(frameRule);
    }

    function noAnimLua(): string {
        return `hl.layer_rule({ match = { namespace = "^lucerna-panel-(bar|dashboard|central|notifications|osd)$" }, no_anim = true })`;
    }

    // Desfoque atrás dos painéis do shell ("lucerna-panel-*"). O ignore_alpha
    // restringe o desfoque aos pixels quase opacos: o véu escuro atrás dos
    // painéis (no máximo 40%) e as sobras transparentes ficam de fora. Por
    // isso a opacidade dos painéis não desce de 50%.
    function blurLua(enabled: bool): string {
        return `hl.layer_rule({ match = { namespace = "^lucerna-panel-.*" }, blur = ${enabled}, ignore_alpha = 0.45 })`;
    }

    function toLua(h: var): string {
        if (!h.activeBorder)
            return "";
        const rgb = hex => `rgb(${String(hex).replace("#", "")})`;
        return `hl.config({ general = { border_size = ${h.borderSize ?? 2}, col = { active_border = "${rgb(h.activeBorder)}", inactive_border = "${rgb(h.inactiveBorder ?? h.activeBorder)}" } }, decoration = { rounding = ${h.rounding ?? 10} } })`;
    }
}
