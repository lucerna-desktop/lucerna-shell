pragma ComponentBehavior: Bound

import QtQuick
import qs.core.config
import qs.core.theme
import qs.core.widgets
import qs.features.settings.state

// Tela e ociosidade: o brilho de cada tela e, depois de quanto tempo parado,
// escurecer, desligar a tela, bloquear e suspender (na tomada e na bateria), e
// quando não contar.
Column {
    spacing: ThemeManager.spacing.large

    Component.onCompleted: IdleSettings.check()

    SettingSection {
        visible: IdleSettings.brightnessScreens.length > 0 || IdleSettings.brightnessUnavailable !== ""
        title: "Brilho"

        // Sem o módulo de energia do lucernad: o porquê, no lugar das telas.
        SettingRow {
            visible: IdleSettings.brightnessUnavailable !== ""
            icon: Icons.brightnessMedium
            title: "Brilho das telas"
            description: IdleSettings.brightnessUnavailable
            dimmed: true
        }

        // Uma linha por índice: o Brightness.screens é refeito a cada
        // mudança de valor, e com a lista como modelo a linha seria recriada
        // no meio do arrasto.
        Repeater {
            model: IdleSettings.brightnessScreens.length

            delegate: SettingRow {
                id: screenRow

                required property int index
                readonly property var screen: IdleSettings.brightnessScreens[screenRow.index] ?? ({})

                wide: true
                icon: screenRow.screen.kind === "backlight" ? Icons.brightnessMedium : Icons.monitor
                title: screenRow.screen.label ?? ""
                // A tela com erro mostra o erro, com o slider desabilitado.
                description: screenRow.screen.error || (screenRow.screen.kind === "ddc" ? `${screenRow.screen.output} · pelo DDC/CI` : "")

                LevelSlider {
                    width: parent.width
                    enabled: !screenRow.screen.error
                    from: 0.01
                    to: 1
                    value: screenRow.screen.value ?? 0
                    onMoved: v => IdleSettings.setBrightness(screenRow.screen.id, v)
                }
            }
        }
    }

    SettingSection {
        title: "Ociosidade"

        SettingRow {
            icon: "timer"
            title: "Cuidar da ociosidade"
            description: "Escurecer, desligar a tela, bloquear e suspender depois de um tempo sem usar o computador. Desligue se preferir o hypridle"

            Switch {
                checked: Config.idleEnabled
                onToggled: on => Config.idleEnabled = on
            }
        }

        Txt {
            x: ThemeManager.spacing.large
            width: parent.width - x * 2
            bottomPadding: ThemeManager.spacing.normal
            visible: IdleSettings.hypridleRunning && Config.idleEnabled
            wrapMode: Text.Wrap
            text: "O hypridle também está rodando: as duas coisas vão agir ao mesmo tempo. Desligue uma delas (tire o hypridle do hyprland.lua ou desligue a opção acima)."
            color: ThemeManager.colors.warning
            font.pixelSize: ThemeManager.font.small + 1
        }

        SettingRow {
            icon: "coffee"
            title: "Não apagar a tela"
            description: "Segura tudo até ser desligado, por exemplo numa apresentação. Também no tile da central"
            dimmed: !Config.idleEnabled

            Switch {
                checked: Config.idleInhibit
                onToggled: on => Config.idleInhibit = on
            }
        }
    }

    Repeater {
        model: [
            { power: "ac", title: "Na tomada" },
            { power: "battery", title: "Na bateria" }
        ]

        delegate: SettingSection {
            id: powerSection

            required property var modelData

            title: modelData.title
            opacity: Config.idleEnabled ? 1 : 0.55

            Repeater {
                model: IdleSettings.stages

                delegate: SettingRow {
                    id: stageRow

                    required property var modelData

                    wide: true
                    icon: modelData.icon
                    title: modelData.label

                    Select {
                        width: parent.width
                        visibleRows: 6
                        options: IdleSettings.optionsFor(powerSection.modelData.power, stageRow.modelData.id)
                        value: IdleSettings.timeOf(powerSection.modelData.power, stageRow.modelData.id)
                        onSelected: v => IdleSettings.setTime(powerSection.modelData.power, stageRow.modelData.id, v)
                    }
                }
            }
        }
    }

    SettingSection {
        title: "Não contar a ociosidade quando"
        opacity: Config.idleEnabled ? 1 : 0.55

        SettingRow {
            icon: Icons.media
            title: "Há mídia tocando"
            description: "Música ou vídeo em qualquer player"

            Switch {
                checked: Config.idleMedia
                onToggled: on => Config.idleMedia = on
            }
        }

        SettingRow {
            icon: Icons.fullscreen
            title: "Um app está em tela cheia"
            description: "Vídeo, jogo ou apresentação. Os apps que pedem para não apagar (um navegador tocando vídeo) já são respeitados"

            Switch {
                checked: Config.idleFullscreen
                onToggled: on => Config.idleFullscreen = on
            }
        }
    }
}
