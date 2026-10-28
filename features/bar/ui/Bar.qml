import QtQuick
import Quickshell

// Em cada monitor, a faixa invisível que detecta o mouse no topo. A barra fica
// na janela da forma (BarLayer, posta pelo shell.qml).
Variants {
    model: Quickshell.screens

    BarTrigger {
        required property var modelData

        screen: modelData
    }
}
