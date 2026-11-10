pragma ComponentBehavior: Bound

import QtQuick
import qs.core.theme
import qs.core.widgets

// O espectro em volta de uma capa redonda: barrinhas radiais, uma por faixa de
// frequência, que saem da borda do círculo (`innerSize`) até a borda do item
// (`size`). Espelhado, o espectro dá a volta duas vezes (as graves em cima, as
// agudas embaixo, simétrico), com o dobro de barras da mesma assinatura. Sem
// quadro, cada barra fica na altura de repouso.
// `live` falso (pausado, fora da tela) recolhe as barras, suave.
// A capa vai por cima, a cargo de quem usa.
Item {
    id: root

    // Lado do item e diâmetro da capa.
    required property real size
    required property real innerSize
    // [0..1] por faixa, já na escala de quem olha (Spectrum.values).
    required property var values
    required property int bands
    required property bool live
    property bool mirrored: false
    property real barWidth: ThemeManager.px(3)

    readonly property int count: mirrored ? bands * 2 : bands
    readonly property real barStart: innerSize / 2 + Math.max(ThemeManager.px(3), size * 0.03)
    readonly property real barReach: size / 2 - barStart

    // 1 tocando, 0 pausado: as barras sobem e recolhem suave.
    property real gain: live ? 1 : 0

    Behavior on gain { Anim { type: Anim.Standard } }

    width: size
    height: size

    Repeater {
        model: root.count

        delegate: Item {
            id: bar

            required property int index
            // Espelhado: a segunda volta lê as faixas de trás para frente.
            readonly property int band: bar.index < root.bands ? bar.index : root.count - 1 - bar.index
            readonly property real level: root.values[bar.band] ?? 0

            anchors.fill: parent
            rotation: bar.index * 360 / root.count

            Rectangle {
                x: (root.size - width) / 2
                y: root.size / 2 - root.barStart - height
                width: root.barWidth
                height: root.barWidth * 0.7 + root.gain * bar.level * (root.barReach - root.barWidth * 0.7)
                radius: root.barWidth / 2
                color: ThemeManager.colors.accent
                opacity: 0.85
            }
        }
    }
}
