import QtQuick
import qs.features.bar.state

// A aba da barra, que avisa o hover para a lógica de mostrar/esconder. O fundo de vidro não é dele: é a forma da
// tela (core/widgets/FrameShape) que desenha, a mesma que se funde à moldura.
Rectangle {
    color: "transparent"

    HoverHandler {
        onHoveredChanged: BarState.setHovering(hovered)
    }
}
