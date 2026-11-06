import QtQuick
import qs.core.theme
import qs.core.widgets

// Uma linha de resultado: ícone do app (ou glifo da ação), nome e descrição.
Clickable {
    id: row

    required property var result
    property bool selected: false
    // Posição na lista, para o atraso da entrada em cascata.
    property int order: 0

    height: ThemeManager.px(48)
    radius: ThemeManager.radius.normal
    color: "transparent"

    // Entra suave, e com um leve atraso por posição (efeito cascata).
    opacity: 0
    Component.onCompleted: fadeIn.start()

    SequentialAnimation {
        id: fadeIn

        PauseAnimation {
            duration: Math.min(row.order, 8) * 18
        }

        Anim {
            target: row
            property: "opacity"
            to: 1
            type: Anim.FastEffects
        }
    }

    ItemIcon {
        id: iconBox

        anchors.left: parent.left
        anchors.leftMargin: ThemeManager.spacing.small
        anchors.verticalCenter: parent.verticalCenter
        item: row.result
        size: ThemeManager.px(32)
        highlighted: row.selected
    }

    Column {
        anchors {
            left: iconBox.right
            right: arrow.left
            leftMargin: ThemeManager.spacing.normal
            rightMargin: ThemeManager.spacing.small
            verticalCenter: parent.verticalCenter
        }

        Txt {
            width: parent.width
            text: row.result.name
            font.weight: row.selected ? Font.DemiBold : Font.Normal
        }

        Txt {
            width: parent.width
            visible: text !== ""
            text: row.result.description
            muted: true
            font.pixelSize: ThemeManager.font.small
        }
    }

    Icon {
        id: arrow

        anchors.right: parent.right
        anchors.rightMargin: ThemeManager.spacing.normal
        anchors.verticalCenter: parent.verticalCenter
        icon: Icons.arrowRight
        size: ThemeManager.px(14)
        color: ThemeManager.colors.accent
        opacity: row.selected ? 1 : 0

        Behavior on opacity { Anim { type: Anim.FastEffects } }
    }
}
