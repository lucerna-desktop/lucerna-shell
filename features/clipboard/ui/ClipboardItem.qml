import QtQuick
import qs.core.theme
import qs.core.widgets
import qs.features.clipboard.state

// Uma entrada do histórico: miniatura ou ícone, o texto (duas linhas), quando
// foi copiada, e os botões de fixar e apagar (no hover ou selecionada).
Clickable {
    id: root

    required property var entry
    required property bool current
    readonly property bool isImage: entry.kind === "image"
    readonly property bool hasThumb: isImage && !!entry.thumb

    signal chosen
    signal hoveredIn

    height: isImage ? ThemeManager.px(104) : entry.kind === "files" ? ThemeManager.px(56) : ThemeManager.px(64)
    radius: ThemeManager.radius.normal
    color: current ? ThemeManager.alpha(ThemeManager.colors.accent, 0.14) : "transparent"
    onClicked: root.chosen()
    onHoveredChanged: {
        if (hovered)
            root.hoveredIn();
    }

    Rectangle {
        id: thumb

        anchors.left: parent.left
        anchors.leftMargin: ThemeManager.spacing.normal
        anchors.verticalCenter: parent.verticalCenter
        width: root.isImage ? ThemeManager.px(136) : ThemeManager.px(36)
        height: root.isImage ? ThemeManager.px(84) : ThemeManager.px(36)
        radius: root.isImage ? ThemeManager.radius.small : ThemeManager.px(18)
        color: root.isImage ? ThemeManager.alpha(ThemeManager.colors.text, 0.05) : ThemeManager.alpha(ThemeManager.colors.accent, root.current ? 0.22 : 0.12)
        clip: true

        Image {
            anchors.fill: parent
            visible: root.hasThumb
            source: root.hasThumb ? `file://${root.entry.thumb}` : ""
            sourceSize: Qt.size(ThemeManager.px(272), ThemeManager.px(168))
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }

        Icon {
            anchors.centerIn: parent
            visible: !root.hasThumb
            icon: root.isImage ? "image" : root.entry.kind === "files" ? "folder" : "notes"
            size: ThemeManager.px(20)
            color: ThemeManager.colors.accent
        }
    }

    Column {
        anchors.left: thumb.right
        anchors.leftMargin: ThemeManager.spacing.normal
        anchors.right: actions.left
        anchors.rightMargin: ThemeManager.spacing.small
        anchors.verticalCenter: parent.verticalCenter
        spacing: ThemeManager.px(2)

        Txt {
            width: parent.width
            textFormat: Text.StyledText
            text: ClipboardState.marked(ClipboardState.preview(root.entry), root.entry.matches)
            wrapMode: Text.Wrap
            maximumLineCount: root.isImage || root.entry.kind === "files" ? 1 : 2
            elide: Text.ElideRight
            font.weight: root.current ? Font.DemiBold : Font.Normal
        }

        Row {
            spacing: ThemeManager.px(4)

            Icon {
                visible: root.entry.pinned
                anchors.verticalCenter: parent.verticalCenter
                icon: Icons.pin
                filled: true
                size: ThemeManager.px(13)
                color: ThemeManager.colors.accent
            }

            Txt {
                text: ClipboardState.detail(root.entry)
                faint: true
                font.pixelSize: ThemeManager.font.small
            }
        }
    }

    Row {
        id: actions

        anchors.right: parent.right
        anchors.rightMargin: ThemeManager.spacing.small
        anchors.verticalCenter: parent.verticalCenter
        opacity: root.hovered || root.current ? 1 : 0
        spacing: ThemeManager.px(2)

        Behavior on opacity { Anim { type: Anim.FastEffects } }

        IconButton {
            icon: Icons.pin
            iconSize: ThemeManager.px(18)
            active: root.entry.pinned
            onClicked: ClipboardState.togglePin(root.entry)
        }

        IconButton {
            icon: Icons.trash
            iconSize: ThemeManager.px(18)
            onClicked: ClipboardState.remove(root.entry)
        }
    }
}
