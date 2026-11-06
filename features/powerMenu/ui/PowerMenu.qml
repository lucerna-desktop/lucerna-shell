pragma ComponentBehavior: Bound

import QtQuick
import qs.core.pixel
import qs.core.theme
import qs.core.widgets
import qs.features.powerMenu.state

// Menu de energia: setas escolhem, Enter aciona. Sair, reiniciar e desligar
// pedem confirmação (segundo Enter ou clique).
OverlayPanel {
    id: panel

    name: "power"
    open: PowerMenuState.open
    screen: PowerMenuState.screen
    onDismissed: PowerMenuState.close()

    property int selected: 0

    onSelectedChanged: PowerMenuState.cancel()

    onOpenChanged: {
        if (open) {
            selected = 0;
            row.forceActiveFocus();
        }
    }

    Surface {
        level: 0
        x: panel.snap((parent.width - width) / 2)
        y: panel.snap((parent.height - height) / 2 + (1 - panel.progress) * 24)
        width: column.implicitWidth + ThemeManager.spacing.large * 2
        height: column.implicitHeight + ThemeManager.spacing.large * 2

        Column {
            id: column

            anchors.centerIn: parent
            spacing: ThemeManager.spacing.normal

            Item {
                width: row.width
                height: row.height

                // Anel de seleção que desliza até o botão escolhido.
                Rectangle {
                    readonly property Item target: buttons.count > 0 ? buttons.itemAt(panel.selected) : null
                    readonly property bool confirming: PowerMenuState.pending !== ""

                    x: (target?.x ?? 0) - 3
                    y: -3
                    width: (target?.width ?? 0) + 6
                    height: (target?.height ?? 0) + 6
                    radius: ThemeManager.radius.normal + 3
                    color: "transparent"
                    border.width: 2
                    border.color: confirming ? ThemeManager.colors.danger : ThemeManager.colors.accent

                    Behavior on x { Anim { type: Anim.FastSpatial } }
                    Behavior on border.color { ColorAnim {} }
                }

                Row {
                    id: row

                    spacing: ThemeManager.spacing.small
                    focus: true

                    Keys.onPressed: event => {
                        const count = PowerMenuState.actions.length;
                        if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab)
                            panel.selected = (panel.selected + 1) % count;
                        else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab)
                            panel.selected = (panel.selected - 1 + count) % count;
                        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
                            PowerMenuState.trigger(PowerMenuState.actions[panel.selected].id);
                        else
                            return;
                        event.accepted = true;
                    }

                    Repeater {
                        id: buttons

                        model: PowerMenuState.actions

                        delegate: Clickable {
                            id: button

                            required property var modelData
                            required property int index
                            readonly property bool confirming: PowerMenuState.pending === modelData.id
                            readonly property bool current: index === panel.selected

                            width: 104
                            height: 104
                            radius: ThemeManager.radius.normal
                            pressScale: 0.92
                            color: confirming ? ThemeManager.alpha(ThemeManager.colors.danger, 0.18)
                                : current ? ThemeManager.alpha(ThemeManager.colors.accent, 0.12)
                                : ThemeManager.glass(ThemeManager.colors.raised, 1)
                            border.width: ThemeManager.outlines ? Pixel.hairline(Window.window?.devicePixelRatio ?? 1) : 0
                            border.color: ThemeManager.colors.border
                            onHoveredChanged: {
                                if (hovered)
                                    panel.selected = index;
                            }
                            onClicked: PowerMenuState.trigger(modelData.id)

                            Column {
                                anchors.centerIn: parent
                                spacing: ThemeManager.spacing.small

                                Icon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    icon: button.modelData.icon
                                    size: 30
                                    color: button.confirming ? ThemeManager.colors.danger : button.current ? ThemeManager.colors.accent : ThemeManager.colors.text
                                }

                                Txt {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: button.confirming ? "Confirmar?" : button.modelData.name
                                    color: button.confirming ? ThemeManager.colors.danger : ThemeManager.colors.text
                                    font.pixelSize: ThemeManager.font.small
                                }
                            }
                        }
                    }
                }

            }

            Txt {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: PowerMenuState.devMode
                text: "Modo de desenvolvimento: suspender, reiniciar e desligar são simulados"
                faint: true
                font.pixelSize: ThemeManager.font.small
            }
        }
    }
}
