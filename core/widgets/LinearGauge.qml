import QtQuick
import qs.core.theme

// Barra horizontal: trecho preenchido, uma folga e o resto do trilho, com um
// ponto no fim (como no Caelestia). `value` vai de 0 a 1. O preenchimento
// padrão é o das barras de porcentagem (accentFill), totalmente arredondado.
Item {
    id: root

    property real value: 0
    property color color: ThemeManager.colors.accentFill
    property color trackColor: ThemeManager.colors.track
    property real animatedValue: Math.max(0, Math.min(1, value))
    readonly property real gap: height * 1.2

    Behavior on animatedValue { Anim { type: Anim.StandardLarge } }

    implicitHeight: ThemeManager.px(6)
    implicitWidth: ThemeManager.px(160)

    Rectangle {
        id: fill

        width: Math.max(root.height, (root.width - root.gap) * root.animatedValue)
        height: root.height
        radius: height / 2
        color: root.color
        visible: root.animatedValue > 0.001
    }

    Rectangle {
        x: fill.visible ? fill.width + root.gap : 0
        width: Math.max(0, root.width - x)
        height: root.height
        radius: height / 2
        color: root.trackColor

        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: (parent.height - height) / 2
            anchors.verticalCenter: parent.verticalCenter
            width: parent.height * 0.6
            height: width
            radius: width / 2
            color: root.color
            opacity: 0.8
        }
    }
}
