import QtQuick
import qs.core.format
import qs.core.theme
import qs.core.widgets

// Uma linha de nível: o ícone (ou a imagem do app) à esquerda, o slider e a
// porcentagem à direita. Com `iconClickable`, o ícone é um botão (silenciar).
// Com `label` (o nome do app, quando ele não tem ícone), o nome fica pequeno
// em cima do slider.
// Controlado: emite `moved` e `iconClicked`; quem usa decide `value`.
Item {
    id: root

    property string icon
    // Imagem no lugar do ícone (a de um aplicativo); "" usa `icon`.
    property string image
    property string label
    property real value: 0
    property real from: 0
    property bool muted: false
    property bool iconClickable: false

    signal moved(real value)
    signal iconClicked

    width: parent?.width ?? 0
    height: label ? ThemeManager.px(52) : ThemeManager.px(44)

    Clickable {
        id: tile

        x: ThemeManager.spacing.tiny
        anchors.verticalCenter: parent.verticalCenter
        width: ThemeManager.px(36)
        height: ThemeManager.px(36)
        radius: ThemeManager.radius.small
        enabled: root.iconClickable
        opacity: 1
        onClicked: root.iconClicked()

        Image {
            anchors.centerIn: parent
            visible: root.image !== ""
            width: ThemeManager.px(24)
            height: ThemeManager.px(24)
            source: root.image
            sourceSize: Qt.size(ThemeManager.px(48), ThemeManager.px(48))
            asynchronous: true
            opacity: root.muted ? 0.35 : 1
        }

        Icon {
            anchors.centerIn: parent
            visible: root.image === ""
            icon: root.icon
            size: ThemeManager.px(20)
            filled: tile.hovered
            color: root.muted ? ThemeManager.colors.textFaint : ThemeManager.colors.textMuted
        }

        // O mudo por cima da imagem do app.
        Icon {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            visible: root.image !== "" && root.muted
            icon: Icons.volumeOff
            size: ThemeManager.px(14)
            color: ThemeManager.colors.text
        }
    }

    Txt {
        anchors.left: slider.left
        anchors.right: slider.right
        y: ThemeManager.spacing.tiny
        visible: root.label !== ""
        text: root.label
        muted: true
        font.pixelSize: ThemeManager.font.small
    }

    Slider {
        id: slider

        anchors.left: tile.right
        anchors.leftMargin: ThemeManager.spacing.small
        anchors.right: percent.left
        anchors.rightMargin: ThemeManager.spacing.small
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: root.label ? ThemeManager.px(8) : 0
        from: root.from
        value: root.value
        opacity: root.muted ? 0.5 : 1
        onMoved: v => root.moved(v)
    }

    Txt {
        id: percent

        anchors.right: parent.right
        anchors.rightMargin: ThemeManager.spacing.small
        anchors.verticalCenter: slider.verticalCenter
        width: ThemeManager.px(40)
        horizontalAlignment: Text.AlignRight
        text: Format.percent(root.value)
        mono: true
        muted: true
        font.pixelSize: ThemeManager.font.small + 1
    }
}
