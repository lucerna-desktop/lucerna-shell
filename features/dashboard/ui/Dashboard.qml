pragma ComponentBehavior: Bound

import QtQuick
import qs.core.frame
import qs.core.theme
import qs.core.widgets
import qs.features.dashboard.state

// Painel superior: escorre da moldura de cima, logo abaixo da pílula fundida
// (a "cabeça" dele), com mola: a forma cresce da largura da pílula até a do
// painel e da altura 0 até a da aba atual. O fundo é um pedaço da forma da tela
// (Frame); o conteúdo, com a largura do painel aberto, é recortado por ela e
// entra quando ela passa de ~60%. Tab/Shift+Tab ou 1–4 trocam de aba; Esc ou
// clique fora fecham.
OverlayPanel {
    id: panel

    name: "dashboard"
    open: DashboardState.open
    screen: DashboardState.screen
    frameScreen: DashboardState.screen
    inputItem: drawer
    onDismissed: DashboardState.close()

    readonly property real fullWidth: Math.min(920, width - ThemeManager.spacing.small * 2)
    readonly property real fullHeight: contentScope.height + ThemeManager.spacing.large * 2
    // A pílula fundida dessa tela; sem ela, o painel sai direto da moldura.
    readonly property rect pill: Frame.pillOn(DashboardState.screen)
    readonly property bool fromPill: pill.width > 0

    onOpenChanged: {
        if (open)
            contentScope.forceActiveFocus();
    }

    readonly property int index: DashboardState.currentIndex
    readonly property Loader currentPage: pageRepeater.count > index ? pageRepeater.itemAt(index) as Loader : null

    FrameBlob {
        screen: DashboardState.screen
        framed: true
        open: panel.open
        progress: panel.progress
        rect: Qt.rect(drawer.x, drawer.y, drawer.width, drawer.height)
    }

    // A área da forma do painel: o conteúdo é recortado por ela.
    Item {
        id: drawer

        width: panel.fromPill ? panel.pill.width + (panel.fullWidth - panel.pill.width) * Frame.clamp(panel.progress) : panel.fullWidth
        x: (parent.width - width) / 2
        height: Math.max(0, panel.fullHeight * panel.progress)
        y: panel.fromPill ? panel.pill.y + panel.pill.height : Frame.thicknessAt(panel.progress)
        clip: true

        // Para "fechar ao tirar o mouse".
        HoverHandler {
            onHoveredChanged: DashboardState.setPointerInside(hovered)
        }

        // Largura fixa (a do painel aberto): a forma cresce em volta dele sem
        // refazer o layout a cada quadro.
        FocusScope {
            id: contentScope

            x: (parent.width - panel.fullWidth) / 2 + ThemeManager.spacing.large
            width: panel.fullWidth - ThemeManager.spacing.large * 2
            anchors.bottom: parent.bottom
            anchors.bottomMargin: ThemeManager.spacing.large
            height: tabs.height + ThemeManager.spacing.normal + pages.height
            focus: true
            opacity: Frame.contentOpacity(panel.progress)

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Tab)
                    DashboardState.setTab(panel.index + 1);
                else if (event.key === Qt.Key_Backtab)
                    DashboardState.setTab(panel.index - 1);
                else if (event.key >= Qt.Key_1 && event.key < Qt.Key_1 + DashboardState.tabs.length)
                    DashboardState.setTab(event.key - Qt.Key_1);
                else
                    return;
                event.accepted = true;
            }

            TabBar {
                id: tabs

                width: parent.width
                tabs: DashboardState.tabs
                currentIndex: panel.index
                onActivated: index => DashboardState.setTab(index)
            }

            Item {
                id: pages

                anchors.top: tabs.bottom
                anchors.topMargin: ThemeManager.spacing.normal
                width: parent.width
                height: (panel.currentPage?.item as Item)?.implicitHeight ?? 0
                clip: true

                Behavior on height { Anim { type: Anim.Spatial } }


                // As páginas seguem a ordem e a visibilidade das abas.
                Row {
                    id: pagesRow

                    x: -panel.index * pages.width

                    Behavior on x { Anim { type: Anim.Spatial } }

                    Repeater {
                        id: pageRepeater

                        model: DashboardState.tabs

                        delegate: Loader {
                            required property var modelData

                            width: pages.width
                            sourceComponent: ({
                                overview: overviewPage,
                                media: mediaPage,
                                performance: performancePage,
                                weather: weatherPage
                            })[modelData.id]
                        }
                    }
                }
            }
        }
    }

    Component {
        id: overviewPage

        OverviewPage {}
    }

    Component {
        id: mediaPage

        MediaPage {}
    }

    Component {
        id: performancePage

        PerformancePage {}
    }

    Component {
        id: weatherPage

        WeatherPage {}
    }
}
