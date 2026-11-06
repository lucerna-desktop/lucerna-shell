pragma ComponentBehavior: Bound

import QtQuick
import qs.core.config
import qs.core.theme
import qs.core.widgets
import qs.features.settings.state

// Papel de parede: por tema (o próprio, só a imagem, um efeito animado ou uma
// imagem sua), como exibir (automático, animado ou parado, por monitor) e as
// opções de economia do animado.
Column {
    id: page

    spacing: ThemeManager.spacing.large

    Component.onCompleted: WallpaperSettings.startEditing()

    SettingSection {
        title: "Tema"

        SettingRow {
            wide: true
            icon: Icons.palette
            title: "Papel de parede do tema"
            description: "Cada tema tem o seu. O efeito animado usa as cores do tema"

            Select {
                width: parent.width
                searchable: true
                visibleRows: 6
                options: WallpaperSettings.themeOptions
                value: WallpaperSettings.theme
                onSelected: v => {
                    WallpaperSettings.theme = v;
                    WallpaperSettings.browsing = false;
                }
            }
        }

        // Opções em cartões, dividindo a linha por igual.
        Item {
            width: parent.width
            height: options.height + ThemeManager.spacing.large * 2

            Flow {
                id: options

                readonly property int columns: Math.max(2, Math.floor((width + spacing) / (ThemeManager.px(170) + spacing)))
                readonly property real cardWidth: (width - (columns - 1) * spacing) / columns

                x: ThemeManager.spacing.large
                y: ThemeManager.spacing.large
                width: parent.width - x * 2
                spacing: ThemeManager.spacing.normal

                Repeater {
                    model: WallpaperSettings.options

                    delegate: WallpaperOption {
                        required property var modelData

                        width: options.cardWidth
                        image: modelData.static ?? ""
                        shader: modelData.shader ?? ""
                        colors: WallpaperSettings.colors
                        label: modelData.label
                        detail: modelData.detail
                        selected: WallpaperSettings.chosenKey === modelData.key
                        onClicked: WallpaperSettings.choose(modelData)
                    }
                }

                // Imagem, vídeo ou GIF do usuário
                WallpaperOption {
                    id: own

                    width: options.cardWidth
                    image: WallpaperSettings.converting ? "" : WallpaperSettings.image
                    colors: WallpaperSettings.colors
                    label: WallpaperSettings.converting ? "Preparando o vídeo…" : WallpaperSettings.usesVideo ? "Seu vídeo" : WallpaperSettings.usesImage ? "Sua imagem" : "Imagem ou vídeo"
                    detail: WallpaperSettings.converting ? `${Math.round(WallpaperSettings.convertProgress * 100)}%` : WallpaperSettings.usesImage ? WallpaperSettings.sourceName : WallpaperSettings.canConvert ? "Imagem, vídeo ou GIF" : "Do computador"
                    selected: WallpaperSettings.usesImage || WallpaperSettings.converting
                    onClicked: {
                        if (!WallpaperSettings.converting)
                            WallpaperSettings.browsing = !WallpaperSettings.browsing;
                    }

                    Icon {
                        visible: !WallpaperSettings.usesImage && !WallpaperSettings.converting
                        x: (parent.width - width) / 2
                        y: (parent.width * 9 / 16 + ThemeManager.px(12) - height) / 2
                        icon: "add_photo_alternate"
                        size: ThemeManager.px(30)
                        color: ThemeManager.colors.accent
                    }

                    // Progresso da conversão
                    Rectangle {
                        visible: WallpaperSettings.converting
                        x: ThemeManager.px(18)
                        y: parent.width * 9 / 16 / 2
                        width: parent.width - ThemeManager.px(36)
                        height: ThemeManager.px(6)
                        radius: height / 2
                        color: ThemeManager.colors.track

                        Rectangle {
                            width: parent.width * WallpaperSettings.convertProgress
                            height: parent.height
                            radius: height / 2
                            color: ThemeManager.colors.accent

                            Behavior on width { Anim { type: Anim.Effects } }
                        }
                    }

                    Rectangle {
                        visible: WallpaperSettings.usesVideo && !WallpaperSettings.converting
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: ThemeManager.px(12)
                        width: videoBadge.implicitWidth + ThemeManager.px(12)
                        height: ThemeManager.px(20)
                        radius: height / 2
                        color: ThemeManager.alpha("#000000", 0.45)

                        Txt {
                            id: videoBadge

                            anchors.centerIn: parent
                            text: "Vídeo"
                            color: "#ffffff"
                            font.pixelSize: ThemeManager.font.small - 1
                        }
                    }
                }
            }
        }

        Txt {
            x: ThemeManager.spacing.large
            width: parent.width - x * 2
            bottomPadding: ThemeManager.spacing.normal
            visible: text !== ""
            wrapMode: Text.Wrap
            text: WallpaperSettings.videoError ? `Não deu para usar o vídeo: ${WallpaperSettings.videoError}` : WallpaperSettings.usesVideo && WallpaperSettings.probed && !WallpaperSettings.hardwareDecode ? "Esta GPU não decodifica vídeo por hardware (falta o VA-API ou o driver dele): o vídeo roda na CPU e gasta mais. O arquivo já foi preparado para ficar o mais leve possível assim." : ""
            color: WallpaperSettings.videoError ? ThemeManager.colors.danger : ThemeManager.colors.textMuted
            font.pixelSize: ThemeManager.font.small + 1
        }

        SettingRow {
            visible: WallpaperSettings.usesImage
            wide: true
            icon: Icons.resolution
            title: WallpaperSettings.usesVideo ? "Ajuste do vídeo" : "Ajuste da imagem"
            description: !WallpaperSettings.usesVideo ? "" : WallpaperSettings.readySizes.length ? `Pronto para ${WallpaperSettings.readySizes.join(", ")}${WallpaperSettings.pendingCount ? ` · preparando mais ${WallpaperSettings.pendingCount}` : ""}. Cada tela ganha a sua versão` : "Preparando a versão de cada tela"

            SegmentedControl {
                width: parent.width
                options: [
                    { label: "Preencher (corta as bordas)", value: "crop" },
                    { label: "Inteira", value: "fit" }
                ]
                value: Config.wallpaperFill
                onSelected: v => WallpaperSettings.setFill(v)
            }
        }
    }

    ImageBrowser {
        visible: WallpaperSettings.browsing
    }

    SettingSection {
        title: "Exibição"

        SettingRow {
            wide: true
            icon: Icons.play
            title: "Animação"
            description: "Automático: anima quando o papel tem efeito e, se escolhido abaixo, só na tomada"

            SegmentedControl {
                width: parent.width
                options: WallpaperSettings.modeOptions
                value: WallpaperSettings.mode
                onSelected: v => WallpaperSettings.setMode(v)
            }
        }

        Repeater {
            model: WallpaperSettings.screens.length > 1 ? WallpaperSettings.screens : []

            delegate: SettingRow {
                id: monitorRow

                required property string modelData

                wide: true
                icon: Icons.monitor
                title: modelData

                Row {
                    width: parent.width
                    spacing: ThemeManager.spacing.small

                    Select {
                        width: (parent.width - parent.spacing) / 2
                        options: WallpaperSettings.monitorModeOptions
                        value: WallpaperSettings.monitors[monitorRow.modelData]?.mode ?? ""
                        onSelected: v => WallpaperSettings.setMonitor(monitorRow.modelData, { mode: v })
                    }

                    Select {
                        width: (parent.width - parent.spacing) / 2
                        options: WallpaperSettings.monitorSourceOptions
                        value: WallpaperSettings.monitors[monitorRow.modelData]?.source ?? ""
                        onSelected: v => WallpaperSettings.setMonitor(monitorRow.modelData, { source: v })
                    }
                }
            }
        }
    }

    SettingSection {
        title: "Economia"

        SettingRow {
            wide: true
            icon: Icons.refreshRate
            title: "Quadros por segundo"
            description: "60 é mais fluido e custa cerca do dobro na GPU nos efeitos. Na bateria, os efeitos voltam a 30 sozinhos. Nos vídeos é o limite ao converter: um vídeo de 24 fps continua em 24, e nada passa da taxa do monitor"

            SegmentedControl {
                width: parent.width
                options: WallpaperSettings.fpsOptions
                value: WallpaperSettings.fps
                onSelected: v => WallpaperSettings.setFps(v)
            }
        }

        SettingRow {
            icon: Icons.battery[3]
            title: "Parado fora da tomada"
            description: "No automático, na bateria fica a imagem parada"
            dimmed: WallpaperSettings.mode !== "auto"

            Switch {
                checked: Config.wallpaperBatteryStatic
                onToggled: on => WallpaperSettings.setBatteryStatic(on)
            }
        }

        SettingRow {
            icon: Icons.pin
            title: "Pausar com janelas abertas"
            description: "Tela cheia e tela bloqueada sempre pausam. Ligado, qualquer janela no workspace também (sobra pouco à mostra)"

            Switch {
                checked: Config.wallpaperStrict
                onToggled: on => WallpaperSettings.setStrict(on)
            }
        }

        SettingRow {
            icon: Icons.monitor
            title: "Preparar vídeos para outras telas"
            description: "Deixa os vídeos prontos também para as resoluções mais comuns (1080p, 1440p, 4K, ultrawide 21:9 e 16:10), na tomada e sem pressa. Desligado, a versão de uma tela nova é feita quando ela aparece, em segundos"

            Switch {
                checked: Config.wallpaperVideoPrecache
                onToggled: on => WallpaperSettings.setPrecache(on)
            }
        }

        SettingRow {
            icon: Icons.resolution
            title: "Resolução cheia"
            description: "Desligado, o efeito é desenhado em metade da resolução e ampliado: quase igual, com um quarto do custo"

            Switch {
                checked: Config.wallpaperFullRes
                onToggled: on => WallpaperSettings.setFullRes(on)
            }
        }
    }
}
