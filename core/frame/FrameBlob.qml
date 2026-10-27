import QtQuick
import qs.core.theme

// Um pedaço da forma da tela (ver Frame): o retângulo, em coordenadas da tela,
// que a janela da barra desenha na cor da barra, fundido com a moldura e com
// os outros pedaços. Fica registrado enquanto existe.
QtObject {
    id: root

    // A tela (ShellScreen) onde ele aparece.
    property var screen: null
    // "pill" (a pílula da barra) ou "panel" (o fundo de um painel).
    property string role: "panel"
    // Traz a moldura junto (o painel superior e a central).
    property bool framed: false
    // Pedido aberto; `progress` é a abertura animada (0 a 1, a mola passa de 1).
    property bool open: false
    property real progress: 0
    property rect rect: Qt.rect(0, 0, 0, 0)
    property real radius: ThemeManager.radius.large

    Component.onCompleted: Frame.register(root)
    Component.onDestruction: Frame.unregister(root)
}
