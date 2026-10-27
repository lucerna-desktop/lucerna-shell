import QtQuick
import qs.core.format
import qs.core.theme
import qs.core.widgets

// Card da aba Desempenho para a memória e o disco: o título no padrão do
// StatCard (CardTitle), o anel com a porcentagem dentro e, embaixo, o rótulo
// (`label`, "usado / total"). Com `clickable`, o clique emite `swapped` e o
// conteúdo novo aparece esmaecendo, como no StatCard.
Surface {
    id: root

    property string icon: ""
    property string title: ""
    property real fraction: 0
    property string label: ""
    // O mesmo tamanho na memória e no disco: o título, o anel e o rótulo
    // alinhados entre os dois cards.
    property real gaugeSize: 109
    property real thickness: 9
    property real numberSize: ThemeManager.font.large + 6
    property bool clickable: false
    property int dots: 0
    property int dot: 0

    signal swapped

    readonly property int margin: ThemeManager.spacing.normal + 2

    implicitHeight: margin * 2 + titleRow.height + ThemeManager.spacing.tiny + body.height

    AnimatedNumber {
        id: shown

        value: root.fraction
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

        CardTitle {
            id: titleRow

            x: root.margin
            y: root.margin
            width: parent.width - root.margin * 2
            icon: root.icon
            text: root.title
            dots: root.dots
            dot: root.dot
        }

        // Anel e rótulo no centro do que sobra abaixo do título.
        Column {
            id: body

            anchors.horizontalCenter: parent.horizontalCenter
            y: titleRow.y + titleRow.height + ThemeManager.spacing.tiny + Math.max(0, (parent.height - root.margin - titleRow.y - titleRow.height - ThemeManager.spacing.tiny - height) / 2)
            spacing: 2

            CircularGauge {
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.gaugeSize
                height: root.gaugeSize
                thickness: root.thickness
                value: root.fraction

                Txt {
                    anchors.centerIn: parent
                    text: Format.percent(shown.shown)
                    mono: true
                    font.pixelSize: root.numberSize
                    font.weight: Font.DemiBold
                }
            }

            Txt {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.label
                muted: true
                font.pixelSize: ThemeManager.font.small
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
