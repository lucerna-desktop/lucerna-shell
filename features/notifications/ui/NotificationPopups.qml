import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core.frame
import qs.core.theme
import qs.core.widgets
import qs.features.notifications.state

// Popups no canto superior direito do monitor com foco. Entram e saem
// deslizando pela direita; os de baixo se reacomodam com mola.
//
// A janela ocupa a coluna inteira, mas só a área dos cartões recebe cliques
// (máscara), e ela só existe enquanto há popups (mais o tempo da animação de
// saída do último). O resumo do modo jogo é um cartão próprio no topo da
// pilha, que abre as notificações no clique.
PanelWindow {
    id: window

    readonly property bool hasPopups: NotificationsState.popups.length > 0 || NotificationsState.summary !== null

    onHasPopupsChanged: {
        if (!hasPopups)
            linger.restart();
    }

    Timer {
        id: linger

        interval: 600
    }

    visible: (hasPopups || linger.running) && !NotificationsState.popupsHidden
    screen: NotificationsState.screen
    anchors {
        top: true
        right: true
        bottom: true
    }
    // Fora da moldura: a espessura dela e o espaço de sempre, que deixam o
    // cartão fora do arco do canto (Frame.cornerClear), à mostra ou não.
    // Falso positivo do qmllint com o grupo margins do PanelWindow (ver o spec do CI).
    margins.top: Frame.thickness + ThemeManager.spacing.small // qmllint disable unqualified missing-property
    margins.right: Frame.thickness + ThemeManager.spacing.small // qmllint disable unqualified missing-property
    implicitWidth: 380
    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    mask: Region {
        item: list.contentItem
    }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "lucerna-panel-notifications"

    ListView {
        id: list

        anchors.fill: parent
        spacing: ThemeManager.spacing.small
        interactive: false

        // O cabeçalho fica dentro do contentItem: a máscara já o inclui.
        header: Item {
            width: ListView.view.width
            height: NotificationsState.summary ? summaryCard.height + ThemeManager.spacing.small : 0
            visible: NotificationsState.summary !== null

            Surface {
                id: summaryCard

                width: parent.width
                level: 0
                implicitHeight: summaryRow.implicitHeight + ThemeManager.spacing.normal * 2
                radius: ThemeManager.radius.normal
                border.color: ThemeManager.colors.border
                border.width: ThemeManager.outlines ? 1 : 0

                Clickable {
                    anchors.fill: parent
                    radius: parent.radius
                    onClicked: NotificationsState.openSummary()
                }

                Row {
                    id: summaryRow

                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        margins: ThemeManager.spacing.normal
                    }
                    spacing: ThemeManager.spacing.normal

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "sports_esports"
                        size: 22
                        color: ThemeManager.colors.accent
                    }

                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 22 - ThemeManager.spacing.normal
                        text: NotificationsState.summaryText
                        wrapMode: Text.Wrap
                    }
                }
            }
        }

        model: ScriptModel {
            values: NotificationsState.popups
        }

        delegate: NotificationCard {
            required property var modelData

            width: ListView.view.width
            notification: modelData
            popup: true
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
