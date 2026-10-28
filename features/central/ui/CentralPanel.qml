import QtQuick
import qs.core.frame
import qs.core.theme
import qs.core.widgets

// Um dos dois painéis da central: `panelWidth` de largura, a `margin` da borda
// direita (dentro da moldura). O fundo é o bloco da central (a forma da tela);
// o conteúdo desliza com ele desde o 1º quadro. Entra deslizando da direita e
// sai pelo mesmo caminho, com a mesma mola (que passa do zero na volta: só
// esconde). Os dois abrindo ou fechando juntos andam no mesmo passo, como uma
// peça só. Os filhos vão para dentro da margem interna (`padding`). `reveal`
// (0 a 1) é quanto da altura está à mostra, de cima para baixo: o bloco da
// forma vai até `shownHeight`, e o conteúdo é cortado nela.
Item {
    id: root

    required property real margin
    // Largura da tela, para colar na borda direita.
    required property real areaWidth
    property real panelWidth: 440
    // Entrada e saída (0 → 1), animadas por enter() e leave().
    property real shown: 0
    // Pedido aberto (o último enter() ou leave()).
    property bool wanted: false
    readonly property real padding: ThemeManager.spacing.normal
    readonly property real travel: width + margin + 24
    property real reveal: 1
    readonly property real shownHeight: height * reveal
    default property alias content: body.data

    width: panelWidth
    visible: shown > 0
    opacity: Frame.clamp(shown)
    x: areaWidth - width - margin + (1 - shown) * travel

    function enter(): void {
        wanted = true;
        // Reaberta na saída, segue de onde está; senão, entra do zero.
        if (leaving.running)
            leaving.stop();
        else
            shown = 0;
        entering.restart();
    }

    function leave(): void {
        wanted = false;
        entering.stop();
        leaving.restart();
    }

    Anim {
        id: entering

        target: root
        property: "shown"
        to: 1
        type: Anim.Spatial
    }

    Anim {
        id: leaving

        target: root
        property: "shown"
        to: 0
        type: Anim.Spatial
    }

    // Corta só enquanto cresce: com tudo à mostra, sem recorte.
    Item {
        width: root.width
        height: root.shownHeight
        clip: root.reveal < 1

        Item {
            id: body

            x: root.padding
            y: root.padding
            width: root.width - root.padding * 2
            height: root.height - root.padding * 2
        }
    }
}
