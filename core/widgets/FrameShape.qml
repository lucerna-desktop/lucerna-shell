pragma ComponentBehavior: Bound

import QtQuick
import qs.core.frame
import qs.core.theme

// A forma da tela (ver Frame), desenhada por um shader: a moldura e os pedaços
// ativos da tela `screen`, fundidos, na cor e na transparência da barra.
// Preenche a janela, presa à borda direita da tela: a tela inteira, uma das
// colunas da direita ou 1 px (Frame.extentOn). Os pedaços e as faixas ficam em
// coordenadas da tela; cada faixa é posta na janela descontando a origem dela.
// O shader roda só nas faixas onde pode haver forma (Frame.regions): um
// ShaderEffect por faixa, todos com as mesmas uniforms, cada um desenhando o
// seu pedaço da mesma forma. Parado, não redesenha.
Item {
    id: root

    required property var screen
    // Os pedaços ativos da tela e a abertura da moldura (Frame.blobsOn e
    // Frame.progressIn), separados uma vez pela janela.
    required property var parts
    required property real fuse
    // O tamanho medido pelas janelas (Frame.sizeOn), o mesmo do conteúdo dos
    // painéis: a tela informada pode estar velha.
    readonly property size screenSize: screen ? Frame.sizeOn(screen) : Qt.size(width, height)
    // Onde a janela começa na tela (presa à direita).
    readonly property real originX: screenSize.width - width
    readonly property var regions: Frame.regions(parts, fuse, screenSize)
    readonly property var packed: Frame.slots(parts, fuse, screenSize)

    // As uniforms comuns a todas as faixas, calculadas uma vez por quadro.
    readonly property vector4d frame: Qt.vector4d(Frame.thicknessAt(fuse), Frame.radius * fuse, screenSize.width, screenSize.height)
    readonly property vector4d fill: vec(ThemeManager.glass(ThemeManager.colors.base, 0))
    readonly property vector4d edge: vec(ThemeManager.colors.border)
    readonly property real outline: ThemeManager.outlines ? 1 : 0
    readonly property real reach: Frame.reach
    readonly property vector4d b0: slot(0)
    readonly property vector4d k0: props(0)
    readonly property vector4d b1: slot(1)
    readonly property vector4d k1: props(1)
    readonly property vector4d b2: slot(2)
    readonly property vector4d k2: props(2)
    readonly property vector4d b3: slot(3)
    readonly property vector4d k3: props(3)
    readonly property vector4d b4: slot(4)
    readonly property vector4d k4: props(4)
    readonly property vector4d b5: slot(5)
    readonly property vector4d k5: props(5)

    anchors.fill: parent

    function vec(c: color): vector4d {
        return Qt.vector4d(c.r, c.g, c.b, c.a);
    }

    function slot(i: int): vector4d {
        const r = packed.rects[i];
        return Qt.vector4d(r[0], r[1], r[2], r[3]);
    }

    function props(i: int): vector4d {
        const k = packed.props[i];
        return Qt.vector4d(k[0], k[1], k[2], 0);
    }

    Repeater {
        model: Frame.regionCount

        delegate: ShaderEffect {
            required property int index
            readonly property rect region: index < root.regions.length ? root.regions[index] : Qt.rect(0, 0, 0, 0)

            x: region.x - root.originX
            y: region.y
            width: region.width
            height: region.height
            visible: width > 0 && height > 0

            property vector4d area: Qt.vector4d(region.x, region.y, region.width, region.height)
            property vector4d frame: root.frame
            property vector4d fill: root.fill
            property vector4d edge: root.edge
            property real outline: root.outline
            property real reach: root.reach
            property vector4d b0: root.b0
            property vector4d k0: root.k0
            property vector4d b1: root.b1
            property vector4d k1: root.k1
            property vector4d b2: root.b2
            property vector4d k2: root.k2
            property vector4d b3: root.b3
            property vector4d k3: root.k3
            property vector4d b4: root.b4
            property vector4d k4: root.k4
            property vector4d b5: root.b5
            property vector4d k5: root.k5

            fragmentShader: Qt.resolvedUrl("shaders/frame.qsb")
        }
    }
}
