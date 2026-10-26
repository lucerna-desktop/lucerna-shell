pragma ComponentBehavior: Bound

import QtQuick
import qs.core.theme
import qs.core.widgets
import qs.features.dashboard.state

// Calendário do mês. As setas ou a roda do mouse trocam o mês; clicar no título volta ao atual.
Item {
    id: root

    readonly property bool onScreen: DashboardState.isShowing("overview")

    // Altura de cada linha de dias: fixa, o calendário não se espalha pela altura do card.
    readonly property int rowHeight: 30

    // Título, cabeçalho e seis linhas.
    implicitHeight: 28 + ThemeManager.spacing.small + 22 + 6 * rowHeight

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: event => {
            grid.direction = event.angleDelta.y > 0 ? -1 : 1;
            OverviewState.shiftMonth(grid.direction);
        }
    }

    Column {
        id: column

        width: parent.width
        spacing: ThemeManager.spacing.small

        Item {
            width: parent.width
            height: 28

            IconButton {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                icon: Icons.chevronLeft
                iconSize: 18
                onClicked: {
                    grid.direction = -1;
                    OverviewState.shiftMonth(-1);
                }
            }

            Clickable {
                anchors.centerIn: parent
                width: title.implicitWidth + ThemeManager.spacing.normal
                height: 26
                onClicked: OverviewState.resetMonth()

                Txt {
                    id: title

                    anchors.centerIn: parent
                    text: OverviewState.monthTitle
                    color: ThemeManager.colors.accent
                    font.weight: Font.DemiBold
                }
            }

            IconButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                icon: Icons.chevronRight
                iconSize: 18
                onClicked: {
                    grid.direction = 1;
                    OverviewState.shiftMonth(1);
                }
            }
        }

        Grid {
            id: grid

            readonly property real cell: width / 7
            property int direction: 1

            // Ao trocar de mês, os dias entram deslizando do lado da navegação.
            Connections {
                target: OverviewState

                function onMonthOffsetChanged() {
                    monthSlide.restart();
                }
            }

            ParallelAnimation {
                id: monthSlide

                Anim { target: grid; property: "opacity"; from: 0; to: 1; type: Anim.Effects }
                Anim { target: slide; property: "x"; from: 24 * grid.direction; to: 0; type: Anim.Spatial }
            }

            transform: Translate {
                id: slide
            }

            width: parent.width
            columns: 7

            Repeater {
                model: OverviewState.weekdays

                delegate: Txt {
                    required property var modelData

                    width: grid.cell
                    height: 22
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData.initial
                    color: modelData.sunday ? ThemeManager.colors.danger : ThemeManager.colors.textFaint
                    font.pixelSize: ThemeManager.font.small
                    font.weight: Font.DemiBold
                }
            }

            Repeater {
                model: OverviewState.calendarDays

                delegate: Item {
                    required property var modelData

                    width: grid.cell
                    height: root.rowHeight

                    // Hoje: uma bolha só, criada apenas na célula de hoje; anima só com o
                    // painel aberto na aba Painel.
                    Loader {
                        anchors.centerIn: parent
                        active: parent.modelData.today

                        sourceComponent: Blob {
                            width: 30
                            height: 30
                            active: root.onScreen
                            morphing: true
                            spinning: true
                            spinDuration: 30000
                            steps: 48
                            color: ThemeManager.colors.accent
                        }
                    }

                    Txt {
                        anchors.fill: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: parent.modelData.day
                        font.pixelSize: ThemeManager.font.small + 1
                        font.features: { "tnum": 1 }
                        color: parent.modelData.today ? ThemeManager.colors.accentText : parent.modelData.sunday ? (parent.modelData.inMonth ? ThemeManager.colors.danger : ThemeManager.alpha(ThemeManager.colors.danger, 0.45)) : parent.modelData.inMonth ? ThemeManager.colors.text : ThemeManager.colors.textFaint
                        font.weight: parent.modelData.today ? Font.DemiBold : Font.Normal
                    }
                }
            }
        }
    }
}
