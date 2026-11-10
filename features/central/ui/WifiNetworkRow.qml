pragma ComponentBehavior: Bound

import QtQuick
import qs.core.theme
import qs.core.widgets
import qs.features.central.state

// Linha de uma rede na página do Wi-Fi: a rede (clicar conecta, desconecta ou
// abre a senha), o cadeado, o esquecer (na rede salva) e, aberto, o campo de
// senha com o Conectar. `modelData` é um item de WifiState.networks.
Column {
    id: entry

    required property var modelData
    readonly property bool open: WifiState.expanded === entry.modelData.network

    width: parent?.width ?? 0
    spacing: ThemeManager.px(4)

    // A senha fica no WifiState: a linha aberta a pega ao abrir, ao nascer
    // aberta (a lista de redes refeita recria as linhas) e ao reaparecer, com o
    // cursor onde estava e o foco no campo.
    onOpenChanged: {
        if (open)
            restore();
    }
    Component.onCompleted: {
        if (open)
            restore();
    }

    function restore(): void {
        const cursor = WifiState.cursor;
        password.text = WifiState.password;
        password.cursorPosition = Math.min(cursor, password.length);
        password.forceActiveFocus();
    }

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

                objectName: "password"

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
                onTextChanged: {
                    if (entry.open)
                        WifiState.password = text;
                }
                onCursorPositionChanged: {
                    if (entry.open)
                        WifiState.cursor = cursorPosition;
                }
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

        // A senha e o foco de novo quando o campo aparece (a abertura o anima a
        // partir da altura zero, invisível); fechado, o campo apaga o texto
        // quando some, no fim da animação.
        onVisibleChanged: {
            if (visible && entry.open)
                entry.restore();
            else if (!visible && !entry.open)
                password.text = "";
        }
    }
}
