pragma ComponentBehavior: Bound

import QtQuick
import qs.core.input
import qs.core.theme
import qs.core.widgets
import qs.features.settings.state

// Adicionar ou editar um mapeamento: o botão/tecla (capturado), a ação e o que
// ela precisa (a combinação a enviar ou o comando).
Surface {
    id: root

    // "mouse" ou "key": este editor só aparece para o seu tipo.
    required property string kind

    readonly property var draft: BindsState.draft
    readonly property var action: InputActions.find(draft?.action?.id ?? "")

    visible: BindsState.editing && BindsState.mode === kind
    width: parent.width
    height: visible ? content.height + ThemeManager.spacing.large * 2 : 0
    color: ThemeManager.alpha(ThemeManager.colors.accent, 0.06)

    Column {
        id: content

        x: ThemeManager.spacing.large
        y: ThemeManager.spacing.large
        width: parent.width - x * 2
        spacing: ThemeManager.spacing.normal

        Txt {
            text: root.kind === "mouse" ? "Botão" : "Tecla"
            muted: true
            font.pixelSize: ThemeManager.font.small
            font.weight: Font.DemiBold
        }

        Loader {
            width: parent.width
            active: BindsState.capturing === "trigger"
            visible: active

            sourceComponent: CaptureBox {
                mode: root.kind
                hint: root.kind === "key" ? "Teclas extras do teclado (F13–F24, macro, mídia) ou uma combinação com Super, Ctrl, Alt e Shift" : ""
                onButton: (b, m) => BindsState.capturedButton(b, m)
                onKey: (k, c, m) => {
                    if (!BindsState.capturedKey(k, c, m) && !InputActions.modifierKeys.includes(k))
                        hint = "Essa tecla não tem nome no layout atual";
                }
            }
        }

        Row {
            width: parent.width
            visible: BindsState.capturing !== "trigger"
            spacing: ThemeManager.spacing.normal

            Txt {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - change.width - parent.spacing
                text: root.draft ? BindsState.describeTrigger(root.draft) : ""
                font.pixelSize: ThemeManager.font.large
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            TonalButton {
                id: change

                icon: Icons.record
                text: "Trocar"
                onClicked: BindsState.capture("trigger")
            }
        }

        Txt {
            text: "Ação"
            muted: true
            font.pixelSize: ThemeManager.font.small
            font.weight: Font.DemiBold
        }

        Select {
            width: parent.width
            searchable: true
            visibleRows: 7
            options: BindsState.actionOptions
            value: root.draft?.action?.id ?? ""
            onSelected: v => BindsState.setAction(v)
        }

        // Atalho a enviar
        Loader {
            width: parent.width
            active: root.action?.kind === "shortcut" && BindsState.capturing === "shortcut"
            visible: active

            sourceComponent: CaptureBox {
                mode: "key"
                text: "Aperte a combinação que o botão vai enviar"
                hint: "Ex.: Ctrl + C, Ctrl + Shift + T, F5"
                onKey: (k, c, m) => BindsState.capturedKey(k, c, m)
            }
        }

        Row {
            width: parent.width
            visible: root.action?.kind === "shortcut" && BindsState.capturing !== "shortcut"
            spacing: ThemeManager.spacing.normal

            Txt {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - record.width - parent.spacing
                text: root.draft?.action?.key ? `Envia ${InputActions.prettyCombo(root.draft.action.mods ?? "", root.draft.action.key)} para a janela em foco` : "Nenhuma combinação ainda"
                muted: !root.draft?.action?.key
                wrapMode: Text.Wrap
            }

            TonalButton {
                id: record

                icon: Icons.record
                text: root.draft?.action?.key ? "Trocar" : "Gravar"
                onClicked: BindsState.capture("shortcut")
            }
        }

        // Comando
        Rectangle {
            width: parent.width
            height: ThemeManager.px(40)
            visible: root.action?.kind === "command"
            radius: height / 2
            color: ThemeManager.alpha(ThemeManager.colors.text, 0.06)
            border.width: command.activeFocus ? ThemeManager.px(2) : 0
            border.color: ThemeManager.colors.accent

            TextInput {
                id: command

                anchors.fill: parent
                anchors.leftMargin: ThemeManager.spacing.normal + ThemeManager.px(2)
                anchors.rightMargin: ThemeManager.spacing.normal
                verticalAlignment: TextInput.AlignVCenter
                color: ThemeManager.colors.text
                font.family: ThemeManager.font.mono
                font.pixelSize: ThemeManager.font.normal
                clip: true
                text: root.draft?.action?.command ?? ""
                onTextEdited: BindsState.setCommand(text)

                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !command.text
                    text: "Ex.: kitty, firefox --new-window, grim ~/print.png"
                    faint: true
                }
            }
        }

        Row {
            anchors.right: parent.right
            spacing: ThemeManager.spacing.small

            TonalButton {
                text: "Cancelar"
                onClicked: BindsState.cancel()
            }

            TonalButton {
                icon: Icons.check
                text: "Salvar"
                enabled: BindsState.canSave
                opacity: enabled ? 1 : 0.45
                onClicked: BindsState.save()
            }
        }
    }
}
