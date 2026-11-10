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

            delegate: Column {
                id: entry

                required property var modelData
                readonly property bool open: WifiState.expanded === entry.modelData.network

                width: parent?.width ?? 0
                spacing: ThemeManager.px(4)

                ListRow {
                    id: row

                    icon: entry.modelData.icon
                    title: entry.modelData.name
                    detail: entry.modelData.connected ? "Conectada" : entry.modelData.busy ? "Conectando…" : entry.modelData.known ? "Salva" : entry.modelData.secure ? "Protegida" : "Aberta"
                    lit: entry.modelData.connected
                    busy: entry.modelData.busy
                    onClicked: WifiState.activate(entry.modelData)

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: entry.modelData.secure
                        icon: Icons.lock
                        size: ThemeManager.px(16)
                        color: ThemeManager.colors.textFaint
                    }

                    IconButton {
                        visible: entry.modelData.known && row.hovered
                        icon: Icons.trash
                        iconSize: ThemeManager.px(18)
                        foreground: ThemeManager.colors.textMuted
                        onClicked: WifiState.forget(entry.modelData)
                    }
                }

                // Senha, para redes protegidas ainda não salvas.
                Item {
                    width: parent.width
                    height: entry.open ? ThemeManager.px(52) : 0
                    clip: true
                    visible: height > 0

                    Behavior on height { Anim { type: Anim.FastSpatial } }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: connect.left
                        anchors.rightMargin: ThemeManager.spacing.small
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: ThemeManager.spacing.small
                        height: ThemeManager.px(42)
                        radius: height / 2
                        color: ThemeManager.alpha(ThemeManager.colors.text, 0.06)
                        border.width: password.activeFocus ? ThemeManager.px(2) : 0
                        border.color: ThemeManager.colors.accent

                        TextInput {
                            id: password

                            anchors.fill: parent
                            anchors.leftMargin: ThemeManager.spacing.normal + ThemeManager.px(2)
                            anchors.rightMargin: ThemeManager.spacing.normal
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: TextInput.Password
                            color: ThemeManager.colors.text
                            font.family: ThemeManager.font.sans
                            font.variableAxes: ThemeManager.fontAxes(Font.Normal)
                            font.pixelSize: ThemeManager.font.normal
                            clip: true
                            onAccepted: WifiState.submitPassword(entry.modelData, text)

                            Txt {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !password.text
                                text: "Senha"
                                faint: true
                            }
                        }
                    }

                    TonalButton {
                        id: connect

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Conectar"
                        onClicked: WifiState.submitPassword(entry.modelData, password.text)
                    }

                    onVisibleChanged: {
                        if (visible) {
                            password.text = "";
                            password.forceActiveFocus();
                        }
                    }
                }
            }
        }
    }
}
