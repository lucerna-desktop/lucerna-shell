pragma Singleton

import QtQuick
import Quickshell
import qs.core.carousel
import qs.core.config
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
    readonly property string blurRule: Hypr.usingLua ? blurLua(ThemeManager.blur.mode, ThemeManager.transparency.enabled) : ""
    readonly property string blurConfig: Hypr.usingLua ? blurConfigLua(ThemeManager.blur.size, ThemeManager.blur.passes) : ""
    // Janelas sem desfoque (Config.blurWindows desligado): uma regra de janela.
    readonly property string windowRule: Hypr.usingLua && !Config.blurWindows ? windowBlurLua() : ""
    // A regra de janela já foi enviada: religar precisa do reload.
    property bool windowRuleSent: false

    onHyprlandConfigChanged: {
        if (hyprlandConfig)
            Hypr.evalLua(hyprlandConfig);
    }

    // Cada layer_rule é acumulada pelo Hyprland; só reenvia quando muda.
    onBlurRuleChanged: {
        if (blurRule)
            Hypr.evalLua(blurRule);
    }

    // Desligar envia a regra. Religar não manda a regra contrária (desfaria um
    // no_blur do próprio usuário): recarrega a config do Hyprland, que apaga a
    // regra, e o reapply() manda de volta o que é do shell.
    onWindowRuleChanged: {
        const action = windowRuleAction(windowRule, windowRuleSent);
        if (action === "eval")
            Hypr.evalLua(windowRule);
        else if (action === "reload")
            Hypr.reloadConfig();
        windowRuleSent = windowRule !== "";
    }

    // O que fazer quando a regra de janela muda: "eval" (mandar a regra),
    // "reload" (ela saiu depois de enviada) ou "" (nada).
    function windowRuleAction(rule: string, sent: bool): string {
        if (rule)
            return "eval";
        return sent ? "reload" : "";
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

    // Os painéis que saem da moldura ("lucerna-frame-*") e a barra, que desenha
    // a forma deles, não ganham o esmaecer de camada do Hyprland: a forma e o
    // conteúdo entram juntos, sem a camada inteira começar transparente.
    readonly property string frameRule: Hypr.usingLua ? noAnimLua() : ""

    Component.onCompleted: {
        blurDelay.start();
        if (frameRule)
            Hypr.evalLua(frameRule);
        if (windowRule) {
            Hypr.evalLua(windowRule);
            windowRuleSent = true;
        }
    }

    // Um `hyprctl reload` apaga as regras de camada e a config aplicadas por
    // cima do hyprland.lua: manda tudo de novo.
    Connections {
        target: Hypr

        function onConfigReloaded() {
            root.reapply();
        }
    }

    function reapply(): void {
        for (const lua of rules(Hypr.usingLua))
            Hypr.evalLua(lua);
    }

    // O que o shell aplica por cima do hyprland.lua (e reaplica depois de um
    // reload). Sem a config em Lua, nada.
    function rules(lua: bool): var {
        if (!lua)
            return [];
        const list = [toLua(ThemeManager.hyprland), blurLua(ThemeManager.blur.mode, ThemeManager.transparency.enabled), blurConfigLua(ThemeManager.blur.size, ThemeManager.blur.passes), noAnimLua()];
        if (!Config.blurWindows)
            list.push(windowBlurLua());
        return list.filter(x => x);
    }

    function noAnimLua(): string {
        return `hl.layer_rule({ match = { namespace = "^lucerna-(panel-bar|frame-.*)$" }, no_anim = true })`;
    }

    // Desfoque atrás dos painéis do shell ("lucerna-panel-*"), pelo nível
    // (ThemeManager.blurModes) e só com a transparência ligada. O ignore_alpha
    // restringe o desfoque aos pixels quase opacos: o véu escuro atrás dos
    // painéis (no máximo 40%) e as sobras transparentes ficam de fora. Por
    // isso a opacidade dos painéis não desce de 50%. No nível "performance", o
    // xray: a camada desfoca só o fundo (papel de parede e camadas de baixo),
    // que o Hyprland guarda e reaproveita, em vez das janelas atrás dela.
    function blurLua(mode: string, transparency: bool): string {
        return `hl.layer_rule({ match = { namespace = "^lucerna-panel-.*" }, blur = ${transparency && mode !== "off"}, xray = ${mode === "performance"}, ignore_alpha = 0.45 })`;
    }

    // Intensidade do desfoque, com o que não custa nada na aparência: vfr (no
    // 0.56 é debug:vfr), as otimizações do desfoque e nada de desfoque nos
    // popups. Nunca mexe no decoration.blur.enabled: isso mataria também o
    // desfoque das camadas.
    function blurConfigLua(size: int, passes: int): string {
        return `hl.config({ debug = { vfr = true }, decoration = { blur = { size = ${size}, passes = ${passes}, new_optimizations = true, popups = false } } })`;
    }

    // Janelas sem desfoque. Só no_blur = true: o contrário apagaria um no_blur
    // que o usuário tenha na config dele.
    function windowBlurLua(): string {
        return `hl.window_rule({ match = { class = ".*" }, no_blur = true })`;
    }

    function toLua(h: var): string {
        if (!h.activeBorder)
            return "";
        const rgb = hex => `rgb(${String(hex).replace("#", "")})`;
        return `hl.config({ general = { border_size = ${h.borderSize ?? 2}, col = { active_border = "${rgb(h.activeBorder)}", inactive_border = "${rgb(h.inactiveBorder ?? h.activeBorder)}" } }, decoration = { rounding = ${h.rounding ?? 10} } })`;
    }
}
