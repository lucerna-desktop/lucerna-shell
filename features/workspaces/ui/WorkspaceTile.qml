pragma ComponentBehavior: Bound

import QtQuick
import qs.core.pixel
import qs.core.theme
import qs.core.widgets
import qs.features.workspaces.state

// Um workspace na visão geral: o papel de parede reduzido, as janelas no
// lugar e o número. Recebe janelas arrastadas de outros workspaces.
Item {
    id: root

    required property int wsId
    required property real tileWidth

    readonly property var monitor: WorkspacesState.monitorRect(wsId)
    readonly property real factor: tileWidth / monitor.width
    readonly property var windows: WorkspacesState.windowsOf(wsId)
    readonly property bool current: WorkspacesState.focusedId === wsId
    readonly property bool selected: WorkspacesState.selected === wsId
    readonly property bool dragChild: windows.some(w => w.address === WorkspacesState.dragging)

    width: tileWidth
    height: tileWidth * monitor.height / monitor.width + label.height + ThemeManager.spacing.small
    z: dragChild ? 50 : 0

    Rectangle {
        id: screenArea

        width: root.tileWidth
        height: root.tileWidth * root.monitor.height / root.monitor.width
        radius: ThemeManager.radius.normal
        color: ThemeManager.alpha(ThemeManager.colors.base, 0.6)
        border.width: drop.containsDrag || root.selected ? ThemeManager.px(2) : root.current ? Pixel.hairline(Window.window?.devicePixelRatio ?? 1) : 0
        border.color: drop.containsDrag || root.selected ? ThemeManager.colors.accent : ThemeManager.alpha(ThemeManager.colors.accent, 0.5)

        Image {
            anchors.fill: parent
            anchors.margins: ThemeManager.px(2)
            readonly property string path: ThemeManager.resolvePath(ThemeManager.wallpaperFor(ThemeManager.current).static ?? "")

            source: path ? `file://${path}` : ""
            sourceSize: Qt.size(ThemeManager.px(480), ThemeManager.px(270))
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: 0.55
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: WorkspacesState.selected = root.wsId
            onClicked: WorkspacesState.go(root.wsId)
        }

        Item {
            id: thumbs

            anchors.fill: parent

            Repeater {
                model: root.windows

                delegate: WindowThumb {
                    required property var modelData

                    win: modelData
                    factor: root.factor
                }
            }
        }

        Txt {
            anchors.centerIn: parent
            visible: root.windows.length === 0
            text: drop.containsDrag ? "Soltar aqui" : "Vazio"
            faint: !drop.containsDrag
            color: drop.containsDrag ? ThemeManager.colors.accent : ThemeManager.colors.textFaint
        }

        DropArea {
            id: drop

            anchors.fill: parent
            keys: ["lucerna-window"]
            onDropped: event => WorkspacesState.moveWindow((event.source as WindowThumb).win, root.wsId)
        }
    }

    Row {
        id: label

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: screenArea.bottom
        anchors.topMargin: ThemeManager.spacing.small
        spacing: ThemeManager.px(6)

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: root.current ? ThemeManager.px(18) : ThemeManager.px(6)
            height: ThemeManager.px(6)
            radius: height / 2
            color: root.current ? ThemeManager.colors.accent : root.windows.length ? ThemeManager.colors.textMuted : ThemeManager.colors.border
        }

        Txt {
            anchors.verticalCenter: parent.verticalCenter
            text: root.windows.length ? `${root.wsId} · ${root.windows.length} ${root.windows.length === 1 ? "janela" : "janelas"}` : `${root.wsId}`
            font.pixelSize: ThemeManager.font.small + 1
            font.weight: root.selected ? Font.DemiBold : Font.Normal
            color: root.selected ? ThemeManager.colors.accent : ThemeManager.colors.textMuted
        }
    }
}
