import QtQuick
import qs.core.theme
import qs.core.widgets
import qs.features.settings.state

// Mouse: ponteiro, rolagem, foco, touchpad, botões mapeados e velocidade por
// dispositivo.
Column {
    spacing: ThemeManager.spacing.large

    SettingSection {
        title: "Ponteiro"

        SettingRow {
            wide: true
            icon: Icons.pointerSpeed
            title: "Velocidade"

            LevelSlider {
                width: parent.width
                from: -1
                to: 1
                stepSize: 0.05
                value: MouseState.sensitivity
                format: v => v === 0 ? "Padrão" : `${v > 0 ? "+" : ""}${Math.round(v * 100)}`
                onMoved: v => MouseState.set("input.sensitivity", Math.round(v * 100) / 100)
            }
        }

        SettingRow {
            wide: true
            icon: Icons.refreshRate
            title: "Aceleração"
            description: "Adaptativa: movimentos rápidos vão mais longe. Plana: a mesma distância em qualquer velocidade, melhor para jogos"

            SegmentedControl {
                width: parent.width
                options: [
                    { label: "Adaptativa", value: "adaptive" },
                    { label: "Plana", value: "flat" }
                ]
                value: MouseState.accel
                onSelected: v => MouseState.set("input.accel_profile", v)
            }
        }

        SettingRow {
            icon: Icons.leftHanded
            title: "Canhoto"
            description: "Troca os botões esquerdo e direito"

            Switch {
                checked: MouseState.leftHanded
                onToggled: on => MouseState.set("input.left_handed", on)
            }
        }

        SettingRow {
            wide: true
            icon: Icons.focusMouse
            title: "Foco das janelas"

            SegmentedControl {
                width: parent.width
                options: [
                    { label: "Ao passar o mouse", value: 1 },
                    { label: "Ao clicar", value: 0 }
                ]
                value: MouseState.followMouse
                onSelected: v => MouseState.set("input.follow_mouse", v)
            }
        }
    }

    SettingSection {
        title: "Rolagem"

        SettingRow {
            icon: Icons.scroll
            title: "Rolagem natural"
            description: "O conteúdo acompanha o dedo, como no celular"

            Switch {
                checked: MouseState.naturalScroll
                onToggled: on => MouseState.set("input.natural_scroll", on)
            }
        }

        SettingRow {
            wide: true
            icon: Icons.pointerSpeed
            title: "Velocidade da rolagem"

            LevelSlider {
                width: parent.width
                from: 0.2
                to: 3
                stepSize: 0.1
                value: MouseState.scrollFactor
                format: v => `${v.toFixed(1)}×`
                onMoved: v => MouseState.set("input.scroll_factor", Math.round(v * 10) / 10)
            }
        }
    }

    SettingSection {
        visible: MouseState.hasTouchpad
        title: "Touchpad"

        SettingRow {
            icon: Icons.tap
            title: "Tocar para clicar"
            description: "Um toque clica; dois, o botão direito; três, o do meio"

            Switch {
                checked: MouseState.tapToClick
                onToggled: on => MouseState.set("input.touchpad.tap_to_click", on)
            }
        }

        SettingRow {
            icon: Icons.tap
            title: "Tocar e arrastar"
            description: "Dois toques rápidos seguram para arrastar"
            dimmed: !MouseState.tapToClick

            Switch {
                checked: MouseState.tapAndDrag
                onToggled: on => MouseState.set("input.touchpad.tap_and_drag", on)
            }
        }

        SettingRow {
            icon: Icons.scroll
            title: "Rolagem natural"

            Switch {
                checked: MouseState.touchpadNatural
                onToggled: on => MouseState.set("input.touchpad.natural_scroll", on)
            }
        }

        SettingRow {
            wide: true
            icon: Icons.pointerSpeed
            title: "Velocidade da rolagem"

            LevelSlider {
                width: parent.width
                from: 0.2
                to: 3
                stepSize: 0.1
                value: MouseState.touchpadScroll
                format: v => `${v.toFixed(1)}×`
                onMoved: v => MouseState.set("input.touchpad.scroll_factor", Math.round(v * 10) / 10)
            }
        }

        SettingRow {
            icon: Icons.keyboard
            title: "Desligar enquanto digita"

            Switch {
                checked: MouseState.disableWhileTyping
                onToggled: on => MouseState.set("input.touchpad.disable_while_typing", on)
            }
        }

        SettingRow {
            icon: Icons.touchpad
            title: "Clique com dedos"
            description: "Apertar com dois dedos é o botão direito, com três é o do meio (em vez de pela região do touchpad)"

            Switch {
                checked: MouseState.clickfinger
                onToggled: on => MouseState.set("input.touchpad.clickfinger_behavior", on)
            }
        }

        SettingRow {
            icon: Icons.touchpad
            title: "Botão do meio com os dois"
            description: "Apertar esquerdo e direito juntos vira o botão do meio"

            Switch {
                checked: MouseState.middleEmulation
                onToggled: on => MouseState.set("input.touchpad.middle_button_emulation", on)
            }
        }
    }

    SettingSection {
        title: "Botões"

        BindList {
            entries: BindsState.mouse
            emptyText: "Os botões do meio e os laterais podem abrir o launcher, trocar de workspace, controlar a mídia, enviar um atalho de teclado ou rodar um comando."
        }
    }

    BindEditor {
        kind: "mouse"
    }

    TonalButton {
        visible: !BindsState.editing
        icon: Icons.add
        text: "Mapear um botão"
        onClicked: BindsState.startNew("mouse")
    }

    SettingSection {
        visible: MouseState.mice.length > 0
        title: "Dispositivos"

        Repeater {
            model: MouseState.mice

            delegate: SettingRow {
                id: device

                required property var modelData
                readonly property bool own: MouseState.hasOwnSpeed(modelData.name)

                wide: own
                icon: Icons.mouse
                title: modelData.name
                description: own ? "Velocidade própria" : "Usa a velocidade geral"

                Column {
                    width: device.own ? parent.width : implicitWidth
                    spacing: ThemeManager.spacing.small

                    Switch {
                        anchors.right: parent.right
                        checked: device.own
                        onToggled: on => on ? MouseState.setDeviceSpeed(device.modelData.name, MouseState.sensitivity) : MouseState.clearDevice(device.modelData.name)
                    }

                    LevelSlider {
                        visible: device.own
                        width: parent.width
                        from: -1
                        to: 1
                        stepSize: 0.05
                        value: MouseState.deviceSpeed(device.modelData.name)
                        format: v => v === 0 ? "Padrão" : `${v > 0 ? "+" : ""}${Math.round(v * 100)}`
                        onMoved: v => MouseState.setDeviceSpeed(device.modelData.name, v)
                    }
                }
            }
        }
    }

    TonalButton {
        visible: MouseState.customized
        icon: Icons.refresh
        text: "Voltar ao hyprland.lua"
        onClicked: MouseState.reset()
    }
}
