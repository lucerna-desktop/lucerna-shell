pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.core.pixel
import qs.core.theme
import qs.core.widgets
import qs.features.settings.state

// Disposição dos monitores: cada um é um cartão na proporção da área que ocupa.
// Arrastar move; ao soltar, encaixa colado na borda de outro (a prévia mostra
// onde). Clicar seleciona para ajustar abaixo.
Rectangle {
    id: canvas

    // A escala da janela (fracionária: 1,25), para as linhas finas (ver Pixel).
    readonly property real dpr: Window.window?.devicePixelRatio ?? 1

    readonly property var area: MonitorsState.bounds
    readonly property real pad: ThemeManager.px(28)
    // Pixels do canvas por pixel lógico. Fica fixo durante o arrasto.
    property real k: Math.min((width - pad * 2) / area.w, (height - pad * 2) / area.h)
    readonly property real ox: (width - area.w * k) / 2 - area.x * k
    readonly property real oy: (height - area.h * k) / 2 - area.y * k
    // Distância, na tela, em que o encaixe puxa para um alinhamento.
    readonly property real pull: ThemeManager.px(14) / k

    property string dragging: ""
    property var ghost: null

    implicitHeight: ThemeManager.px(250)
    radius: ThemeManager.radius.normal
    color: ThemeManager.alpha(ThemeManager.colors.text, 0.03)
    border.width: ThemeManager.outlines ? Pixel.hairline(canvas.dpr) : 0
    border.color: ThemeManager.colors.border

    Behavior on k { enabled: canvas.dragging === ""; Anim { type: Anim.Spatial } }

    // Prévia do encaixe
    Rectangle {
        visible: canvas.ghost !== null
        x: canvas.ox + (canvas.ghost?.x ?? 0) * canvas.k
        y: canvas.oy + (canvas.ghost?.y ?? 0) * canvas.k
        width: (canvas.ghost?.w ?? 0) * canvas.k
        height: (canvas.ghost?.h ?? 0) * canvas.k
        radius: ThemeManager.radius.small + ThemeManager.px(2)
        color: ThemeManager.alpha(ThemeManager.colors.accent, 0.08)
        border.width: ThemeManager.px(2)
        border.color: ThemeManager.alpha(ThemeManager.colors.accent, 0.6)

        Behavior on x { Anim { type: Anim.FastSpatial } }
        Behavior on y { Anim { type: Anim.FastSpatial } }
    }

    Repeater {
        // Pelos nomes: os cartões continuam os mesmos quando o rascunho muda,
        // e o encaixe anima.
        model: ScriptModel {
            values: MonitorsState.placed.map(m => m.name)
        }

        delegate: Rectangle {
            id: tile

            required property string modelData
            readonly property var spec: MonitorsState.draft.find(m => m.name === modelData) ?? ({})
            readonly property var rect: MonitorsState.rectOf(spec)
            readonly property bool selected: MonitorsState.current?.name === modelData
            readonly property bool moving: canvas.dragging === modelData
            property real dx: 0
            property real dy: 0

            x: canvas.ox + tile.rect.x * canvas.k + tile.dx
            y: canvas.oy + tile.rect.y * canvas.k + tile.dy
            width: tile.rect.w * canvas.k
            height: tile.rect.h * canvas.k
            z: tile.moving ? 2 : tile.selected ? 1 : 0
            radius: ThemeManager.radius.small + ThemeManager.px(2)
            color: tile.selected ? ThemeManager.alpha(ThemeManager.colors.accent, 0.22) : ThemeManager.colors.surface
            border.width: tile.selected ? ThemeManager.px(2) : Pixel.hairline(canvas.dpr)
            border.color: tile.selected ? ThemeManager.colors.accent : ThemeManager.colors.border
            scale: tile.moving ? 1.03 : 1
            opacity: tile.moving ? 0.9 : 1

            Behavior on x { enabled: !tile.moving; Anim { type: Anim.Spatial } }
            Behavior on y { enabled: !tile.moving; Anim { type: Anim.Spatial } }
            Behavior on width { Anim { type: Anim.Spatial } }
            Behavior on height { Anim { type: Anim.Spatial } }
            Behavior on scale { Anim { type: Anim.FastSpatial } }
            Behavior on color { ColorAnim {} }

            Column {
                anchors.centerIn: parent
                width: parent.width - ThemeManager.px(12)
                spacing: 0

                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: MonitorsState.numberOf(tile.modelData)
                    color: tile.selected ? ThemeManager.colors.accent : ThemeManager.colors.text
                    font.pixelSize: Math.max(ThemeManager.px(14), Math.min(ThemeManager.px(34), tile.height * 0.3))
                    font.weight: Font.DemiBold
                }

                Txt {
                    width: parent.width
                    visible: tile.height > ThemeManager.px(64)
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: tile.spec.label
                    font.pixelSize: ThemeManager.font.small
                }

                Txt {
                    width: parent.width
                    visible: tile.height > ThemeManager.px(84)
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: `${tile.spec.width} × ${tile.spec.height}`
                    faint: true
                    font.pixelSize: ThemeManager.font.small - 1
                }
            }

            MouseArea {
                id: mouse

                property point press

                anchors.fill: parent
                cursorShape: tile.moving ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                preventStealing: true

                onPressed: event => {
                    mouse.press = mouse.mapToItem(canvas, event.x, event.y);
                    MonitorsState.select(tile.modelData);
                }
                onPositionChanged: event => {
                    const p = mouse.mapToItem(canvas, event.x, event.y);
                    if (!tile.moving && Math.hypot(p.x - mouse.press.x, p.y - mouse.press.y) < ThemeManager.px(4))
                        return;
                    canvas.dragging = tile.modelData;
                    tile.dx = p.x - mouse.press.x;
                    tile.dy = p.y - mouse.press.y;
                    const at = MonitorsState.snap(tile.modelData, tile.rect.x + tile.dx / canvas.k, tile.rect.y + tile.dy / canvas.k, canvas.pull, null);
                    canvas.ghost = { x: at.x, y: at.y, w: tile.rect.w, h: tile.rect.h };
                }
                onReleased: {
                    if (!tile.moving)
                        return;
                    const x = tile.rect.x + tile.dx / canvas.k;
                    const y = tile.rect.y + tile.dy / canvas.k;
                    canvas.dragging = "";
                    canvas.ghost = null;
                    MonitorsState.drop(tile.modelData, x, y, canvas.pull);
                    tile.dx = 0;
                    tile.dy = 0;
                }
            }
        }
    }

    Txt {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: ThemeManager.spacing.normal
        text: MonitorsState.placed.length > 1 ? "Arraste para posicionar" : ""
        faint: true
        font.pixelSize: ThemeManager.font.small
    }
}
