import QtQuick
import qs.core.theme
import qs.core.widgets
import qs.features.settings.state

// Notificações: não perturbe e tempo dos popups.
Column {
    spacing: ThemeManager.spacing.large

    SettingSection {
        title: "Popups"

        SettingRow {
            icon: Icons.bellSleep
            title: "Não perturbe"
            description: "Esconde os popups; as notificações continuam na central. As críticas ainda aparecem"

            Switch {
                checked: SettingsState.doNotDisturb
                onToggled: on => SettingsState.setDoNotDisturb(on)
            }
        }

        SettingRow {
            icon: Icons.timer
            wide: true
            title: "Tempo na tela"
            description: "Quanto um popup fica visível quando o app não define um prazo"

            LevelSlider {
                width: parent.width
                from: 2
                to: 15
                stepSize: 1
                value: SettingsState.notificationSeconds
                format: v => `${Math.round(v)} s`
                onMoved: v => SettingsState.setNotificationSeconds(v)
            }
        }
    }

    TonalButton {
        anchors.right: parent.right
        icon: Icons.bellBadge
        text: "Enviar uma de teste"
        onClicked: SettingsState.testNotification()
    }
}
