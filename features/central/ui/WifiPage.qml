pragma ComponentBehavior: Bound

import QtQuick
import qs.core.theme
import qs.core.widgets
import qs.features.central.state

// Página do Wi-Fi no painel de ações da central: voltar, o título e o
// liga/desliga no topo; embaixo, as redes (o card rola, se passar da altura).
// Clicar numa rede protegida e desconhecida abre o campo de senha ali mesmo.
Column {
    id: root

    width: parent?.width ?? 0
    spacing: ThemeManager.spacing.small

    PageHeader {
        title: "Wi-Fi"
        onBack: CentralState.setPage("")

        Switch {
            visible: WifiState.available
            checked: WifiState.enabled
            enabled: !WifiState.hardwareBlocked
            onToggled: on => WifiState.setEnabled(on)
        }
    }

    Txt {
        width: parent.width
        visible: WifiState.error !== ""
        text: WifiState.error
        color: ThemeManager.colors.danger
        wrapMode: Text.Wrap
        font.pixelSize: ThemeManager.font.small + 1
    }

    EmptyState {
        visible: !WifiState.available || !WifiState.enabled || WifiState.hardwareBlocked
        icon: Icons.wifiOff
        text: !WifiState.available ? "Nenhuma placa Wi-Fi encontrada" : WifiState.hardwareBlocked ? "Bloqueado pelo botão do aparelho" : "O Wi-Fi está desligado"
    }

    EmptyState {
        visible: WifiState.available && WifiState.enabled && !WifiState.hardwareBlocked && WifiState.networks.length === 0
        icon: Icons.wifi[0]
        text: "Procurando redes…"
    }

    Column {
        id: networks

        width: root.width
        visible: WifiState.enabled && !WifiState.hardwareBlocked && WifiState.networks.length > 0
        spacing: ThemeManager.px(2)

        Repeater {
            model: WifiState.networks

            delegate: WifiNetworkRow {}
        }
    }
}
