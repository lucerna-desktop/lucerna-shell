import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core.panels
import qs.core.theme

// Janela de sobreposição em tela cheia para painéis (launcher, temas, energia,
// central de notificações). Escurece o fundo, pega o teclado enquanto aberta e
// avisa `dismissed` ao clicar fora do conteúdo ou apertar Esc.
//
// O conteúdo vai como filho direto; `progress` (0 → 1) acompanha a animação de
// abertura para o conteúdo animar junto.
//
// Não modal (acompanhante ou base, ver Panels): não escurece nem cobre a tela;
// só `inputItem` recebe o mouse, então a barra e os outros painéis seguem
// clicáveis. O clique fora é tratado pelo Panels.
PanelWindow {
    id: root

    required property bool open
    property real dim: ThemeManager.dark ? 0.4 : 0.22
    property string name: "panel"
    readonly property bool modal: Panels.isModal(name) || !inputItem
    property Item inputItem: null
    readonly property real progress: shown
    readonly property size area: Qt.size(width, height)
    readonly property real areaWidth: area.width
    readonly property real areaHeight: area.height
    default property alias content: container.data

    signal dismissed

    property real shown: open ? 1 : 0

    // Abre com mola (curva expressiva) e fecha acelerando, sem passar do zero:
    // passar do zero esconderia a janela e ela piscaria. A curva sai do alvo
    // do Behavior, não de `open`: o Behavior dispara antes de a escolha ser
    // reavaliada, e a abertura saía com a curva da saída (um salto no 1º quadro).
    Behavior on shown {
        id: shownBehavior

        Anim {
            type: shownBehavior.targetValue > 0 ? Anim.Spatial : Anim.EmphasizedAccel
        }
    }

    visible: shown > 0
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    // "lucerna-panel-*" recebe o desfoque do Hyprland (ver ThemeSwitcherState).
    WlrLayershell.namespace: `lucerna-panel-${name}`
    // Não modal: teclado "sob demanda", que o Hyprland entrega ao abrir e ao
    // clicar; mais de um aberto, fica com o último clicado.
    WlrLayershell.keyboardFocus: modal ? (open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None) : !visible ? WlrKeyboardFocus.None : WlrKeyboardFocus.OnDemand
    mask: !modal ? companionMask : null

    Region {
        id: companionMask

        item: root.inputItem
    }

    Component.onCompleted: Panels.register(root)
    Component.onDestruction: Panels.unregister(root)

    Rectangle {
        anchors.fill: parent
        visible: root.modal
        color: ThemeManager.alpha("#000000", root.dim * root.shown)
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: event => {
            if (!container.childAt(event.x, event.y))
                root.dismissed();
        }
    }

    FocusScope {
        id: container

        anchors.fill: parent
        opacity: root.shown
        focus: true
        Keys.onEscapePressed: root.dismissed()
    }
}
