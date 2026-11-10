import QtQuick
import qs.core.pixel
import qs.core.theme

// Uma linha de opção: ícone, título, descrição e o controle à direita.
// `wide` põe o controle embaixo do texto, ocupando a largura (para sliders).
// `dimmed` marca a opção que não vale agora: o título e a descrição passam a
// um tom apagado que ainda fica a 4,5:1 do cartão (ThemeManager.dimmedOn do
// textMuted sobre o raised, o fundo mais claro dos cartões nos escuros e o
// mais escuro nos claros) e o ícone ao textFaint, sem opacidade sobre o
// texto. O controle, sem um desativado próprio (Switch, SegmentedControl),
// ainda leva a opacidade; com `dimsControl: false`, ele mostra o próprio
// estado (a LevelSlider com `enabled: false`, cujo nome e valor são texto).
Item {
    id: root

    property string icon
    property string title
    property string description
    property bool wide: false
    property bool dimmed: false
    property bool dimsControl: true
    property bool separator: true
    default property alias control: slot.data
    readonly property color dimColor: ThemeManager.dimmedOn(ThemeManager.colors.textMuted, ThemeManager.colors.raised)

    width: parent?.width ?? 0
    implicitHeight: (wide ? labels.height + slot.childrenRect.height + ThemeManager.spacing.normal : Math.max(labels.height, slot.childrenRect.height)) + ThemeManager.spacing.large * 1.4

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
        color: root.dimmed ? ThemeManager.colors.textFaint : ThemeManager.colors.textMuted
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
            color: root.dimmed ? root.dimColor : ThemeManager.colors.text
            font.weight: Font.Medium
        }

        Txt {
            width: parent.width
            visible: root.description !== ""
            text: root.description
            color: root.dimmed ? root.dimColor : ThemeManager.colors.textMuted
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
        opacity: root.dimmed && root.dimsControl ? 0.45 : 1

        Behavior on opacity { Anim { type: Anim.Effects } }
    }
}
