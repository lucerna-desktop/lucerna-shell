pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core.frame
import qs.core.panels

// A janela da forma de um monitor (ver Frame): sempre aberta, desenha a forma
// da tela (a moldura, a aba da barra e os fundos dos painéis que saem das
// bordas, numa peça só) e, por cima dela, o que as features põem nela (a
// barra, e depois o conteúdo dos painéis da moldura), em coordenadas da tela.
// A composição fica no shell.qml (uma feature não importa outra).
//
// Presa à direita, muda de largura só entre os níveis do Frame.extentOn: 1 px
// sem nada à mostra, a coluna, a coluna larga e a tela inteira. O Hyprland
// desfoca e recompõe a cada quadro só a janela. Recebe o mouse só nas áreas
// de entrada ativas da tela (FrameInput); fora delas, o clique passa para as
// janelas de baixo. Pega o teclado (sob demanda, nunca exclusivo: o Hyprland
// mandaria todo clique para ela, mesmo fora da máscara) só enquanto uma área
// ativa pede.
PanelWindow {
    id: root

    // A tela vem de fora (fixa por janela). Ler `screen` da própria janela aqui
    // daria laço: mudar a visibilidade renotifica `screen`.
    required property var targetScreen
    // O tamanho da tela medido pelas janelas (Frame.sizeOn), não o informado,
    // que pode estar velho; esta mede o dela (a altura sempre; a largura só
    // em tela cheia).
    readonly property size screenSize: Frame.sizeOn(targetScreen)
    // Os pedaços ativos desta tela, separados uma vez por quadro: a forma e o
    // tamanho da janela derivam deles.
    readonly property var parts: Frame.blobsOn(targetScreen)
    readonly property real fuse: Frame.progressIn(parts)
    readonly property real extent: Frame.extentOn(parts, Frame.inputsOn(targetScreen), fuse, screenSize)
    readonly property bool full: extent >= screenSize.width
    // O que as features põem na janela, em coordenadas da tela, por cima da
    // forma; os primeiros ficam embaixo.
    default property alias content: layer.data

    screen: targetScreen
    visible: true
    anchors {
        top: true
        bottom: true
        left: root.full
        right: true
    }
    implicitWidth: extent
    color: "transparent"
    // Não reserva espaço: as janelas começam no topo.
    exclusionMode: ExclusionMode.Ignore
    // Na camada de cima de tudo: por cima de uma janela em tela cheia (o OSD
    // precisa). Os painéis centralizados, criados ao abrir, ficam por cima
    // dela. "lucerna-panel-*" recebe o desfoque (ver ThemeSwitcherState).
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "lucerna-panel-frame"
    WlrLayershell.keyboardFocus: Frame.keyboardOn(targetScreen) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask: Region {
        regions: areas.instances
    }

    // A largura só com a janela em tela cheia e já do tamanho dela (logo
    // depois de virar tela cheia, a largura ainda é a da coluna até o
    // compositor responder).
    onWidthChanged: Frame.measure(targetScreen, full && width > Frame.wideColumn ? width : 0, height)
    onHeightChanged: Frame.measure(targetScreen, full && width > Frame.wideColumn ? width : 0, height)

    // Os painéis registrados não fecham os acompanhantes ao receber um clique.
    Component.onCompleted: {
        Frame.addWindow(root);
        Panels.register(root);
    }
    Component.onDestruction: {
        Frame.removeWindow(root);
        Panels.unregister(root);
    }

    // As áreas de entrada ativas da tela, postas na janela (presa à direita).
    Variants {
        id: areas

        model: Frame.inputsOn(root.targetScreen)

        Region {
            required property var modelData

            x: modelData.rect.x - (root.screenSize.width - root.width)
            y: modelData.rect.y
            width: modelData.rect.width
            height: modelData.rect.height
        }
    }

    FrameShape {
        screen: root.targetScreen
        parts: root.parts
        fuse: root.fuse
    }

    Item {
        id: layer

        x: root.width - root.screenSize.width
        width: root.screenSize.width
        height: root.screenSize.height
    }
}
