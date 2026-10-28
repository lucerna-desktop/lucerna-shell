import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.features.idle.state

// O escurecer da ociosidade: um véu preto em cada tela, que não pega o mouse
// (qualquer movimento desfaz, porque acaba a ociosidade). O resto da feature
// (desligar a tela, bloquear, suspender) vive no IdleState.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: veil

        required property var modelData
        property real shown: IdleState.dimmed ? 1 : 0

        // Escurece devagar; volta rápido ao mexer. A duração pelo alvo do
        // Behavior, não pelo estado (ver OverlayPanel).
        Behavior on shown {
            id: shownBehavior

            NumberAnimation { duration: shownBehavior.targetValue > 0 ? 1800 : 180; easing.type: Easing.InOutQuad }
        }

        screen: modelData
        visible: shown > 0
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        mask: Region {}
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "lucerna-dim"

        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: 0.6 * veil.shown
        }
    }
}
