pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Widgets
import qs.core.theme
import qs.core.widgets
import qs.features.dashboard.state

// Aba Mídia: capa com o espectro em volta, controles, progresso e letra sincronizada.
Item {
    id: root

    implicitHeight: 300

    // A máscara das bordas da letra (duas texturas refeitas a cada linha) só
    // com a aba à mostra e com letra; desligada, o ListView fica como está.
    readonly property bool lyricsMasked: MediaState.onScreen && MediaState.lyrics.length > 0

    // Sem player
    Column {
        anchors.centerIn: parent
        visible: !MediaState.available
        spacing: ThemeManager.spacing.small

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            icon: Icons.musicOff
            size: 48
            color: ThemeManager.colors.textFaint
        }

        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Nada tocando"
            font.pixelSize: ThemeManager.font.large
        }

        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Abra um player com suporte a MPRIS (Spotify, navegador, mpv…)"
            faint: true
            font.pixelSize: ThemeManager.font.small
        }
    }

    RowLayout {
        anchors.fill: parent
        visible: MediaState.available
        spacing: ThemeManager.spacing.large

        // Capa redonda, como um disco que gira enquanto toca, com o espectro
        // em volta (espelhado: o dobro de barras, simétrico).
        Item {
            Layout.preferredWidth: 280
            Layout.fillHeight: true

            SpectrumRing {
                anchors.centerIn: parent
                visible: MediaState.visualizer
                size: 276
                innerSize: cover.width
                values: DashboardState.spectrum
                bands: DashboardState.spectrumBars
                live: MediaState.live
                mirrored: true
                barWidth: 4
            }

            ClippingRectangle {
                id: cover

                anchors.centerIn: parent
                width: 188
                height: 188
                radius: width / 2
                color: ThemeManager.colors.raised

                Item {
                    anchors.fill: parent

                    NumberAnimation on rotation {
                        running: true
                        paused: running && !MediaState.live
                        from: 0
                        to: 360
                        duration: 30000
                        loops: Animation.Infinite
                    }

                    Icon {
                        anchors.centerIn: parent
                        visible: art.status !== Image.Ready
                        icon: Icons.album
                        size: 72
                        color: ThemeManager.colors.textFaint
                    }

                    Image {
                        id: art

                        anchors.fill: parent
                        source: MediaState.art
                        sourceSize: Qt.size(376, 376)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }
            }
        }

        // Faixa e controles
        ColumnLayout {
            id: track

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: ThemeManager.spacing.small

            // A troca de player: o conteúdo novo vem de quase apagado.
            Anim {
                id: playerSwap

                target: track
                property: "opacity"
                from: 0.2
                to: 1
                type: Anim.FastEffects
            }

            // O nome do player e, com mais de um, o ícone que passa para o próximo.
            Row {
                spacing: ThemeManager.spacing.tiny

                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: MediaState.player
                    faint: true
                    font.pixelSize: ThemeManager.font.small
                }

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: MediaState.playerCount > 1
                    icon: Icons.swap
                    iconSize: 16
                    foreground: ThemeManager.colors.textFaint
                    onClicked: {
                        MediaState.cyclePlayer();
                        playerSwap.restart();
                    }
                }
            }

            Txt {
                Layout.fillWidth: true
                text: MediaState.title
                font.pixelSize: ThemeManager.font.large + 6
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
                maximumLineCount: 2
            }

            Txt {
                Layout.fillWidth: true
                visible: text !== ""
                text: MediaState.artist
                color: ThemeManager.colors.accent
            }

            Txt {
                Layout.fillWidth: true
                visible: text !== ""
                text: MediaState.album
                muted: true
                font.pixelSize: ThemeManager.font.small + 1
            }

            // Progresso: clicar ou arrastar pula para o ponto.
            Item {
                Layout.fillWidth: true
                Layout.topMargin: ThemeManager.spacing.normal
                Layout.preferredHeight: 20

                LinearGauge {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 6
                    value: MediaState.progress
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onPressed: event => MediaState.seek(event.x / width)
                    onPositionChanged: event => {
                        if (pressed)
                            MediaState.seek(event.x / width);
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true

                Txt {
                    text: MediaState.positionText
                    mono: true
                    faint: true
                    font.pixelSize: ThemeManager.font.small
                }

                Item {
                    Layout.fillWidth: true
                }

                Txt {
                    text: MediaState.lengthText
                    mono: true
                    faint: true
                    font.pixelSize: ThemeManager.font.small
                }
            }

            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: ThemeManager.spacing.normal

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Icons.previous
                    iconSize: 28
                    onClicked: MediaState.previous()
                }

                Clickable {
                    width: 60
                    height: 60
                    radius: MediaState.playing ? ThemeManager.radius.large : 30
                    active: true
                    onClicked: MediaState.togglePlaying()

                    Behavior on radius { Anim { type: Anim.FastSpatial } }

                    Icon {
                        anchors.centerIn: parent
                        icon: MediaState.playing ? Icons.pause : Icons.play
                        filled: true
                        size: 32
                        color: ThemeManager.colors.accentText
                    }
                }

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Icons.next
                    iconSize: 28
                    onClicked: MediaState.next()
                }
            }
        }

        // Letra
        Surface {
            Layout.preferredWidth: 300
            Layout.fillHeight: true
            visible: MediaState.lyricsEnabled
            clip: true

            CardTitle {
                id: lyricsHeader

                x: ThemeManager.spacing.normal + 2
                y: ThemeManager.spacing.normal + 2
                width: parent.width - 2 * (ThemeManager.spacing.normal + 2)
                icon: Icons.lyrics
                text: "Letra"
            }

            // Sem letra: o ícone e o aviso, discretos.
            Column {
                anchors.centerIn: parent
                visible: MediaState.lyrics.length === 0
                width: parent.width - ThemeManager.spacing.large * 2
                spacing: ThemeManager.spacing.small

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    icon: Icons.lyrics
                    size: 32
                    color: ThemeManager.colors.textFaint
                }

                Txt {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: MediaState.lyricsNote
                    faint: true
                }
            }

            // No estilo dos players: à esquerda, em negrito e maior, a linha
            // atual cheia, as próximas a 45% e as cantadas a 30%; a atual fica
            // um pouco acima do meio e a troca desliza. As bordas esmaecem (a
            // máscara). Clicar numa linha vai para o tempo dela. Sem tempo, a
            // letra fica parada e rola pela roda, sem destaque.
            ListView {
                id: lyricsView

                anchors {
                    top: lyricsHeader.bottom
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    topMargin: ThemeManager.spacing.small
                    leftMargin: ThemeManager.spacing.normal + 2
                    rightMargin: ThemeManager.spacing.normal + 2
                    bottomMargin: ThemeManager.spacing.small
                }
                clip: true
                spacing: ThemeManager.spacing.normal + 2
                model: MediaState.lyrics
                currentIndex: MediaState.currentLine
                interactive: !MediaState.lyricsSynced
                highlightRangeMode: MediaState.lyricsSynced ? ListView.StrictlyEnforceRange : ListView.NoHighlightRange
                preferredHighlightBegin: height * 0.36
                preferredHighlightEnd: height * 0.36 + 24
                highlightMoveDuration: ThemeManager.anim.large
                highlightMoveVelocity: -1
                boundsBehavior: Flickable.StopAtBounds
                // Respiro em cima e embaixo, para a primeira e a última linha
                // não ficarem sob o esmaecimento.
                header: Item {
                    width: 1
                    height: ThemeManager.spacing.large
                }
                footer: Item {
                    width: 1
                    height: lyricsView.height * 0.5
                }

                layer.enabled: root.lyricsMasked
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: lyricsMask
                    maskThresholdMin: 0
                    maskSpreadAtMin: 1
                }

                delegate: Txt {
                    id: line

                    required property var modelData
                    required property int index
                    readonly property string role: MediaState.lineRole(line.index, MediaState.currentLine)

                    width: lyricsView.width
                    text: line.modelData.text || "♪"
                    elide: Text.ElideNone
                    wrapMode: Text.Wrap
                    font.pixelSize: ThemeManager.font.large + 2
                    font.weight: Font.DemiBold
                    lineHeight: 1.15
                    opacity: ({ current: 1, next: 0.45, past: 0.3, plain: 0.85 })[line.role]
                    scale: line.role === "current" ? 1.03 : 1
                    transformOrigin: Item.Left

                    Behavior on opacity { Anim { type: Anim.Effects } }
                    Behavior on scale { Anim { type: Anim.Spatial } }

                    MouseArea {
                        anchors.fill: parent
                        enabled: MediaState.lyricsSynced && MediaState.canSeek
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: MediaState.seekTo(line.modelData.time)
                    }
                }
            }

            // A máscara das bordas: opaca no meio, esmaecendo no topo e na base.
            Item {
                id: lyricsMask

                anchors.fill: lyricsView
                visible: false
                layer.enabled: root.lyricsMasked

                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0; color: "transparent" }
                        GradientStop { position: 0.12; color: "black" }
                        GradientStop { position: 0.85; color: "black" }
                        GradientStop { position: 1; color: "transparent" }
                    }
                }
            }
        }
    }
}
