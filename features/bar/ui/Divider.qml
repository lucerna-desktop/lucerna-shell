import QtQuick
import qs.core.pixel
import qs.core.theme

// Separador vertical discreto entre os grupos da barra.
Rectangle {
    anchors.verticalCenter: parent.verticalCenter
    width: Pixel.hairline(Window.window?.devicePixelRatio ?? 1)
    height: 16
    color: ThemeManager.colors.border
    opacity: 0.8
}
