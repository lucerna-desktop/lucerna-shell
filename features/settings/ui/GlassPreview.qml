pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.core.pixel
import qs.core.theme
import qs.core.widgets

// Prévia ao vivo do vidro: um painel de mentira sobre o wallpaper e formas
// coloridas, com a transparência e um desfoque parecido com o do Hyprland.
ClippingRectangle {
    id: root

    // A escala da janela (fracionária: 1,25), para as linhas finas (ver Pixel).
    readonly property real dpr: Window.window?.devicePixelRatio ?? 1

    property bool transparency: true
    property real panelOpacity: 0.8
    property real cardOpacity: 0.55
    property bool blur: true
    property int blurSize: 6
    property int blurPasses: 2

    implicitHeight: ThemeManager.px(190)
    radius: ThemeManager.radius.large
    color: ThemeManager.colors.base

    // O que fica atrás do painel: wallpaper e formas que se movem devagar.
    Item {
        id: backdrop

        anchors.fill: parent

        Image {
            anchors.fill: parent
            source: ThemeManager.wallpaper ? `file://${ThemeManager.wallpaper}` : ""
            sourceSize: Qt.size(width, height)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }

        Repeater {
            model: [
                { c: ThemeManager.colors.accent, x: 0.18, s: ThemeManager.px(110), d: 9000 },
                { c: ThemeManager.colors.success, x: 0.52, s: ThemeManager.px(80), d: 12000 },
                { c: ThemeManager.colors.danger, x: 0.78, s: ThemeManager.px(96), d: 10000 }
            ]

            delegate: Blob {
                required property var modelData

                width: modelData.s
                height: modelData.s
                x: modelData.x * backdrop.width - width / 2
                y: backdrop.height / 2 - height / 2
                lobes: 6
                amplitude: 0.08
                color: modelData.c
                spinning: true
                spinDuration: modelData.d

                SequentialAnimation on y {
                    loops: Animation.Infinite
                    running: root.visible

                    NumberAnimation { to: backdrop.height / 2 - 70; duration: 2600; easing.type: Easing.InOutSine }
                    NumberAnimation { to: backdrop.height / 2 - 20; duration: 2600; easing.type: Easing.InOutSine }
                }
            }
        }
    }

    Item {
        id: panel

        anchors.centerIn: parent
        width: parent.width * 0.62
        height: parent.height * 0.62

        // O fundo atrás do painel, desfocado e recortado com os cantos do painel.
        ClippingRectangle {
            anchors.fill: parent
            radius: ThemeManager.radius.large
            color: "transparent"
            visible: root.transparency && root.blur

            MultiEffect {
                x: -panel.x
                y: -panel.y
                width: root.width
                height: root.height
                source: backdrop
                blurEnabled: true
                blurMax: 48
                // Aproxima tamanho × passadas do Hyprland na escala do MultiEffect.
                blur: Math.min(1, root.blurSize * root.blurPasses / 16)
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: ThemeManager.radius.large
            color: ThemeManager.alpha(ThemeManager.colors.base, root.transparency ? root.panelOpacity : 1)
            border.width: ThemeManager.outlines ? Pixel.hairline(root.dpr) : 0
            border.color: ThemeManager.colors.border

            Behavior on color { ColorAnim {} }

            Row {
                id: cards

                anchors.fill: parent
                anchors.margins: ThemeManager.spacing.normal
                spacing: ThemeManager.spacing.small

                Repeater {
                    model: 3

                    delegate: Rectangle {
                        width: (cards.width - cards.spacing * 2) / 3
                        height: parent.height
                        radius: ThemeManager.radius.normal
                        color: ThemeManager.alpha(ThemeManager.colors.surface, root.transparency ? root.cardOpacity : 1)
                        border.width: ThemeManager.outlines ? Pixel.hairline(root.dpr) : 0
                        border.color: ThemeManager.colors.border

                        Behavior on color { ColorAnim {} }

                        Column {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.margins: ThemeManager.spacing.small + ThemeManager.px(2)
                            spacing: ThemeManager.px(6)

                            Rectangle { width: ThemeManager.px(22); height: ThemeManager.px(22); radius: ThemeManager.px(11); color: ThemeManager.colors.accent; opacity: 0.9 }
                            Rectangle { width: ThemeManager.px(54); height: ThemeManager.px(6); radius: ThemeManager.px(3); color: ThemeManager.colors.text; opacity: 0.8 }
                            Rectangle { width: ThemeManager.px(36); height: ThemeManager.px(6); radius: ThemeManager.px(3); color: ThemeManager.colors.textMuted; opacity: 0.6 }
                        }
                    }
                }
            }
        }
    }

    Txt {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: ThemeManager.spacing.small
        text: "Prévia"
        faint: true
        font.pixelSize: ThemeManager.font.small
    }
}
