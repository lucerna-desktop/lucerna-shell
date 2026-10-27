import QtQuick
import qs.features.bar.state

// Um pedaço da barra (a pílula ou a ilha), que avisa o hover para a lógica de
// mostrar/esconder e de expandir. O fundo de vidro não é dele: é a forma da
// tela (core/widgets/FrameShape) que desenha, a mesma que se funde à moldura.
Rectangle {
    color: "transparent"

    HoverHandler {
        onHoveredChanged: BarState.setHovering(hovered)
    }
}
