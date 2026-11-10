import QtQuick
import qs.core.theme
import qs.core.widgets

// Item de lista clicável: ícone num ladrilho, título, detalhe e controles à direita.
// `lit` acende o ladrilho (rede conectada, dispositivo em uso, saída atual): o
// tom de contêiner, com o ícone na cor de acento.
Clickable {
    id: root

    property string icon
    property string title
    property string detail
    property bool lit: false
    property bool busy: false
    default property alias trailing: slot.data

    width: parent?.width ?? 0
    height: ThemeManager.px(58)
    radius: ThemeManager.radius.normal + ThemeManager.px(2)

    Rectangle {
        id: tile

        x: ThemeManager.spacing.small
        anchors.verticalCenter: parent.verticalCenter
        width: ThemeManager.px(40)
        height: ThemeManager.px(40)
        radius: root.lit ? ThemeManager.px(20) : ThemeManager.radius.normal
        color: root.lit ? ThemeManager.colors.accentContainer : ThemeManager.alpha(ThemeManager.colors.text, 0.06)

        Behavior on radius { Anim { type: Anim.FastSpatial } }
        Behavior on color { ColorAnim {} }

        Icon {
            id: glyph

            anchors.centerIn: parent
            icon: root.icon
            size: ThemeManager.px(20)
            filled: root.lit || root.hovered
            color: root.lit ? ThemeManager.colors.accentIcon : ThemeManager.colors.textMuted

            // Gira enquanto conecta/pareia.
            RotationAnimation on rotation {
                running: root.busy
                from: 0
                to: 360
                duration: 1400
                loops: Animation.Infinite
                onStopped: glyph.rotation = 0
            }
        }
    }

    Column {
        anchors.left: tile.right
        anchors.leftMargin: ThemeManager.spacing.normal
        anchors.right: slot.left
        anchors.rightMargin: ThemeManager.spacing.small
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Txt {
            width: parent.width
            text: root.title
            font.weight: root.lit ? Font.DemiBold : Font.Normal
        }

        Txt {
            width: parent.width
            visible: root.detail !== ""
            text: root.detail
            muted: !root.lit
            color: root.lit ? ThemeManager.colors.accent : ThemeManager.colors.textMuted
            font.pixelSize: ThemeManager.font.small
        }
    }

    Row {
        id: slot

        anchors.right: parent.right
        anchors.rightMargin: ThemeManager.spacing.small
        anchors.verticalCenter: parent.verticalCenter
        spacing: ThemeManager.px(2)
    }
}
