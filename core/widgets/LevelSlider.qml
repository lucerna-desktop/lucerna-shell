pragma ComponentBehavior: Bound

import QtQuick
import qs.core.level
import qs.core.theme

// A barra de porcentagem do shell (central, volume por app, Configurações).
// Numa linha em cima, o nome à esquerda e o valor à direita, em texto normal
// sobre o fundo do painel (a linha some sem os dois). Embaixo, a barra em
// pílula: trilho no `track`, a parte cheia no `accentFill` e, opcional, um
// ícone dentro dela à esquerda (com `iconClickable`, um botão: silenciar). Sem
// alça nem balão. Cresce um pouco com o mouse por cima, ao arrastar e ao
// mudar pelo teclado. Mudo ou desativado: a parte cheia em cinza e o ícone no
// perigo, sem opacidade sobre o texto. As contas ficam em core/level/Level.
// Controlado: emite `moved` e `iconClicked`; quem usa decide `value`.
Item {
    id: root

    property real from: 0
    property real to: 1
    property real value: 0
    property real stepSize: 0
    // Função de formato do valor (valor → texto), passada por quem usa; por isso var.
    property var format: v => `${Math.round(v * 100)}%`
    property string label: ""
    property bool showValue: true
    property string icon: ""
    property bool iconClickable: false
    property bool muted: false
    // A roda do mouse muda o valor (a central). Desligada, a roda segue para
    // quem está embaixo (a página das Configurações rola).
    property bool wheelEnabled: false

    signal moved(real value)
    signal iconClicked

    readonly property real fraction: Level.fraction(value, from, to)
    readonly property bool dragging: mouse.pressed
    readonly property bool hovered: mouse.containsMouse || iconButton.hovered
    readonly property bool off: muted || !enabled
    readonly property string valueText: showValue ? format.call(null, value) : ""
    readonly property bool hasHeader: label !== "" || valueText !== ""
    readonly property real barHeight: ThemeManager.px(20)
    readonly property real grow: ThemeManager.px(3)
    property real shownFraction: fraction

    // Arrastando, segue o dedo; senão (teclado, roda, valor externo), anima.
    Behavior on shownFraction {
        enabled: !root.dragging

        Anim { type: Anim.Standard }
    }

    implicitWidth: ThemeManager.px(260)
    implicitHeight: slot.y + slot.height
    activeFocusOnTab: true

    function setFromX(x: real): void {
        moved(Level.valueAt(x, width, from, to, stepSize));
    }

    function wheelBy(event: var): void {
        if (!wheelEnabled || !enabled) {
            event.accepted = false;
            return;
        }
        moved(Level.stepped(value, event.angleDelta.y > 0 ? 1 : -1, from, to, stepSize));
    }

    Keys.onLeftPressed: moved(Level.stepped(value, -1, from, to, stepSize))
    Keys.onRightPressed: moved(Level.stepped(value, 1, from, to, stepSize))

    // Nome e valor
    Item {
        id: header

        visible: root.hasHeader
        width: root.width
        height: root.hasHeader ? Math.max(name.implicitHeight, amount.implicitHeight) : 0

        Txt {
            id: name

            anchors.left: parent.left
            anchors.right: amount.left
            anchors.rightMargin: ThemeManager.spacing.small
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            font.weight: Font.Medium
        }

        Txt {
            id: amount

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.valueText
            muted: true
            mono: true
            font.pixelSize: ThemeManager.font.small + 1
        }
    }

    // A faixa da barra já na altura crescida: crescer não empurra nada.
    Item {
        id: slot

        y: root.hasHeader ? header.height + ThemeManager.spacing.tiny : 0
        width: root.width
        height: root.barHeight + root.grow

        Rectangle {
            id: bar

            readonly property bool raised: root.enabled && (root.hovered || root.dragging || keyHint.running)
            // Com valor, a parte cheia tem pelo menos a altura da barra (o
            // círculo da ponta esquerda) e cobre o ícone inteiro; sem valor, o
            // ícone fica sobre o trilho. Sem recorte (ClippingRectangle é um
            // shader e some no renderizador por software).
            readonly property bool hasFill: fillPart.width > 0

            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: raised ? root.barHeight + root.grow : root.barHeight
            radius: height / 2
            color: ThemeManager.colors.track

            Behavior on height { Anim { type: Anim.FastEffects } }

            Rectangle {
                id: fillPart

                width: Level.fillWidth(root.shownFraction, bar.width, bar.height)
                height: bar.height
                radius: height / 2
                color: root.off ? ThemeManager.colors.mutedFill : ThemeManager.colors.accentFill
                visible: width > 0

                Behavior on color { ColorAnim {} }
            }

            // Cada fundo com a sua cor de ícone, a 3:1 dele (ThemeManager.levelColorsOf).
            Icon {
                x: (bar.height - width) / 2
                anchors.verticalCenter: parent.verticalCenter
                visible: root.icon !== ""
                icon: root.icon
                size: ThemeManager.px(14)
                filled: true
                color: bar.hasFill ? (root.off ? ThemeManager.colors.mutedFillIcon : ThemeManager.colors.fillIcon) : (root.off ? ThemeManager.colors.mutedTrackIcon : ThemeManager.colors.trackIcon)

                Behavior on color { ColorAnim {} }
            }
        }
    }

    // Mostra a barra crescida por um instante ao mudar pelo teclado.
    Timer {
        id: keyHint

        interval: 900
    }

    onValueChanged: {
        if (activeFocus && !dragging)
            keyHint.restart();
    }

    MouseArea {
        id: mouse

        y: slot.y - ThemeManager.px(4)
        width: root.width
        height: slot.height + ThemeManager.px(8)
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        onPressed: event => {
            root.forceActiveFocus();
            root.setFromX(event.x);
        }
        onPositionChanged: event => {
            if (pressed)
                root.setFromX(event.x);
        }
        onWheel: event => root.wheelBy(event)
    }

    // O ícone silencia: fica por cima do arrasto.
    Clickable {
        id: iconButton

        visible: root.icon !== "" && root.iconClickable
        anchors.verticalCenter: slot.verticalCenter
        width: bar.height
        height: bar.height
        radius: height / 2
        onClicked: root.iconClicked()
        onWheel: event => root.wheelBy(event)
    }
}
