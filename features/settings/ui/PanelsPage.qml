import QtQuick
import qs.core.theme
import qs.core.widgets
import qs.features.settings.state

// Painéis: se o painel superior fica aberto junto das configurações.
Column {
    spacing: ThemeManager.spacing.large

    SettingSection {
        title: "Abrir juntos"

        Repeater {
            model: SettingsState.companionOptions

            delegate: SettingRow {
                id: row

                required property var modelData

                icon: row.modelData.icon
                title: row.modelData.label
                description: row.modelData.description

                Switch {
                    checked: SettingsState.panelsTogether.includes(row.modelData.id)
                    onToggled: on => SettingsState.setTogether(row.modelData.id, on)
                }
            }
        }
    }

    Txt {
        width: parent.width
        wrapMode: Text.Wrap
        text: "Ligado, o painel superior fica aberto por cima das configurações. Desligado, ele abre sozinho e fecha os demais. A central, o launcher, os temas e o menu de energia sempre abrem sozinhos."
        faint: true
        font.pixelSize: ThemeManager.font.small
    }
}
