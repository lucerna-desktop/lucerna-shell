pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core.theme
import qs.core.widgets
import qs.features.bar.state

// A janela da barra num monitor. O arranjo vem do estilo escolhido nas
// configurações (pílula ou ilha); os dois flutuam no topo, se escondem
// sozinhos e só as partes visíveis recebem o mouse.
PanelWindow {
    id: root

    // A tela vem de fora (fixa por janela). Ler `screen` da própria janela aqui
    // daria laço: mudar a visibilidade renotifica `screen`.
    required property var targetScreen
    readonly property bool shown: BarState.shownOn(targetScreen)
    property real progress: shown ? 1 : 0

    Behavior on progress {
        Anim {
            type: root.shown ? Anim.Spatial : Anim.EmphasizedAccel
        }
    }

    screen: targetScreen
    visible: shown || progress > 0
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: ThemeManager.barHeight + ThemeManager.spacing.small * 2
    color: "transparent"
    // Escondida sozinha: não reserva espaço, as janelas começam no topo.
    exclusionMode: ExclusionMode.Ignore
    // O item do Loader é um QObject: o `as` de cada estilo dá o tipo que tem `mask`.
    function layoutMask(): Region {
        const item = layout.item;
        return (item as IslandLayout)?.mask ?? (item as PillLayout)?.mask ?? null;
    }

    mask: layoutMask()
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "lucerna-panel-bar"

    // Clicar na barra não fecha os painéis acompanhantes.
    Component.onCompleted: BarState.registerSurface(root)
    Component.onDestruction: BarState.unregisterSurface(root)

    Loader {
        id: layout

        anchors.fill: parent
        sourceComponent: BarState.style === "island" ? islandLayout : pillLayout
    }

    Component {
        id: islandLayout

        IslandLayout {
            progress: root.progress
        }
    }

    Component {
        id: pillLayout

        PillLayout {
            progress: root.progress
        }
    }
}
