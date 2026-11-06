import QtQuick
import qs.core.theme

// Grupo de opções: título discreto e um cartão com as linhas, separadas por fios.
Column {
    id: root

    property string title
    default property alias rows: list.data

    width: parent?.width ?? 0
    spacing: ThemeManager.spacing.small

    Txt {
        visible: root.title !== ""
        text: root.title.toUpperCase()
        faint: true
        font.pixelSize: ThemeManager.font.small
        font.weight: Font.DemiBold
        font.letterSpacing: 1
        leftPadding: ThemeManager.px(4)
    }

    Surface {
        width: parent.width
        height: list.implicitHeight
        radius: ThemeManager.radius.large

        Column {
            id: list

            width: parent.width
        }
    }
}
