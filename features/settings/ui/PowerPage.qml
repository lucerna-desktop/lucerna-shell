import QtQuick
import qs.core.theme
import qs.core.widgets
import qs.features.settings.state

// Energia e bateria: avisos, ação no nível crítico, perfil automático, tampa e modo leve.
Column {
    spacing: ThemeManager.spacing.large

    Txt {
        width: parent.width
        visible: !SettingsState.hasBattery
        wrapMode: Text.Wrap
        muted: true
        text: "Nenhuma bateria encontrada. As opções abaixo só têm efeito em notebooks."
    }

    SettingSection {
        title: "Barra"

        SettingRow {
            icon: Icons.battery[5]
            title: "Mostrar a porcentagem"
            description: "Ao lado do ícone da bateria"

            Switch {
                checked: SettingsState.batteryShowPercent
                onToggled: on => SettingsState.setBatteryShowPercent(on)
            }
        }
    }

    SettingSection {
        title: "Avisos"

        SettingRow {
            wide: true
            icon: Icons.battery[1]
            title: "Bateria baixa"
            description: "Avisa uma vez por descarga, ao chegar neste nível"

            Slider {
                width: parent.width
                from: 5
                to: 40
                stepSize: 1
                value: SettingsState.batteryLowLevel
                format: v => `${Math.round(v)}%`
                onMoved: v => SettingsState.setBatteryLowLevel(v)
            }
        }

        SettingRow {
            wide: true
            icon: Icons.batteryAlert
            title: "Bateria crítica"
            description: "Sempre abaixo do nível baixo"

            Slider {
                width: parent.width
                from: 1
                to: 20
                stepSize: 1
                value: SettingsState.batteryCriticalLevel
                format: v => `${Math.round(v)}%`
                onMoved: v => SettingsState.setBatteryCriticalLevel(v)
            }
        }

        SettingRow {
            icon: Icons.battery[7]
            title: "Carga completa"
            description: "Avisa quando a bateria termina de carregar"

            Switch {
                checked: SettingsState.batteryNotifyFull
                onToggled: on => SettingsState.setBatteryNotifyFull(on)
            }
        }

        SettingRow {
            icon: Icons.batteryCharging
            title: "Carregador"
            description: "Avisa ao conectar e ao desconectar o carregador"

            Switch {
                checked: SettingsState.batteryNotifyPlug
                onToggled: on => SettingsState.setBatteryNotifyPlug(on)
            }
        }
    }

    SettingSection {
        title: "No nível crítico"

        SettingRow {
            wide: true
            icon: Icons.power
            title: "Ação"
            description: "Antes, um aviso dá 60 segundos: conectar o carregador cancela"

            SegmentedControl {
                width: parent.width
                options: SettingsState.criticalActions
                value: SettingsState.batteryCriticalAction
                onSelected: v => SettingsState.setBatteryCriticalAction(v)
            }
        }
    }

    SettingSection {
        title: "Perfil de energia"

        SettingRow {
            icon: Icons.balance
            title: "Trocar ao tirar e pôr na tomada"
            description: "Escolhe o perfil conforme a fonte de energia"

            Switch {
                checked: SettingsState.autoProfile
                onToggled: on => SettingsState.setAutoProfile(on)
            }
        }

        SettingRow {
            wide: true
            icon: Icons.battery[4]
            title: "Na bateria"
            dimmed: !SettingsState.autoProfile

            SegmentedControl {
                width: parent.width
                options: SettingsState.profileOptions
                value: SettingsState.profileOnBattery
                onSelected: v => SettingsState.setProfileOnBattery(v)
            }
        }

        SettingRow {
            wide: true
            icon: Icons.batteryCharging
            title: "Na tomada"
            dimmed: !SettingsState.autoProfile

            SegmentedControl {
                width: parent.width
                options: SettingsState.profileOptions
                value: SettingsState.profileOnAC
                onSelected: v => SettingsState.setProfileOnAC(v)
            }
        }

        SettingRow {
            icon: Icons.eco
            title: "Economia com bateria baixa"
            description: "Muda para o perfil Economia abaixo do nível escolhido"

            Switch {
                checked: SettingsState.saverBelowEnabled
                onToggled: on => SettingsState.setSaverBelowEnabled(on)
            }
        }

        SettingRow {
            wide: true
            title: "Nível"
            dimmed: !SettingsState.saverBelowEnabled

            Slider {
                width: parent.width
                from: 5
                to: 60
                stepSize: 5
                value: SettingsState.saverBelow
                format: v => `${Math.round(v)}%`
                enabled: SettingsState.saverBelowEnabled
                onMoved: v => SettingsState.setSaverBelow(v)
            }
        }
    }

    // Só em notebooks: num desktop não há tampa.
    SettingSection {
        visible: SettingsState.hasBattery
        title: "Tampa"

        SettingRow {
            icon: Icons.lock
            title: "Bloquear ao fechar a tampa com monitor externo"
            description: "Desligado, fechar a tampa com um monitor externo ligado só apaga a tela do notebook."

            Switch {
                checked: SettingsState.lockOnLidDocked
                onToggled: on => SettingsState.setLockOnLidDocked(on)
            }
        }
    }

    SettingSection {
        title: "Modo leve"

        SettingRow {
            icon: Icons.bolt
            title: "Economizar efeitos na bateria"
            description: "Sem tomada, desliga a transparência e o desfoque e deixa as animações mais curtas, para gastar menos GPU"

            Switch {
                checked: SettingsState.batteryLightMode
                onToggled: on => SettingsState.setBatteryLightMode(on)
            }
        }
    }
}
