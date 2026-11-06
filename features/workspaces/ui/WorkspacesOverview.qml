pragma ComponentBehavior: Bound

import QtQuick
import qs.core.theme
import qs.core.widgets
import qs.features.workspaces.state

// Painel da visão geral (Super+Tab). As miniaturas só existem enquanto ele
// está na tela: cada abertura captura as janelas de novo, e fechado não guarda
// nada na memória.
OverlayPanel {
    id: panel

    name: "overview"
    open: WorkspacesState.open
    screen: WorkspacesState.screen
    onDismissed: WorkspacesState.close()
    Loader {
        id: content

        anchors.fill: parent
        active: panel.visible
        focus: true
        onLoaded: (item as Item).forceActiveFocus()

        sourceComponent: FocusScope {
            id: overview

            focus: true

            readonly property int count: WorkspacesState.ids.length
            readonly property int columns: count <= 5 ? count : Math.ceil(count / 2)
            readonly property real tileWidth: Math.min(380, (width - 160 - (columns - 1) * ThemeManager.spacing.large) / columns)

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab)
                    WorkspacesState.move(1);
                else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab)
                    WorkspacesState.move(-1);
                else if (event.key === Qt.Key_Down)
                    WorkspacesState.move(columns);
                else if (event.key === Qt.Key_Up)
                    WorkspacesState.move(-columns);
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                    WorkspacesState.go(WorkspacesState.selected);
                else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9)
                    WorkspacesState.go(event.key - Qt.Key_0);
                else
                    return;
                event.accepted = true;
            }

            Surface {
                level: 0
                x: panel.snap((parent.width - width) / 2)
                y: panel.snap((parent.height - height) / 2 + (1 - panel.progress) * 24)
                width: grid.width + ThemeManager.spacing.large * 2
                height: grid.height + header.height + ThemeManager.spacing.large * 3
                radius: ThemeManager.radius.large + 4
                scale: 0.96 + 0.04 * panel.progress

                Row {
                    id: header

                    x: ThemeManager.spacing.large
                    y: ThemeManager.spacing.large
                    spacing: ThemeManager.spacing.small

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "overview_key"
                        filled: true
                        color: ThemeManager.colors.accent
                    }

                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Workspaces"
                        font.pixelSize: ThemeManager.font.large
                        font.weight: Font.DemiBold
                    }

                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Clique para ir · arraste uma janela para mover · botão do meio fecha"
                        faint: true
                        font.pixelSize: ThemeManager.font.small
                        leftPadding: ThemeManager.spacing.normal
                    }
                }

                Grid {
                    id: grid

                    x: ThemeManager.spacing.large
                    y: header.y + header.height + ThemeManager.spacing.large
                    columns: overview.columns
                    spacing: ThemeManager.spacing.large

                    Repeater {
                        model: WorkspacesState.ids

                        delegate: WorkspaceTile {
                            required property int modelData

                            wsId: modelData
                            tileWidth: overview.tileWidth
                        }
                    }
                }
            }
        }
    }
}
