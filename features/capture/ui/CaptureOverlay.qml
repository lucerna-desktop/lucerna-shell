pragma ComponentBehavior: Bound
import QtQuick
import qs.core.theme
import qs.core.widgets
import qs.features.capture.state

// Painel de captura, por cima da tela: a seleção (área, janela ou tela) e a
// barra de ferramentas embaixo. Enter captura, Esc cancela. Quando some da
// tela, avisa o estado, que espera e captura (o painel não sai na foto).
OverlayPanel {
    id: panel

    name: "capture"
    open: CaptureState.open
    screen: CaptureState.screen
    dim: 0
    onDismissed: CaptureState.close()
    onVisibleChanged: {
        if (!visible)
            CaptureState.overlayHidden();
    }
    onOpenChanged: {
        if (open)
            keys.forceActiveFocus();
    }

    readonly property var origin: CaptureState.screenRect
    readonly property string target: CaptureState.target
    readonly property color veil: ThemeManager.alpha("#000000", 0.4)

    // Área em coordenadas locais.
    readonly property var local: CaptureState.area ? {
        x: CaptureState.area.x - origin.x,
        y: CaptureState.area.y - origin.y,
        width: CaptureState.area.width,
        height: CaptureState.area.height
    } : { x: 0, y: 0, width: 0, height: 0 }

    property var hovered: null
    readonly property var hoveredLocal: hovered ? { x: hovered.x - origin.x, y: hovered.y - origin.y, width: hovered.width, height: hovered.height } : null

    // O que fica aceso (sem véu): a área, a janela sob o mouse ou nada (a tela).
    readonly property var hole: target === "area" ? local : target === "window" ? hoveredLocal : null

    Item {
        id: keys

        anchors.fill: parent
        focus: true
        Keys.onReturnPressed: panel.confirm()
        Keys.onEnterPressed: panel.confirm()

        // Véu em volta do que fica aceso (ou na tela toda, sem nada aceso).
        Rectangle {
            visible: !panel.hole
            anchors.fill: parent
            color: panel.target === "screen" ? ThemeManager.alpha("#000000", 0.18) : panel.veil
            border.width: panel.target === "screen" ? ThemeManager.px(4) : 0
            border.color: ThemeManager.colors.accent
        }

        Item {
            id: frame

            visible: !!panel.hole
            anchors.fill: parent

            readonly property var h: panel.hole ?? { x: 0, y: 0, width: 0, height: 0 }

            Rectangle { x: 0; y: 0; width: parent.width; height: Math.max(0, parent.h.y); color: panel.veil }
            Rectangle { x: 0; y: parent.h.y + parent.h.height; width: parent.width; height: Math.max(0, parent.height - y); color: panel.veil }
            Rectangle { x: 0; y: parent.h.y; width: Math.max(0, parent.h.x); height: parent.h.height; color: panel.veil }
            Rectangle { x: parent.h.x + parent.h.width; y: parent.h.y; width: Math.max(0, parent.width - x); height: parent.h.height; color: panel.veil }

            Rectangle {
                x: parent.h.x - ThemeManager.px(2)
                y: parent.h.y - ThemeManager.px(2)
                width: parent.h.width + ThemeManager.px(4)
                height: parent.h.height + ThemeManager.px(4)
                color: "transparent"
                border.width: ThemeManager.px(2)
                border.color: ThemeManager.colors.accent
                radius: panel.target === "window" ? ThemeManager.px(6) : 0
            }

            // Tamanho (área) ou título (janela), no tom de contêiner
            Rectangle {
                readonly property bool above: parent.h.y > 40
                x: Math.max(ThemeManager.px(8), Math.min(parent.width - width - ThemeManager.px(8), parent.h.x))
                y: above ? parent.h.y - height - ThemeManager.px(8) : parent.h.y + ThemeManager.px(8)
                width: sizeText.implicitWidth + ThemeManager.px(16)
                height: ThemeManager.px(26)
                radius: height / 2
                color: ThemeManager.colors.accentContainer

                Txt {
                    id: sizeText

                    anchors.centerIn: parent
                    text: panel.target === "window" ? (panel.hovered?.title || panel.hovered?.cls || "Janela") : `${Math.round(panel.local.width)} × ${Math.round(panel.local.height)}`
                    color: ThemeManager.colors.onAccentContainer
                    font.pixelSize: ThemeManager.font.small + 1
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, ThemeManager.px(420))
                }
            }

            // Alças nos cantos da área
            Repeater {
                model: panel.target === "area" ? 4 : 0

                delegate: Rectangle {
                    required property int index

                    x: frame.h.x + (index % 2 ? frame.h.width : 0) - ThemeManager.px(6)
                    y: frame.h.y + (index > 1 ? frame.h.height : 0) - ThemeManager.px(6)
                    width: ThemeManager.px(12)
                    height: ThemeManager.px(12)
                    radius: width / 2
                    color: ThemeManager.colors.accent
                    border.width: ThemeManager.px(2)
                    border.color: ThemeManager.colors.accentText
                }
            }
        }

        MouseArea {
            id: mouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: panel.target === "area" ? Qt.CrossCursor : Qt.PointingHandCursor

            // Arrastar: "new" (desenhar), "move" ou um canto (0–3) para redimensionar.
            property string action: ""
            property point start
            property var startRect: null

            function cornerAt(x: real, y: real): int {
                const r = panel.local;
                const corners = [[r.x, r.y], [r.x + r.width, r.y], [r.x, r.y + r.height], [r.x + r.width, r.y + r.height]];
                return corners.findIndex(c => Math.abs(c[0] - x) < ThemeManager.px(14) && Math.abs(c[1] - y) < ThemeManager.px(14));
            }

            function inside(x: real, y: real): bool {
                const r = panel.local;
                return x >= r.x && x <= r.x + r.width && y >= r.y && y <= r.y + r.height;
            }

            function setLocal(x1: real, y1: real, x2: real, y2: real): void {
                const cx1 = Math.max(0, Math.min(width, Math.min(x1, x2)));
                const cy1 = Math.max(0, Math.min(height, Math.min(y1, y2)));
                const cx2 = Math.max(0, Math.min(width, Math.max(x1, x2)));
                const cy2 = Math.max(0, Math.min(height, Math.max(y1, y2)));
                CaptureState.setArea({ x: panel.origin.x + cx1, y: panel.origin.y + cy1, width: Math.max(1, cx2 - cx1), height: Math.max(1, cy2 - cy1) });
            }

            onPressed: event => {
                keys.forceActiveFocus();
                if (panel.target !== "area")
                    return;
                start = Qt.point(event.x, event.y);
                startRect = Object.assign({}, panel.local);
                const corner = cornerAt(event.x, event.y);
                action = corner >= 0 ? String(corner) : inside(event.x, event.y) ? "move" : "new";
                if (action === "new")
                    setLocal(event.x, event.y, event.x + 1, event.y + 1);
            }

            onPositionChanged: event => {
                if (panel.target === "window") {
                    panel.hovered = CaptureState.windowAt(panel.origin.x + event.x, panel.origin.y + event.y);
                    return;
                }
                if (!pressed || panel.target !== "area")
                    return;
                const r = startRect;
                const dx = event.x - start.x;
                const dy = event.y - start.y;
                if (action === "new") {
                    setLocal(start.x, start.y, event.x, event.y);
                } else if (action === "move") {
                    const nx = Math.max(0, Math.min(width - r.width, r.x + dx));
                    const ny = Math.max(0, Math.min(height - r.height, r.y + dy));
                    setLocal(nx, ny, nx + r.width, ny + r.height);
                } else {
                    const c = Number(action);
                    const left = c % 2 === 0 ? r.x + dx : r.x;
                    const right = c % 2 === 1 ? r.x + r.width + dx : r.x + r.width;
                    const top = c < 2 ? r.y + dy : r.y;
                    const bottom = c > 1 ? r.y + r.height + dy : r.y + r.height;
                    setLocal(left, top, right, bottom);
                }
            }

            onReleased: action = ""

            onClicked: event => {
                if (panel.target === "window" && panel.hovered)
                    CaptureState.confirm(panel.hovered);
                else if (panel.target === "screen")
                    CaptureState.confirm(CaptureState.screen?.name);
            }

            onDoubleClicked: event => {
                if (panel.target === "area" && inside(event.x, event.y))
                    CaptureState.confirm(CaptureState.area);
            }
        }

        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            y: ThemeManager.px(64)
            text: panel.target === "area" ? "Arraste para escolher a área · Enter ou clique duplo captura · Esc cancela"
                : panel.target === "window" ? "Clique numa janela · Esc cancela"
                : "Clique para capturar a tela · Esc cancela"
            color: "white"
            style: Text.Outline
            styleColor: ThemeManager.alpha("#000000", 0.6)
            font.weight: Font.DemiBold
        }

        CaptureToolbar {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: ThemeManager.px(48) + (1 - panel.progress) * -ThemeManager.px(24)
            onCapture: panel.confirm()
        }
    }

    function confirm(): void {
        if (target === "window") {
            if (hovered)
                CaptureState.confirm(hovered);
        } else {
            CaptureState.confirmCurrent();
        }
    }
}
