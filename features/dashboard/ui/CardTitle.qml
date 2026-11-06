pragma ComponentBehavior: Bound

import QtQuick
import qs.core.theme
import qs.core.widgets

// Título dos cards da aba Desempenho: ícone de acento e o texto numa linha
// (cortado com "…" se não couber em `width`); com mais de um em `dots`, as
// bolinhas mostram qual (`dot`) está na tela.
Row {
    id: root

    property string icon: ""
    property string text: ""
    property int dots: 0
    property int dot: 0

    spacing: ThemeManager.spacing.small

    Icon {
        id: titleIcon

        anchors.verticalCenter: parent.verticalCenter
        icon: root.icon
        size: ThemeManager.px(18)
        color: ThemeManager.colors.accent
    }

    Txt {
        anchors.verticalCenter: parent.verticalCenter
        width: root.width - titleIcon.width - root.spacing - (dotsRow.visible ? dotsRow.width + root.spacing : 0)
        text: root.text
    }

    Row {
        id: dotsRow

        anchors.verticalCenter: parent.verticalCenter
        visible: root.dots > 1
        spacing: ThemeManager.px(4)

        Repeater {
            model: root.dots

            delegate: Rectangle {
                id: dotItem

                required property int index

                width: ThemeManager.px(6)
                height: ThemeManager.px(6)
                radius: width / 2
                color: dotItem.index === root.dot ? ThemeManager.colors.accent : ThemeManager.colors.track
            }
        }
    }
}
