pragma ComponentBehavior: Bound

import QtQuick
import qs.core.theme
import qs.core.widgets
import qs.features.central.state

// Central: dois painéis flutuantes na direita, sobre a área de trabalho, sem
// escurecer a tela, que abrem e fecham cada um pelo seu estado: as Ações em
// cima (na altura do conteúdo, até deixar o mínimo das Notificações, se elas
// estiverem abertas) e as Notificações embaixo, na altura que sobra; sozinhas,
// elas sobem até perto do topo. Cada painel entra deslizando da
// direita (em cascata, se os dois abrem juntos) e sai mais rápido; as
// Notificações sobem e descem junto com a entrada e a saída das Ações. Esc ou
// o clique fora dos painéis fecham os dois.
OverlayPanel {
    id: panel

    name: "central"
    open: CentralState.open
    screen: CentralState.screen
    dim: 0
    onDismissed: CentralState.close()

    // Distância das bordas da tela e entre os dois painéis.
    readonly property real margin: ThemeManager.spacing.large
    readonly property real gap: ThemeManager.spacing.normal
    // Altura mínima das notificações.
    readonly property real inboxMin: 160
    // Quanto do lugar das Ações (a altura e o vão) as Notificações deixam em
    // cima: 1 com as Ações abertas, 0 sem elas. Muda só com as Notificações
    // abertas: na saída delas, ficam onde estavam.
    property real reserve: 1

    onOpenChanged: {
        if (open)
            focusSink.forceActiveFocus();
    }

    // Os dois sub-estados mudam juntos numa chamada só (o atalho geral, o IPC
    // central): a decisão espera o fim dela, para a cascata valer só quando os
    // dois abrem juntos.
    Connections {
        target: CentralState

        function onActionsOpenChanged() {
            Qt.callLater(panel.sync);
        }

        function onNotificationsOpenChanged() {
            Qt.callLater(panel.sync);
        }
    }

    function sync(): void {
        const both = CentralState.actionsOpen && !actions.wanted && CentralState.notificationsOpen && !inbox.wanted;
        if (CentralState.notificationsOpen) {
            const target = CentralState.actionsOpen ? 1 : 0;
            if (inbox.wanted) {
                // No passo das Ações: a mola da entrada, a aceleração da saída.
                reserveAnim.type = target ? Anim.Spatial : Anim.StandardAccel;
                reserveAnim.to = target;
                reserveAnim.restart();
            } else {
                reserveAnim.stop();
                reserve = target;
            }
        }
        if (CentralState.actionsOpen && !actions.wanted)
            actions.enter(both);
        else if (!CentralState.actionsOpen && actions.wanted) {
            actions.leave();
            // O campo focado (a senha do Wi-Fi) some com as Ações: o Esc volta para cá.
            focusSink.forceActiveFocus();
        }
        if (CentralState.notificationsOpen && !inbox.wanted)
            inbox.enter(both);
        else if (!CentralState.notificationsOpen && inbox.wanted)
            inbox.leave();
    }

    Anim {
        id: reserveAnim

        target: panel
        property: "reserve"
    }

    // Fica com o teclado ao abrir: o Esc sobe dele até o OverlayPanel. Sem
    // tamanho, não segura o clique fora.
    Item {
        id: focusSink
    }

    // Por cima das Notificações: na saída das Ações, elas sobem por baixo.
    ActionsPanel {
        id: actions

        z: 1
        order: 0
        margin: panel.margin
        areaWidth: panel.width
        y: CentralState.top
        maxHeight: Math.max(0, panel.height - y - panel.margin - (CentralState.notificationsOpen ? panel.gap + panel.inboxMin : 0))
    }

    InboxPanel {
        id: inbox

        order: 1
        margin: panel.margin
        areaWidth: panel.width
        y: CentralState.top + panel.reserve * (actions.height + panel.gap)
        height: Math.max(0, panel.height - y - panel.margin)
    }
}
