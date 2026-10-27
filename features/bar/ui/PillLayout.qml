import QtQuick
import Quickshell
import qs.core.frame
import qs.core.theme
import qs.core.widgets
import qs.features.bar.state

// A barra: uma aba centralizada, fundida à borda de cima da moldura (a forma
// da tela desenha o fundo dela), com tudo à mostra. Ao abrir o painel
// superior, ela se transforma nele (`morph`): o conteúdo esmaece e ela deixa
// de receber o mouse, que passa ao painel.
Item {
    id: root

    required property real progress
    required property real morph

    readonly property Region mask: Region {
        item: root.morph > 0 ? null : pill
    }
    // O fundo, que a forma da tela desenha (Frame).
    readonly property rect shape: Qt.rect(pill.x, pill.y, pill.width, pill.height)

    Glass {
        id: pill

        anchors.horizontalCenter: parent.horizontalCenter
        y: BarState.pillY(height, root.progress)
        width: row.implicitWidth + ThemeManager.spacing.normal * 2
        height: ThemeManager.barHeight
        radius: height / 2

        Behavior on width { Anim { type: Anim.FastSpatial } }

        Row {
            id: row

            anchors.centerIn: parent
            spacing: ThemeManager.spacing.small
            opacity: Frame.barContentOpacity(root.morph)
            visible: opacity > 0

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
