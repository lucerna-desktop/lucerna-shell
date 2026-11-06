import QtQuick
import qs.core.input
import qs.core.theme
import qs.core.widgets
import qs.features.settings.state

// Teclado: layouts, digitação, teclas especiais (opções do xkb), teclas
// remapeadas e teclas extras/atalhos mapeados para ações.
Column {
    spacing: ThemeManager.spacing.large

    SettingSection {
        title: "Layouts"

        Repeater {
            model: KeyboardState.layouts

            delegate: SettingRow {
                id: layoutRow

                required property var modelData
                required property int index

                wide: true
                icon: Icons.layout
                title: KeyboardState.layoutName(modelData.layout)
                description: index === 0 ? "Principal" : `${index + 1}º`

                Item {
                    width: parent.width
                    height: ThemeManager.px(40)

                    Select {
                        width: parent.width - actions.width - ThemeManager.spacing.small
                        searchable: true
                        options: KeyboardState.variantOptions(layoutRow.modelData.layout)
                        value: layoutRow.modelData.variant ?? ""
                        onSelected: v => KeyboardState.setVariant(layoutRow.index, v)
                    }

                    Row {
                        id: actions

                        anchors.right: parent.right
                        height: ThemeManager.px(40)
                        spacing: ThemeManager.px(2)

                        IconButton {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "keyboard_arrow_up"
                            iconSize: ThemeManager.px(20)
                            enabled: layoutRow.index > 0
                            onClicked: KeyboardState.moveLayout(layoutRow.index, -1)
                        }

                        IconButton {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: Icons.trash
                            iconSize: ThemeManager.px(18)
                            enabled: KeyboardState.layouts.length > 1
                            onClicked: KeyboardState.removeLayout(layoutRow.index)
                        }
                    }
                }
            }
        }

        SettingRow {
            visible: KeyboardState.layouts.length < 4
            wide: true
            icon: Icons.add
            title: "Adicionar layout"

            Select {
                width: parent.width
                searchable: true
                visibleRows: 8
                placeholder: "Escolher um idioma ou layout"
                options: KeyboardState.layoutOptions
                value: ""
                onSelected: v => KeyboardState.addLayout(v)
            }
        }

        SettingRow {
            visible: KeyboardState.layouts.length > 1
            wide: true
            icon: Icons.swap
            title: "Trocar de layout com"

            SegmentedControl {
                width: parent.width
                options: KeyboardState.switchChoices
                value: KeyboardState.choiceOf(KeyboardState.switchGroup)
                onSelected: v => KeyboardState.setChoice(KeyboardState.switchGroup, v)
            }
        }
    }

    SettingSection {
        title: "Digitação"

        SettingRow {
            wide: true
            icon: Icons.timer
            title: "Espera até repetir"
            description: "Quanto tempo segurar uma tecla até ela começar a se repetir"

            Slider {
                width: parent.width
                from: 150
                to: 1000
                stepSize: 25
                value: KeyboardState.repeatDelay
                format: v => `${Math.round(v)} ms`
                onMoved: v => KeyboardState.set("input.repeat_delay", Math.round(v))
            }
        }

        SettingRow {
            wide: true
            icon: Icons.repeat
            title: "Velocidade da repetição"

            Slider {
                width: parent.width
                from: 10
                to: 80
                stepSize: 1
                value: KeyboardState.repeatRate
                format: v => `${Math.round(v)} por segundo`
                onMoved: v => KeyboardState.set("input.repeat_rate", Math.round(v))
            }
        }

        SettingRow {
            icon: Icons.numlock
            title: "Num Lock ligado ao entrar"

            Switch {
                checked: KeyboardState.numlock
                onToggled: on => KeyboardState.set("input.numlock_by_default", on)
            }
        }

        // Campo para testar a digitação e a repetição.
        Item {
            width: parent.width
            height: ThemeManager.px(40) + ThemeManager.spacing.large * 2

            Rectangle {
                x: ThemeManager.spacing.large
                y: ThemeManager.spacing.large
                width: parent.width - x * 2
                height: ThemeManager.px(40)
                radius: height / 2
                color: ThemeManager.alpha(ThemeManager.colors.text, 0.06)
                border.width: tryIt.activeFocus ? ThemeManager.px(2) : 0
                border.color: ThemeManager.colors.accent

                TextInput {
                    id: tryIt

                    anchors.fill: parent
                    anchors.leftMargin: ThemeManager.spacing.normal + ThemeManager.px(2)
                    anchors.rightMargin: ThemeManager.spacing.normal
                    verticalAlignment: TextInput.AlignVCenter
                    color: ThemeManager.colors.text
                    font.family: ThemeManager.font.sans
                    font.variableAxes: ThemeManager.fontAxes(Font.Normal)
                    font.pixelSize: ThemeManager.font.normal
                    clip: true

                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !tryIt.text
                        text: "Teste aqui"
                        faint: true
                    }
                }
            }
        }
    }

    SettingSection {
        title: "Teclas especiais"

        SettingRow {
            wide: true
            icon: Icons.keyboard
            title: "Caps Lock funciona como"

            Select {
                width: parent.width
                options: KeyboardState.capsChoices
                value: KeyboardState.choiceOf(KeyboardState.capsGroup)
                onSelected: v => KeyboardState.setChoice(KeyboardState.capsGroup, v)
            }
        }

        SettingRow {
            wide: true
            icon: Icons.compose
            title: "Tecla Compose"
            description: "Compõe caracteres em sequência: Compose, ' e e dão é"

            Select {
                width: parent.width
                options: KeyboardState.composeChoices
                value: KeyboardState.choiceOf(KeyboardState.composeGroup)
                onSelected: v => KeyboardState.setChoice(KeyboardState.composeGroup, v)
            }
        }

        SettingRow {
            icon: Icons.swap
            title: "Trocar Alt e Super"

            Switch {
                checked: KeyboardState.hasOption("altwin:swap_alt_win")
                onToggled: on => KeyboardState.toggleOption("altwin:swap_alt_win", on)
            }
        }

        SettingRow {
            icon: Icons.keyboard
            title: "Os dois Shift ligam o Caps Lock"

            Switch {
                checked: KeyboardState.hasOption("shift:both_capslock")
                onToggled: on => KeyboardState.toggleOption("shift:both_capslock", on)
            }
        }

        Repeater {
            model: KeyboardState.otherOptions

            delegate: SettingRow {
                id: optionRow

                required property var modelData

                icon: Icons.settings
                title: modelData.description
                description: modelData.name

                IconButton {
                    icon: Icons.trash
                    iconSize: ThemeManager.px(18)
                    onClicked: KeyboardState.toggleOption(optionRow.modelData.name, false)
                }
            }
        }

        SettingRow {
            wide: true
            icon: Icons.add
            title: "Outras opções do xkb"
            description: "Todas as que o xkb oferece (em inglês)"

            Select {
                width: parent.width
                searchable: true
                visibleRows: 8
                placeholder: "Buscar uma opção"
                options: KeyboardState.optionChoices
                value: ""
                onSelected: v => KeyboardState.toggleOption(v, true)
            }
        }
    }

    SettingSection {
        title: "Teclas remapeadas"

        Txt {
            x: ThemeManager.spacing.large
            width: parent.width - x * 2
            topPadding: ThemeManager.spacing.normal
            bottomPadding: ThemeManager.spacing.normal
            visible: KeyboardState.remaps.length === 0
            wrapMode: Text.Wrap
            text: "Faça uma tecla virar outra em qualquer programa: o Caps Lock virar Esc, o Alt direito virar Super, uma tecla que você não usa virar Tocar/pausar, ou desativar uma tecla."
            muted: true
            font.pixelSize: ThemeManager.font.small + 1
        }

        Repeater {
            model: KeyboardState.remaps

            delegate: SettingRow {
                id: remapRow

                required property var modelData

                icon: Icons.swap
                title: `${KeyboardState.keyLabel(modelData.from)}  →  ${KeyboardState.targetLabel(modelData.to)}`
                description: `Tecla <${modelData.from}>`

                IconButton {
                    icon: Icons.trash
                    iconSize: ThemeManager.px(18)
                    onClicked: KeyboardState.removeRemap(remapRow.modelData.from)
                }
            }
        }
    }

    // Editor de remapeamento
    Surface {
        visible: KeyboardState.remapDraft !== null
        width: parent.width
        height: visible ? remapEditor.height + ThemeManager.spacing.large * 2 : 0
        color: ThemeManager.alpha(ThemeManager.colors.accent, 0.06)

        Column {
            id: remapEditor

            x: ThemeManager.spacing.large
            y: ThemeManager.spacing.large
            width: parent.width - x * 2
            spacing: ThemeManager.spacing.normal

            Txt {
                text: "Tecla"
                muted: true
                font.pixelSize: ThemeManager.font.small
                font.weight: Font.DemiBold
            }

            Loader {
                width: parent.width
                active: KeyboardState.remapCapturing !== ""
                visible: active

                sourceComponent: CaptureBox {
                    mode: "key"
                    text: KeyboardState.remapCapturing === "from" ? "Aperte a tecla que vai mudar" : "Aperte a tecla que ela vai virar"
                    hint: "Vale qualquer tecla, inclusive Ctrl, Alt, Shift e Super"
                    onKey: (k, c, m) => {
                        if (!KeyboardState.capturedRemapKey(c))
                            hint = "Essa tecla não está no layout atual";
                    }
                }
            }

            Row {
                width: parent.width
                visible: KeyboardState.remapCapturing === ""
                spacing: ThemeManager.spacing.normal

                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - changeKey.width - parent.spacing
                    text: KeyboardState.remapDraft?.from ? KeyboardState.keyLabel(KeyboardState.remapDraft.from) : ""
                    font.pixelSize: ThemeManager.font.large
                    font.weight: Font.DemiBold
                }

                TonalButton {
                    id: changeKey

                    icon: Icons.record
                    text: "Trocar"
                    onClicked: KeyboardState.captureRemap("from")
                }
            }

            Txt {
                visible: KeyboardState.remapCapturing === ""
                text: "Vira"
                muted: true
                font.pixelSize: ThemeManager.font.small
                font.weight: Font.DemiBold
            }

            Item {
                visible: KeyboardState.remapCapturing === ""
                width: parent.width
                height: target.height

                Select {
                    id: target

                    width: parent.width - pressTarget.width - ThemeManager.spacing.small
                    visibleRows: 7
                    placeholder: KeyboardState.remapDraft ? KeyboardState.targetLabel(KeyboardState.remapDraft.to) : ""
                    options: KeyboardState.targetOptions
                    value: InputActions.remapTargets.findIndex(t => JSON.stringify(t.to) === JSON.stringify(KeyboardState.remapDraft?.to))
                    onSelected: v => KeyboardState.setRemapTarget(v)
                }

                TonalButton {
                    id: pressTarget

                    anchors.right: parent.right
                    icon: Icons.record
                    text: "Outra tecla"
                    onClicked: KeyboardState.captureRemap("to")
                }
            }

            Row {
                anchors.right: parent.right
                spacing: ThemeManager.spacing.small

                TonalButton {
                    text: "Cancelar"
                    onClicked: KeyboardState.cancelRemap()
                }

                TonalButton {
                    icon: Icons.check
                    text: "Salvar"
                    enabled: !!KeyboardState.remapDraft?.from && KeyboardState.remapCapturing === ""
                    opacity: enabled ? 1 : 0.45
                    onClicked: KeyboardState.saveRemap()
                }
            }
        }
    }

    TonalButton {
        visible: KeyboardState.remapDraft === null
        icon: Icons.add
        text: "Remapear uma tecla"
        onClicked: KeyboardState.startRemap()
    }

    SettingSection {
        title: "Teclas extras e atalhos"

        BindList {
            entries: BindsState.keys
            emptyText: "Teclas extras (F13–F24, macro, mídia, calculadora…) ou combinações como Super + E podem abrir o launcher, controlar a mídia, trocar de workspace, enviar outro atalho ou rodar um comando."
        }
    }

    BindEditor {
        kind: "key"
    }

    TonalButton {
        visible: !BindsState.editing
        icon: Icons.add
        text: "Mapear uma tecla"
        onClicked: BindsState.startNew("key")
    }

    TonalButton {
        visible: KeyboardState.customized
        icon: Icons.refresh
        text: "Voltar ao hyprland.lua"
        onClicked: KeyboardState.reset()
    }
}
