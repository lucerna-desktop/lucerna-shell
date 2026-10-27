pragma ComponentBehavior: Bound

import QtQuick
import qs.core.frame
import qs.core.theme
import qs.core.widgets
import qs.features.dashboard.state

// Painel superior: a aba da barra, fundida à moldura de cima, se transforma
// nele, com mola: uma peça só, que se alarga da largura da aba até a do painel
// e cresce para baixo até a altura da aba atual. O conteúdo da barra esmaece
// no começo (ver Frame.morphOn); o topo da peça passa a ser o cabeçalho do
// painel, a fileira de abas, seguida do conteúdo. Ao fechar, a peça encolhe de
// volta para a aba da barra e o conteúdo dela reaparece. O fundo é um pedaço
// da forma da tela (Frame); o conteúdo, com a largura do painel aberto, é
// recortado por ela e entra quando ela passa de ~70%. Tab/Shift+Tab ou 1–4
// trocam de aba; Esc ou clique fora fecham.
OverlayPanel {
    id: panel

    name: "dashboard"
    open: DashboardState.open
    screen: DashboardState.screen
    frameScreen: DashboardState.screen
    inputItem: drawer
    onDismissed: DashboardState.close()

    readonly property real fullWidth: Math.min(920, width - ThemeManager.spacing.small * 2)
    // Da borda de cima (com a moldura) até o fim do conteúdo.
    readonly property real fullHeight: Frame.thickness + contentScope.height + ThemeManager.spacing.large * 2
    // A aba da barra dessa tela, de onde a peça parte; sem ela, sai direto da moldura.
    readonly property rect pill: Frame.pillOn(DashboardState.screen)
    readonly property bool fromPill: pill.width > 0
    readonly property real startWidth: fromPill ? pill.width : fullWidth
    readonly property real startHeight: fromPill ? pill.height : 0

    onOpenChanged: {
        if (open)
            contentScope.forceActiveFocus();
    }

    readonly property int index: DashboardState.currentIndex
    readonly property Loader currentPage: pageRepeater.count > index ? pageRepeater.itemAt(index) as Loader : null

    FrameBlob {
        screen: DashboardState.screen
        framed: true
        fromBar: true
        open: panel.open
        progress: panel.progress
        rect: Frame.attach(Qt.rect(drawer.x, drawer.y, drawer.width, drawer.height), Frame.edges.dashboard)
    }

    // A peça, da aba da barra até o painel: o conteúdo é recortado por ela, e
    // ela recebe o mouse (a barra, transformada nela, deixa de receber).
    Item {
        id: drawer

        readonly property real grow: Frame.clamp(panel.progress)

        width: panel.startWidth + (panel.fullWidth - panel.startWidth) * grow
        x: (parent.width - width) / 2
        y: panel.fromPill ? panel.pill.y : 0
        height: Math.max(0, panel.startHeight + (panel.fullHeight - panel.startHeight) * panel.progress)

        // Para "fechar ao tirar o mouse".
        HoverHandler {
            onHoveredChanged: DashboardState.setPointerInside(hovered)
        }

        // O recorte do conteúdo, recuado da beira da peça (Frame.contentInset):
        // a forma, na outra janela, pode chegar um quadro depois.
        Item {
            id: inset

            x: Frame.contentInset
            width: Math.max(0, parent.width - Frame.contentInset * 2)
            height: Math.max(0, parent.height - Frame.contentInset)
            clip: true

            // Largura fixa (a do painel aberto): a forma cresce em volta dele sem
            // refazer o layout a cada quadro.
            FocusScope {
                id: contentScope

                x: (drawer.width - panel.fullWidth) / 2 + ThemeManager.spacing.large - Frame.contentInset
                width: panel.fullWidth - ThemeManager.spacing.large * 2
                // O cabeçalho no topo da peça, logo abaixo da moldura.
                y: Frame.thickness + ThemeManager.spacing.large - drawer.y
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
