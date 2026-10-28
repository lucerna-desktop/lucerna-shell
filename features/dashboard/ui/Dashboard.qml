pragma ComponentBehavior: Bound

import QtQuick
import qs.core.frame
import qs.core.panels
import qs.core.theme
import qs.core.widgets
import qs.features.dashboard.state

// Painel superior, dentro da janela da forma de um monitor (ver
// core/widgets/FrameWindow), em coordenadas da tela: a aba da barra, fundida à
// moldura de cima, se transforma nele, com mola: uma peça só, que se alarga da
// largura da aba até a do painel e cresce para baixo. O conteúdo da barra
// esmaece no começo (ver Frame.morphOn). O fundo é um pedaço da forma da tela
// (Frame); o conteúdo, com a largura do painel aberto, fica preso ao pé da
// peça e é recortado por ela: desce com o fundo desde o 1º quadro. Ao fechar,
// a mesma mola ao contrário. Tab/Shift+Tab ou 1–4 trocam de aba; Esc fecha, e
// o clique fora fecha pelo grab (ver Panels).
Item {
    id: panel

    required property var screen
    readonly property bool here: DashboardState.screen === screen
    readonly property bool open: DashboardState.open && here
    // A mola espera a janela da forma chegar à tela inteira (Frame.readyOn).
    property real progress: open && Frame.readyOn(screen, Frame.sizeOn(screen).width) ? 1 : 0

    // A mesma mola nos dois sentidos. Ao fechar ela passa do zero uma vez e
    // volta por baixo: só esconde, nunca reabre.
    Behavior on progress {
        Anim {
            type: Anim.Spatial
        }
    }

    anchors.fill: parent
    visible: open || progress > 0

    readonly property real fullWidth: Math.min(920, width - ThemeManager.spacing.small * 2)
    // Da borda de cima (com a moldura) até o fim do conteúdo.
    readonly property real fullHeight: Frame.thickness + contentScope.height + ThemeManager.spacing.large * 2
    // A aba da barra dessa tela, de onde a peça parte; sem ela, sai direto da moldura.
    readonly property rect pill: Frame.pillOn(screen)
    readonly property bool fromPill: pill.width > 0
    readonly property real startWidth: fromPill ? pill.width : fullWidth
    readonly property real startHeight: fromPill ? pill.height : 0

    onOpenChanged: {
        if (open)
            contentScope.forceActiveFocus();
    }

    readonly property int index: DashboardState.currentIndex
    readonly property Loader currentPage: pageRepeater.count > index ? pageRepeater.itemAt(index) as Loader : null

    // O véu, só com o painel modal: a tela inteira, por cima da forma.
    Rectangle {
        anchors.fill: parent
        visible: Panels.isModal("dashboard")
        color: ThemeManager.alpha("#000000", (ThemeManager.dark ? 0.4 : 0.22) * Frame.clamp(panel.progress))
    }

    FrameBlob {
        screen: panel.screen
        framed: true
        fromBar: true
        open: panel.open
        progress: panel.progress
        rect: Frame.attach(Qt.rect(drawer.x, drawer.y, drawer.width, drawer.height), Frame.edges.dashboard)
    }

    // A peça recebe o mouse (a barra, transformada nela, deixa de receber) e,
    // aberto, o teclado; fechando, o teclado volta logo para a janela de baixo.
    FrameInput {
        screen: panel.screen
        active: panel.open || panel.progress > 0
        rect: Qt.rect(drawer.x, drawer.y, drawer.width, drawer.height)
        keyboard: panel.open
    }

    // A peça, da aba da barra até o painel: o conteúdo é recortado por ela.
    Item {
        id: drawer

        readonly property real grow: Frame.clamp(panel.progress)

        width: panel.startWidth + (panel.fullWidth - panel.startWidth) * grow
        x: (panel.width - width) / 2
        y: panel.fromPill ? panel.pill.y : 0
        height: Math.max(0, panel.startHeight + (panel.fullHeight - panel.startHeight) * panel.progress)
        clip: true

        // Para "fechar ao tirar o mouse".
        HoverHandler {
            onHoveredChanged: DashboardState.setPointerInside(hovered)
        }

        // Largura fixa (a do painel aberto): a forma cresce em volta dele sem
        // refazer o layout a cada quadro.
        FocusScope {
            id: contentScope

            x: (drawer.width - panel.fullWidth) / 2 + ThemeManager.spacing.large
            width: panel.fullWidth - ThemeManager.spacing.large * 2
            // Preso ao pé da peça: aberta, o cabeçalho fica logo abaixo da
            // moldura; antes, sobe junto com o pé.
            y: drawer.height - panel.fullHeight + Frame.thickness + ThemeManager.spacing.large - drawer.y
            height: tabs.height + ThemeManager.spacing.normal + pages.height
            focus: true
            opacity: Frame.clamp(panel.progress)

            Keys.onEscapePressed: DashboardState.close()

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
