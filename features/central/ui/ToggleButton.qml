import QtQuick
import qs.core.theme
import qs.core.widgets

// Botão de texto da central: no tom de contêiner do acento quando ligado,
// vazio quando desligado. Quem usa dá o tamanho.
Clickable {
    id: root

    property string label
    property bool checked: false

    active: checked
    radius: ThemeManager.radius.normal
    pressScale: 0.94
    color: checked ? ThemeManager.colors.accentContainer : ThemeManager.alpha(ThemeManager.colors.text, 0.06)

    Txt {
        anchors.centerIn: parent
        width: Math.min(implicitWidth, root.width - ThemeManager.spacing.small * 2)
        horizontalAlignment: Text.AlignHCenter
        text: root.label
        font.weight: root.checked ? Font.DemiBold : Font.Medium
        color: root.checked ? ThemeManager.colors.onAccentContainer : ThemeManager.colors.textMuted

        Behavior on color { ColorAnim {} }
    }
}
