pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.core.config
import qs.core.format
import qs.core.theme
import qs.core.widgets
import qs.features.dashboard.state

// Aba Painel: usuário, relógio e clima, calendário, recursos e mídia.
Item {
    id: root

    readonly property bool onScreen: DashboardState.isShowing("overview")
    // Os cards de cima das colunas esquerda (usuário) e direita (sistema) têm a mesma altura.
    readonly property int topCardHeight: 132
    // Margem interna dos cards, a mesma das outras abas.
    readonly property int cardMargin: ThemeManager.spacing.normal + 2
    // O clima só entra com dados (ou o aviso do modo offline); senão o relógio fica sozinho.
    readonly property bool weatherOn: OverviewState.shows("weather") && (OverviewState.hasWeather || Config.offline)

    implicitHeight: layout.visibleChildren.length ? layout.implicitHeight : 120

    Txt {
        anchors.centerIn: parent
        visible: !layout.visibleChildren.length
        text: "Todos os cartões estão escondidos (Configurações → Painel superior)"
        faint: true
    }

    RowLayout {
        id: layout

        width: parent.width
        spacing: ThemeManager.spacing.normal

        // Coluna 1: usuário + relógio (e clima)
        ColumnLayout {
            Layout.preferredWidth: 270
            Layout.fillWidth: !calendarCard.visible && !column3.visible
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignTop
            visible: OverviewState.shows("user") || OverviewState.shows("clock") || root.weatherOn
            spacing: ThemeManager.spacing.normal

            Surface {
                Layout.fillWidth: true
                Layout.preferredHeight: root.topCardHeight
                visible: OverviewState.shows("user")

                Row {
                    anchors.fill: parent
                    anchors.margins: root.cardMargin
                    spacing: ThemeManager.spacing.normal

                    Item {
                        width: 64
                        height: 64
                        anchors.verticalCenter: parent.verticalCenter

                        Blob {
                            anchors.fill: parent
                            morphing: true
                            active: root.onScreen
                            steps: 96
                            color: ThemeManager.alpha(ThemeManager.colors.accent, 0.22)
                            spinning: true
                            spinDuration: 30000
                        }

                        Icon {
                            anchors.centerIn: parent
                            visible: face.status !== Image.Ready
                            icon: Icons.person
                            filled: true
                            size: 30
                            color: ThemeManager.colors.accent
                        }

                        ClippingRectangle {
                            anchors.centerIn: parent
                            width: 52
                            height: 52
                            radius: 26
                            color: "transparent"
                            visible: face.status === Image.Ready

                            Image {
                                id: face

                                anchors.fill: parent
                                source: OverviewState.face
                                sourceSize: Qt.size(104, 104)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                            }
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Txt {
                            text: OverviewState.user
                            font.pixelSize: ThemeManager.font.large
                            font.weight: Font.DemiBold
                        }

                        Txt {
                            text: OverviewState.hostname
                            muted: true
                            font.pixelSize: ThemeManager.font.small
                        }

                        Row {
                            spacing: 4
                            visible: OverviewState.uptime !== ""

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                icon: Icons.uptime
                                size: 14
                                color: ThemeManager.colors.textFaint
                            }

                            Txt {
                                text: OverviewState.uptime
                                faint: true
                                font.pixelSize: ThemeManager.font.small
                            }
                        }
                    }
                }

                // Configurações e energia, que saíram da barra.
                Column {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: ThemeManager.spacing.small
                    spacing: 2

                    IconButton {
                        icon: Icons.settings
                        iconSize: 18
                        onClicked: OverviewState.openSettings()
                    }

                    IconButton {
                        icon: Icons.power
                        iconSize: 18
                        foreground: ThemeManager.colors.danger
                        onClicked: OverviewState.openPower()
                    }
                }
            }

            // Na altura do conteúdo; com sobra (o calendário mais alto), cresce até
            // terminar na mesma linha que ele.
            Surface {
                Layout.fillWidth: true
                Layout.preferredHeight: clockContent.implicitHeight + 2 * root.cardMargin
                Layout.fillHeight: true
                visible: OverviewState.shows("clock") || root.weatherOn

                // Duas colunas, centradas na altura: hora e data à esquerda, clima à direita.
                // Sem clima (desligado, sem dados e fora do modo offline), o relógio fica
                // sozinho e centralizado. Em card estreito, a data quebra em duas
                // linhas e o clima encolhe (duas linhas ou elide); a hora, não.
                RowLayout {
                    id: clockContent

                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, parent.width - 2 * root.cardMargin)
                    spacing: ThemeManager.spacing.normal + 2

                    Column {
                        id: clockColumn

                        // A data numa linha ("Sábado, 17 de outubro"); se não couber, o dia da
                        // semana numa linha e o dia e o mês na de baixo, sem reticências.
                        readonly property string oneLine: `${OverviewState.weekday}, ${OverviewState.date}`
                        readonly property bool dateFits: oneLineMetrics.advanceWidth <= width

                        visible: OverviewState.shows("clock")
                        Layout.alignment: Qt.AlignVCenter
                        Layout.minimumWidth: Math.max(clockRow.width, weekdayMetrics.advanceWidth, dayMetrics.advanceWidth)
                        Layout.preferredWidth: Math.max(clockRow.width, oneLineMetrics.advanceWidth)
                        Layout.maximumWidth: Layout.preferredWidth
                        Layout.fillWidth: true
                        spacing: 0

                        TextMetrics {
                            id: oneLineMetrics

                            font: dateText.font
                            text: clockColumn.oneLine
                        }

                        TextMetrics {
                            id: weekdayMetrics

                            font: dateText.font
                            text: `${OverviewState.weekday},`
                        }

                        TextMetrics {
                            id: dayMetrics

                            font: dateText.font
                            text: OverviewState.date
                        }

                        // Dígitos em células de largura fixa (a do dígito mais largo): a hora não
                        // pula ao mudar de minuto, mesmo numa fonte sem números tabulares.
                        Row {
                            id: clockRow

                            readonly property real digitWidth: {
                                // Ler a família religa a conta quando a fonte do tema muda.
                                if (!digitMetrics.font.family)
                                    return 0;
                                return Math.max(...[0, 1, 2, 3, 4, 5, 6, 7, 8, 9].map(d => digitMetrics.advanceWidth(String(d))));
                            }

                            FontMetrics {
                                id: digitMetrics

                                font.family: ThemeManager.font.sans
                                font.variableAxes: ThemeManager.fontAxes(Font.Light)
                                font.pixelSize: ThemeManager.font.huge - 6
                                font.weight: Font.Light
                                font.features: { "tnum": 1 }
                            }

                            Repeater {
                                model: 5

                                delegate: Txt {
                                    required property int index

                                    width: index === 2 ? implicitWidth : clockRow.digitWidth
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideNone
                                    text: OverviewState.time.charAt(index)
                                    font.pixelSize: digitMetrics.font.pixelSize
                                    font.weight: digitMetrics.font.weight
                                    font.features: { "tnum": 1 }
                                }
                            }
                        }

                        Txt {
                            id: dateText

                            width: parent.width
                            text: clockColumn.dateFits ? clockColumn.oneLine : `${OverviewState.weekday},\n${OverviewState.date}`
                            muted: true
                            font.pixelSize: ThemeManager.font.small + 1
                        }
                    }

                    Column {
                        visible: root.weatherOn
                        Layout.alignment: Qt.AlignVCenter
                        Layout.minimumWidth: weatherRow.width
                        Layout.preferredWidth: Math.max(weatherRow.width, conditionText.implicitWidth, placeText.implicitWidth)
                        Layout.maximumWidth: Layout.preferredWidth
                        Layout.fillWidth: true
                        spacing: 2

                        Row {
                            id: weatherRow

                            spacing: ThemeManager.spacing.small
                            anchors.horizontalCenter: parent.horizontalCenter

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                icon: OverviewState.weatherIcon
                                filled: true
                                size: 30
                                color: ThemeManager.colors.accent
                            }

                            Txt {
                                visible: OverviewState.hasWeather
                                anchors.verticalCenter: parent.verticalCenter
                                text: OverviewState.weatherTemp
                                font.pixelSize: ThemeManager.font.huge - 14
                                font.weight: Font.DemiBold
                            }
                        }

                        Txt {
                            id: conditionText

                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: OverviewState.weatherText
                            muted: true
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            font.pixelSize: ThemeManager.font.small
                        }

                        Txt {
                            id: placeText

                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            visible: text !== ""
                            text: OverviewState.weatherPlace
                            faint: true
                            font.pixelSize: ThemeManager.font.small
                        }
                    }
                }
            }
        }

        // Coluna 2: calendário
        Surface {
            id: calendarCard

            Layout.preferredWidth: 300
            Layout.preferredHeight: calendar.implicitHeight + 2 * root.cardMargin
            Layout.fillHeight: true
            Layout.fillWidth: !column3.visible
            visible: OverviewState.shows("calendar")

            Calendar {
                id: calendar

                anchors.fill: parent
                anchors.margins: root.cardMargin
            }
        }

        // Coluna 3: recursos + mídia
        ColumnLayout {
            id: column3

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignTop
            visible: OverviewState.shows("resources") || OverviewState.shows("media")
            spacing: ThemeManager.spacing.normal

            Surface {
                Layout.fillWidth: true
                Layout.preferredHeight: root.topCardHeight
                Layout.fillHeight: !OverviewState.shows("media")
                visible: OverviewState.shows("resources")

                // Sem o lucernad: o ícone e "Indisponível", no lugar das barras.
                Row {
                    anchors.centerIn: parent
                    visible: !OverviewState.statsAvailable
                    spacing: ThemeManager.spacing.small

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: Icons.performance
                        size: 18
                        color: ThemeManager.colors.textFaint
                    }

                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Indisponível"
                        faint: true
                    }
                }

                Column {
                    visible: OverviewState.statsAvailable
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: ThemeManager.spacing.normal + 2
                    spacing: ThemeManager.spacing.normal + 4

                    Repeater {
                        model: [
                            { icon: Icons.cpu, label: "CPU", value: OverviewState.cpu },
                            { icon: Icons.memory, label: "Memória", value: OverviewState.memory },
                            { icon: Icons.storage, label: "Disco", value: OverviewState.disk }
                        ]

                        delegate: Row {
                            id: metric

                            required property var modelData

                            width: parent.width
                            spacing: ThemeManager.spacing.small

                            AnimatedNumber {
                                id: number

                                value: metric.modelData.value
                            }

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                icon: parent.modelData.icon
                                size: 18
                                color: ThemeManager.colors.accent
                            }

                            Txt {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 64
                                text: parent.modelData.label
                                muted: true
                                font.pixelSize: ThemeManager.font.small + 1
                            }

                            LinearGauge {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 18 - 64 - 44 - parent.spacing * 3
                                value: parent.modelData.value
                            }

                            Txt {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 44
                                horizontalAlignment: Text.AlignRight
                                text: Format.percent(number.shown)
                                mono: true
                                font.pixelSize: ThemeManager.font.small + 1
                            }
                        }
                    }
                }
            }

            // O visualizador (88) e as margens; a mesma altura tocando ou não.
            Surface {
                Layout.fillWidth: true
                Layout.preferredHeight: 88 + 2 * root.cardMargin
                Layout.fillHeight: true
                visible: OverviewState.shows("media")

                MediaCard {
                    anchors.fill: parent
                    anchors.margins: root.cardMargin
                    onScreen: root.onScreen
                }
            }
        }
    }
}
