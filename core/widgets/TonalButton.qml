import QtQuick
import qs.core.theme

// Botão "tonal" do Material 3: pílula preenchida com um tom do acento, sem
// contorno. Para ações secundárias (restaurar, testar...).
Clickable {
    id: root

    property alias icon: glyph.icon
    property alias text: caption.text

    implicitWidth: row.implicitWidth + ThemeManager.spacing.large * 2
    implicitHeight: ThemeManager.px(40)
    radius: height / 2
    pressScale: 0.96
    color: ThemeManager.alpha(ThemeManager.colors.accent, 0.16)

    Row {
        id: row

        anchors.centerIn: parent
        spacing: ThemeManager.spacing.small

        Icon {
            id: glyph

            anchors.verticalCenter: parent.verticalCenter
            visible: icon !== ""
            size: ThemeManager.px(18)
            filled: root.hovered
            color: ThemeManager.colors.accent
        }

        Txt {
            id: caption

            anchors.verticalCenter: parent.verticalCenter
            color: ThemeManager.colors.accent
            font.pixelSize: ThemeManager.font.small + 1
            font.weight: Font.DemiBold
        }
    }
}
