import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core.frame
import qs.core.theme
import qs.core.widgets
import qs.features.osd.state

// Indicador de volume/brilho: sai da borda direita, no meio da altura, em pé:
// o número em cima, a trilha e o ícone embaixo (o aviso do modo jogo troca o
// número e a trilha por um texto deitado). O fundo é um pedaço da forma da
// tela (Frame), preso à borda com os arcos côncavos, que cresce dela para fora
// com mola; o conteúdo entra quando ele passa de ~70%. Não recebe cliques.
PanelWindow {
    id: window

    readonly property real flare: Frame.smoothing
    // A espessura da moldura entra só com ela à mostra (o painel superior
    // aberto); sozinho, o OSD sai da borda sem moldura.
    readonly property real bodyWidth: 52 + Frame.thicknessAt(Frame.progressOn(OsdState.screen))
    readonly property real bodyHeight: 220
    property real shown: OsdState.shown ? 1 : 0

    Behavior on shown {
        Anim {
            type: OsdState.shown ? Anim.Spatial : Anim.EmphasizedAccel
        }
    }

    screen: OsdState.screen
    visible: shown > 0 && Frame.isReady(OsdState.screen)
    anchors.right: true
    // Fixa (com a moldura inteira): a janela não muda de tamanho a cada quadro.
    implicitWidth: 52 + Frame.thickness + flare
    implicitHeight: bodyHeight + flare * 2
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Overlay
    // Sem o desfoque: o fundo é a forma, na janela da barra (ver OverlayPanel).
    WlrLayershell.namespace: "lucerna-frame-osd"

    // O bloco, em coordenadas da tela (a janela fica no meio da borda direita).
    FrameBlob {
        readonly property size area: Frame.sizeOn(OsdState.screen)
        readonly property real edge: area.width
        readonly property real top: (area.height - window.implicitHeight) / 2 + window.flare
        readonly property real grown: window.bodyWidth * Math.max(0, window.shown)

        screen: OsdState.screen
        open: OsdState.shown
        progress: window.shown
        rect: Frame.attach(Qt.rect(edge - grown, top, grown, window.bodyHeight), Frame.edges.osd)
    }

    Item {
        x: window.width - window.bodyWidth * window.shown
        y: window.flare
        width: 52
        height: window.bodyHeight
        opacity: Frame.contentOpacity(window.shown)

        Txt {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -(glyph.height + ThemeManager.spacing.normal) / 2
            visible: OsdState.kind === "game"
            rotation: -90
            text: OsdState.text
            muted: !OsdState.gameOn
            font.pixelSize: ThemeManager.font.small
            font.weight: Font.DemiBold
        }

        Txt {
            id: label

            anchors.top: parent.top
            anchors.topMargin: ThemeManager.spacing.normal
            anchors.horizontalCenter: parent.horizontalCenter
            visible: OsdState.kind !== "game"
            text: OsdState.muted ? "mudo" : OsdState.percent
            mono: true
            muted: OsdState.muted
            font.pixelSize: ThemeManager.font.small
        }

        Rectangle {
            anchors {
                top: label.bottom
                bottom: glyph.top
                topMargin: ThemeManager.spacing.normal
                bottomMargin: ThemeManager.spacing.normal
                horizontalCenter: parent.horizontalCenter
            }
            width: 6
            radius: 3
            visible: OsdState.kind !== "game"
            color: ThemeManager.colors.track

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: parent.height * Math.min(1, OsdState.value)
                radius: parent.radius
                color: OsdState.muted ? ThemeManager.colors.textFaint : ThemeManager.colors.accent

                Behavior on height { Anim { type: Anim.Standard } }
            }
        }

        Icon {
            id: glyph

            anchors.bottom: parent.bottom
            anchors.bottomMargin: ThemeManager.spacing.normal
            anchors.horizontalCenter: parent.horizontalCenter
            icon: OsdState.icon
            size: 20
            color: OsdState.muted || (OsdState.kind === "game" && !OsdState.gameOn) ? ThemeManager.colors.textFaint : ThemeManager.colors.accent
        }
    }
}
