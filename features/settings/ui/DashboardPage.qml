import QtQuick
import qs.core.theme
import qs.core.widgets
import qs.features.settings.state

// Painel superior: abas, visão geral, mídia, desempenho, clima e privacidade.
Column {
    spacing: ThemeManager.spacing.large

    SettingSection {
        title: "Abas"

        // Ordem e visibilidade: setas movem a aba; o interruptor a esconde.
        Repeater {
            model: SettingsState.dashboardTabs

            delegate: SettingRow {
                id: tabRow

                required property var modelData

                icon: modelData.icon
                title: modelData.label
                dimmed: !modelData.visible

                Row {
                    spacing: 2

                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "keyboard_arrow_up"
                        iconSize: 20
                        enabled: !tabRow.modelData.first
                        onClicked: SettingsState.moveTab(tabRow.modelData.id, -1)
                    }

                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "keyboard_arrow_down"
                        iconSize: 20
                        enabled: !tabRow.modelData.last
                        onClicked: SettingsState.moveTab(tabRow.modelData.id, 1)
                    }

                    Item {
                        width: ThemeManager.spacing.small
                        height: 1
                    }

                    Switch {
                        anchors.verticalCenter: parent.verticalCenter
                        checked: tabRow.modelData.visible
                        // A última aba visível não pode ser escondida.
                        enabled: !tabRow.modelData.visible || SettingsState.visibleTabCount > 1
                        onToggled: on => SettingsState.setTabVisible(tabRow.modelData.id, on)
                    }
                }
            }
        }

        SettingRow {
            wide: true
            icon: Icons.dashboard
            title: "Aba ao abrir"
            description: "A última usada ou sempre a mesma"

            SegmentedControl {
                width: parent.width
                options: SettingsState.startTabOptions
                value: SettingsState.startTab
                onSelected: v => SettingsState.setStartTab(v)
            }
        }
    }

    SettingSection {
        title: "Abrir e fechar"

        SettingRow {
            icon: Icons.uptime
            title: "Abrir ao parar o mouse na hora"
            description: "Além do clique. Um instante parado sobre a hora da barra abre o painel"

            Switch {
                checked: SettingsState.hoverOpen
                onToggled: on => SettingsState.setHoverOpen(on)
            }
        }

        SettingRow {
            icon: Icons.close
            title: "Fechar ao tirar o mouse"
            description: "O painel fecha meio segundo depois que o mouse sai dele"

            Switch {
                checked: SettingsState.hoverClose
                onToggled: on => SettingsState.setHoverClose(on)
            }
        }
    }

    SettingSection {
        title: "Visão geral"

        Repeater {
            model: SettingsState.overviewCards

            delegate: SettingRow {
                id: cardRow

                required property var modelData

                icon: modelData.icon
                title: modelData.label
                description: modelData.description

                Switch {
                    checked: cardRow.modelData.visible
                    onToggled: on => SettingsState.setCardVisible(cardRow.modelData.id, on)
                }
            }
        }

        SettingRow {
            wide: true
            icon: Icons.calendar
            title: "Primeiro dia da semana"
            description: "No calendário"

            SegmentedControl {
                width: parent.width
                options: [
                    { label: "Domingo", value: 0 },
                    { label: "Segunda", value: 1 }
                ]
                value: SettingsState.weekStart
                onSelected: v => SettingsState.setWeekStart(v)
            }
        }
    }

    SettingSection {
        title: "Mídia"

        SettingRow {
            icon: Icons.lyrics
            title: "Letra sincronizada"
            description: "Busca a letra na LRCLIB (e no Vagalume, com a sua chave), que recebem o título, o artista, o álbum e a duração da faixa"
            dimmed: SettingsState.offline

            Switch {
                checked: SettingsState.lyrics
                onToggled: on => SettingsState.setLyrics(on)
            }
        }

        SettingRow {
            wide: true
            icon: Icons.lyrics
            title: "Chave do Vagalume"
            description: SettingsState.webNote !== "" ? SettingsState.webNote : "Opcional: com ela, a letra também é buscada no Vagalume"
            dimmed: SettingsState.offline

            Column {
                width: parent.width
                spacing: ThemeManager.spacing.small

                Rectangle {
                    width: parent.width
                    height: 40
                    radius: 20
                    color: ThemeManager.alpha(ThemeManager.colors.text, 0.06)
                    border.width: vagalume.activeFocus ? 2 : 0
                    border.color: ThemeManager.colors.accent

                    TextInput {
                        id: vagalume

                        anchors.fill: parent
                        anchors.leftMargin: ThemeManager.spacing.normal + 2
                        anchors.rightMargin: ThemeManager.spacing.normal
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.Password
                        color: ThemeManager.colors.text
                        font.family: ThemeManager.font.sans
                        font.variableAxes: ThemeManager.fontAxes(Font.Normal)
                        font.pixelSize: ThemeManager.font.normal
                        clip: true
                        text: SettingsState.vagalumeKey
                        // Grava depois de parar de digitar, no Enter, ao perder o foco ou
                        // ao esconder a página (a chave colada não se perde); com texto
                        // inválido, mostra o erro e repõe o valor salvo.
                        function save(): void {
                            saveTimer.stop();
                            keyError.text = SettingsState.setVagalumeKey(text);
                        }

                        onTextEdited: saveTimer.restart()
                        onEditingFinished: save()
                        onActiveFocusChanged: {
                            if (activeFocus)
                                return;
                            save();
                            if (keyError.text !== "")
                                text = SettingsState.vagalumeKey;
                        }
                        onVisibleChanged: {
                            if (!visible && saveTimer.running)
                                save();
                        }

                        Timer {
                            id: saveTimer

                            interval: 600
                            onTriggered: vagalume.save()
                        }

                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !vagalume.text
                            text: "Cole a chave aqui"
                            faint: true
                        }
                    }
                }

                Txt {
                    id: keyError

                    width: parent.width
                    visible: text !== ""
                    color: ThemeManager.colors.danger
                    font.pixelSize: ThemeManager.font.small + 1
                    wrapMode: Text.Wrap
                }

                Txt {
                    text: "<a href=\"https://auth.vagalume.com.br/settings/api/\">Criar uma chave</a>"
                    textFormat: Text.StyledText
                    linkColor: ThemeManager.colors.accent
                    font.pixelSize: ThemeManager.font.small + 1
                    onLinkActivated: link => Qt.openUrlExternally(link)
                }
            }
        }

        SettingRow {
            icon: Icons.sound
            title: "Espectro em volta da capa"
            description: "Na aba Mídia, barras que seguem as frequências do que está tocando (pelo lucernad)"

            Switch {
                checked: SettingsState.audioPulse
                onToggled: on => SettingsState.setAudioPulse(on)
            }
        }
    }

    SettingSection {
        title: "Desempenho"

        SettingRow {
            wide: true
            icon: Icons.timer
            title: "Atualização"
            description: "De quanto em quanto tempo os dados são lidos. Mais tempo, menos consumo"

            SegmentedControl {
                width: parent.width
                options: [
                    { label: "1 s", value: 1000 },
                    { label: "2 s", value: 2000 },
                    { label: "5 s", value: 5000 }
                ]
                value: SettingsState.statsInterval
                onSelected: v => SettingsState.setStatsInterval(v)
            }
        }

        SettingRow {
            icon: Icons.gpu
            title: "Mostrar a GPU"
            description: "Desligado, nem a consulta ao estado da placa é feita"

            Switch {
                checked: SettingsState.showGpu
                onToggled: on => SettingsState.setShowGpu(on)
            }
        }
    }

    SettingSection {
        title: "Clima"

        SettingRow {
            wide: true
            icon: Icons.location
            title: "Cidade"
            description: SettingsState.weatherPlace ? `Atual: ${SettingsState.weatherPlace}` : "Nenhuma cidade escolhida"
            dimmed: SettingsState.offline

            Column {
                width: parent.width
                spacing: ThemeManager.spacing.small

                Row {
                    width: parent.width
                    spacing: ThemeManager.spacing.small

                    Rectangle {
                        width: parent.width - search.width - parent.spacing
                        height: 40
                        radius: 20
                        color: ThemeManager.alpha(ThemeManager.colors.text, 0.06)
                        border.width: city.activeFocus ? 2 : 0
                        border.color: ThemeManager.colors.accent

                        TextInput {
                            id: city

                            anchors.fill: parent
                            anchors.leftMargin: ThemeManager.spacing.normal + 2
                            anchors.rightMargin: ThemeManager.spacing.normal
                            verticalAlignment: TextInput.AlignVCenter
                            color: ThemeManager.colors.text
                            font.family: ThemeManager.font.sans
                            font.variableAxes: ThemeManager.fontAxes(Font.Normal)
                            font.pixelSize: ThemeManager.font.normal
                            clip: true
                            enabled: !SettingsState.offline
                            onAccepted: SettingsState.searchCity(text)

                            Txt {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !city.text
                                text: "Ex.: Recife, Curitiba, Lisboa"
                                faint: true
                            }
                        }
                    }

                    TonalButton {
                        id: search

                        icon: Icons.magnify
                        text: SettingsState.citySearching ? "Buscando…" : "Buscar"
                        enabled: !SettingsState.offline && city.text.trim() !== ""
                        onClicked: SettingsState.searchCity(city.text)
                    }
                }

                Repeater {
                    model: SettingsState.cityResults

                    delegate: Clickable {
                        id: result

                        required property int index
                        required property var modelData

                        width: parent.width
                        height: 36
                        onClicked: SettingsState.chooseCity(result.index)

                        Txt {
                            anchors.fill: parent
                            anchors.leftMargin: ThemeManager.spacing.normal
                            anchors.rightMargin: ThemeManager.spacing.normal
                            text: result.modelData.label
                        }
                    }
                }

                Txt {
                    visible: SettingsState.citySearchError !== ""
                    text: SettingsState.citySearchError
                    color: ThemeManager.colors.danger
                    font.pixelSize: ThemeManager.font.small + 1
                }

                TonalButton {
                    icon: Icons.refresh
                    text: "Atualizar agora"
                    enabled: !SettingsState.offline && SettingsState.webNote === ""
                    onClicked: SettingsState.refreshWeather()
                }
            }
        }

        SettingRow {
            wide: true
            icon: Icons.temperature
            title: "Temperatura"

            SegmentedControl {
                width: parent.width
                options: [
                    { label: "Celsius (°C)", value: "c" },
                    { label: "Fahrenheit (°F)", value: "f" }
                ]
                value: SettingsState.temperatureUnit
                onSelected: v => SettingsState.setTemperatureUnit(v)
            }
        }

        SettingRow {
            wide: true
            icon: Icons.wind
            title: "Vento"

            SegmentedControl {
                width: parent.width
                options: [
                    { label: "km/h", value: "kmh" },
                    { label: "m/s", value: "ms" }
                ]
                value: SettingsState.windUnit
                onSelected: v => SettingsState.setWindUnit(v)
            }
        }

        SettingRow {
            wide: true
            icon: Icons.refresh
            title: "Atualizar a cada"
            description: "Enquanto a aba Clima ou a visão geral está aberta"
            dimmed: SettingsState.offline

            SegmentedControl {
                width: parent.width
                options: [
                    { label: "15 min", value: 15 },
                    { label: "30 min", value: 30 },
                    { label: "1 h", value: 60 }
                ]
                value: SettingsState.weatherRefresh
                onSelected: v => SettingsState.setWeatherRefresh(v)
            }
        }
    }

    SettingSection {
        title: "Privacidade"

        SettingRow {
            icon: "cloud_off"
            title: "Modo offline"
            description: "Desliga tudo o que usa a internet: o clima (Open-Meteo) e as letras (LRCLIB e Vagalume). O resto do shell não sai da máquina"

            Switch {
                checked: SettingsState.offline
                onToggled: on => SettingsState.setOffline(on)
            }
        }
    }
}
