pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core.frame
import qs.core.theme
import qs.core.widgets
import qs.features.bar.state

// A janela da barra num monitor, que é também a da forma da tela (Frame): a
// barra e, por baixo dela, a forma que desenha o fundo da barra (uma aba
// fundida à borda de cima), a moldura e os fundos dos painéis que saem das
// bordas, numa peça só. A barra traz a moldura junto: aparece e recolhe com
// ela. O conteúdo dos painéis fica nas janelas deles, por cima desta.
//
// Só existe enquanto há forma na tela, e ocupa a tela inteira. Só a barra
// recebe o mouse: o resto (a moldura, os fundos) deixa o clique passar.
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
    visible: Frame.wantedOn(targetScreen)
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    // Escondida sozinha: não reserva espaço, as janelas começam no topo.
    exclusionMode: ExclusionMode.Ignore
    mask: layout.mask
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
        framed: true
        open: root.shown
        progress: root.progress
        rect: layout.shape
        radius: ThemeManager.barHeight / 2
    }

    PillLayout {
        id: layout

        anchors.fill: parent
        progress: root.progress
        morph: Frame.morphOn(root.targetScreen)
    }
}
