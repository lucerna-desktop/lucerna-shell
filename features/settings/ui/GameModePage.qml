pragma ComponentBehavior: Bound

import QtQuick
import qs.core.config
import qs.core.theme
import qs.core.widgets
import qs.features.settings.state

// Modo jogo: o estado agora (com o efeito de cada item), como ele entra, as
// listas por app e o que ele desliga no compositor, no shell e no sistema. O
// estado é do lucernad; sem ele, só o aviso, e as seções ficam apagadas.
Column {
    id: page

    spacing: ThemeManager.spacing.large

    Component.onCompleted: GameModeState.refreshWindows()

    // Uma linha com uma chave de uma preferência game*.
    component PrefRow: SettingRow {
        id: row

        required property string key

        dimmed: !GameModeState.available

        Switch {
            checked: Config[row.key] === true
            onToggled: on => GameModeState.set(row.key, on)
        }
    }

    // Uma lista de classes ("always" ou "never"): as classes, cada uma com o
    // remover, e o acréscimo pelas janelas abertas ou digitando.
    component ClassList: SettingRow {
        id: classRow

        required property string list
        readonly property var classes: list === "always" ? GameModeState.always : GameModeState.never

        wide: true
        dimmed: !GameModeState.available

        Column {
            width: parent.width
            spacing: ThemeManager.spacing.small

            Txt {
                visible: classRow.classes.length === 0
                text: "Nenhum app"
                faint: true
            }

            Flow {
                width: parent.width
                spacing: ThemeManager.spacing.small

                Repeater {
                    model: classRow.classes

                    delegate: Rectangle {
                        id: chip

                        required property string modelData

                        width: chipRow.implicitWidth + ThemeManager.spacing.normal + 4
                        height: 30
                        radius: 15
                        color: ThemeManager.alpha(ThemeManager.colors.text, 0.06)

                        Row {
                            id: chipRow

                            anchors.verticalCenter: parent.verticalCenter
                            x: ThemeManager.spacing.normal
                            spacing: 2

                            Txt {
                                anchors.verticalCenter: parent.verticalCenter
                                text: chip.modelData
                                mono: true
                                font.pixelSize: ThemeManager.font.small + 1
                            }

                            IconButton {
                                anchors.verticalCenter: parent.verticalCenter
                                icon: Icons.close
                                iconSize: 13
                                implicitWidth: 22
                                implicitHeight: 22
                                foreground: ThemeManager.colors.textMuted
                                onClicked: GameModeState.removeClass(classRow.list, chip.modelData)
                            }
                        }
                    }
                }
            }

            Row {
                width: parent.width
                spacing: ThemeManager.spacing.small

                Select {
                    width: (parent.width - add.width - ThemeManager.spacing.small * 2) / 2
                    placeholder: GameModeState.openClasses.length ? "Janelas abertas" : "Nenhuma janela nova"
                    enabled: GameModeState.openClasses.length > 0
                    options: GameModeState.openClasses.map(c => ({
                                label: c,
                                value: c
                            }))
                    value: null
                    onSelected: v => GameModeState.addClass(classRow.list, v)
                }

                Rectangle {
                    width: (parent.width - add.width - ThemeManager.spacing.small * 2) / 2
                    height: 40
                    radius: 20
                    color: ThemeManager.alpha(ThemeManager.colors.text, 0.06)
                    border.width: typed.activeFocus ? 2 : 0
                    border.color: ThemeManager.colors.accent

                    TextInput {
                        id: typed

                        function submit(): void {
                            GameModeState.addClass(classRow.list, text);
                            text = "";
                        }

                        anchors.fill: parent
                        anchors.leftMargin: ThemeManager.spacing.normal + 2
                        anchors.rightMargin: ThemeManager.spacing.normal
                        verticalAlignment: TextInput.AlignVCenter
                        color: ThemeManager.colors.text
                        font.family: ThemeManager.font.mono
                        font.pixelSize: ThemeManager.font.normal
                        clip: true
                        maximumLength: 128
                        onAccepted: submit()

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !typed.text
                            text: "Classe da janela"
                            faint: true
                        }
                    }
                }

                TonalButton {
                    id: add

                    icon: Icons.add
                    text: "Acrescentar"
                    enabled: typed.text.trim() !== ""
                    onClicked: typed.submit()
                }
            }
        }
    }

    SettingSection {
        title: "Agora"

        SettingRow {
            icon: "sports_esports"
            title: GameModeState.statusLine
            description: GameModeState.available ? "Liga sozinho com um jogo ou uma tela cheia; ligado à mão, só sai à mão" : "O modo jogo é do lucernad: sem ele, fica indisponível"

            TonalButton {
                enabled: GameModeState.available
                text: GameModeState.active ? "Desligar" : "Ligar"
                onClicked: GameModeState.toggleNow()
            }
        }

        Repeater {
            model: GameModeState.effectRows

            delegate: SettingRow {
                id: effect

                required property var modelData

                icon: ""
                title: effect.modelData.label
                dimmed: !GameModeState.available

                Txt {
                    text: effect.modelData.state
                    color: effect.modelData.state === "ativo" ? ThemeManager.colors.accent : effect.modelData.state.startsWith("erro") ? ThemeManager.colors.danger : ThemeManager.colors.textMuted
                    font.pixelSize: ThemeManager.font.small + 1
                }
            }
        }
    }

    SettingSection {
        title: "Entrada"

        PrefRow {
            key: "gameAutoFullscreen"
            icon: Icons.fullscreen
            title: "Tela cheia"
            description: "Um app em tela cheia de verdade (não só maximizado) por um segundo. Os da lista “Nunca” não contam"
        }

        PrefRow {
            key: "gameAutoGames"
            icon: "videogame_asset"
            title: "Jogos detectados"
            description: "Steam e Proton, gamescope, Wine e Lutris, enquanto a janela existir"
        }

        SettingRow {
            icon: Icons.keyboard
            title: "Atalho"
            description: {
                const keys = ShortcutsState.shortcut("game").keys;
                return keys.length ? `${keys.map(k => ShortcutsState.pretty(k)).join(" ou ")} liga e desliga` : "Sem tecla: escolha uma em Atalhos";
            }

            TonalButton {
                text: "Atalhos"
                onClicked: SettingsState.openTopic("shortcuts")
            }
        }
    }

    SettingSection {
        title: "Apps"

        ClassList {
            list: "always"
            icon: "playlist_add_check"
            title: "Sempre"
            description: "Ligam o modo jogo enquanto estiverem abertos"
        }

        ClassList {
            list: "never"
            icon: "playlist_remove"
            title: "Nunca"
            description: "Não contam como tela cheia nem como jogo (players e navegadores, de fábrica)"
        }
    }

    SettingSection {
        title: "Compositor"

        PrefRow {
            key: "gameEffects"
            icon: Icons.blur
            title: "Desligar desfoque, sombras e animações"
            description: "Voltam exatamente como estavam ao sair"
        }

        PrefRow {
            key: "gameVrr"
            icon: Icons.monitor
            title: "VRR em tela cheia"
            description: "Só se o VRR estiver desligado; a sua escolha nunca é reduzida"
        }

        PrefRow {
            key: "gameTearing"
            icon: "speed"
            title: "Tearing"
            description: "Menos atraso, mas a imagem pode rasgar"
        }
    }

    SettingSection {
        title: "Shell"

        PrefRow {
            key: "gameWallpaper"
            icon: Icons.wallpaper
            title: "Pausar o papel de parede animado"
        }

        PrefRow {
            key: "gameQuiet"
            icon: Icons.bellSleep
            title: "Não perturbe, com um resumo ao sair"
            description: "As críticas ainda aparecem; o seu não perturbe continua seu"
        }

        PrefRow {
            key: "gameBar"
            icon: Icons.toolbar
            title: "Barra presa no topo"
            description: "O mouse no topo não a traz; a ação “Mostrar/esconder a barra” traz"
        }

        PrefRow {
            key: "gameIdle"
            icon: "timer"
            title: "Não apagar a tela"
        }

        PrefRow {
            key: "gameNotices"
            icon: Icons.info
            title: "Avisos ao entrar e ao sair"
            description: "Um aviso na borda ao entrar e ao sair; o resumo das notificações, com o não perturbe ligado"
        }
    }

    SettingSection {
        title: "Sistema"

        PrefRow {
            key: "gameProfile"
            icon: Icons.bolt
            title: "Perfil de desempenho"
            description: "Volta ao anterior ao sair"
        }

        PrefRow {
            key: "gameGamemode"
            icon: "rocket_launch"
            title: "GameMode da Feral"
            description: "Se estiver instalado"
        }

        PrefRow {
            key: "gameLight"
            icon: "eco"
            title: "lucernad mais leve"
            description: "Coleta do sistema mais espaçada, espectro pausado e histórico da área de transferência adiado"
        }
    }
}
