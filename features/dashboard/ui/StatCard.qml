pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import qs.core.theme
import qs.core.widgets

// Card da aba Desempenho para a CPU e a GPU: o título numa linha (ícone e texto, cortado com
// "…" se não couber), um véu claro da esquerda até `fraction`, o valor grande à
// direita com a bolha que muda de forma atrás e a temperatura com a barrinha
// embaixo (some sem leitura). Com `clickable`, o clique emite `swapped` (quem
// usa troca o que mostra na hora; cada clique conta) e o conteúdo novo
// aparece esmaecendo; as bolinhas do título mostram qual de `dots` está na
// tela.
Surface {
    id: root

    property string icon: ""
    property string title: ""
    property real fraction: 0
    property string label: ""
    property string value: ""
    // Unidade de uma letra ("%") fica ao lado do número; mais comprida
    // ("MHz"), embaixo.
    property string unit: ""
    property bool hasTemp: false
    property string tempText: ""
    property real tempFraction: 0
    property bool hot: false
    property real pulse: 0
    // Falso pausa a bolha (aba fora da tela, GPU em repouso) sem mudar a forma.
    property bool blobActive: true
    // O relógio da bolha, para mudar de forma junto com a de outro card.
    property BlobMorph blobDriver: null
    property bool clickable: false
    property int dots: 0
    property int dot: 0

    signal swapped

    readonly property int margin: ThemeManager.spacing.normal + ThemeManager.px(2)
    // Onde acaba a área da esquerda: antes do rótulo, se há, ou da bolha.
    readonly property real leftLimit: label ? valueLabel.x : blobBox.x
    readonly property bool stackUnit: unit.length > 1
    // Um tamanho só para a bolha de todo card, que cabe o pior caso, "100%" ou
    // "0000" com "MHz" embaixo, com folga; 64 px no mínimo. Não muda com o
    // valor, nem com a troca de GPU, nem de um card para o outro.
    readonly property real blobSize: Math.max(ThemeManager.px(64), Math.ceil(Math.max(percentMetrics.advanceWidth + percentUnitMetrics.advanceWidth, clockMetrics.advanceWidth, clockUnitMetrics.advanceWidth)) + ThemeManager.px(20))

    implicitHeight: Math.max(margin * 2 + titleRow.height + ThemeManager.spacing.normal + (root.hasTemp ? temp.height : 0), blobSize + margin * 2)

    AnimatedNumber {
        id: shownFraction

        value: Math.max(0, Math.min(1, root.fraction))
    }

    TextMetrics {
        id: percentMetrics

        font: number.font
        text: "100"
    }

    TextMetrics {
        id: percentUnitMetrics

        font: unitText.font
        text: "%"
    }

    TextMetrics {
        id: clockMetrics

        font: number.font
        text: "0000"
    }

    // Também dá a altura das letras da unidade (tightBoundingRect: "MHz" não
    // desce da linha de base), para pô-la logo abaixo do número.
    TextMetrics {
        id: clockUnitMetrics

        font: unitText.font
        text: "MHz"
    }

    // A troca só no visual: o conteúdo novo vem de quase apagado.
    Anim {
        id: swap

        target: content
        property: "opacity"
        from: 0.2
        to: 1
        type: Anim.FastEffects
    }

    Item {
        id: content

        anchors.fill: parent

        // O véu, recortado no formato do card, dentro da borda.
        ClippingRectangle {
            anchors.fill: parent
            anchors.margins: root.border.width
            radius: root.radius - root.border.width
            color: "transparent"

            Rectangle {
                width: parent.width * shownFraction.shown
                height: parent.height
                color: ThemeManager.alpha(ThemeManager.colors.text, 0.1)
            }
        }

        CardTitle {
            id: titleRow

            x: root.margin
            y: root.margin
            width: root.leftLimit - x - ThemeManager.spacing.normal
            icon: root.icon
            text: root.title
            dots: root.dots
            dot: root.dot
        }

        Column {
            id: temp

            x: root.margin
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.margin
            visible: root.hasTemp
            spacing: ThemeManager.spacing.small

            Row {
                spacing: ThemeManager.spacing.small

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Icons.temperature
                    size: ThemeManager.px(18)
                    color: root.hot ? ThemeManager.colors.danger : ThemeManager.colors.textMuted
                }

                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.tempText
                    mono: true
                }
            }

            LinearGauge {
                width: Math.min(ThemeManager.px(220), root.leftLimit - root.margin - ThemeManager.spacing.normal)
                value: root.tempFraction
                // O trilho padrão tem a cor do véu do uso e some por cima dele; o texto
                // com transparência aparece sobre o véu e sobre o fundo, em todos os temas.
                trackColor: ThemeManager.alpha(ThemeManager.colors.text, 0.2)
                color: root.hot ? ThemeManager.colors.danger : ThemeManager.colors.accent
            }
        }

        Txt {
            id: valueLabel

            anchors.right: blobBox.left
            anchors.rightMargin: ThemeManager.spacing.small
            anchors.verticalCenter: blobBox.verticalCenter
            text: root.label
            muted: true
            font.pixelSize: ThemeManager.font.small + 1
        }

        Item {
            id: blobBox

            anchors.right: parent.right
            anchors.rightMargin: root.margin
            anchors.verticalCenter: parent.verticalCenter
            width: root.blobSize
            height: root.blobSize

            Blob {
                anchors.fill: parent
                morphing: true
                active: root.blobActive
                driver: root.blobDriver
                steps: 72
                pulse: root.pulse
                color: ThemeManager.alpha(ThemeManager.colors.accent, 0.16)
                spinning: true
                spinDuration: 30000
            }

            Item {
                anchors.centerIn: parent
                width: root.stackUnit ? Math.max(number.width, unitText.width) : number.width + unitText.width
                height: root.stackUnit ? unitText.y + unitText.height : number.height

                Txt {
                    id: number

                    x: root.stackUnit ? (parent.width - width) / 2 : 0
                    text: root.value
                    mono: true
                    font.pixelSize: ThemeManager.font.large + ThemeManager.px(10)
                    font.weight: Font.DemiBold
                }

                Txt {
                    id: unitText

                    x: root.stackUnit ? (parent.width - width) / 2 : number.width
                    // Embaixo: o topo das letras 3 px abaixo da linha de
                    // base do número (os algarismos não descem dela); ao lado:
                    // na mesma linha de base.
                    y: root.stackUnit ? number.baselineOffset + ThemeManager.px(3) - (baselineOffset - clockUnitMetrics.tightBoundingRect.height) : number.baselineOffset - baselineOffset
                    text: root.unit
                    muted: true
                    font.pixelSize: ThemeManager.font.small + 1
                    font.weight: Font.Medium
                }
            }
        }
    }

    Clickable {
        anchors.fill: parent
        visible: root.clickable
        radius: root.radius
        onClicked: {
            root.swapped();
            swap.restart();
        }
    }
}
