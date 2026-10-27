pragma ComponentBehavior: Bound

import QtQuick
import qs.core.theme
import qs.core.widgets
import qs.features.settings.state

// Créditos: a inspiração, os dados e a base do Lucerna, com o link de cada um.
Column {
    spacing: ThemeManager.spacing.large

    Repeater {
        model: SettingsState.credits

        delegate: SettingSection {
            id: section

            required property var modelData

            title: modelData.title

            Repeater {
                model: section.modelData.items

                delegate: SettingRow {
                    id: row

                    required property var modelData

                    title: modelData.name
                    description: modelData.detail

                    IconButton {
                        icon: Icons.openExternal
                        iconSize: 18
                        Accessible.name: `Abrir ${row.modelData.name}`
                        onClicked: SettingsState.openLink(row.modelData.url)
                    }
                }
            }
        }
    }
}
