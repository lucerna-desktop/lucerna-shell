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
// Só existe enquanto há forma na tela. Ocupa a tela inteira, ou só a coluna
// da direita quando só o OSD está à mostra, sem a moldura
// (Frame.compactOn): o Hyprland desfoca e recompõe a cada quadro só ela. Só a
// barra recebe o mouse: o resto (a moldura, os fundos) deixa o clique passar.
PanelWindow {
    id: root

    // A tela vem de fora (fixa por janela). Ler `screen` da própria janela aqui
    // daria laço: mudar a visibilidade renotifica `screen`.
    required property var targetScreen
    readonly property bool shown: BarState.shownOn(targetScreen)
    property real progress: shown ? 1 : 0
    readonly property size screenSize: Qt.size(targetScreen?.width ?? 0, targetScreen?.height ?? 0)
    // Os pedaços ativos desta tela, separados uma vez por quadro: a forma, o
    // tamanho da janela e a transformação da barra derivam deles.
    readonly property var parts: Frame.blobsOn(targetScreen)
    readonly property real fuse: Frame.progressIn(parts)
    readonly property bool compact: Frame.compactOn(parts, fuse, screenSize)
    // Sem pedaço, a janela some só depois de apresentar um quadro vazio: o
    // último buffer dela nunca é a forma antiga (que sobraria um quadro além
    // do conteúdo do painel, na outra janela). Os quadros vazios a esperar.
    property int lingering: 0

    onPartsChanged: {
        if (!parts.length && visible) {
            lingering = 2;
            lingerLimit.restart();
        }
    }

    Connections {
        target: root.contentItem.Window.window

        function onFrameSwapped() {
            if (root.lingering > 0 && !root.parts.length)
                root.lingering--;
        }
    }

    // Se nenhum quadro vier (nada mudou na tela), não fica presa à mostra.
    Timer {
        id: lingerLimit

        interval: 250
        onTriggered: root.lingering = 0
    }

    Behavior on progress {
        Anim {
            type: root.shown ? Anim.Spatial : Anim.EmphasizedAccel
        }
    }

    screen: targetScreen
    visible: parts.length > 0 || lingering > 0
    anchors {
        top: true
        bottom: true
        left: !compact
        right: true
    }
    implicitWidth: Frame.column
    color: "transparent"
    // Escondida sozinha: não reserva espaço, as janelas começam no topo.
    exclusionMode: ExclusionMode.Ignore
    mask: layout.mask
    // Na camada de cima de tudo, como os painéis: a forma fica atrás do
    // conteúdo deles (que esperam esta janela existir, Frame.isReady) e por
    // cima de uma janela em tela cheia (o OSD precisa).
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
        parts: root.parts
        fuse: root.fuse
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

    // Em coordenadas da tela, como a forma (a janela está presa à direita).
    PillLayout {
        id: layout

        x: root.width - root.screenSize.width
        width: root.screenSize.width
        height: parent.height
        progress: root.progress
        morph: Frame.morphIn(root.parts)
    }
}
