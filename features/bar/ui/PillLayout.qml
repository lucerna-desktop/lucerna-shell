import QtQuick
import Quickshell
import qs.core.theme
import qs.core.widgets
import qs.features.bar.state

// Pílula: uma só, flutuante e centralizada, com tudo à mostra.
Item {
    id: root

    required property real progress
    // Fundida à moldura (0 a 1): sobe até encostar na borda de cima.
    required property real fuse
    readonly property real gap: ThemeManager.spacing.small

    readonly property Region mask: Region {
        item: pill
    }
    // O fundo, que a forma da tela desenha (Frame).
    readonly property rect shape: Qt.rect(pill.x, pill.y, pill.width, pill.height)

    Glass {
        id: pill

        anchors.horizontalCenter: parent.horizontalCenter
        y: BarState.pillY(root.gap, height, root.progress, root.fuse)
        width: row.implicitWidth + ThemeManager.spacing.normal * 2
        height: ThemeManager.barHeight
        radius: height / 2

        Behavior on width { Anim { type: Anim.FastSpatial } }

        Row {
            id: row

            anchors.centerIn: parent
            spacing: ThemeManager.spacing.small

            Workspaces {
                anchors.verticalCenter: parent.verticalCenter
            }

            Divider {}

            ClockButton {
                anchors.verticalCenter: parent.verticalCenter
            }

            Divider {}

            Actions {}
        }
    }
}
