pragma ComponentBehavior: Bound

import QtQuick
import qs.core.frame
import qs.core.theme
import qs.core.widgets
import qs.features.bar.state

// A barra num monitor, dentro da janela da forma dele (core/widgets/FrameWindow),
// em coordenadas da tela: a aba fundida à borda de cima da moldura, cujo fundo
// a forma da tela desenha (Frame). A barra traz a moldura junto: aparece e
// recolhe com ela. Só a pílula recebe o mouse (FrameInput), e só enquanto a
// barra não está virando o painel superior.
Item {
    id: root

    required property var screen
    readonly property bool shown: BarState.shownOn(screen)
    // A barra traz a moldura: a mola espera a janela da forma chegar à tela
    // inteira (Frame.readyOn).
    property real progress: shown && Frame.readyOn(screen, Frame.sizeOn(screen).width) ? 1 : 0
    readonly property real morph: Frame.morphOn(screen)

    // A curva pelo alvo do Behavior, não por `shown` (ver OverlayPanel).
    Behavior on progress {
        id: progressBehavior

        Anim {
            type: progressBehavior.targetValue > 0 ? Anim.Spatial : Anim.EmphasizedAccel
        }
    }

    anchors.fill: parent

    FrameBlob {
        screen: root.screen
        role: "pill"
        framed: true
        open: root.shown
        progress: root.progress
        rect: layout.shape
        radius: ThemeManager.barHeight / 2
    }

    FrameInput {
        screen: root.screen
        active: root.shown && root.morph <= 0
        rect: layout.shape
    }

    PillLayout {
        id: layout

        anchors.fill: parent
        progress: root.progress
        morph: root.morph
    }
}
