import QtQuick
import qs.core.frame
import qs.core.theme

// A forma da tela (ver Frame), desenhada por um shader: a moldura e os pedaços
// ativos da tela `screen`, fundidos, na cor e na transparência da barra.
// Preenche a janela, que fica no canto da tela; o shader só cobre a área que
// tem forma (a janela toda com a moldura à mostra). Parado, não redesenha.
Item {
    id: root

    required property var screen

    readonly property var parts: Frame.blobsOn(screen)
    readonly property real fuse: Frame.progressOn(screen)
    readonly property rect area: Frame.bounds(parts, fuse, Qt.size(width, height))
    readonly property var packed: Frame.slots(parts, fuse)
    readonly property color color: ThemeManager.glass(ThemeManager.colors.base, 0)
    readonly property color edgeColor: ThemeManager.colors.border

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

    ShaderEffect {
        x: root.area.x
        y: root.area.y
        width: root.area.width
        height: root.area.height
        visible: width > 0 && height > 0

        property vector4d area: Qt.vector4d(root.area.x, root.area.y, root.area.width, root.area.height)
        property vector4d frame: Qt.vector4d(Frame.thicknessAt(root.fuse), Frame.radius * root.fuse, root.screen?.width ?? root.width, root.screen?.height ?? root.height)
        property vector4d fill: root.vec(root.color)
        property vector4d edge: root.vec(root.edgeColor)
        property real outline: ThemeManager.outlines ? 1 : 0
        property vector4d b0: root.slot(0)
        property vector4d k0: root.props(0)
        property vector4d b1: root.slot(1)
        property vector4d k1: root.props(1)
        property vector4d b2: root.slot(2)
        property vector4d k2: root.props(2)
        property vector4d b3: root.slot(3)
        property vector4d k3: root.props(3)
        property vector4d b4: root.slot(4)
        property vector4d k4: root.props(4)
        property vector4d b5: root.slot(5)
        property vector4d k5: root.props(5)

        fragmentShader: Qt.resolvedUrl("shaders/frame.qsb")
    }
}
