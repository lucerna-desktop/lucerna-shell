import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core.frame
import qs.core.theme
import qs.core.widgets
import qs.features.notifications.state

// Popups no canto superior direito do monitor com foco, num bloco que sai do
// canto (preso às bordas de cima e da direita, com os arcos côncavos na
// junção). O fundo do bloco é um pedaço da forma da tela (Frame); a altura dele
// segue a dos cartões, com mola, e os cartões entram depois dele. Os cartões
// entram e saem deslizando pela direita; os de baixo se reacomodam com mola.
// Com a central aberta, ficam escondidos: a lista dela mostra os mesmos.
//
// A janela ocupa a coluna inteira, mas só a área dos cartões recebe cliques
// (máscara), e ela só existe enquanto há popups (mais o tempo da animação de
// saída do último).
PanelWindow {
    id: window

    readonly property bool hasPopups: NotificationsState.popups.length > 0
    readonly property bool wanted: hasPopups && !NotificationsState.popupsHidden
    // Do conteúdo até a beira do bloco; à esquerda, mais a folga do arco côncavo.
    readonly property real pad: ThemeManager.spacing.normal
    readonly property real flare: Frame.smoothing
    readonly property real cardWidth: 380
    // A altura do bloco: a dos cartões, com mola; some quando não há popups.
    property real blockHeight: wanted ? list.contentHeight + pad * 2 : 0
    readonly property real target: list.contentHeight + pad * 2

    Behavior on blockHeight {
        Anim {
            type: window.wanted ? Anim.Spatial : Anim.EmphasizedAccel
        }
    }

    onHasPopupsChanged: {
        if (!hasPopups)
            linger.restart();
    }

    Timer {
        id: linger

        interval: 600
    }

    visible: (hasPopups || linger.running || blockHeight > 0) && !NotificationsState.popupsHidden && Frame.isReady(NotificationsState.screen)
    screen: NotificationsState.screen
    anchors {
        top: true
        right: true
        bottom: true
    }
    implicitWidth: cardWidth + pad * 2 + flare + Frame.thickness
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    mask: Region {
        item: list.contentItem
    }
    WlrLayershell.layer: WlrLayer.Overlay
    // Sem o desfoque: o fundo é a forma, na janela da barra (ver OverlayPanel).
    WlrLayershell.namespace: "lucerna-frame-notifications"

    // O bloco, em coordenadas da tela (a janela fica na beira direita).
    FrameBlob {
        screen: NotificationsState.screen
        open: window.wanted
        progress: window.blockHeight / Math.max(1, window.target)
        rect: {
            const x = (NotificationsState.screen?.width ?? window.width) - window.width + window.flare;
            return Frame.attach(Qt.rect(x, 0, window.width - window.flare, Math.max(0, window.blockHeight)), Frame.edges.notifications);
        }
    }

    ListView {
        id: list

        anchors.fill: parent
        anchors.topMargin: window.pad + Frame.thickness
        anchors.rightMargin: window.pad + Frame.thickness
        anchors.leftMargin: window.pad + window.flare
        spacing: ThemeManager.spacing.small
        interactive: false
        // Os cartões entram depois do bloco.
        opacity: Frame.contentOpacity(window.blockHeight / Math.max(1, window.target))

        model: ScriptModel {
            values: NotificationsState.popups
        }

        delegate: NotificationCard {
            required property var modelData

            width: ListView.view.width
            notification: modelData
            popup: true
            // Dentro do bloco: cartão sobre painel.
            level: 1
            timeText: NotificationsState.timeLabel(modelData)
            timeout: NotificationsState.timeoutFor(modelData)
            // Com a central aberta a janela some, mas o prazo não corre.
            held: NotificationsState.popupsHidden
            onExpired: NotificationsState.hidePopup(modelData)
            onDismissRequested: NotificationsState.dismiss(modelData)
            onActionInvoked: action => NotificationsState.invoke(modelData, action)
        }

        add: Transition {
            ParallelAnimation {
                Anim { property: "x"; from: 64; to: 0; type: Anim.Spatial }
                Anim { property: "opacity"; from: 0; to: 1; type: Anim.Effects }
            }
        }

        remove: Transition {
            ParallelAnimation {
                Anim { property: "x"; to: 96; type: Anim.EmphasizedAccel }
                Anim { property: "opacity"; to: 0; type: Anim.EmphasizedAccel }
            }
        }

        displaced: Transition {
            Anim { properties: "x,y"; type: Anim.Spatial }
            Anim { property: "opacity"; to: 1; type: Anim.Effects }
        }
    }
}
