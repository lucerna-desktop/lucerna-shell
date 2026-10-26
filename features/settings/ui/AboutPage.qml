pragma ComponentBehavior: Bound

import QtQuick
import qs.core.theme
import qs.core.widgets
import qs.features.settings.state

// Sobre: o shell, as versões e as dependências.
Column {
    spacing: ThemeManager.spacing.large

    Row {
        spacing: ThemeManager.spacing.large

        Image {
            anchors.verticalCenter: parent.verticalCenter
            width: 65
            height: 84
            source: ThemeManager.logo
            sourceSize: Qt.size(width * 2, height * 2)
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Txt {
                text: "Lucerna"
                font.pixelSize: ThemeManager.font.huge - 12
                font.weight: Font.DemiBold
            }

            Txt {
                text: "Shell de desktop para o Hyprland, escrito em Quickshell"
                muted: true
            }
        }
    }

    SettingSection {
        title: "Sistema"

        Repeater {
            model: SettingsState.about

            delegate: SettingRow {
                id: row

                required property var modelData

                title: modelData.label

                Txt {
                    text: row.modelData.value
                    mono: true
                    muted: true
                    font.pixelSize: ThemeManager.font.small + 1
                }
            }
        }
    }

    SettingSection {
        title: "Dependências"

        SettingRow {
            title: "Obrigatórias"
            description: "Hyprland 0.56+ (config em Lua), Quickshell 0.3.1+, a fonte Material Symbols e o lucernad"
        }

        SettingRow {
            title: "Opcionais"
            description: "PipeWire, UPower e NetworkManager"
        }
    }
}
