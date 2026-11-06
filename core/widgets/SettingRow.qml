import QtQuick
import qs.core.pixel
import qs.core.theme

// Uma linha de opção: ícone, título, descrição e o controle à direita.
// `wide` põe o controle embaixo do texto, ocupando a largura (para sliders).
Item {
    id: root

    property string icon
    property string title
    property string description
    property bool wide: false
    property bool dimmed: false
    property bool separator: true
    default property alias control: slot.data

    width: parent?.width ?? 0
    implicitHeight: (wide ? labels.height + slot.childrenRect.height + ThemeManager.spacing.normal : Math.max(labels.height, slot.childrenRect.height)) + ThemeManager.spacing.large * 1.4
    opacity: dimmed ? 0.45 : 1

    Behavior on opacity { Anim { type: Anim.Effects } }


    Rectangle {
        visible: root.separator && root.y > 0
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: ThemeManager.spacing.large
        anchors.rightMargin: ThemeManager.spacing.large
        height: Pixel.hairline(Window.window?.devicePixelRatio ?? 1)
        color: ThemeManager.colors.border
        opacity: 0.6
    }

    Icon {
        id: glyph

        visible: root.icon !== ""
        x: ThemeManager.spacing.large
        y: labels.y + 1
        icon: root.icon
        size: ThemeManager.px(22)
        color: ThemeManager.colors.textMuted
    }

    Column {
        id: labels

        anchors.left: glyph.visible ? glyph.right : parent.left
        anchors.leftMargin: glyph.visible ? ThemeManager.spacing.normal : ThemeManager.spacing.large
        anchors.right: root.wide ? parent.right : slot.left
        anchors.rightMargin: ThemeManager.spacing.large
        anchors.verticalCenter: root.wide ? undefined : parent.verticalCenter
        y: ThemeManager.spacing.large * 0.7
        spacing: ThemeManager.px(2)

        Txt {
            width: parent.width
            text: root.title
            font.weight: Font.Medium
        }

        Txt {
            width: parent.width
            visible: root.description !== ""
            text: root.description
            muted: true
            wrapMode: Text.Wrap
            font.pixelSize: ThemeManager.font.small + 1
        }
    }

    Item {
        id: slot

        anchors.right: parent.right
        anchors.rightMargin: ThemeManager.spacing.large
        // Largo: o controle ocupa o cartão de borda a borda (mesma margem dos
        // dois lados), não começa alinhado ao texto — senão fica torto à direita.
        anchors.left: root.wide ? parent.left : undefined
        anchors.leftMargin: ThemeManager.spacing.large
        anchors.verticalCenter: root.wide ? undefined : parent.verticalCenter
        y: labels.y + labels.height + ThemeManager.spacing.normal
        width: root.wide ? undefined : childrenRect.width
        height: childrenRect.height
    }
}
