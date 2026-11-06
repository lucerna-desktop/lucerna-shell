pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import qs.core.theme
import qs.core.widgets
import qs.features.dashboard.state

// Card de mídia da aba Painel: a capa num círculo, com o espectro em volta
// (barrinhas radiais espelhadas, uma por par de faixas do lucernad: graves no
// topo dos dois lados, agudos embaixo); ao lado, o título, o artista e os
// controles. Só anima com a aba à mostra e tocando; pausado, o espectro
// recolhe e a capa para. Sem player: o ícone e "Nada tocando".
Item {
    id: root

    // A aba Painel à mostra.
    required property bool onScreen

    readonly property bool hasMedia: OverviewState.hasMedia
    readonly property bool live: onScreen && OverviewState.mediaPlaying
    // Lado do visualizador: a capa e o espaço das barras em volta.
    readonly property real visualSize: ThemeManager.px(88)
    readonly property real coverSize: ThemeManager.px(52)

    Item {
        id: visual

        anchors.verticalCenter: parent.verticalCenter
        width: root.visualSize
        height: root.visualSize

        SpectrumRing {
            visible: root.hasMedia
            size: root.visualSize
            innerSize: root.coverSize
            values: DashboardState.spectrumPaired
            bands: DashboardState.spectrumPairedBars
            live: root.live
            mirrored: true
        }

        // A capa, girando devagar enquanto toca.
        ClippingRectangle {
            id: cover

            anchors.centerIn: parent
            width: root.coverSize
            height: root.coverSize
            radius: root.coverSize / 2
            color: ThemeManager.colors.raised

            Icon {
                anchors.centerIn: parent
                visible: !root.hasMedia
                icon: Icons.musicOff
                size: ThemeManager.px(26)
                color: ThemeManager.colors.textFaint
            }

            Item {
                id: spinner

                anchors.fill: parent
                visible: root.hasMedia

                NumberAnimation on rotation {
                    running: root.hasMedia
                    paused: running && !root.live
                    from: 0
                    to: 360
                    duration: 24000
                    loops: Animation.Infinite
                }

                Icon {
                    anchors.centerIn: parent
                    visible: art.status !== Image.Ready
                    icon: Icons.album
                    size: ThemeManager.px(26)
                    color: ThemeManager.colors.textFaint
                }

                Image {
                    id: art

                    anchors.fill: parent
                    source: OverviewState.mediaArt
                    sourceSize: Qt.size(ThemeManager.px(104), ThemeManager.px(104))
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
        }
    }

    // A troca de player: o conteúdo novo vem de quase apagado.
    Anim {
        id: cardSwap

        target: root
        property: "opacity"
        from: 0.2
        to: 1
        type: Anim.FastEffects
    }

    Column {
        anchors.left: visual.right
        anchors.leftMargin: ThemeManager.spacing.normal
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: ThemeManager.px(2)

        Txt {
            width: parent.width
            text: OverviewState.mediaTitle
            font.weight: Font.DemiBold
            muted: !root.hasMedia
        }

        Txt {
            width: parent.width
            visible: text !== ""
            text: OverviewState.mediaArtist
            color: ThemeManager.colors.accent
            font.pixelSize: ThemeManager.font.small + 1
        }

        Row {
            visible: root.hasMedia
            topPadding: ThemeManager.spacing.tiny
            spacing: ThemeManager.spacing.tiny

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: Icons.previous
                iconSize: ThemeManager.px(20)
                onClicked: OverviewState.previousTrack()
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: ThemeManager.px(36)
                implicitHeight: ThemeManager.px(36)
                radius: ThemeManager.px(18)
                active: true
                icon: OverviewState.mediaPlaying ? Icons.pause : Icons.play
                iconSize: ThemeManager.px(22)
                onClicked: OverviewState.togglePlaying()
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: Icons.next
                iconSize: ThemeManager.px(20)
                onClicked: OverviewState.nextTrack()
            }

            // Com mais de um player, passa para o próximo (sem lista).
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: OverviewState.playerCount > 1
                icon: Icons.swap
                iconSize: ThemeManager.px(16)
                foreground: ThemeManager.colors.textFaint
                onClicked: {
                    OverviewState.cyclePlayer();
                    cardSwap.restart();
                }
            }
        }
    }
}
