import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core.frame
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
//
// Saindo da moldura (`frameScreen`, ver Frame): o fundo é um pedaço da forma
// da tela, desenhado pela janela da barra, que esta espera existir para ficar
// por cima dela; o conteúdo não esmaece com a janela (o painel o mostra quando
// a forma passa de ~70%); e, modal, a pílula fundida fica fora da máscara: o
// clique nela vai para a barra.
PanelWindow {
    id: root

    required property bool open
    property real dim: ThemeManager.dark ? 0.4 : 0.22
    property string name: "panel"
    readonly property bool modal: Panels.isModal(name) || !inputItem
    property Item inputItem: null
    // A tela da moldura de onde o painel sai; null para os centralizados.
    property var frameScreen: null
    readonly property bool framed: frameScreen !== null
    readonly property real progress: shown
    // O tamanho para o layout: saindo da moldura, o da tela dela. A janela só
    // ganha o tamanho da tela depois de aparecer (antes, 0 ou o padrão), e a
    // forma, desenhada na janela da barra, já aparece antes dela: medida pela
    // janela, saía por um quadro no canto de cima à esquerda.
    readonly property real areaWidth: framed ? frameScreen?.width ?? 0 : width
    readonly property real areaHeight: framed ? frameScreen?.height ?? 0 : height
    default property alias content: container.data

    signal dismissed

    property real shown: open ? 1 : 0

    // Abre com mola (curva expressiva) e fecha acelerando, sem passar do zero:
    // passar do zero esconderia a janela e ela piscaria.
    Behavior on shown {
        Anim {
            type: root.open ? Anim.Spatial : Anim.EmphasizedAccel
        }
    }

    visible: shown > 0 && (!framed || Frame.isReady(frameScreen))
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
    // Saindo da moldura, "lucerna-frame-*": o fundo é a forma, já desfocada
    // na janela da barra; desfocar de novo atrás do conteúdo dobraria o custo
    // do Hyprland a cada quadro.
    WlrLayershell.namespace: framed ? `lucerna-frame-${name}` : `lucerna-panel-${name}`
    // Não modal: teclado "sob demanda", que o Hyprland entrega ao abrir e ao
    // clicar; mais de um aberto, fica com o último clicado.
    // Modal da moldura (a central): também sob demanda. Com o teclado exclusivo,
    // o Hyprland manda todo clique para a camada exclusiva, mesmo fora da
    // máscara, e a pílula fundida deixaria de ser clicável; o clique fora dela
    // continua caindo na tela inteira deste painel, que fecha.
    WlrLayershell.keyboardFocus: modal && !framed ? (open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None) : !visible ? WlrKeyboardFocus.None : WlrKeyboardFocus.OnDemand
    mask: !modal ? companionMask : framed ? pillMask : null

    Region {
        id: companionMask

        item: root.inputItem
    }

    // A tela inteira menos a pílula fundida da tela da moldura.
    Region {
        id: pillMask

        readonly property rect pill: root.framed ? Frame.pillOn(root.frameScreen) : Qt.rect(0, 0, 0, 0)

        width: root.width
        height: root.height

        Region {
            x: pillMask.pill.x
            y: pillMask.pill.y
            width: pillMask.pill.width
            height: pillMask.pill.height
            intersection: Intersection.Subtract
        }
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
        opacity: root.framed ? 1 : root.shown
        focus: true
        Keys.onEscapePressed: root.dismissed()
    }
}
