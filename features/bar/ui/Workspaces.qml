import QtQuick
import qs.core.theme
import qs.core.widgets
import qs.features.bar.state

// Indicador de workspaces: o com foco vira uma pílula acesa; os ocupados, um
// ponto claro; os vazios, um ponto apagado. Roda do mouse troca de workspace.
Item {
    implicitWidth: row.implicitWidth
    implicitHeight: ThemeManager.px(28)

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: event => BarState.cycleWorkspace(event.angleDelta.y > 0 ? -1 : 1)
    }

    Row {
        id: row

        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Repeater {
            model: BarState.workspaceIds

            delegate: MouseArea {
                id: cell

                required property int modelData
                readonly property string state_: BarState.workspaceState(modelData)

                width: dot.width + ThemeManager.spacing.small * 1.5
                height: ThemeManager.px(28)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: BarState.focusWorkspace(modelData)

                Rectangle {
                    id: dot

                    anchors.centerIn: parent
                    width: cell.state_ === "focused" ? ThemeManager.px(22) : ThemeManager.px(7)
                    height: ThemeManager.px(7)
                    radius: height / 2
                    color: cell.state_ === "focused" ? ThemeManager.colors.accent
                        : cell.state_ === "occupied" ? ThemeManager.colors.textMuted
                        : cell.containsMouse ? ThemeManager.colors.textMuted : ThemeManager.colors.border

                    Behavior on width { Anim { type: Anim.FastSpatial } }
                    Behavior on color { ColorAnim {} }
                }
            }
        }
    }
}
