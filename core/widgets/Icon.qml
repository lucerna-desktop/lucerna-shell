import QtQuick
import qs.core.theme

// Ícone da fonte Material Symbols. Os nomes ficam em Icons.qml.
// `filled` preenche o ícone com animação, para estados ativos.
Text {
    id: root

    property string icon
    property int size: ThemeManager.font.large + ThemeManager.px(4)
    property bool filled: false
    property int weight: 400
    property real fill: filled ? 1 : 0

    Behavior on fill { Anim { type: Anim.FastEffects } }

    text: icon
    color: ThemeManager.colors.text
    font.family: ThemeManager.font.icon
    font.pixelSize: size
    // Arredondado a um décimo para não recriar a fonte a cada quadro da animação.
    font.variableAxes: ({
        FILL: Math.round(fill * 10) / 10,
        wght: weight,
        GRAD: ThemeManager.dark ? -25 : 0,
        opsz: Math.max(20, Math.min(48, size))
    })
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
