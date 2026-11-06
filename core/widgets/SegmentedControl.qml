pragma ComponentBehavior: Bound

import QtQuick
import qs.core.pixel
import qs.core.theme

// Botões segmentados: uma escolha entre poucas opções. A seleção é uma pílula
// que desliza com mola até a opção escolhida.
// options: [{ label, value, icon? }]
Item {
    id: root

    required property var options
    property var value

    signal selected(var value)

    readonly property int currentIndex: options.findIndex(o => o.value === value)

    implicitHeight: 40
    implicitWidth: row.implicitWidth

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: ThemeManager.alpha(ThemeManager.colors.text, 0.05)
        border.width: ThemeManager.outlines ? Pixel.hairline(Window.window?.devicePixelRatio ?? 1) : 0
        border.color: ThemeManager.colors.border
    }

    Rectangle {
        readonly property Item target: buttons.count > 0 ? buttons.itemAt(root.currentIndex) : null

        visible: target !== null
        x: (target?.x ?? 0) + 3
        y: 3
        width: (target?.width ?? 0) - 6
        height: parent.height - 6
        radius: height / 2
        color: ThemeManager.alpha(ThemeManager.colors.accent, 0.2)

        Behavior on x { Anim { type: Anim.FastSpatial } }
        Behavior on width { Anim { type: Anim.FastSpatial } }
    }

    Row {
        id: row

        anchors.fill: parent

        Repeater {
            id: buttons

            model: root.options

            delegate: Clickable {
                id: option

                required property var modelData
                required property int index
                readonly property bool current: index === root.currentIndex

                width: root.width > 0 ? root.width / root.options.length : content.implicitWidth + 32
                height: root.height
                radius: height / 2
                onClicked: root.selected(modelData.value)

                Row {
                    id: content

                    anchors.centerIn: parent
                    spacing: 6

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: option.current
                        icon: Icons.check
                        size: 16
                        color: ThemeManager.colors.accent
                    }

                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: option.modelData.label
                        color: option.current ? ThemeManager.colors.accent : ThemeManager.colors.text
                        font.pixelSize: ThemeManager.font.small + 1
                        font.weight: option.current ? Font.DemiBold : Font.Normal

                        Behavior on color { ColorAnim {} }
                    }
                }
            }
        }
    }
}
