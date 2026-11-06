import QtQuick
import qs.core.pixel
import qs.core.theme

// Cartão/painel com o fundo, a borda e o raio do tema. `level` 0 é um painel
// solto na tela; 1 (padrão) é um cartão dentro de outro painel. Os dois ficam
// translúcidos conforme a transparência do tema.
Rectangle {
    property bool raisedLevel: false
    property int level: 1

    color: ThemeManager.glass(raisedLevel ? ThemeManager.colors.raised : ThemeManager.colors.surface, level)
    radius: ThemeManager.radius.large
    border.color: ThemeManager.colors.border
    border.width: ThemeManager.outlines ? Pixel.hairline(Window.window?.devicePixelRatio ?? 1) : 0
}
