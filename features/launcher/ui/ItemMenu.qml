pragma ComponentBehavior: Bound
import QtQuick
import qs.core.pixel
import qs.core.theme
import qs.core.widgets
import qs.features.launcher.state

// Menu do clique direito num resultado: as opções do item (fixar, ocultar,
// copiar…), no ponto do clique. Fecha ao escolher, ao clicar fora ou com Esc.
Item {
    id: root

    property var item: null
    readonly property var options: LauncherState.optionsFor(item)
    readonly property bool shown: item !== null && options.length > 0

    // `point` no sistema de coordenadas deste item.
    function openFor(target: var, point: point): void {
        item = target;
        menu.x = Math.min(point.x, width - menu.width - ThemeManager.px(8));
        menu.y = Math.min(point.y, height - menu.height - ThemeManager.px(8));
    }

    function close(): void {
        item = null;
    }

    visible: shown

    // Clique fora fecha.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: root.close()
    }

    Surface {
        id: menu

        width: ThemeManager.px(240)
        height: list.height + ThemeManager.px(12)
        level: 1
        radius: ThemeManager.radius.normal
        border.width: Pixel.hairline(Window.window?.devicePixelRatio ?? 1)
        border.color: ThemeManager.colors.border

        Column {
            id: list

            x: ThemeManager.px(6)
            y: ThemeManager.px(6)
            width: parent.width - ThemeManager.px(12)

            Repeater {
                model: root.options

                delegate: Clickable {
                    id: opt

                    required property var modelData

                    width: list.width
                    height: ThemeManager.px(36)
                    radius: ThemeManager.radius.small + ThemeManager.px(2)
                    onClicked: {
                        opt.modelData.run();
                        root.close();
                    }

                    Icon {
                        id: optIcon

                        anchors.left: parent.left
                        anchors.leftMargin: ThemeManager.spacing.small
                        anchors.verticalCenter: parent.verticalCenter
                        icon: opt.modelData.icon
                        size: ThemeManager.px(18)
                        color: ThemeManager.colors.accent
                    }

                    Txt {
                        anchors.left: optIcon.right
                        anchors.leftMargin: ThemeManager.spacing.normal
                        anchors.verticalCenter: parent.verticalCenter
                        text: opt.modelData.label
                        font.pixelSize: ThemeManager.font.small + 1
                    }

                    Txt {
                        anchors.right: parent.right
                        anchors.rightMargin: ThemeManager.spacing.small
                        anchors.verticalCenter: parent.verticalCenter
                        text: opt.modelData.shortcut
                        faint: true
                        font.pixelSize: ThemeManager.font.small
                    }
                }
            }
        }
    }
}
