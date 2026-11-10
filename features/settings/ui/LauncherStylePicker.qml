pragma ComponentBehavior: Bound

import QtQuick
import qs.core.theme
import qs.core.widgets
import qs.features.settings.state

// Escolha do estilo do launcher: cartões com uma miniatura de cada um.
Flow {
    id: root

    spacing: ThemeManager.spacing.normal

    readonly property int columns: Math.min(LauncherSettings.styles.length, Math.max(1, Math.floor((width + spacing) / (150 + spacing))))
    readonly property real cardWidth: (width - (columns - 1) * spacing) / columns

    Repeater {
        model: LauncherSettings.styles

        delegate: Clickable {
            id: card

            required property var modelData
            readonly property bool current: modelData.id === LauncherSettings.style
            readonly property color ink: current ? ThemeManager.colors.accent : ThemeManager.colors.textMuted

            width: root.cardWidth
            height: ThemeManager.px(132)
            radius: ThemeManager.radius.normal + ThemeManager.px(2)
            pressScale: 0.95
            color: current ? ThemeManager.alpha(ThemeManager.colors.accent, 0.12) : ThemeManager.alpha(ThemeManager.colors.text, 0.04)
            border.width: current ? ThemeManager.px(2) : 0
            border.color: ThemeManager.colors.accent
            onClicked: LauncherSettings.setStyle(modelData.id)

            // Miniatura: uma "tela" com o launcher desenhado.
            Rectangle {
                id: screen

                x: ThemeManager.px(10)
                y: ThemeManager.px(10)
                width: parent.width - ThemeManager.px(20)
                height: ThemeManager.px(76)
                radius: ThemeManager.radius.small
                color: ThemeManager.colors.base
                clip: true

                // Compacto: campo e uma lista curta, no alto.
                Item {
                    visible: card.modelData.id === "compact"
                    anchors.fill: parent

                    Rectangle {
                        x: parent.width * 0.25
                        y: ThemeManager.px(12)
                        width: parent.width * 0.5
                        height: ThemeManager.px(40)
                        radius: ThemeManager.px(4)
                        color: ThemeManager.colors.surface

                        Rectangle { x: ThemeManager.px(4); y: ThemeManager.px(4); width: parent.width - ThemeManager.px(8); height: ThemeManager.px(7); radius: ThemeManager.px(3); color: card.ink; opacity: 0.8 }

                        Repeater {
                            model: 3

                            delegate: Rectangle {
                                required property int index

                                x: ThemeManager.px(6)
                                y: ThemeManager.px(16) + index * ThemeManager.px(8)
                                width: parent.width * (0.7 - index * 0.12)
                                height: ThemeManager.px(4)
                                radius: height / 2
                                color: ThemeManager.colors.textFaint
                            }
                        }
                    }
                }

                // Completo: coluna de categorias, grade e detalhes.
                Item {
                    visible: card.modelData.id === "full"
                    anchors.fill: parent

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: ThemeManager.px(8)
                        radius: ThemeManager.px(4)
                        color: ThemeManager.colors.surface

                        Rectangle { x: ThemeManager.px(4); y: ThemeManager.px(4); width: parent.width * 0.66; height: ThemeManager.px(6); radius: ThemeManager.px(3); color: card.ink; opacity: 0.8 }

                        Repeater {
                            model: 4

                            delegate: Rectangle {
                                required property int index

                                x: ThemeManager.px(4)
                                y: ThemeManager.px(15) + index * ThemeManager.px(9)
                                width: parent.width * 0.16
                                height: ThemeManager.px(4)
                                radius: height / 2
                                color: index === 0 ? card.ink : ThemeManager.colors.textFaint
                            }
                        }

                        Grid {
                            x: parent.width * 0.23
                            y: ThemeManager.px(15)
                            columns: 4
                            spacing: ThemeManager.px(3)

                            Repeater {
                                model: 8

                                delegate: Rectangle {
                                    width: ThemeManager.px(9)
                                    height: ThemeManager.px(9)
                                    radius: ThemeManager.px(2)
                                    color: ThemeManager.colors.textFaint
                                    opacity: 0.7
                                }
                            }
                        }

                        Rectangle {
                            x: parent.width * 0.72
                            y: ThemeManager.px(4)
                            width: parent.width * 0.26
                            height: parent.height - ThemeManager.px(8)
                            radius: ThemeManager.px(3)
                            color: ThemeManager.colors.raised

                            Rectangle { x: ThemeManager.px(4); y: ThemeManager.px(6); width: ThemeManager.px(10); height: ThemeManager.px(10); radius: ThemeManager.px(3); color: card.ink }
                            Rectangle { x: ThemeManager.px(4); y: ThemeManager.px(22); width: parent.width - ThemeManager.px(8); height: ThemeManager.px(5); radius: ThemeManager.px(2); color: card.ink; opacity: 0.8 }
                        }
                    }
                }

                // Tela cheia: grade grande sobre a tela toda.
                Item {
                    visible: card.modelData.id === "grid"
                    anchors.fill: parent

                    Rectangle {
                        anchors.fill: parent
                        color: ThemeManager.alpha(ThemeManager.colors.surface, 0.8)
                    }

                    Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: ThemeManager.px(7); width: parent.width * 0.4; height: ThemeManager.px(6); radius: ThemeManager.px(3); color: card.ink; opacity: 0.8 }

                    Grid {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: ThemeManager.px(22)
                        columns: 6
                        spacing: ThemeManager.px(6)

                        Repeater {
                            model: 12

                            delegate: Rectangle {
                                width: ThemeManager.px(12)
                                height: ThemeManager.px(12)
                                radius: ThemeManager.px(3)
                                color: ThemeManager.colors.textFaint
                                opacity: 0.7
                            }
                        }
                    }
                }
            }

            Column {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: ThemeManager.px(10)
                spacing: 0

                Txt {
                    text: card.modelData.label
                    font.weight: card.current ? Font.DemiBold : Font.Normal
                    color: card.current ? ThemeManager.colors.accent : ThemeManager.colors.text
                    font.pixelSize: ThemeManager.font.small + 1
                }

                Txt {
                    text: card.modelData.hint
                    faint: true
                    font.pixelSize: ThemeManager.font.small - 1
                }
            }
        }
    }
}
