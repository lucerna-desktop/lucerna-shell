import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core.pixel
import qs.core.theme
import qs.core.widgets
import qs.features.workspaces.state

// Uma janela na miniatura do workspace: a imagem dela (capturada ao abrir a
// visão geral, sem ficar ao vivo), o ícone do app e, no hover, o título e o
// botão de fechar. Clicar vai até ela; arrastar leva para outro workspace.
Item {
    id: root

    required property var win
    required property real factor

    readonly property bool dragging: mouse.drag.active

    onDraggingChanged: WorkspacesState.dragging = dragging ? win.address : ""

    function place(): void {
        x = Qt.binding(() => win.x * factor);
        y = Qt.binding(() => win.y * factor);
    }

    Component.onCompleted: place()
    width: Math.max(24, win.width * factor)
    height: Math.max(18, win.height * factor)
    z: dragging ? 100 : 0
    scale: dragging ? 0.85 : 1

    Behavior on scale { Anim { type: Anim.FastSpatial } }

    Drag.active: dragging
    Drag.hotSpot.x: width / 2
    Drag.hotSpot.y: height / 2
    Drag.keys: ["lucerna-window"]

    Rectangle {
        id: frame

        anchors.fill: parent
        radius: 6
        color: ThemeManager.colors.surface
        border.width: mouse.containsMouse || root.dragging ? 2 : root.win.focused ? Pixel.hairline(Window.window?.devicePixelRatio ?? 1) : 0
        border.color: mouse.containsMouse || root.dragging ? ThemeManager.colors.accent : ThemeManager.alpha(ThemeManager.colors.accent, 0.5)
        clip: true

        ScreencopyView {
            anchors.fill: parent
            anchors.margins: 1
            captureSource: root.win.toplevel?.wayland ?? null
            live: false
        }
    }

    // Ícone do app
    Image {
        readonly property var entry: DesktopEntries.heuristicLookup(root.win.cls)

        anchors.centerIn: parent
        width: Math.min(36, parent.width * 0.4, parent.height * 0.5)
        height: width
        source: entry?.icon ? Quickshell.iconPath(entry.icon, true) : ""
        sourceSize: Qt.size(64, 64)
        visible: status === Image.Ready
        opacity: 0.95
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 22
        visible: mouse.containsMouse && !root.dragging && parent.height > 44
        color: ThemeManager.alpha(ThemeManager.colors.base, 0.85)
        radius: 6

        Txt {
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 24
            verticalAlignment: Text.AlignVCenter
            text: root.win.title
            elide: Text.ElideRight
            font.pixelSize: ThemeManager.font.small
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        drag.target: root
        drag.threshold: 8
        onReleased: {
            if (root.dragging)
                root.Drag.drop();
            root.place();
        }
        onClicked: event => {
            if (event.button === Qt.MiddleButton)
                WorkspacesState.closeWindow(root.win);
            else
                WorkspacesState.focusWindow(root.win);
        }
    }

    IconButton {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 2
        visible: (mouse.containsMouse || hovered) && !root.dragging && parent.width > 60
        icon: Icons.close
        iconSize: 14
        onClicked: WorkspacesState.closeWindow(root.win)
    }
}
