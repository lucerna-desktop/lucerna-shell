import QtQuick

// Uma área de entrada da janela da forma (ver Frame e core/widgets/FrameWindow):
// o retângulo, em coordenadas da tela, onde a janela recebe o mouse enquanto
// ativa (a pílula da barra, o conteúdo de um painel aberto). Fora das áreas
// ativas, o clique passa para as janelas de baixo. Com `keyboard`, a janela
// também pega o teclado enquanto ela está ativa. Fica registrada enquanto
// existe.
QtObject {
    id: root

    // A tela (ShellScreen) onde ela vale.
    property var screen: null
    property bool active: false
    property rect rect: Qt.rect(0, 0, 0, 0)
    // Um painel que digita: a janela pega o teclado (sob demanda).
    property bool keyboard: false

    Component.onCompleted: Frame.registerInput(root)
    Component.onDestruction: Frame.unregisterInput(root)
}
