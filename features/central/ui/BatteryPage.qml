pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import qs.core.format
import qs.core.theme
import qs.core.widgets
import qs.features.central.state

// Página da bateria no painel de ações da central: voltar e o título; a
// porcentagem e o tempo (ou "Carregando"/"Carregada") numa linha, e embaixo o
// card em forma de bateria, preenchido pela carga na cor dela (destaque,
// aviso, erro ou, carregando, verde), sem texto por cima; o perfil de energia em botões de texto (o
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

    // A porcentagem (com o raio, carregando) e o tempo, numa linha acima do
    // desenho, no texto da página: o desenho fica sem texto por cima.
    Item {
        visible: PowerState.hasBattery
        width: parent.width
        height: percentLabel.implicitHeight

        Row {
            x: ThemeManager.px(2)
            anchors.verticalCenter: parent.verticalCenter
            spacing: ThemeManager.px(2)

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: PowerState.charging
                icon: Icons.bolt
                size: ThemeManager.px(24)
                filled: true
                color: ThemeManager.colors.text
            }

            Txt {
                id: percentLabel

                text: Format.percent(PowerState.percentage)
                mono: true
                font.pixelSize: ThemeManager.font.huge - ThemeManager.px(10)
                font.weight: Font.DemiBold
            }
        }

        Txt {
            anchors.right: parent.right
            anchors.rightMargin: ThemeManager.px(2)
            anchors.verticalCenter: parent.verticalCenter
            text: PowerState.batteryNote
            muted: true
            font.weight: Font.Medium
        }
    }

    // O desenho da bateria, preenchido pela carga: o corpo é o trilho, e a
    // parte cheia, a cor do estado (destaque, aviso, erro ou, carregando,
    // verde) ajustada a 3:1 do trilho pelo fillOf (o destaque é o accentFill).
    Item {
        id: card

        readonly property color hue: PowerState.cardBand === "success" ? ThemeManager.colors.success : PowerState.cardBand === "danger" ? ThemeManager.colors.danger : PowerState.cardBand === "warning" ? ThemeManager.colors.warning : ThemeManager.colors.accent
        readonly property bool band: PowerState.cardBand === "success" || PowerState.cardBand === "danger" || PowerState.cardBand === "warning"
        readonly property color empty: ThemeManager.colors.track
        readonly property color fill: band ? ThemeManager.fillOf(hue, ThemeManager.colors.surface, empty) : ThemeManager.colors.accentFill
        // A carga mostrada anima até a nova.
        property real shown: PowerState.percentage

        Behavior on shown { Anim { type: Anim.Standard } }

        visible: PowerState.hasBattery
        width: parent.width
        height: ThemeManager.px(76)

        // O corpo recorta o preenchimento no formato do card.
        ClippingRectangle {
            id: body

            width: parent.width - pole.width - ThemeManager.px(3)
            height: parent.height
            radius: ThemeManager.radius.normal
            color: card.empty

            Rectangle {
                width: body.width * Math.max(0, Math.min(1, card.shown))
                height: body.height
                color: card.fill

                Behavior on color { ColorAnim {} }
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
