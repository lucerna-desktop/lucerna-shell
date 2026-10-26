pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.core.theme
import qs.core.widgets
import qs.features.dashboard.state

// Aba Clima, compacta, na altura da Mídia: um card do agora (o tempo e a
// temperatura; a cidade, o dia, o aviso e o sol; umidade, sensação e vento) e
// os sete dias embaixo. A cidade se escolhe nas configurações; sem o
// lucernad, só o motivo.
Item {
    id: root

    readonly property int mode: !WeatherState.available ? 0 : !WeatherState.hasLocation ? 1 : 2

    // A altura da aba com dados: a mesma da Mídia.
    readonly property int pageHeight: 300

    implicitHeight: mode === 0 ? unavailable.implicitHeight : mode === 1 ? noCity.implicitHeight : pageHeight

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
        // A altura da Mídia: o card do agora em cima, os dias no resto.
        height: root.pageHeight
        spacing: ThemeManager.spacing.normal

        // (1) O agora: o tempo e a temperatura; a cidade, o dia, o aviso e o
        // sol; umidade, sensação e vento.
        Surface {
            Layout.fillWidth: true
            Layout.preferredHeight: 140
            radius: ThemeManager.radius.large

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: ThemeManager.spacing.large + ThemeManager.spacing.tiny
                anchors.rightMargin: ThemeManager.spacing.large + ThemeManager.spacing.tiny
                spacing: ThemeManager.spacing.large + ThemeManager.spacing.small

                Row {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: ThemeManager.spacing.large - ThemeManager.spacing.tiny

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: WeatherState.icon
                        filled: true
                        size: 76
                        color: ThemeManager.colors.accent
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter

                        Txt {
                            text: WeatherState.temp
                            font.pixelSize: ThemeManager.font.huge + 4
                            font.weight: Font.Medium
                        }

                        Txt {
                            leftPadding: 2
                            text: WeatherState.condition
                            muted: true
                        }
                    }
                }

                Column {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: ThemeManager.spacing.small + 2

                    Column {
                        width: parent.width
                        spacing: 2

                        Txt {
                            width: parent.width
                            text: WeatherState.city
                            font.pixelSize: ThemeManager.font.large + 4
                            font.weight: Font.DemiBold
                        }

                        Txt {
                            width: parent.width
                            text: WeatherState.today
                            muted: true
                            font.pixelSize: ThemeManager.font.small
                        }

                        // O aviso (ou a hora da previsão velha), quando há.
                        Txt {
                            width: parent.width
                            visible: text !== ""
                            text: WeatherState.notice || WeatherState.updatedNote
                            faint: true
                            font.pixelSize: ThemeManager.font.small
                        }
                    }

                    Row {
                        spacing: ThemeManager.spacing.large - 2

                        SunStat {
                            icon: Icons.sunrise
                            value: WeatherState.sunrise
                        }

                        SunStat {
                            icon: Icons.sunset
                            value: WeatherState.sunset
                        }
                    }
                }

                Column {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 170
                    spacing: ThemeManager.spacing.small

                    DetailRow {
                        icon: Icons.humidity
                        label: "Umidade"
                        value: WeatherState.humidity
                    }

                    DetailRow {
                        icon: Icons.temperature
                        label: "Sensação"
                        value: WeatherState.feels
                    }

                    DetailRow {
                        icon: Icons.wind
                        label: "Vento"
                        value: WeatherState.wind
                    }
                }
            }
        }

        // (2) Os sete dias, no resto da altura.
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: WeatherState.days.length > 0
            spacing: ThemeManager.spacing.small

            Repeater {
                model: WeatherState.days

                delegate: Surface {
                    id: day

                    required property var modelData

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    radius: ThemeManager.radius.large + ThemeManager.radius.small

                    Column {
                        anchors.centerIn: parent
                        width: parent.width - ThemeManager.spacing.small
                        spacing: ThemeManager.spacing.tiny + 1

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
                            size: 28
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

        // Sem os dias ainda: o espaço fica, para a altura não pular.
        Item {
            Layout.fillHeight: true
            visible: WeatherState.days.length === 0
        }
    }

    component SunStat: Row {
        id: sun

        property string icon
        property string value

        spacing: ThemeManager.spacing.small - 2

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            icon: sun.icon
            size: 18
            color: ThemeManager.colors.accent
        }

        Txt {
            anchors.verticalCenter: parent.verticalCenter
            text: sun.value
            font.pixelSize: ThemeManager.font.small + 1
        }
    }

    component DetailRow: RowLayout {
        id: detail

        property string icon
        property string label
        property string value

        width: parent?.width ?? 0
        spacing: ThemeManager.spacing.small + 2

        Icon {
            icon: detail.icon
            size: 20
            color: ThemeManager.colors.accent
        }

        Txt {
            Layout.fillWidth: true
            text: detail.label
            muted: true
            font.pixelSize: ThemeManager.font.small + 1
        }

        Txt {
            text: detail.value
            font.weight: Font.DemiBold
        }
    }
}
