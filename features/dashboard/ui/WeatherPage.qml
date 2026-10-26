pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.core.theme
import qs.core.widgets
import qs.features.dashboard.state

// Aba Clima, no desenho do Caelestia: a cidade e o dia com o nascer e o pôr do
// sol, o card grande do agora, umidade, sensação e vento, e os sete dias. A
// cidade se escolhe nas configurações; sem o lucernad, só o motivo.
Item {
    id: root

    readonly property int mode: !WeatherState.available ? 0 : !WeatherState.hasLocation ? 1 : 2

    // O ícone grande da linha do topo e dos dias; o do agora é o triplo.
    readonly property int bigIcon: ThemeManager.font.large * 2

    implicitHeight: mode === 0 ? unavailable.implicitHeight : mode === 1 ? noCity.implicitHeight : layout.implicitHeight

    // Sem o lucernad (ou com o módulo de rede fora): a forma com o motivo.
    EmptyState {
        id: unavailable

        visible: root.mode === 0
        icon: Icons.weather
        text: WeatherState.notice
    }

    // Sem cidade: o convite para as configurações, onde fica a busca.
    Column {
        id: noCity

        visible: root.mode === 1
        width: parent.width
        bottomPadding: ThemeManager.spacing.large
        spacing: ThemeManager.spacing.normal

        EmptyState {
            icon: Icons.location
            text: "Escolha a cidade nas configurações"
        }

        Clickable {
            anchors.horizontalCenter: parent.horizontalCenter
            implicitWidth: openRow.implicitWidth + ThemeManager.spacing.large * 2
            implicitHeight: 44
            radius: height / 2
            pressScale: 0.96
            active: true
            onClicked: WeatherState.openSettings()

            Row {
                id: openRow

                anchors.centerIn: parent
                spacing: ThemeManager.spacing.small

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Icons.settings
                    size: 20
                    color: ThemeManager.colors.accentText
                }

                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Abrir configurações"
                    color: ThemeManager.colors.accentText
                    font.weight: Font.DemiBold
                }
            }
        }
    }

    ColumnLayout {
        id: layout

        visible: root.mode === 2
        width: parent.width
        spacing: ThemeManager.spacing.normal

        // (1) A cidade e o dia; o nascer e o pôr do sol à direita.
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: ThemeManager.spacing.large
            Layout.rightMargin: ThemeManager.spacing.large
            spacing: ThemeManager.spacing.large

            Column {
                Layout.fillWidth: true
                spacing: 2

                Txt {
                    width: parent.width
                    text: WeatherState.city
                    font.pixelSize: ThemeManager.font.large + 8
                    font.weight: Font.DemiBold
                }

                Txt {
                    width: parent.width
                    text: WeatherState.today
                    muted: true
                    font.pixelSize: ThemeManager.font.small
                }
            }

            SunStat {
                icon: Icons.sunrise
                label: "Nascer do sol"
                value: WeatherState.sunrise
            }

            SunStat {
                icon: Icons.sunset
                label: "Pôr do sol"
                value: WeatherState.sunset
            }
        }

        // (2) O agora: o ícone grande, a temperatura e a condição.
        Surface {
            Layout.fillWidth: true
            implicitHeight: now.implicitHeight + ThemeManager.spacing.large * 2
            radius: ThemeManager.radius.large * 2

            RowLayout {
                id: now

                anchors.centerIn: parent
                spacing: ThemeManager.spacing.large + ThemeManager.spacing.small

                Icon {
                    Layout.alignment: Qt.AlignVCenter
                    icon: WeatherState.icon
                    filled: true
                    size: root.bigIcon * 3
                    color: ThemeManager.colors.accent
                }

                Column {
                    Layout.alignment: Qt.AlignVCenter

                    Txt {
                        text: WeatherState.temp
                        font.pixelSize: ThemeManager.font.huge + 12
                        font.weight: Font.Medium
                    }

                    Txt {
                        leftPadding: 2
                        text: WeatherState.condition
                        muted: true
                    }
                }
            }
        }

        // (3) Umidade, sensação e vento.
        RowLayout {
            Layout.fillWidth: true
            spacing: ThemeManager.spacing.normal

            DetailCard {
                icon: Icons.humidity
                label: "Umidade"
                value: WeatherState.humidity
            }

            DetailCard {
                icon: Icons.temperature
                label: "Sensação"
                value: WeatherState.feels
            }

            DetailCard {
                icon: Icons.wind
                label: "Vento"
                value: WeatherState.wind
            }
        }

        // (4) Os sete dias.
        Txt {
            Layout.topMargin: ThemeManager.spacing.tiny
            Layout.leftMargin: ThemeManager.spacing.tiny
            visible: WeatherState.days.length > 0
            text: "Previsão de 7 dias"
            font.weight: Font.DemiBold
        }

        RowLayout {
            Layout.fillWidth: true
            visible: WeatherState.days.length > 0
            spacing: ThemeManager.spacing.small

            Repeater {
                model: WeatherState.days

                delegate: Surface {
                    id: day

                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: dayColumn.implicitHeight + ThemeManager.spacing.normal * 2
                    radius: ThemeManager.radius.large + ThemeManager.radius.small

                    Column {
                        id: dayColumn

                        anchors.centerIn: parent
                        width: parent.width - ThemeManager.spacing.small
                        spacing: ThemeManager.spacing.tiny + 2

                        Txt {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: day.modelData.label
                            color: ThemeManager.colors.accent
                            font.weight: Font.DemiBold
                        }

                        Txt {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: day.modelData.date
                            opacity: 0.7
                            font.pixelSize: ThemeManager.font.small
                        }

                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            icon: day.modelData.icon
                            filled: true
                            size: root.bigIcon
                        }

                        Txt {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: day.modelData.range
                            font.pixelSize: ThemeManager.font.small
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }
        }

        // (5) O rodapé: só o aviso, quando há o que dizer.
        Txt {
            Layout.fillWidth: true
            Layout.leftMargin: ThemeManager.spacing.tiny
            visible: text !== ""
            text: WeatherState.notice || WeatherState.updatedNote
            faint: true
            font.pixelSize: ThemeManager.font.small
        }
    }

    component SunStat: Row {
        id: sun

        property string icon
        property string label
        property string value

        spacing: ThemeManager.spacing.small + 2

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            icon: sun.icon
            size: root.bigIcon
            color: ThemeManager.colors.accent
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Txt {
                text: sun.label
                muted: true
                font.pixelSize: ThemeManager.font.small
            }

            Txt {
                text: sun.value
                font.weight: Font.DemiBold
            }
        }
    }

    component DetailCard: Surface {
        id: detail

        property string icon
        property string label
        property string value

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.preferredHeight: 60

        Row {
            anchors.centerIn: parent
            spacing: ThemeManager.spacing.normal

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                icon: detail.icon
                size: 24
                color: ThemeManager.colors.accent
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Txt {
                    text: detail.label
                    opacity: 0.7
                    font.pixelSize: ThemeManager.font.small
                }

                Txt {
                    text: detail.value
                    font.weight: Font.DemiBold
                }
            }
        }
    }
}
