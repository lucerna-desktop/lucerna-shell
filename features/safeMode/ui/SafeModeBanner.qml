pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core.theme
import qs.core.widgets
import qs.features.safeMode.state

// A pílula do modo de segurança, no topo de cada tela: avisa e dá as saídas
// (reiniciar normalmente e ver o registro). Só existe no modo de segurança.
Variants {
    model: SafeModeState.active ? Quickshell.screens : []

    PanelWindow {
        id: window

        required property var modelData

        screen: modelData
        anchors.top: true
        implicitWidth: pill.width
        implicitHeight: pill.y + pill.height
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        // Só a pílula recebe o mouse; a faixa acima dela deixa passar.
        mask: Region {
            item: pill
        }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "lucerna-safe-mode"

        Surface {
            id: pill

            // Abaixo da barra, que fica no topo.
            y: ThemeManager.barHeight + ThemeManager.spacing.large
            width: row.implicitWidth + ThemeManager.spacing.normal * 2
            height: row.implicitHeight + ThemeManager.spacing.small * 2
            level: 0
            radius: height / 2

            Row {
                id: row

                anchors.centerIn: parent
                spacing: ThemeManager.spacing.normal

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "warning"
                    size: ThemeManager.px(20)
                    color: ThemeManager.colors.accent
                }

                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "O Lucerna está no modo de segurança"
                    font.weight: Font.DemiBold
                }

                TonalButton {
                    icon: Icons.restart
                    text: "Reiniciar normalmente"
                    onClicked: SafeModeState.restartNormally()
                }

                TonalButton {
                    icon: Icons.terminal
                    text: "Ver o registro"
                    onClicked: SafeModeState.openLog()
                }
            }
        }
    }
}
