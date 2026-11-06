pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import qs.core.format
import qs.core.theme
import qs.core.widgets

// Slider largo em pílula: a parte cheia na cor de destaque, o ícone à
// esquerda (com `iconClickable`, um botão: silenciar), o rótulo ao lado dele
// e a porcentagem na ponta, dentro da pílula. O texto sobre a parte cheia
// troca para o contraste do destaque. Controlado: emite `moved` e
// `iconClicked`; quem usa decide `value`.
Item {
    id: root

    property string icon
    property string label
    property real value: 0
    property real from: 0
    property real to: 1
    property bool muted: false
    property bool iconClickable: false

    signal moved(real value)
    signal iconClicked

    readonly property real fraction: Math.max(0, Math.min(1, (value - from) / (to - from)))
    readonly property bool dragging: drag.pressed
    property real shownFraction: fraction
    // A parte cheia cobre sempre o ícone.
    readonly property real fill: height + shownFraction * (width - height)

    // Arrastando, segue o dedo; senão (valor externo, roda), anima.
    Behavior on shownFraction {
        enabled: !root.dragging

        Anim { type: Anim.Standard }
    }

    width: parent?.width ?? 0
    height: ThemeManager.px(40)

    function setFromX(x: real): void {
        const f = Math.max(0, Math.min(1, (x - height / 2) / (width - height)));
        moved(from + f * (to - from));
    }

    // O que vai dentro da pílula, nas duas cores.
    component Content: Item {
        id: content

        required property color tint

        width: root.width
        height: root.height

        Icon {
            id: glyph

            x: (root.height - width) / 2
            anchors.verticalCenter: parent.verticalCenter
            icon: root.icon
            size: ThemeManager.px(20)
            filled: true
            color: content.tint
        }

        Txt {
            anchors.left: parent.left
            anchors.leftMargin: root.height + ThemeManager.px(2)
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: content.tint
            font.weight: Font.Medium
        }

        Txt {
            anchors.right: parent.right
            anchors.rightMargin: ThemeManager.spacing.normal + ThemeManager.px(2)
            anchors.verticalCenter: parent.verticalCenter
            text: Format.percent(root.value)
            color: content.tint
            mono: true
            font.pixelSize: ThemeManager.font.small + 1
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: ThemeManager.colors.track
    }

    Content {
        tint: ThemeManager.colors.text
    }

    // A parte cheia leva a cópia clara do conteúdo, cortada na largura dela.
    ClippingRectangle {
        width: root.fill
        height: root.height
        radius: height / 2
        color: ThemeManager.colors.accent
        opacity: root.muted ? 0.5 : 1

        Content {
            tint: ThemeManager.colors.accentText
        }
    }

    MouseArea {
        id: drag

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        onPressed: event => root.setFromX(event.x)
        onPositionChanged: event => {
            if (pressed)
                root.setFromX(event.x);
        }
        onWheel: event => root.moved(Math.max(root.from, Math.min(root.to, root.value + (event.angleDelta.y > 0 ? 0.05 : -0.05) * (root.to - root.from))))
    }

    // O ícone silencia: fica por cima do arrasto.
    Clickable {
        visible: root.iconClickable
        width: root.height
        height: root.height
        radius: height / 2
        onClicked: root.iconClicked()
    }
}
