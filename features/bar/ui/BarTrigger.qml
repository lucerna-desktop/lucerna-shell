import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.features.bar.state

// Faixa de 1 px no topo da tela: encostar o mouse nela mostra a barra, que
// fica escondida sozinha.
PanelWindow {
    id: root

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 1
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "lucerna-bar-trigger"

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: BarState.reveal(root.screen)
        onExited: BarState.setHovering(false)
    }
}
