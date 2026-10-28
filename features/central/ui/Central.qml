pragma ComponentBehavior: Bound

import QtQuick
import qs.core.frame
import qs.core.theme
import qs.core.widgets
import qs.features.central.state

// Central, dentro da janela da forma de um monitor (ver
// core/widgets/FrameWindow), em coordenadas da tela: um bloco só que sai da
// borda direita da moldura, como a sidebar do Caelestia, sobre a área de
// trabalho e sem escurecer a tela. Dentro dele, dois painéis que abrem e
// fecham cada um pelo seu estado, só na tela da central: as Ações em cima (na
// altura do conteúdo, até deixar o mínimo das Notificações, se elas estiverem
// abertas) e as Notificações embaixo, na altura que sobra, até a moldura de
// baixo; sozinhas, elas sobem até a de cima. Cada painel desliza da direita
// para a esquerda com o fundo desde o 1º quadro e sai pelo mesmo caminho, com
// a mesma mola; os dois abrindo ou fechando juntos (o atalho geral) andam no
// mesmo passo, como uma peça só, já na altura toda. As Notificações sobem e
// descem junto com a entrada e a saída das Ações. O fundo do bloco é um pedaço
// da forma da tela (Frame), do tamanho dos painéis à mostra. Só com as Ações
// já à mostra (e ficando), as Notificações crescem para baixo a partir delas
// ao entrar (e encolhem até elas ao sair): o bloco não pula de altura num
// quadro. A pílula fundida continua clicável (fora das áreas de entrada da
// central). Esc fecha os dois; o clique fora fecha pelo grab (ver Panels).
Item {
    id: panel

    required property var screen
    readonly property bool here: CentralState.screen === screen
    readonly property bool open: CentralState.open && here
    // A central traz a moldura: os painéis esperam a janela da forma chegar
    // à tela inteira (Frame.readyOn) para começar a mola.
    readonly property bool ready: Frame.readyOn(screen, Frame.sizeOn(screen).width)
    // Os pedidos de cada painel, só na tela da central.
    readonly property bool actionsWanted: CentralState.actionsOpen && here && ready
    readonly property bool inboxWanted: CentralState.notificationsOpen && here && ready

    anchors.fill: parent

    // Distância da borda direita e da de baixo (a moldura) e entre os dois painéis.
    readonly property real margin: Frame.thickness
    readonly property real gap: ThemeManager.spacing.normal
    // Altura mínima das notificações.
    readonly property real inboxMin: 160
    // Quanto do lugar das Ações (a altura e o vão) as Notificações deixam em
    // cima: 1 com as Ações abertas, 0 sem elas. Muda só com as Notificações
    // abertas: na saída delas, ficam onde estavam.
    property real reserve: 1
    // As Notificações entram ou saem sozinhas, com as Ações à mostra e
    // ficando: crescem a partir delas (e encolhem até elas). Com as duas
    // juntas, não: o bloco desliza já na altura toda.
    property bool inboxGrows: false

    onOpenChanged: {
        if (open)
            focusSink.forceActiveFocus();
    }

    // Os dois sub-estados mudam juntos numa chamada só (o atalho geral, o IPC
    // central): a decisão espera o fim dela, para os dois andarem juntos só
    // quando mudam juntos. A tela da central também conta: trocar de tela é
    // fechar numa e abrir na outra.
    onActionsWantedChanged: Qt.callLater(panel.sync)
    onInboxWantedChanged: Qt.callLater(panel.sync)

    function sync(): void {
        // As Ações já pedidas e ficando, antes de a decisão delas mudar o `wanted`.
        const actionsStay = actionsWanted && actions.wanted;
        if (inboxWanted) {
            const target = actionsWanted ? 1 : 0;
            if (inbox.wanted) {
                // No passo das Ações, com a mesma mola nos dois sentidos.
                reserveAnim.to = target;
                reserveAnim.restart();
            } else {
                reserveAnim.stop();
                reserve = target;
            }
        }
        if (actionsWanted && !actions.wanted)
            actions.enter();
        else if (!actionsWanted && actions.wanted) {
            actions.leave();
            // O campo focado (a senha do Wi-Fi) some com as Ações: o Esc volta para cá.
            if (open)
                focusSink.forceActiveFocus();
        }
        if (inboxWanted && !inbox.wanted) {
            inboxGrows = actionsStay;
            inbox.enter();
        } else if (!inboxWanted && inbox.wanted) {
            // Fechando no meio do crescimento, encolhe dali (sem pulo de altura).
            inboxGrows = actionsStay || (inboxGrows && inbox.shown < 1);
            inbox.leave();
        }
    }

    Anim {
        id: reserveAnim

        target: panel
        property: "reserve"
        type: Anim.Spatial
    }

    // Fica com o teclado ao abrir. Sem tamanho, não segura o clique.
    Item {
        id: focusSink
    }

    // O Esc do focusSink e dos campos dos painéis (a senha do Wi-Fi) sobe até aqui.
    Keys.onEscapePressed: CentralState.close()

    // O bloco: dos painéis à mostra até a borda direita. Encostado na moldura
    // de cima (e na de baixo, com as Notificações até o fim), fica preso a ela
    // também: o canto vira a junção côncava da forma, não um canto próprio.
    readonly property var parts: [actions, inbox].filter(c => c.visible)

    FrameBlob {
        screen: panel.screen
        framed: true
        open: panel.open
        progress: Math.max(actions.shown, inbox.shown)
        rect: {
            const parts = panel.parts;
            if (!parts.length)
                return Qt.rect(0, 0, 0, 0);
            const x = Math.min(...parts.map(c => c.x));
            const top = Math.min(...parts.map(c => c.y));
            const bottom = Math.max(...parts.map(c => c.y + c.shownHeight));
            const edge = (top <= CentralState.top + 0.5 ? "top-" : "") + Frame.edges.central + (bottom >= panel.height - panel.margin - 0.5 ? "-bottom" : "");
            return Frame.attach(Qt.rect(x, top, panel.width - x, bottom - top), edge);
        }
    }

    // Cada painel à mostra recebe o mouse e, com a central aberta, o teclado;
    // fechando, o teclado volta logo para a janela de baixo.
    FrameInput {
        screen: panel.screen
        active: actions.visible
        rect: Qt.rect(actions.x, actions.y, actions.width, actions.shownHeight)
        keyboard: panel.open
    }

    FrameInput {
        screen: panel.screen
        active: inbox.visible
        rect: Qt.rect(inbox.x, inbox.y, inbox.width, inbox.shownHeight)
        keyboard: panel.open
    }

    // Por cima das Notificações: na saída das Ações, elas sobem por baixo.
    ActionsPanel {
        id: actions

        z: 1
        margin: panel.margin
        areaWidth: panel.width
        y: CentralState.top
        // Com as Notificações saindo junto, o limite fica até elas sumirem: a
        // altura não muda na saída.
        maxHeight: Math.max(0, panel.height - y - panel.margin - (panel.inboxWanted || inbox.visible ? panel.gap + panel.inboxMin : 0))
    }

    InboxPanel {
        id: inbox

        margin: panel.margin
        areaWidth: panel.width
        y: CentralState.top + Math.max(0, panel.reserve) * (actions.height + panel.gap)
        height: Math.max(0, panel.height - y - panel.margin)
        // Entrando ou saindo sozinha abaixo das Ações, cresce a partir delas
        // junto com a mola (cortada em 1); senão, já na altura toda.
        reveal: panel.inboxGrows ? Math.min(1, Math.max(0, shown)) : 1
    }
}
