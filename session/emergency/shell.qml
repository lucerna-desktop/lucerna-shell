pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// A tela de emergência do Lucerna: uma config própria do Quickshell, rodada com
// `qs -p` pelo `lucerna-session emergency`, feita sem nada do shell (nem tema,
// nem fontes de ícone, nem serviços) para não cair junto com ele.
//   LUCERNA_EMERGENCY_MODE  crashed (o shell caiu até no modo de segurança) ou
//                           power (o Ctrl+Alt+Delete com o shell morto)
//   LUCERNA_EMERGENCY_LOG   o registro da última queda (as 30 últimas linhas)
//   LUCERNA_SESSION_BIN     o lucerna-session que roda os botões
// No modo power, "Reiniciar o shell" (o primeiro, o do Enter) sobe o shell de
// novo pelo supervisor: é a saída para um shell travado.
// Um véu escuro em cada tela, com o cartão no centro. Setas e Tab escolhem,
// Enter aperta; Esc fecha no modo power. "Abrir um terminal" e "Ver o
// registro" recolhem o véu numa pílula embaixo (no modo crashed; no power, a
// tela fecha), para o terminal ficar visível.
ShellRoot {
    id: root

    readonly property string mode: Quickshell.env("LUCERNA_EMERGENCY_MODE") === "power" ? "power" : "crashed"
    readonly property string logPath: Quickshell.env("LUCERNA_EMERGENCY_LOG") || ""
    readonly property string sessionBin: Quickshell.env("LUCERNA_SESSION_BIN") || "lucerna-session"
    readonly property var actions: mode === "crashed" ? [
        {
            id: "retry",
            label: "Tentar de novo"
        },
        {
            id: "terminal",
            label: "Abrir um terminal"
        },
        {
            id: "log",
            label: "Ver o registro"
        },
        {
            id: "poweroff",
            label: "Desligar"
        },
        {
            id: "reboot",
            label: "Reiniciar"
        },
        {
            id: "logout",
            label: "Sair da sessão"
        }
    ] : [
        {
            id: "restart",
            label: "Reiniciar o shell"
        },
        {
            id: "terminal",
            label: "Abrir um terminal"
        },
        {
            id: "log",
            label: "Ver o registro"
        },
        {
            id: "poweroff",
            label: "Desligar"
        },
        {
            id: "reboot",
            label: "Reiniciar"
        },
        {
            id: "logout",
            label: "Sair da sessão"
        },
        {
            id: "close",
            label: "Fechar"
        }
    ]
    property int selected: 0
    // Recolhida: o véu vira uma pílula embaixo, sem o foco do teclado.
    property bool collapsed: false
    // As 30 últimas linhas do registro, sem as cores do terminal.
    readonly property string logTail: {
        const text = logFile.loaded ? logFile.text() : "";
        const lines = text.replace(/\x1b\[[0-9;]*m/g, "").replace(/\n+$/, "").split("\n");
        return lines.slice(-30).join("\n");
    }

    function run(args) {
        Quickshell.execDetached([root.sessionBin].concat(args));
    }

    function press(id) {
        if (id === "retry" && root.mode === "crashed") {
            root.run(["shell", "start"]);
            Qt.quit();
        } else if (id === "restart" && root.mode === "power") {
            // O shell travado (vivo, mas sem responder) ou morto na pausa: o
            // supervisor para o que houver e sobe de novo (bloqueado, se estava).
            root.run(["shell", "restart"]);
            Qt.quit();
        } else if (id === "terminal" || id === "log") {
            root.run(id === "log" && root.logPath !== "" ? ["open", "terminal", "less", "+G", root.logPath] : ["open", "terminal"]);
            if (root.mode === "power")
                Qt.quit();
            else
                root.collapsed = true;
        } else if (id === "poweroff" || id === "reboot" || id === "logout") {
            root.run([id]);
        } else if (id === "close" && root.mode === "power") {
            Qt.quit();
        }
    }

    function move(step) {
        root.selected = (root.selected + step + root.actions.length) % root.actions.length;
    }

    FileView {
        id: logFile

        path: root.mode === "crashed" ? root.logPath : ""
        blockLoading: true
        printErrors: false
    }

    // A conferência (qs -p … ipc call emergency press ID|state|expand).
    IpcHandler {
        target: "emergency"

        function press(id: string): void {
            root.press(id);
        }

        function state(): string {
            return root.mode;
        }

        // Volta da pílula para a tela inteira (o Ctrl+Alt+Delete de novo).
        function expand(): void {
            root.collapsed = false;
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: window

            required property var modelData

            screen: modelData
            anchors.top: !root.collapsed
            anchors.bottom: true
            anchors.left: !root.collapsed
            anchors.right: !root.collapsed
            implicitWidth: root.collapsed ? pill.width + 32 : 0
            implicitHeight: root.collapsed ? pill.height + 32 : 0
            color: root.collapsed ? "transparent" : "#d9000000"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: root.collapsed ? WlrLayer.Top : WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.collapsed ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "lucerna-emergency"

            Item {
                anchors.fill: parent
                focus: true
                Keys.onPressed: event => {
                    if (root.collapsed)
                        return;
                    if (event.key === Qt.Key_Left || event.key === Qt.Key_Up || event.key === Qt.Key_Backtab)
                        root.move(-1);
                    else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down || event.key === Qt.Key_Tab)
                        root.move(1);
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
                        root.press(root.actions[root.selected].id);
                    else if (event.key === Qt.Key_Escape && root.mode === "power")
                        root.press("close");
                    else
                        return;
                    event.accepted = true;
                }
            }

            Rectangle {
                id: card

                visible: !root.collapsed
                anchors.centerIn: parent
                width: Math.min(parent.width - 48, 820)
                height: column.implicitHeight + 64
                radius: 16
                color: "#1e1e24"
                border.color: "#3a3a44"

                ColumnLayout {
                    id: column

                    anchors.fill: parent
                    anchors.margins: 32
                    spacing: 16

                    Text {
                        Layout.fillWidth: true
                        text: root.mode === "crashed" ? "O Lucerna não conseguiu iniciar" : "Energia e sessão"
                        color: "#f2f2f5"
                        font.pixelSize: 26
                        font.weight: Font.DemiBold
                        wrapMode: Text.Wrap
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: root.mode === "crashed"
                        text: "O shell caiu várias vezes seguidas, também no modo de segurança."
                        color: "#c8c8d0"
                        font.pixelSize: 16
                        wrapMode: Text.Wrap
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 260
                        visible: root.mode === "crashed"
                        radius: 8
                        color: "#121216"
                        clip: true

                        Flickable {
                            id: logView

                            anchors.fill: parent
                            anchors.margins: 12
                            contentWidth: width
                            contentHeight: logText.implicitHeight
                            boundsBehavior: Flickable.StopAtBounds
                            // Começa no fim: as linhas mais novas.
                            onContentHeightChanged: contentY = Math.max(0, contentHeight - height)

                            Text {
                                id: logText

                                width: logView.width
                                text: root.logTail !== "" ? root.logTail : (root.logPath !== "" ? `Não consegui ler ${root.logPath}.` : "Nenhum registro.")
                                textFormat: Text.PlainText
                                color: "#b8b8c2"
                                font.family: "monospace"
                                font.pixelSize: 12
                                wrapMode: Text.WrapAnywhere
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: root.mode === "crashed" && root.logPath !== ""
                        text: root.logPath
                        color: "#8a8a96"
                        font.pixelSize: 12
                        elide: Text.ElideMiddle
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 8

                        Repeater {
                            model: root.actions

                            Rectangle {
                                id: button

                                required property var modelData
                                required property int index
                                readonly property bool current: root.selected === index

                                width: label.implicitWidth + 32
                                height: 40
                                radius: 8
                                // A escolha é só do teclado: o ponteiro parado sobre um botão
                                // quando a tela abre não escolhe nada (um Enter ali desligaria).
                                color: current ? "#4a5cff" : (area.containsMouse ? "#3a3a46" : "#2c2c35")
                                border.color: current ? "#8f9bff" : "transparent"
                                border.width: 2

                                Text {
                                    id: label

                                    anchors.centerIn: parent
                                    text: button.modelData.label
                                    color: "#ffffff"
                                    font.pixelSize: 15
                                }

                                MouseArea {
                                    id: area

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.press(button.modelData.id)
                                }
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.mode === "power" ? "Setas para escolher, Enter para confirmar, Esc para fechar." : "Setas para escolher, Enter para confirmar."
                        color: "#8a8a96"
                        font.pixelSize: 12
                    }
                }
            }

            // Recolhida: a pílula que volta para a tela inteira.
            Rectangle {
                id: pill

                visible: root.collapsed
                anchors.centerIn: parent
                width: pillRow.implicitWidth + 24
                height: pillRow.implicitHeight + 16
                radius: height / 2
                color: "#1e1e24"
                border.color: "#3a3a44"

                RowLayout {
                    id: pillRow

                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        text: "O Lucerna não conseguiu iniciar"
                        color: "#f2f2f5"
                        font.pixelSize: 14
                    }

                    Rectangle {
                        Layout.preferredWidth: showLabel.implicitWidth + 24
                        Layout.preferredHeight: 32
                        radius: 16
                        color: "#4a5cff"

                        Text {
                            id: showLabel

                            anchors.centerIn: parent
                            text: "Mostrar as opções"
                            color: "#ffffff"
                            font.pixelSize: 14
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.collapsed = false
                        }
                    }
                }
            }
        }
    }
}
