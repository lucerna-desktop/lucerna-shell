import QtQuick
import qs.core.theme
import qs.core.widgets
import qs.features.settings.state

// Monitores: disposição (arrastando no canvas) e os ajustes de cada um. Nada
// vale até aplicar; aplicado, volta sozinho se não for confirmado a tempo
// (a confirmação é uma janela à parte, em cada tela: MonitorConfirm).
Column {
    id: page

    readonly property var monitor: MonitorsState.current
    readonly property bool active: monitor?.enabled ?? false

    spacing: ThemeManager.spacing.large

    Component.onCompleted: MonitorsState.checkLogin()

    SettingSection {
        title: "Disposição"

        Item {
            width: parent.width
            height: layout.height + ThemeManager.spacing.large * 2

            Column {
                id: layout

                x: ThemeManager.spacing.large
                y: ThemeManager.spacing.large
                width: parent.width - x * 2
                spacing: ThemeManager.spacing.normal

                MonitorCanvas {
                    width: parent.width
                }

                Item {
                    width: parent.width
                    height: ThemeManager.px(40)

                    TonalButton {
                        icon: Icons.identify
                        text: "Identificar"
                        onClicked: MonitorsState.identify()
                    }

                    Row {
                        anchors.right: parent.right
                        spacing: ThemeManager.spacing.small
                        visible: MonitorsState.dirty && !MonitorsState.pending

                        TonalButton {
                            text: "Descartar"
                            onClicked: MonitorsState.discard()
                        }

                        TonalButton {
                            icon: Icons.check
                            text: "Aplicar"
                            onClicked: MonitorsState.apply()
                        }
                    }
                }
            }
        }
    }

    // Quem escala: o Hyprland (cada monitor na sua escala) ou os apps (os
    // monitores em 1, um fator só pelos toolkits; mais leve para a GPU).
    SettingSection {
        title: "Escala"

        SettingRow {
            wide: true
            icon: Icons.zoom
            title: "Quem aumenta a tela"
            description: MonitorsState.appsMode ? "Os monitores ficam em 100% e cada app aumenta sozinho: mais leve para a placa de vídeo" : "O Hyprland aumenta cada monitor na escala dele: tudo igual, com mais trabalho para a placa de vídeo"

            SegmentedControl {
                width: parent.width
                options: MonitorsState.scaleModeOptions
                value: MonitorsState.scaleMode
                onSelected: v => MonitorsState.setScaleMode(v)
            }
        }

        SettingRow {
            visible: MonitorsState.appsMode
            wide: true
            icon: Icons.resolution
            title: "Tamanho dos apps"

            Select {
                width: parent.width
                options: MonitorsState.appsScaleOptions
                value: MonitorsState.appsScale
                onSelected: v => MonitorsState.setAppsScale(v)
            }
        }

        Txt {
            x: ThemeManager.spacing.large
            width: parent.width - x * 2
            visible: MonitorsState.appsMode
            bottomPadding: ThemeManager.spacing.large
            wrapMode: Text.Wrap
            text: MonitorsState.appsNotice
            color: ThemeManager.colors.warning
            font.pixelSize: ThemeManager.font.small + 1
        }
    }

    // Qual monitor ajustar (inclui os desligados e os que espelham, fora do canvas).
    SegmentedControl {
        width: parent.width
        visible: MonitorsState.draft.length > 1
        options: MonitorsState.draft.map(m => ({ label: `${MonitorsState.numberOf(m.name)} · ${m.label}`, value: m.name }))
        value: page.monitor?.name ?? ""
        onSelected: v => MonitorsState.select(v)
    }

    SettingSection {
        title: !page.monitor ? "Monitor" : page.monitor.label === page.monitor.name ? `${MonitorsState.numberOf(page.monitor.name)} · ${page.monitor.name}` : `${MonitorsState.numberOf(page.monitor.name)} · ${page.monitor.label} (${page.monitor.name})`

        SettingRow {
            icon: Icons.monitor
            title: "Ativo"
            description: MonitorsState.enabledCount <= 1 && page.active ? "É o único ligado; não dá para desligar" : "Desligado, a tela fica apagada e sai da disposição"

            Switch {
                checked: page.active
                enabled: !page.active || MonitorsState.enabledCount > 1
                onToggled: on => MonitorsState.setEnabled(on)
            }
        }

        SettingRow {
            visible: page.active
            wide: true
            icon: Icons.resolution
            title: "Resolução"

            Select {
                width: parent.width
                options: MonitorsState.resolutions
                value: page.monitor ? `${page.monitor.width}x${page.monitor.height}` : ""
                onSelected: v => MonitorsState.setResolution(v)
            }
        }

        SettingRow {
            visible: page.active
            wide: true
            icon: Icons.refreshRate
            title: "Taxa de atualização"

            Select {
                width: parent.width
                options: MonitorsState.refreshRates
                value: page.monitor?.refresh ?? 0
                onSelected: v => MonitorsState.setRefresh(v)
            }
        }

        // No modo "Escala pelos apps", os monitores ficam em 1.
        SettingRow {
            visible: page.active && !page.monitor?.mirror
            wide: true
            dimmed: MonitorsState.appsMode
            icon: Icons.zoom
            title: "Escala"
            description: MonitorsState.appsMode ? "Na escala pelos apps, todos os monitores ficam em 100%" : "Maior deixa tudo maior, com menos espaço na tela"

            SegmentedControl {
                width: parent.width
                enabled: !MonitorsState.appsMode
                options: MonitorsState.scaleOptions
                value: MonitorsState.appsMode ? 1 : page.monitor?.scale ?? 1
                onSelected: v => MonitorsState.setScale(v)
            }
        }

        SettingRow {
            visible: page.active && !page.monitor?.mirror
            wide: true
            icon: Icons.rotate
            title: "Rotação"

            SegmentedControl {
                width: parent.width
                options: [
                    { label: "Normal", value: 0 },
                    { label: "90°", value: 1 },
                    { label: "180°", value: 2 },
                    { label: "270°", value: 3 }
                ]
                value: page.monitor?.transform ?? 0
                onSelected: v => MonitorsState.setTransform(v)
            }
        }

        SettingRow {
            visible: page.active && MonitorsState.mirrorOptions.length > 1
            wide: true
            icon: Icons.mirror
            title: "Espelhar"
            description: "Mostra o mesmo que outro monitor, em vez de estender a área de trabalho"

            Select {
                width: parent.width
                options: MonitorsState.mirrorOptions
                value: page.monitor?.mirror ?? ""
                onSelected: v => MonitorsState.setMirror(v)
            }
        }

        SettingRow {
            visible: page.active
            wide: true
            icon: Icons.vrr
            title: "Taxa variável (VRR)"
            description: "Acompanha o ritmo de quadros de jogos e vídeos; o monitor precisa ter FreeSync ou G-Sync"

            SegmentedControl {
                width: parent.width
                options: [
                    { label: "Desligada", value: 0 },
                    { label: "Sempre", value: 1 },
                    { label: "Tela cheia", value: 2 }
                ]
                value: page.monitor?.vrr ?? 0
                onSelected: v => MonitorsState.setVrr(v)
            }
        }

        SettingRow {
            visible: page.active
            icon: Icons.colorDepth
            title: "Cor de 10 bits"
            description: "Degradês mais suaves em monitores que suportam"

            Switch {
                checked: page.monitor?.tenBit ?? false
                onToggled: on => MonitorsState.setTenBit(on)
            }
        }
    }

    // Na sessão Lucerna, o arranjo já vale desde o login: sem a opção nem o include.
    SettingSection {
        visible: !MonitorsState.layered
        title: "Início da sessão"

        SettingRow {
            icon: Icons.monitor
            title: "Usar o arranjo desde o login"
            description: "Sem isso, no login vale o hyprland.lua até o Lucerna subir. Grava o arranjo salvo em ~/.config/hypr/lucerna-monitors.lua"

            Switch {
                checked: MonitorsState.atLogin
                onToggled: on => MonitorsState.setAtLogin(on)
            }
        }

        Column {
            x: ThemeManager.spacing.large
            width: parent.width - x * 2
            visible: MonitorsState.atLogin
            spacing: ThemeManager.spacing.small
            bottomPadding: ThemeManager.spacing.large

            Txt {
                width: parent.width
                wrapMode: Text.Wrap
                text: MonitorsState.loginIncluded ? "O hyprland.lua já inclui o arquivo." : "Falta incluir o arquivo no hyprland.lua. Ponha esta linha no fim dele, depois das suas regras de monitor, para valer por cima delas:"
                color: MonitorsState.loginIncluded ? ThemeManager.colors.success : ThemeManager.colors.warning
                font.pixelSize: ThemeManager.font.small + 1
            }

            Row {
                visible: !MonitorsState.loginIncluded
                width: parent.width
                spacing: ThemeManager.spacing.small

                Rectangle {
                    width: parent.width - copy.width - parent.spacing
                    height: ThemeManager.px(40)
                    radius: ThemeManager.radius.small + ThemeManager.px(2)
                    color: ThemeManager.alpha(ThemeManager.colors.text, 0.06)

                    Txt {
                        anchors.fill: parent
                        anchors.leftMargin: ThemeManager.spacing.normal
                        anchors.rightMargin: ThemeManager.spacing.normal
                        verticalAlignment: Text.AlignVCenter
                        text: MonitorsState.includeLine
                        mono: true
                        elide: Text.ElideRight
                        font.pixelSize: ThemeManager.font.small + 1
                    }
                }

                TonalButton {
                    id: copy

                    icon: "content_copy"
                    text: "Copiar"
                    onClicked: MonitorsState.copyIncludeLine()
                }
            }
        }
    }
}
