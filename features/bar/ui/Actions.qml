import QtQuick
import qs.core.theme
import qs.core.widgets
import qs.features.bar.state

// Ações da barra: rede, volume, bateria, o modo jogo (só ligado) e
// notificações. Rede, volume e bateria abrem as Ações da central pela sua
// entrada (o mesmo ícone de novo fecha; outro troca a página); o sino abre e
// fecha só as Notificações; o modo jogo desliga no clique. Gravando a tela,
// aparece antes o tempo, que para ao clicar.
Row {
    anchors.verticalCenter: parent?.verticalCenter
    spacing: ThemeManager.px(2)

    Clickable {
        anchors.verticalCenter: parent.verticalCenter
        visible: BarState.recording
        width: recRow.implicitWidth + ThemeManager.px(18)
        height: ThemeManager.px(28)
        radius: height / 2
        // No tom de contêiner do erro, com o texto dele; o ponto e o ícone
        // na cor de erro cheia.
        color: ThemeManager.container(ThemeManager.colors.danger)
        onClicked: BarState.stopRecording()

        Row {
            id: recRow

            anchors.centerIn: parent
            spacing: ThemeManager.px(5)

            Rectangle {
                id: pulse

                anchors.verticalCenter: parent.verticalCenter
                width: ThemeManager.px(8)
                height: ThemeManager.px(8)
                radius: width / 2
                color: ThemeManager.colors.danger

                // Só pulsa à mostra: com a barra escondida, a animação
                // redesenharia a janela da forma a cada quadro.
                SequentialAnimation on opacity {
                    running: BarState.recording && pulse.visible
                    loops: Animation.Infinite

                    NumberAnimation { to: 0.3; duration: 700 }
                    NumberAnimation { to: 1; duration: 700 }
                }
            }

            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: BarState.recordingTime
                mono: true
                color: ThemeManager.onContainer(ThemeManager.colors.danger)
                font.pixelSize: ThemeManager.font.small + 1
                font.weight: Font.DemiBold
            }

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                icon: "stop"
                filled: true
                size: ThemeManager.px(16)
                color: ThemeManager.colors.danger
            }
        }
    }

    IconButton {
        anchors.verticalCenter: parent.verticalCenter
        icon: BarState.networkIcon
        visible: BarState.networkAvailable
        iconSize: ThemeManager.px(18)
        active: BarState.entryOpen("rede")
        foreground: active ? ThemeManager.colors.onAccentContainer : BarState.online ? ThemeManager.colors.textMuted : ThemeManager.colors.textFaint
        onClicked: BarState.toggleEntry("rede")
    }

    IconButton {
        anchors.verticalCenter: parent.verticalCenter
        icon: BarState.volumeIcon
        visible: BarState.audioAvailable
        iconSize: ThemeManager.px(18)
        active: BarState.entryOpen("som")
        foreground: active ? ThemeManager.colors.onAccentContainer : BarState.muted ? ThemeManager.colors.textFaint : ThemeManager.colors.textMuted
        // Clique abre o Som; botão do meio silencia; a roda ajusta o volume.
        onClicked: event => {
            if (event.button === Qt.MiddleButton)
                BarState.toggleMute();
            else
                BarState.toggleEntry("som");
        }
        onWheel: event => BarState.scrollVolume(event.angleDelta.y / 120)
    }

    IconButton {
        anchors.verticalCenter: parent.verticalCenter
        icon: BarState.batteryIcon
        label: BarState.batteryShowPercent ? `${BarState.batteryPercent}%` : ""
        visible: BarState.batteryAvailable
        iconSize: ThemeManager.px(18)
        active: BarState.entryOpen("energia")
        foreground: active ? ThemeManager.colors.onAccentContainer : BarState.batteryLow ? ThemeManager.colors.danger : ThemeManager.colors.textMuted
        onClicked: BarState.toggleEntry("energia")
    }

    // O modo jogo ligado: o clique desliga (o rótulo aparece com o mouse em cima).
    IconButton {
        anchors.verticalCenter: parent.verticalCenter
        icon: "sports_esports"
        visible: BarState.gameIcon
        iconSize: ThemeManager.px(18)
        label: hovered ? "Desligar" : ""
        foreground: ThemeManager.colors.accent
        Accessible.name: BarState.gameTooltip
        onClicked: BarState.stopGame()
    }

    IconButton {
        anchors.verticalCenter: parent.verticalCenter
        icon: BarState.bellIcon
        iconSize: ThemeManager.px(18)
        label: BarState.notificationCount > 0 ? `${BarState.notificationCount}` : ""
        active: BarState.notificationsOpen
        onClicked: BarState.toggleNotifications()
    }
}
