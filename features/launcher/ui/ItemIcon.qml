import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.core.theme
import qs.core.widgets

// O ícone de um resultado: o do app (tema de ícones), a miniatura de uma
// imagem, ou o glifo (ação do shell, tipo de arquivo, web).
Item {
    id: root

    required property var item
    property int size: ThemeManager.px(32)
    property bool highlighted: false

    readonly property string iconPath: item?.icon ? Quickshell.iconPath(item.icon, true) : ""
    readonly property bool thumbnail: item?.kind === "file" && item?.type === "image"

    implicitWidth: size
    implicitHeight: size

    IconImage {
        anchors.fill: parent
        visible: root.iconPath !== ""
        implicitSize: root.size
        source: root.iconPath
        asynchronous: true
    }

    Rectangle {
        anchors.fill: parent
        visible: root.thumbnail
        radius: ThemeManager.radius.small
        color: ThemeManager.alpha(ThemeManager.colors.text, 0.06)
        clip: true

        Image {
            anchors.fill: parent
            source: root.thumbnail ? `file://${root.item.path}` : ""
            sourceSize: Qt.size(root.size * 2, root.size * 2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }

    Icon {
        anchors.centerIn: parent
        visible: root.iconPath === "" && !root.thumbnail
        icon: root.item?.glyph ?? Icons.application
        size: root.size * 0.7
        filled: root.highlighted
        color: root.highlighted ? ThemeManager.colors.accent : ThemeManager.colors.textMuted
    }
}
