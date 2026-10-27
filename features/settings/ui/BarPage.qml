import QtQuick
import qs.core.theme
import qs.core.widgets
import qs.features.settings.state

// Barra: o arranjo do conteúdo (pílula ou ilha, e a data) e quando ela
// aparece. Ela sempre se esconde sozinha e volta ao encostar o mouse no topo.
Column {
    spacing: ThemeManager.spacing.large

    SettingSection {
        title: "Conteúdo"

        Item {
            width: parent.width
            height: picker.implicitHeight + ThemeManager.spacing.large * 2

            BarStylePicker {
                id: picker

                anchors.fill: parent
                anchors.margins: ThemeManager.spacing.large
            }
        }

        SettingRow {
            icon: Icons.calendar
            title: "Mostrar a data"
            description: "Ao lado da hora na pílula; embaixo dela quando a ilha abre"

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
            description: "Na área de trabalho vazia a barra fica à mostra, já que não cobre nada. Some quando uma janela abre"

            Switch {
                checked: SettingsState.barOnEmpty
                onToggled: on => SettingsState.setBarOnEmpty(on)
            }
        }

        SettingRow {
            icon: Icons.dashboard
            title: "Aparecer ao trocar de workspace"
            description: "Mostra a barra por um instante (a ilha, aberta), para ver em qual workspace você está"

            Switch {
                checked: SettingsState.barPeek
                onToggled: on => SettingsState.setBarPeek(on)
            }
        }
    }
}
