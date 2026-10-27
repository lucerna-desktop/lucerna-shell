import QtQuick
import qs.core.theme
import qs.core.widgets
import qs.features.settings.state

// Barra: o conteúdo (a data) e quando ela aparece. Há um modelo só, a aba
// fundida à moldura da tela; ela sempre se esconde sozinha e volta, com a
// moldura, ao encostar o mouse no topo.
Column {
    spacing: ThemeManager.spacing.large

    SettingSection {
        title: "Conteúdo"

        SettingRow {
            icon: Icons.calendar
            title: "Mostrar a data"
            description: "Ao lado da hora, na barra"

            Switch {
                checked: SettingsState.barShowDate
                onToggled: on => SettingsState.setBarShowDate(on)
            }
        }
    }

    SettingSection {
        title: "Quando aparece"

        SettingRow {
            icon: Icons.wallpaper
            title: "Sempre visível sem janelas"
            description: "Na área de trabalho vazia a barra fica à mostra, com a moldura, já que não cobre nada. Some quando uma janela abre"

            Switch {
                checked: SettingsState.barOnEmpty
                onToggled: on => SettingsState.setBarOnEmpty(on)
            }
        }

        SettingRow {
            icon: Icons.dashboard
            title: "Aparecer ao trocar de workspace"
            description: "Mostra a barra e a moldura por um instante, para ver em qual workspace você está"

            Switch {
                checked: SettingsState.barPeek
                onToggled: on => SettingsState.setBarPeek(on)
            }
        }
    }
}
