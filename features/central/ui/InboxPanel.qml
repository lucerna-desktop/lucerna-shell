pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.core.theme
import qs.core.widgets
import qs.features.central.state

// Notificações da central: o cabeçalho com "Limpar" e a lista, a mais nova em
// cima, com as ações de cada uma. Ocupa a altura que recebe e rola; sem
// notificações, só o ícone.
CentralPanel {
    Item {
        id: headerRow

        width: parent.width
        height: ThemeManager.px(36)

        Txt {
            anchors.left: parent.left
            anchors.leftMargin: ThemeManager.spacing.tiny
            anchors.verticalCenter: parent.verticalCenter
            text: "Notificações"
            font.weight: Font.DemiBold
        }

        Clickable {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: InboxState.list.length > 0
            width: clearLabel.implicitWidth + ThemeManager.spacing.normal * 2
            height: ThemeManager.px(28)
            radius: height / 2
            color: ThemeManager.alpha(ThemeManager.colors.text, 0.08)
            onClicked: InboxState.clearAll()

            Txt {
                id: clearLabel

                anchors.centerIn: parent
                text: "Limpar"
                font.pixelSize: ThemeManager.font.small
            }
        }
    }

    ListView {
        id: list

        y: headerRow.height + ThemeManager.spacing.small
        width: parent.width
        height: Math.max(0, parent.height - y)
        clip: true
        spacing: ThemeManager.spacing.small
        boundsBehavior: Flickable.StopAtBounds

        model: ScriptModel {
            values: InboxState.list
        }

        delegate: NotificationCard {
            id: card

            required property var modelData

            width: ListView.view.width
            notification: card.modelData
            timeText: InboxState.timeLabel(card.modelData)
            onDismissRequested: InboxState.dismiss(card.modelData)
            onActionInvoked: action => InboxState.invoke(card.modelData, action)
        }

        add: Transition {
            ParallelAnimation {
                Anim { property: "x"; from: ThemeManager.px(48); to: 0; type: Anim.Spatial }
                Anim { property: "opacity"; from: 0; to: 1; type: Anim.Effects }
            }
        }

        remove: Transition {
            ParallelAnimation {
                Anim { property: "x"; to: ThemeManager.px(96); type: Anim.EmphasizedAccel }
                Anim { property: "opacity"; to: 0; type: Anim.EmphasizedAccel }
            }
        }

        displaced: Transition {
            Anim { properties: "x,y"; type: Anim.Spatial }
            Anim { property: "opacity"; to: 1; type: Anim.Effects }
        }
    }

    // Sem notificações: só o ícone, discreto.
    Icon {
        anchors.centerIn: list
        visible: InboxState.list.length === 0
        icon: Icons.bellOutline
        size: ThemeManager.px(40)
        color: ThemeManager.colors.textFaint
    }
}
