pragma ComponentBehavior: Bound

import QtQuick
import qs.core.config
import qs.core.nightlight
import qs.core.theme
import qs.core.widgets
import qs.features.settings.state

// Luz noturna: ligar, a temperatura e o horário (pôr do sol, fixo ou sempre).
Column {
    spacing: ThemeManager.spacing.large

    SettingSection {
        title: "Luz noturna"

        SettingRow {
            icon: "nightlight"
            title: "Luz noturna"
            description: NightLightSettings.available ? `Deixa a tela mais quente à noite. ${NightSchedule.status}` : "Deixa a tela mais quente à noite"
            dimmed: !NightLightSettings.available

            Switch {
                checked: Config.nightLightEnabled
                onToggled: on => {
                    Config.nightLightEnabled = on;
                    Config.nightLightOverride = null;
                }
            }
        }

        Txt {
            x: ThemeManager.spacing.large
            width: parent.width - x * 2
            bottomPadding: ThemeManager.spacing.normal
            visible: !NightLightSettings.available
            wrapMode: Text.Wrap
            text: "Precisa do hyprsunset, que muda a cor na própria tela, sem custo para a GPU: sudo pacman -S hyprsunset"
            color: ThemeManager.colors.warning
            font.pixelSize: ThemeManager.font.small + 1
        }

        SettingRow {
            wide: true
            icon: "thermostat"
            title: "Temperatura"
            description: "Mais baixa, mais quente. Ao ajustar, a tela mostra por alguns segundos"
            dimmed: !NightLightSettings.available

            LevelSlider {
                width: parent.width
                from: 2500
                to: 6000
                stepSize: 100
                value: Config.nightLightTemp
                format: v => `${Math.round(v)} K`
                onMoved: v => NightLightSettings.setTemp(v)
            }
        }
    }

    SettingSection {
        title: "Horário"
        opacity: Config.nightLightEnabled ? 1 : 0.55

        SettingRow {
            wide: true
            icon: "schedule"
            title: "Quando ligar"
            description: "Entra e sai aos poucos, em 30 minutos. Ligar ou desligar pelo tile da central vale até a próxima virada"

            SegmentedControl {
                width: parent.width
                options: NightLightSettings.schedules
                value: Config.nightLightSchedule
                onSelected: v => {
                    Config.nightLightSchedule = v;
                    Config.nightLightOverride = null;
                }
            }
        }

        SettingRow {
            visible: Config.nightLightSchedule === "sun"
            icon: Icons.location
            title: NightSchedule.location ? NightSchedule.location.name : "Nenhuma cidade escolhida"
            description: NightSchedule.location ? NightLightSettings.sunText : "O pôr do sol usa a cidade do clima. Até escolher, vale o horário fixo abaixo"

            TonalButton {
                icon: Icons.location
                text: NightSchedule.location ? "Trocar" : "Escolher"
                onClicked: SettingsState.openTopic("dashboard")
            }
        }

        Repeater {
            model: Config.nightLightSchedule === "custom" || NightSchedule.needsLocation ? [
                { key: "nightLightFrom", label: "Liga às", icon: "bedtime" },
                { key: "nightLightTo", label: "Desliga às", icon: "wb_sunny" }
            ] : []

            delegate: SettingRow {
                id: clockRow

                required property var modelData

                wide: true
                icon: modelData.icon
                title: modelData.label

                Select {
                    width: parent.width
                    visibleRows: 6
                    searchable: true
                    options: NightLightSettings.clockOptionsFor(Config[clockRow.modelData.key])
                    value: Config[clockRow.modelData.key]
                    onSelected: v => {
                        Config[clockRow.modelData.key] = v;
                        Config.nightLightOverride = null;
                    }
                }
            }
        }
    }
}
