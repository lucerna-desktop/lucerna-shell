import QtQuick
import qs.core.theme
import qs.core.widgets
import qs.features.settings.state

// Launcher: estilo, buscador da web, favoritos, apps ocultos e o histórico
// de uso.
Column {
    spacing: ThemeManager.spacing.large

    SettingSection {
        title: "Estilo"

        Item {
            width: parent.width
            height: picker.implicitHeight + ThemeManager.spacing.large * 2

            LauncherStylePicker {
                id: picker

                anchors.fill: parent
                anchors.margins: ThemeManager.spacing.large
            }
        }
    }

    SettingSection {
        title: "Busca"

        SettingRow {
            wide: true
            icon: "language"
            title: "Buscador da web"
            description: "O primeiro da categoria Web (no estilo completo)"

            SegmentedControl {
                width: parent.width
                options: LauncherSettings.engineOptions
                value: LauncherSettings.engine
                onSelected: v => LauncherSettings.setEngine(v)
            }
        }

        SettingRow {
            icon: "history"
            title: "Histórico de uso"
            description: LauncherSettings.usedCount ? `Os apps mais abertos vêm primeiro (${LauncherSettings.usedCount} no histórico)` : "Os apps mais abertos vêm primeiro; ainda não há histórico"

            TonalButton {
                text: "Limpar"
                enabled: LauncherSettings.usedCount > 0
                opacity: enabled ? 1 : 0.45
                onClicked: LauncherSettings.clearUsage()
            }
        }
    }

    SettingSection {
        title: "Favoritos"

        Txt {
            x: ThemeManager.spacing.large
            width: parent.width - x * 2
            topPadding: ThemeManager.spacing.normal
            bottomPadding: ThemeManager.spacing.normal
            visible: LauncherSettings.favorites.length === 0
            wrapMode: Text.Wrap
            text: "Nenhum app fixado. No launcher completo, escolha um app e use Mais opções → Fixar nos favoritos. Sem favoritos, aparecem os mais usados."
            muted: true
            font.pixelSize: ThemeManager.font.small + 1
        }

        Repeater {
            model: LauncherSettings.favorites

            delegate: SettingRow {
                id: favRow

                required property var modelData
                required property int index

                icon: "star"
                title: modelData.name
                description: modelData.genericName || modelData.comment || ""

                Row {
                    spacing: ThemeManager.px(2)

                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "keyboard_arrow_up"
                        iconSize: ThemeManager.px(20)
                        enabled: favRow.index > 0
                        onClicked: LauncherSettings.moveFavorite(favRow.modelData.id, -1)
                    }

                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: Icons.trash
                        iconSize: ThemeManager.px(18)
                        onClicked: LauncherSettings.unpin(favRow.modelData.id)
                    }
                }
            }
        }
    }

    SettingSection {
        visible: LauncherSettings.hidden.length > 0
        title: "Ocultos"

        Repeater {
            model: LauncherSettings.hidden

            delegate: SettingRow {
                id: hiddenRow

                required property var modelData

                icon: "visibility_off"
                title: modelData.name
                description: "Não aparece no launcher"

                TonalButton {
                    text: "Mostrar"
                    onClicked: LauncherSettings.unhide(hiddenRow.modelData.id)
                }
            }
        }
    }
}
