pragma ComponentBehavior: Bound

import QtQuick
import qs.core.theme
import qs.core.widgets
import qs.features.central.state

// Ações da central: a engrenagem das Configurações, os tiles em duas colunas
// (o corpo liga e desliga; a setinha abre a página) e os sliders de volume e
// brilho. Uma página troca o card inteiro. A altura acompanha o conteúdo até
// `maxHeight`; passando disso, o conteúdo rola.
CentralPanel {
    id: root

    property real maxHeight: ThemeManager.px(600)

    height: Math.min(card.implicitHeight + padding * 2, maxHeight)

    // Anima a troca de página; na entrada (os tiles ainda chegando), não.
    Behavior on height {
        enabled: root.shown >= 1

        Anim { type: Anim.Spatial }
    }

    Flickable {
        id: scroller

        width: parent.width
        height: parent.height
        contentHeight: card.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Loader {
            id: card

            width: scroller.width
            sourceComponent: ({ wifi: wifiPage, bluetooth: bluetoothPage, output: outputPage, input: inputPage, battery: batteryPage })[CentralState.page] ?? home
            onLoaded: {
                scroller.contentY = 0;
                pageIn.restart();
            }

            transform: Translate {
                id: cardOffset
            }

            // A página entra pela direita; a volta, pela esquerda.
            ParallelAnimation {
                id: pageIn

                Anim { target: card; property: "opacity"; from: 0; to: 1; type: Anim.Effects }
                Anim { target: cardOffset; property: "x"; from: CentralState.page ? ThemeManager.px(16) : -ThemeManager.px(16); to: 0; type: Anim.Spatial }
            }
        }
    }

    Component {
        id: home

        Column {
            spacing: ThemeManager.spacing.small

            // A engrenagem, numa faixa fina acima dos tiles.
            Item {
                width: parent.width
                height: ThemeManager.px(28)

                IconButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Icons.settings
                    iconSize: ThemeManager.px(20)
                    implicitWidth: ThemeManager.px(32)
                    implicitHeight: ThemeManager.px(28)
                    radius: ThemeManager.px(14)
                    foreground: ThemeManager.colors.textMuted
                    onClicked: ControlsState.openSettings()
                }
            }

            // O modelo é a quantidade: ligar um tile refaz a lista, mas não
            // recria os tiles (a onda e a cor seguem).
            Grid {
                id: grid

                readonly property real cell: (width - columnSpacing) / 2

                width: parent.width
                columns: 2
                columnSpacing: ThemeManager.spacing.small
                rowSpacing: ThemeManager.spacing.small

                Repeater {
                    model: ControlsState.tiles.length

                    delegate: Tile {
                        id: tile

                        required property int index
                        readonly property var item: ControlsState.tiles[tile.index] ?? null

                        width: grid.cell
                        icon: tile.item?.icon ?? ""
                        title: tile.item?.title ?? ""
                        status: tile.item?.status ?? ""
                        checked: tile.item?.checked ?? false
                        hasPage: (tile.item?.page ?? "") !== ""
                        alert: tile.item?.alert ?? false
                        clickable: tile.item?.clickable ?? false
                        onClicked: ControlsState.activate(tile.item?.id ?? "")
                        onPageClicked: CentralState.setPage(tile.item?.page ?? "")
                    }
                }
            }

            // Respiro entre os tiles e os sliders, só com algum slider.
            Item {
                visible: SoundState.available || ControlsState.hasBrightness
                width: 1
                height: ThemeManager.spacing.tiny
            }

            PillSlider {
                visible: SoundState.available
                icon: SoundState.volumeIcon
                label: "Volume"
                value: SoundState.volume
                muted: SoundState.muted
                iconClickable: true
                onMoved: v => SoundState.setVolume(v)
                onIconClicked: SoundState.toggleMute()
            }

            // A tela não apaga: o mínimo é 1%.
            PillSlider {
                visible: ControlsState.hasBrightness
                icon: Icons.brightnessMedium
                label: "Brilho"
                from: 0.01
                value: ControlsState.brightness
                onMoved: v => ControlsState.setBrightness(v)
            }
        }
    }

    Component {
        id: wifiPage

        WifiPage {}
    }

    Component {
        id: bluetoothPage

        BluetoothPage {}
    }

    Component {
        id: outputPage

        OutputPage {}
    }

    Component {
        id: inputPage

        InputPage {}
    }

    Component {
        id: batteryPage

        BatteryPage {}
    }
}
