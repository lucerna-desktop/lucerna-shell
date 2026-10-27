pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core.frame
import qs.core.theme
import qs.core.widgets
import qs.features.bar.state

// A janela da barra num monitor, que é também a da forma da tela (Frame): a
// pílula (ou a ilha) e, por baixo dela, a forma que desenha o fundo da pílula,
// a moldura e os fundos dos painéis que saem das bordas, numa peça só. O
// conteúdo dos painéis fica nas janelas deles, por cima desta.
//
// Só existe enquanto há forma na tela; ocupa a faixa da pílula ou, com algum
// painel saindo das bordas, a tela inteira. Só a pílula recebe o mouse: o
// resto (a moldura, os fundos) deixa o clique passar.
PanelWindow {
    id: root

    // A tela vem de fora (fixa por janela). Ler `screen` da própria janela aqui
    // daria laço: mudar a visibilidade renotifica `screen`.
    required property var targetScreen
    readonly property bool shown: BarState.shownOn(targetScreen)
    property real progress: shown ? 1 : 0
    readonly property real fuse: Frame.progressOn(targetScreen)
    readonly property real strip: ThemeManager.barHeight + ThemeManager.spacing.small * 2

    Behavior on progress {
        Anim {
            type: root.shown ? Anim.Spatial : Anim.EmphasizedAccel
        }
    }

    screen: targetScreen
    visible: Frame.wantedOn(targetScreen)
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Frame.fullOn(targetScreen) ? (targetScreen?.height ?? strip) : strip
    color: "transparent"
    // Escondida sozinha: não reserva espaço, as janelas começam no topo.
    exclusionMode: ExclusionMode.Ignore
    // O item do Loader é um QObject: o `as` de cada estilo dá o tipo que tem `mask`.
    function layoutMask(): Region {
        const item = layout.item;
        return (item as IslandLayout)?.mask ?? (item as PillLayout)?.mask ?? null;
    }

    function layoutShape(): rect {
        const item = layout.item;
        return (item as IslandLayout)?.shape ?? (item as PillLayout)?.shape ?? Qt.rect(0, 0, 0, 0);
    }

    mask: layoutMask()
    // Na camada de cima de tudo, como os painéis: a forma fica atrás do
    // conteúdo deles (que esperam esta janela existir, Frame.isReady) e por
    // cima de uma janela em tela cheia (o OSD e os popups precisam).
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "lucerna-panel-bar"

    // Clicar na barra não fecha os painéis acompanhantes.
    // Os painéis que saem da moldura esperam esta janela à mostra.
    Component.onCompleted: {
        BarState.registerSurface(root);
        Frame.addWindow(root);
    }
    Component.onDestruction: {
        BarState.unregisterSurface(root);
        Frame.removeWindow(root);
    }

    FrameShape {
        screen: root.targetScreen
    }

    FrameBlob {
        screen: root.targetScreen
        role: "pill"
        open: root.shown
        progress: root.progress
        rect: root.layoutShape()
        radius: ThemeManager.barHeight / 2
    }

    Loader {
        id: layout

        anchors.fill: parent
        sourceComponent: BarState.style === "island" ? islandLayout : pillLayout
    }

    Component {
        id: islandLayout

        IslandLayout {
            progress: root.progress
            fuse: root.fuse
        }
    }

    Component {
        id: pillLayout

        PillLayout {
            progress: root.progress
            fuse: root.fuse
        }
    }
}
