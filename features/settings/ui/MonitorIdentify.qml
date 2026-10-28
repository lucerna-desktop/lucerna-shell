import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core.theme
import qs.core.widgets
import qs.features.settings.state

// "Identificar": o número de cada monitor, grande, no centro da própria tela.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: window

        required property var modelData
        property real shown: MonitorsState.identifying ? 1 : 0

        // A curva pelo alvo do Behavior, não pelo estado (ver OverlayPanel).
        Behavior on shown {
            id: shownBehavior

            Anim { type: shownBehavior.targetValue > 0 ? Anim.Spatial : Anim.EmphasizedAccel }
        }

        screen: modelData
        visible: shown > 0
        implicitWidth: 260
        implicitHeight: 220
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        mask: Region {}
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "lucerna-panel-identify"

        Surface {
            anchors.fill: parent
            level: 0
            radius: ThemeManager.radius.large + 4
            opacity: window.shown
            scale: 0.85 + 0.15 * window.shown

            Column {
                anchors.centerIn: parent
                spacing: 2

                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: MonitorsState.numberOf(window.modelData.name)
                    color: ThemeManager.colors.accent
                    font.pixelSize: 110
                    font.weight: Font.DemiBold
                }

                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: window.modelData.name
                    muted: true
                }
            }
        }
    }
}
