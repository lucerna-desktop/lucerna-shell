pragma ComponentBehavior: Bound

import QtQuick
import qs.core.carousel
import qs.core.theme
import qs.core.widgets
import qs.features.themeSwitcher.state

// Seletor de temas em carrossel, solto na parte de baixo da tela, sem caixa e
// sem escurecer o resto: só um degradê escuro atrás da fila. ← e → giram a
// fila (o ThemeSwitcherState aplica o tema do centro depois da espera), Enter
// mantém, Esc ou clique fora desfaz. Clicar num card lateral gira até ele; no
// central, é o Enter.
OverlayPanel {
    id: panel

    name: "themes"
    open: ThemeSwitcherState.open
    screen: ThemeSwitcherState.screen
    dim: 0
    onDismissed: ThemeSwitcherState.cancel()

    // Centro vertical da fila: a base do card central a 120 px da borda de baixo.
    readonly property real cardHeight: ThemeManager.px(180)
    readonly property real rowY: height - ThemeManager.px(120) - cardHeight / 2

    // Entrada em cascata, depois de o estado centrar a fila.
    Connections {
        target: ThemeSwitcherState

        function onOpened() {
            stage.forceActiveFocus();
            for (let i = 0; i < cards.count; i++)
                (cards.itemAt(i) as ThemeCard)?.enter();
        }
    }

    // Saída: todos descem juntos.
    onOpenChanged: {
        if (!open) {
            for (let i = 0; i < cards.count; i++)
                (cards.itemAt(i) as ThemeCard)?.leave();
        }
    }

    // Sem tamanho: o OverlayPanel fecha no clique que não cai em nenhum filho
    // dele (childAt), e assim o degradê não segura o clique fora. Os cards,
    // com o próprio MouseArea, ficam com o clique deles.
    Item {
        id: stage

        focus: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Left)
                ThemeSwitcherState.step(-1);
            else if (event.key === Qt.Key_Right)
                ThemeSwitcherState.step(1);
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                ThemeSwitcherState.confirm();
            else
                return;
            event.accepted = true;
        }

        // Degradê só atrás da fila, subindo até 40% da altura. No máximo 40%
        // de opacidade: abaixo do ignore_alpha (0,45) da regra de desfoque do
        // Hyprland (ThemeSwitcherState.blurLua), então nunca é desfocado. Atrás
        // de todos os cards (os laterais têm z negativo), para não escurecê-los.
        Rectangle {
            z: -10
            y: panel.height * 0.6
            width: panel.width
            height: panel.height * 0.4
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: ThemeManager.alpha("#000000", 0.4) }
            }
        }

        Repeater {
            id: cards

            model: ThemeSwitcherState.themes

            delegate: ThemeCard {
                id: tile

                required property var modelData
                required property int index

                theme: tile.modelData
                distance: Carousel.offset(tile.index, ThemeSwitcherState.index, ThemeSwitcherState.themes.length)
                centerX: panel.width / 2
                count: ThemeSwitcherState.themes.length
                height: panel.cardHeight
                y: panel.rowY - tile.height / 2
                onClicked: ThemeSwitcherState.pick(tile.index)
                // A lista trocada com o seletor aberto recria os cards: já visíveis.
                initiallyShown: panel.open
            }
        }
    }
}
