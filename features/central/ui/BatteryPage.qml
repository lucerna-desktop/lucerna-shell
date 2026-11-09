pragma ComponentBehavior: Bound

import QtQuick
import qs.core.format
import qs.core.theme
import qs.core.widgets
import qs.features.central.state

// Página da bateria no painel de ações da central: voltar e o título; o card
// em forma de bateria, no tom de contêiner da cor dela (destaque, aviso, erro
// ou, carregando, verde), com a porcentagem, o tempo (ou "Carregando"/
// "Carregada") e a barra de nível; o perfil de energia em botões de texto (o
// atual cheio); o consumo da última hora num gráfico; e a bateria dos dispositivos
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

        // A cor do estado (sem estado, o destaque). O card é o contêiner dela,
        // com o texto dele por cima; dentro, a barra de nível: o trilho é o
        // contêiner levado 25% rumo ao texto, e o preenchimento, a cor do
        // estado a 3:1 do trilho.
        readonly property color hue: PowerState.cardBand === "success" ? ThemeManager.colors.success : PowerState.cardBand === "danger" ? ThemeManager.colors.danger : PowerState.cardBand === "warning" ? ThemeManager.colors.warning : ThemeManager.colors.accent
        readonly property bool band: PowerState.cardBand === "success" || PowerState.cardBand === "danger" || PowerState.cardBand === "warning"
        readonly property color bg: band ? ThemeManager.container(hue) : ThemeManager.colors.accentContainer
        readonly property color ink: band ? ThemeManager.onContainer(hue) : ThemeManager.colors.onAccentContainer
        readonly property color empty: ThemeManager.trackOn(bg, ink)
        readonly property color fill: ThemeManager.iconOn(hue, empty, ThemeManager.dark)
        // A carga mostrada anima até a nova.
        property real shown: PowerState.percentage

        Behavior on shown { Anim { type: Anim.Standard } }

        visible: PowerState.hasBattery
        width: parent.width
        height: ThemeManager.px(76)

        Rectangle {
            id: body

            width: parent.width - pole.width - ThemeManager.px(3)
            height: parent.height
            radius: ThemeManager.radius.normal
            color: card.bg

            Behavior on color { ColorAnim {} }

            // A porcentagem (com o raio, carregando) à esquerda e o tempo à
            // direita, acima da barra.
            Item {
                id: labels

                x: ThemeManager.spacing.normal + ThemeManager.px(2)
                width: parent.width - x * 2
                height: level.y

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: ThemeManager.px(2)

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: PowerState.charging
                        icon: Icons.bolt
                        size: ThemeManager.px(24)
                        filled: true
                        color: card.fill
                    }

                    Txt {
                        text: Format.percent(PowerState.percentage)
                        mono: true
                        color: card.ink
                        font.pixelSize: ThemeManager.font.huge - ThemeManager.px(10)
                        font.weight: Font.DemiBold
                    }
                }

                Txt {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: PowerState.batteryNote
                    color: card.ink
                    font.weight: Font.Medium
                }
            }

            // A barra de nível, embaixo.
            Rectangle {
                id: level

                x: labels.x
                y: parent.height - height - ThemeManager.spacing.normal
                width: labels.width
                height: ThemeManager.px(8)
                radius: height / 2
                color: card.empty

                Behavior on color { ColorAnim {} }

                Rectangle {
                    width: Math.max(height, parent.width * Math.max(0, Math.min(1, card.shown)))
                    height: parent.height
                    radius: parent.radius
                    visible: card.shown > 0
                    color: card.fill

                    Behavior on color { ColorAnim {} }
                }
            }
        }

        // O polo, à direita, no contêiner; com a bateria cheia, no
        // preenchimento.
        Rectangle {
            id: pole

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: ThemeManager.px(5)
            height: parent.height * 0.36
            topRightRadius: ThemeManager.px(3)
            bottomRightRadius: ThemeManager.px(3)
            color: card.shown >= 0.995 ? card.fill : card.bg

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
