import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core.theme
import qs.core.widgets
import qs.features.notifications.state

// Popups no canto superior direito do monitor com foco. Entram e saem
// deslizando pela direita; os de baixo se reacomodam com mola.
//
// A janela ocupa a coluna inteira, mas só a área dos cartões recebe cliques
// (máscara), e ela só existe enquanto há popups (mais o tempo da animação de
// saída do último).
PanelWindow {
    id: window

    readonly property bool hasPopups: NotificationsState.popups.length > 0

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
    // Falso positivo do qmllint com o grupo margins do PanelWindow (ver o spec do CI).
    margins.top: ThemeManager.spacing.small // qmllint disable unqualified missing-property
    margins.right: ThemeManager.spacing.small // qmllint disable unqualified missing-property
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
