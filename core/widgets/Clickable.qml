pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import qs.core.theme

// Área clicável no estilo "state layer" do Material 3: um véu no hover e uma
// onda (ripple) que se espalha do ponto do clique. Base dos botões do shell.
Rectangle {
    id: root

    property bool active: false
    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed
    // Ativo, o tom de contêiner do destaque (não o destaque cheio): o texto do
    // tema por cima passa de 4,5:1 em todos os temas.
    property color activeColor: ThemeManager.colors.accentContainer
    // Encolhe um pouco ao pressionar (1 = não encolhe). Para botões grandes.
    property real pressScale: 1
    // Falso apaga o véu de hover (um botão filho com o véu próprio por cima).
    property bool hoverVeil: true

    signal clicked(var mouse)
    signal wheel(var wheel)

    // O véu e a onda na cor do texto por cima: sobre o contêiner, misturam
    // poucos % do texto nele (nunca voltam ao destaque cheio). Quem tem um
    // fundo ativo próprio (um véu translúcido) troca pela cor do texto dele.
    property color layerColor: active ? ThemeManager.colors.onAccentContainer : ThemeManager.colors.text

    radius: ThemeManager.radius.small
    color: active ? activeColor : "transparent"
    opacity: enabled ? 1 : 0.4
    scale: pressed ? pressScale : 1

    Behavior on color { ColorAnim {} }
    Behavior on scale { Anim { type: Anim.FastSpatial } }

    // Véu de hover/pressão
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.layerColor
        opacity: root.pressed ? 0.12 : root.hovered && root.hoverVeil ? 0.08 : 0

        Behavior on opacity { Anim { type: Anim.FastEffects } }
    }

    // Onda: só existe enquanto anima, para não custar nada parada.
    Loader {
        id: rippleLoader

        property real originX: 0
        property real originY: 0

        anchors.fill: parent
        active: false

        sourceComponent: ClippingRectangle {
            radius: root.radius
            color: "transparent"

            Rectangle {
                id: wave

                readonly property real reach: Math.hypot(Math.max(rippleLoader.originX, root.width - rippleLoader.originX), Math.max(rippleLoader.originY, root.height - rippleLoader.originY)) * 2

                x: rippleLoader.originX - width / 2
                y: rippleLoader.originY - height / 2
                width: 0
                height: width
                radius: width / 2
                color: root.layerColor
                opacity: 0.16

                Component.onCompleted: grow.start()

                ParallelAnimation {
                    id: grow

                    Anim {
                        target: wave
                        property: "width"
                        to: wave.reach
                        type: Anim.Standard
                    }
                }

                SequentialAnimation {
                    running: !root.pressed && !grow.running

                    Anim {
                        target: wave
                        property: "opacity"
                        to: 0
                        type: Anim.Effects
                    }

                    ScriptAction {
                        script: rippleLoader.active = false
                    }
                }
            }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onPressed: event => {
            rippleLoader.active = false;
            rippleLoader.originX = event.x;
            rippleLoader.originY = event.y;
            rippleLoader.active = true;
        }
        onClicked: event => root.clicked(event)
        onWheel: event => root.wheel(event)
    }
}
