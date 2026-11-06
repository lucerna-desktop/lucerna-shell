pragma ComponentBehavior: Bound

import QtQuick
import qs.core.pixel
import qs.core.theme

// Abas com ícone e rótulo. O indicador desliza e estica até a aba atual, e o
// ícone da aba atual fica preenchido.
Item {
    id: root

    // [{ icon, label }]
    required property var tabs
    property int currentIndex: 0
    // Largura do rótulo da aba atual, para o indicador: a aba atual escreve aqui
    // (o Binding do delegate). O repeater.itemAt devolve Item, que não tem labelWidth.
    property real currentLabelWidth: ThemeManager.px(40)

    signal activated(int index)

    implicitHeight: ThemeManager.px(52)

    Row {
        id: row

        anchors.fill: parent

        Repeater {
            id: repeater

            model: root.tabs

            delegate: Clickable {
                id: tab

                required property var modelData
                required property int index
                readonly property bool current: index === root.currentIndex
                readonly property real labelWidth: label.width

                width: row.width / root.tabs.length
                height: row.height
                radius: ThemeManager.radius.normal
                onClicked: root.activated(index)

                // Só a aba atual escreve. RestoreNone: ao deixar de ser a atual, a
                // aba não devolve o valor antigo por cima do que a nova escreveu.
                Binding {
                    target: root
                    property: "currentLabelWidth"
                    value: tab.labelWidth
                    when: tab.current
                    restoreMode: Binding.RestoreNone
                }

                Column {
                    anchors.centerIn: parent
                    spacing: ThemeManager.px(2)

                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        icon: tab.modelData.icon
                        filled: tab.current || tab.hovered
                        color: tab.current ? ThemeManager.colors.accent : ThemeManager.colors.textMuted

                        Behavior on color { ColorAnim {} }
                    }

                    Txt {
                        id: label

                        anchors.horizontalCenter: parent.horizontalCenter
                        text: tab.modelData.label
                        color: tab.current ? ThemeManager.colors.accent : ThemeManager.colors.textMuted
                        font.pixelSize: ThemeManager.font.small + 1

                        Behavior on color { ColorAnim {} }
                    }
                }
            }
        }
    }

    // Indicador: a largura do rótulo da aba atual, colado embaixo.
    Rectangle {
        // A aba atual, para a posição (x, logo abaixo); a largura vem do root.
        readonly property Item target: repeater.count > 0 ? repeater.itemAt(root.currentIndex) : null
        readonly property real targetWidth: Math.max(ThemeManager.px(28), root.currentLabelWidth + ThemeManager.px(12))

        anchors.bottom: parent.bottom
        x: target ? target.x + (target.width - width) / 2 : 0
        width: targetWidth
        height: ThemeManager.px(3)
        radius: height / 2
        color: ThemeManager.colors.accent

        Behavior on x { Anim { type: Anim.Spatial } }
        Behavior on width { Anim { type: Anim.FastSpatial } }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: Pixel.hairline(Window.window?.devicePixelRatio ?? 1)
        color: ThemeManager.colors.border
        z: -1
    }
}
