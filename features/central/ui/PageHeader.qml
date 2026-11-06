import QtQuick
import qs.core.theme
import qs.core.widgets

// Topo de uma página dentro de um card da central: voltar, o título e, à
// direita, o que vier como filho (o liga/desliga do recurso).
Item {
    id: root

    property string title
    default property alias controls: slot.data

    signal back

    width: parent?.width ?? 0
    height: ThemeManager.px(40)

    IconButton {
        id: backButton

        anchors.verticalCenter: parent.verticalCenter
        icon: Icons.chevronLeft
        iconSize: ThemeManager.px(22)
        implicitWidth: ThemeManager.px(36)
        implicitHeight: ThemeManager.px(36)
        radius: ThemeManager.px(18)
        onClicked: root.back()
    }

    Txt {
        anchors.left: backButton.right
        anchors.leftMargin: ThemeManager.spacing.tiny
        anchors.right: slot.left
        anchors.rightMargin: ThemeManager.spacing.small
        anchors.verticalCenter: parent.verticalCenter
        text: root.title
        font.pixelSize: ThemeManager.font.large
        font.weight: Font.DemiBold
    }

    Row {
        id: slot

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: ThemeManager.spacing.small
    }
}
