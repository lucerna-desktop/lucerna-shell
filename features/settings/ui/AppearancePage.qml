pragma ComponentBehavior: Bound

import QtQuick
import qs.core.pixel
import qs.core.theme
import qs.core.widgets
import qs.features.settings.state

// Aparência: tema, tamanho do shell e velocidade das animações.
Column {
    id: page

    // A escala da janela (fracionária: 1,25), para as linhas finas (ver Pixel).
    readonly property real dpr: Window.window?.devicePixelRatio ?? 1

    spacing: ThemeManager.spacing.large

    SettingSection {
        title: "Tema"

        Item {
            width: parent.width
            height: themeFlow.implicitHeight + ThemeManager.spacing.large * 2

            Flow {
                id: themeFlow

                anchors.fill: parent
                anchors.margins: ThemeManager.spacing.large
                spacing: ThemeManager.spacing.normal

                // Os cartões dividem a linha por igual: sem vão sobrando à direita.
                readonly property int columns: Math.min(SettingsState.themes.length, Math.max(1, Math.floor((width + spacing) / (135 + spacing))))
                readonly property real chipWidth: (width - (columns - 1) * spacing) / columns

                Repeater {
                    model: SettingsState.themes

                    delegate: Clickable {
                        id: chip

                        required property var modelData
                        readonly property bool current: modelData.id === SettingsState.theme

                        width: themeFlow.chipWidth
                        height: ThemeManager.px(64)
                        radius: ThemeManager.radius.normal
                        pressScale: 0.95
                        color: modelData.colors.base ?? "black"
                        border.width: current ? ThemeManager.px(2) : ThemeManager.outlines ? Pixel.hairline(page.dpr) : 0
                        border.color: current ? ThemeManager.colors.accent : (modelData.colors.border ?? "gray")
                        onClicked: SettingsState.applyTheme(modelData.id)

                        Row {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.margins: ThemeManager.px(10)
                            spacing: ThemeManager.px(4)

                            Repeater {
                                model: ["accent", "text", "textMuted", "surface"]

                                delegate: Rectangle {
                                    required property string modelData

                                    width: ThemeManager.px(14)
                                    height: ThemeManager.px(14)
                                    radius: width / 2
                                    color: chip.modelData.colors[modelData] ?? "gray"
                                    border.width: Pixel.hairline(page.dpr)
                                    border.color: chip.modelData.colors.border ?? "gray"
                                }
                            }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: ThemeManager.px(10)
                            elide: Text.ElideRight
                            text: chip.modelData.name
                            color: chip.modelData.colors.text ?? "white"
                            font.family: ThemeManager.font.sans
                            font.variableAxes: ThemeManager.fontAxes(Font.DemiBold)
                            font.pixelSize: ThemeManager.font.normal
                            font.weight: Font.DemiBold
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: ThemeManager.px(8)
                            width: ThemeManager.px(20)
                            height: ThemeManager.px(20)
                            radius: width / 2
                            color: chip.modelData.colors.accent ?? "white"
                            scale: chip.current ? 1 : 0
                            opacity: chip.current ? 1 : 0

                            Behavior on scale { Anim { type: Anim.FastSpatial } }
                            Behavior on opacity { Anim { type: Anim.FastEffects } }

                            Icon {
                                anchors.centerIn: parent
                                icon: Icons.check
                                size: ThemeManager.px(14)
                                weight: 600
                                color: chip.modelData.colors.accentText ?? "black"
                            }
                        }
                    }
                }
            }
        }
    }

    SettingSection {
        title: "Tamanho"

        SettingRow {
            icon: Icons.zoom
            title: "Tamanho do shell"
            description: "Aumenta o shell sem mudar a escala do monitor."
            wide: true

            SegmentedControl {
                width: parent.width
                options: SettingsState.shellScaleOptions
                value: SettingsState.shellScale
                onSelected: v => SettingsState.setShellScale(v)
            }
        }
    }

    SettingSection {
        title: "Cartões"

        SettingRow {
            icon: Icons.toolbar
            title: "Contorno nos cartões"
            description: "Uma linha fina em volta de cartões e painéis. Sem ela, eles se destacam só pelo tom"

            Switch {
                checked: SettingsState.outlines
                onToggled: on => SettingsState.setOutlines(on)
            }
        }
    }

    SettingSection {
        title: "Movimento"

        SettingRow {
            icon: Icons.animation
            title: "Animações"
            description: "Velocidade das transições do shell. \"Desligadas\" troca tudo na hora"
            wide: true

            SegmentedControl {
                width: parent.width
                options: SettingsState.animationOptions
                value: SettingsState.animationScale
                onSelected: v => SettingsState.setAnimationScale(v)
            }
        }
    }
}
