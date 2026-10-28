import QtQuick
import qs.core.frame
import qs.core.theme
import qs.core.widgets
import qs.features.osd.state

// Indicador de volume/brilho: sai da borda direita, no meio da altura, em pé:
// o número em cima, a trilha e o ícone embaixo (o aviso do modo jogo troca o
// número e a trilha por um texto deitado). O fundo é um pedaço da forma da
// tela (Frame), preso à borda com os arcos côncavos, que cresce dela para fora
// com mola; o conteúdo desliza com ele desde o 1º quadro. Não recebe cliques.
Item {
    id: root

    required property var screen
    readonly property bool here: OsdState.screen === screen
    // A espessura da moldura entra só com ela à mostra (o painel superior
    // aberto); sozinho, o OSD sai da borda sem moldura.
    readonly property real bodyWidth: 52 + Frame.thicknessAt(Frame.progressOn(screen))
    readonly property real bodyHeight: 220
    readonly property bool open: OsdState.shown && here
    // A mola espera a janela da forma chegar à coluna (Frame.readyOn).
    property real shown: open && Frame.readyOn(screen, Frame.column) ? 1 : 0

    // A mesma mola nos dois sentidos. Ao fechar ela passa do zero uma vez e
    // volta por baixo: só esconde (`visible`), nunca reabre.
    Behavior on shown {
        Anim {
            type: Anim.Spatial
        }
    }

    anchors.fill: parent
    visible: shown > 0

    // O bloco, em coordenadas da tela (no meio da borda direita).
    FrameBlob {
        readonly property real edge: root.width
        readonly property real top: (root.height - root.bodyHeight) / 2
        readonly property real grown: root.bodyWidth * Math.max(0, root.shown)

        screen: root.screen
        open: root.open
        progress: root.shown
        rect: Frame.attach(Qt.rect(edge - grown, top, grown, root.bodyHeight), Frame.edges.osd)
    }

    Item {
        x: root.width - root.bodyWidth * root.shown
        y: (root.height - root.bodyHeight) / 2
        width: 52
        height: root.bodyHeight
        opacity: Frame.clamp(root.shown)

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
