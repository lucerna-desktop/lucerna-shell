pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import qs.core.format
import qs.core.theme
import qs.core.widgets
import qs.features.central.state

// Página da bateria no painel de ações da central: voltar e o título; o card
// em forma de bateria, cheio até a carga no tom de contêiner da cor dela
// (destaque, aviso, erro ou, carregando, verde), com a porcentagem e o tempo (ou "Carregando"/
// "Carregada") por cima; o perfil de energia em botões de texto (o atual
// cheio); o consumo da última hora num gráfico; e a bateria dos dispositivos
// Bluetooth conectados. Sem bateria, sem perfil ou sem dispositivos, o bloco
// some.
Column {
    id: root

    width: parent?.width ?? 0
    spacing: ThemeManager.spacing.small

    PageHeader {
        title: PowerState.title
        onBack: CentralState.setPage("")
    }

    Item {
        id: card

        // A cor do estado (sem estado, o destaque), em tom de contêiner, com o
        // texto dele por cima.
        readonly property color hue: PowerState.cardBand === "success" ? ThemeManager.colors.success : PowerState.cardBand === "danger" ? ThemeManager.colors.danger : PowerState.cardBand === "warning" ? ThemeManager.colors.warning : ThemeManager.colors.accent
        readonly property bool band: PowerState.cardBand === "success" || PowerState.cardBand === "danger" || PowerState.cardBand === "warning"
        readonly property color fill: band ? ThemeManager.container(hue) : ThemeManager.colors.accentContainer
        readonly property color ink: band ? ThemeManager.onContainer(hue) : ThemeManager.colors.onAccentContainer
        readonly property color empty: ThemeManager.colors.track
        // A carga mostrada anima até a nova.
        property real shown: PowerState.percentage

        Behavior on shown { Anim { type: Anim.Standard } }

        visible: PowerState.hasBattery
        width: parent.width
        height: ThemeManager.px(76)

        // O que vai por cima do card, nas duas cores: a porcentagem (com o
        // raio, carregando) à esquerda e o tempo à direita.
        component CardLabel: Item {
            id: label

            required property color tint
            // O tempo fica mais apagado sobre o vazio; sobre a cor, cheio.
            property real noteOpacity: 0.8

            width: body.width
            height: body.height

            Row {
                x: ThemeManager.spacing.normal + ThemeManager.px(2)
                anchors.verticalCenter: parent.verticalCenter
                spacing: ThemeManager.px(2)

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: PowerState.charging
                    icon: Icons.bolt
                    size: ThemeManager.px(26)
                    filled: true
                    color: label.tint
                }

                Txt {
                    text: Format.percent(PowerState.percentage)
                    mono: true
                    color: label.tint
                    font.pixelSize: ThemeManager.font.huge - ThemeManager.px(8)
                    font.weight: Font.DemiBold
                }
            }

            Txt {
                anchors.right: parent.right
                anchors.rightMargin: ThemeManager.spacing.normal + ThemeManager.px(2)
                anchors.verticalCenter: parent.verticalCenter
                text: PowerState.batteryNote
                color: label.tint
                opacity: label.noteOpacity
                font.weight: Font.Medium
            }
        }

        // O corpo recorta o preenchimento e o texto no formato do card.
        ClippingRectangle {
            id: body

            width: parent.width - pole.width - ThemeManager.px(3)
            height: parent.height
            radius: ThemeManager.radius.normal
            color: card.empty

            CardLabel {
                tint: ThemeManager.colors.text
            }

            // A parte cheia leva a cópia do texto na cor do texto do contêiner,
            // cortada na largura dela.
            Rectangle {
                width: body.width * Math.max(0, Math.min(1, card.shown))
                height: body.height
                clip: true
                color: card.fill

                Behavior on color { ColorAnim {} }

                CardLabel {
                    tint: card.ink
                    noteOpacity: 1
                }
            }
        }

        // O polo, à direita: cheio só com a bateria cheia.
        Rectangle {
            id: pole

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: ThemeManager.px(5)
            height: parent.height * 0.36
            topRightRadius: ThemeManager.px(3)
            bottomRightRadius: ThemeManager.px(3)
            color: card.shown >= 0.995 ? card.fill : card.empty

            Behavior on color { ColorAnim {} }
        }
    }

    Row {
        id: profiles

        visible: PowerState.profilesAvailable
        width: parent.width
        spacing: ThemeManager.spacing.small

        // Pela quantidade, como os outros botões: cada um lê o seu perfil.
        Repeater {
            model: PowerState.profileButtons.length

            delegate: ToggleButton {
                id: profile

                required property int index
                readonly property var item: PowerState.profileButtons[profile.index] ?? null

                width: (profiles.width - profiles.spacing * (PowerState.profileButtons.length - 1)) / PowerState.profileButtons.length
                height: ThemeManager.px(40)
                label: profile.item?.label ?? ""
                checked: profile.item?.value === PowerState.profile
                onClicked: PowerState.setProfile(profile.item?.value ?? PowerState.profile)
            }
        }
    }

    // O consumo da última hora: o rótulo, o valor de agora e o gráfico.
    Group {
        visible: PowerState.hasBattery

        Item {
            width: parent.width
            height: ThemeManager.px(32)

            Txt {
                x: ThemeManager.spacing.small
                anchors.verticalCenter: parent.verticalCenter
                text: "Consumo"
                font.weight: Font.Medium
            }

            Txt {
                anchors.right: parent.right
                anchors.rightMargin: ThemeManager.spacing.small
                anchors.verticalCenter: parent.verticalCenter
                text: PowerState.consumptionText
                mono: true
                muted: true
            }
        }

        Sparkline {
            x: ThemeManager.spacing.small
            width: parent.width - x * 2
            height: ThemeManager.px(72)
            normalized: PowerState.chart

            Txt {
                anchors.centerIn: parent
                visible: PowerState.chartNote !== ""
                text: PowerState.chartNote
                faint: true
            }
        }

        Item {
            width: 1
            height: ThemeManager.spacing.small
        }
    }

    Group {
        visible: PowerState.devices.length > 0

        // Pela quantidade, como os botões e os volumes: a bateria que muda
        // refaz a lista, mas não recria as linhas.
        Repeater {
            model: PowerState.devices.length

            delegate: Item {
                id: device

                required property int index
                readonly property var item: PowerState.devices[device.index] ?? null

                width: parent?.width ?? 0
                height: ThemeManager.px(44)

                Icon {
                    id: deviceIcon

                    x: ThemeManager.spacing.small
                    anchors.verticalCenter: parent.verticalCenter
                    icon: device.item?.icon ?? ""
                    size: ThemeManager.px(20)
                    color: ThemeManager.colors.textMuted
                }

                Txt {
                    anchors.left: deviceIcon.right
                    anchors.leftMargin: ThemeManager.spacing.normal
                    anchors.right: percent.left
                    anchors.rightMargin: ThemeManager.spacing.small
                    anchors.verticalCenter: parent.verticalCenter
                    text: device.item?.name ?? ""
                }

                Txt {
                    id: percent

                    anchors.right: parent.right
                    anchors.rightMargin: ThemeManager.spacing.small
                    anchors.verticalCenter: parent.verticalCenter
                    text: Format.percent(device.item?.battery ?? 0)
                    mono: true
                    muted: true
                }
            }
        }
    }
}
