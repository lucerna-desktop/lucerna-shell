import QtQuick
import qs.core.config
import qs.core.pixel
import qs.core.theme
import qs.core.widgets
import qs.features.capture.state

// Barra do painel de captura: foto ou vídeo, o alvo, as opções (espera,
// cursor na foto, som no vídeo) e o botão de capturar.
Surface {
    id: root

    signal capture

    level: 0
    radius: ThemeManager.radius.large + ThemeManager.px(4)
    width: content.implicitWidth + ThemeManager.spacing.large * 2
    height: content.implicitHeight + ThemeManager.spacing.large * 2

    readonly property bool recordMode: CaptureState.mode === "record"

    Column {
        id: content

        anchors.centerIn: parent
        spacing: ThemeManager.spacing.normal

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: ThemeManager.spacing.normal

            SegmentedControl {
                width: ThemeManager.px(220)
                anchors.verticalCenter: parent.verticalCenter
                options: CaptureState.modes.filter(m => m.value === "shot" || CaptureState.canRecord)
                value: CaptureState.mode
                onSelected: v => CaptureState.setMode(v)
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Pixel.hairline(Window.window?.devicePixelRatio ?? 1)
                height: ThemeManager.px(28)
                color: ThemeManager.colors.border
            }

            Repeater {
                model: CaptureState.targets

                delegate: Clickable {
                    id: option

                    required property var modelData
                    readonly property bool current: CaptureState.target === modelData.value

                    anchors.verticalCenter: parent.verticalCenter
                    width: ThemeManager.px(84)
                    height: ThemeManager.px(60)
                    radius: ThemeManager.radius.normal
                    color: current ? ThemeManager.alpha(ThemeManager.colors.accent, 0.18) : "transparent"
                    border.width: current ? Pixel.hairline(Window.window?.devicePixelRatio ?? 1) : 0
                    border.color: ThemeManager.alpha(ThemeManager.colors.accent, 0.6)
                    onClicked: CaptureState.setTarget(modelData.value)

                    Column {
                        anchors.centerIn: parent
                        spacing: ThemeManager.px(2)

                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            icon: option.modelData.icon
                            filled: option.current
                            size: ThemeManager.px(24)
                            color: option.current ? ThemeManager.colors.accent : ThemeManager.colors.textMuted
                        }

                        Txt {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: option.modelData.label
                            font.pixelSize: ThemeManager.font.small + 1
                            font.weight: option.current ? Font.DemiBold : Font.Normal
                        }
                    }
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Pixel.hairline(Window.window?.devicePixelRatio ?? 1)
                height: ThemeManager.px(28)
                color: ThemeManager.colors.border
            }

            // Capturar
            Clickable {
                anchors.verticalCenter: parent.verticalCenter
                width: ThemeManager.px(60)
                height: ThemeManager.px(60)
                radius: width / 2
                // O tom de contêiner (do erro, gravando), com o ícone na cor cheia.
                color: root.recordMode ? ThemeManager.container(ThemeManager.colors.danger) : ThemeManager.colors.accentContainer
                layerColor: ThemeManager.colors.base
                pressScale: 0.92
                onClicked: root.capture()

                Icon {
                    anchors.centerIn: parent
                    icon: root.recordMode ? "radio_button_checked" : "photo_camera"
                    filled: true
                    size: ThemeManager.px(28)
                    color: root.recordMode ? ThemeManager.containerIcon(ThemeManager.colors.danger) : ThemeManager.colors.accentIcon
                }
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: Icons.close
                iconSize: ThemeManager.px(20)
                onClicked: CaptureState.close()
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: ThemeManager.spacing.normal

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                icon: "timer"
                size: ThemeManager.px(18)
                color: ThemeManager.colors.textMuted
            }

            SegmentedControl {
                width: ThemeManager.px(300)
                anchors.verticalCenter: parent.verticalCenter
                options: CaptureState.delays
                value: Config.captureDelay
                onSelected: v => Config.captureDelay = v
            }

            Clickable {
                visible: !root.recordMode
                anchors.verticalCenter: parent.verticalCenter
                width: cursorRow.implicitWidth + ThemeManager.px(20)
                height: ThemeManager.px(36)
                radius: height / 2
                color: Config.captureCursor ? ThemeManager.alpha(ThemeManager.colors.accent, 0.18) : "transparent"
                onClicked: Config.captureCursor = !Config.captureCursor

                Row {
                    id: cursorRow

                    anchors.centerIn: parent
                    spacing: ThemeManager.px(6)

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "arrow_selector_tool"
                        filled: Config.captureCursor
                        size: ThemeManager.px(18)
                        color: Config.captureCursor ? ThemeManager.colors.accent : ThemeManager.colors.textMuted
                    }

                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Cursor"
                        font.pixelSize: ThemeManager.font.small + 1
                    }
                }
            }

            SegmentedControl {
                visible: root.recordMode
                width: ThemeManager.px(360)
                anchors.verticalCenter: parent.verticalCenter
                options: CaptureState.audios
                value: Config.captureAudio
                onSelected: v => Config.captureAudio = v
            }
        }
    }
}
