import QtQuick
import qs.core.input
import qs.core.theme
import qs.core.widgets
import qs.features.settings.state

// Os botões ou teclas mapeados, cada um com a ação; editar e remover.
Column {
    id: root

    required property var entries
    property string emptyText: ""

    width: parent.width

    Txt {
        x: ThemeManager.spacing.large
        width: parent.width - x * 2
        topPadding: ThemeManager.spacing.normal
        bottomPadding: ThemeManager.spacing.normal
        visible: root.entries.length === 0
        wrapMode: Text.Wrap
        text: root.emptyText
        muted: true
        font.pixelSize: ThemeManager.font.small + 1
    }

    Repeater {
        model: root.entries

        delegate: SettingRow {
            id: row

            required property var modelData

            icon: InputActions.find(modelData.action?.id ?? "")?.icon ?? Icons.keyboard
            title: BindsState.describeTrigger(modelData)
            description: InputActions.describe(modelData.action)

            Row {
                spacing: ThemeManager.px(2)

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Icons.edit
                    iconSize: ThemeManager.px(18)
                    enabled: !BindsState.editing
                    onClicked: BindsState.edit(row.modelData)
                }

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Icons.trash
                    iconSize: ThemeManager.px(18)
                    onClicked: BindsState.remove(row.modelData)
                }
            }
        }
    }
}
