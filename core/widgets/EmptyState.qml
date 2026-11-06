import QtQuick
import qs.core.theme

// Estado vazio de uma seção: forma orgânica com ícone e uma frase.
Column {
    id: root

    property string icon
    property string text

    width: parent?.width ?? 0
    topPadding: ThemeManager.spacing.large * 2
    spacing: ThemeManager.spacing.normal

    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        width: ThemeManager.px(88)
        height: ThemeManager.px(88)

        Blob {
            anchors.fill: parent
            lobes: 7
            amplitude: 0.06
            color: ThemeManager.colors.track
            spinning: parent.visible
            spinDuration: 30000
        }

        Icon {
            anchors.centerIn: parent
            icon: root.icon
            size: ThemeManager.px(36)
            color: ThemeManager.colors.textFaint
        }
    }

    Txt {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: parent.text
        faint: true
    }
}
