import QtQuick
import QtQuick.Effects
import qs.core.pixel
import qs.core.theme
import qs.core.widgets
import qs.features.lockscreen.state

Item {
    id: root

    // Entrada: o fundo desfoca aos poucos e o conteúdo sobe com mola.
    property real shown: 0

    Behavior on shown { Anim { type: Anim.SlowSpatial } }

    Component.onCompleted: {
        input.forceActiveFocus();
        shown = 1;
    }

    Image {
        id: wallpaper

        anchors.fill: parent
        source: ThemeManager.wallpaper ? `file://${ThemeManager.wallpaper}` : ""
        sourceSize: Qt.size(width / 2, height / 2)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: wallpaper
        blurEnabled: true
        blurMax: 64
        blur: Math.min(1, root.shown)
        brightness: -0.08 * Math.min(1, root.shown)
    }

    Rectangle {
        anchors.fill: parent
        color: ThemeManager.alpha(ThemeManager.colors.base, 0.45 * Math.min(1, root.shown))
    }

    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -40 + (1 - root.shown) * 60
        opacity: Math.min(1, root.shown)
        spacing: ThemeManager.spacing.small

        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            text: LockscreenState.time
            mono: true
            font.pixelSize: ThemeManager.font.huge * 2
            font.weight: Font.Light
        }

        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            text: LockscreenState.date
            muted: true
            font.pixelSize: ThemeManager.font.large
        }

        Item {
            width: 1
            height: ThemeManager.spacing.large * 2
        }

        // Campo de senha
        Rectangle {
            id: field

            anchors.horizontalCenter: parent.horizontalCenter
            width: 320
            height: 48
            radius: height / 2
            color: ThemeManager.alpha(ThemeManager.colors.surface, 0.9)
            border.width: LockscreenState.error || input.activeFocus ? 2 : ThemeManager.outlines ? Pixel.hairline(Window.window?.devicePixelRatio ?? 1) : 0
            border.color: LockscreenState.error ? ThemeManager.colors.danger : input.activeFocus ? ThemeManager.alpha(ThemeManager.colors.accent, 0.6) : ThemeManager.colors.border

            Behavior on border.color { ColorAnim {} }

            SequentialAnimation {
                id: shake

                NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: -10; duration: 50 }
                NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: 10; duration: 70 }
                NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: -6; duration: 70 }
                NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: 0; duration: 50 }
            }

            Connections {
                target: LockscreenState

                function onFailed() {
                    input.text = "";
                    shake.restart();
                }

                function onLockedChanged() {
                    input.text = "";
                }
            }

            Icon {
                id: lockIcon

                anchors.left: parent.left
                anchors.leftMargin: ThemeManager.spacing.normal + 4
                anchors.verticalCenter: parent.verticalCenter
                icon: Icons.lock
                color: ThemeManager.colors.accent

                SequentialAnimation on opacity {
                    running: LockscreenState.busy
                    loops: Animation.Infinite
                    onStopped: lockIcon.opacity = 1

                    NumberAnimation { to: 0.3; duration: 400 }
                    NumberAnimation { to: 1; duration: 400 }
                }
            }

            TextInput {
                id: input

                anchors {
                    left: lockIcon.right
                    right: parent.right
                    leftMargin: ThemeManager.spacing.small
                    rightMargin: ThemeManager.spacing.large
                    verticalCenter: parent.verticalCenter
                }
                focus: true
                echoMode: TextInput.Password
                passwordCharacter: "●"
                enabled: !LockscreenState.busy
                color: ThemeManager.colors.text
                font.family: ThemeManager.font.sans
                font.variableAxes: ThemeManager.fontAxes(Font.Normal)
                font.pixelSize: ThemeManager.font.large
                font.letterSpacing: 2
                clip: true
                onAccepted: LockscreenState.submit(text)
                Keys.onEscapePressed: text = ""

                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !input.text
                    text: LockscreenState.busy ? "Verificando…" : LockscreenState.user ? `Senha de ${LockscreenState.user}` : "Senha"
                    faint: true
                    font.pixelSize: ThemeManager.font.normal
                }
            }
        }

        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            height: ThemeManager.font.normal * 2
            text: LockscreenState.error
            color: ThemeManager.colors.danger
            font.pixelSize: ThemeManager.font.small
        }
    }
}
