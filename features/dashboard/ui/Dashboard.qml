pragma ComponentBehavior: Bound

import QtQuick
import qs.core.theme
import qs.core.widgets
import qs.features.dashboard.state

// Painel superior: desce de dentro da barra, com mola, e a altura acompanha a
// aba atual. Tab/Shift+Tab ou 1–4 trocam de aba; Esc ou clique fora fecham.
OverlayPanel {
    id: panel

    name: "dashboard"
    open: DashboardState.open
    screen: DashboardState.screen
    inputItem: drawer
    onDismissed: DashboardState.close()

    onOpenChanged: {
        if (open)
            contentScope.forceActiveFocus();
    }

    readonly property int index: DashboardState.currentIndex
    readonly property Loader currentPage: pageRepeater.count > index ? pageRepeater.itemAt(index) as Loader : null

    // Cartão flutuante que desce do topo da tela com mola.
    Rectangle {
        id: drawer

        width: Math.min(920, parent.width - ThemeManager.spacing.small * 2)
        x: (parent.width - width) / 2
        height: contentScope.height + ThemeManager.spacing.large * 2
        y: DashboardState.topOffset - (1 - panel.progress) * (height + DashboardState.topOffset + 16)
        color: ThemeManager.glass(ThemeManager.colors.base, 0)
        radius: ThemeManager.radius.large
        border.width: ThemeManager.outlines ? 1 : 0
        border.color: ThemeManager.colors.border

        // Para "fechar ao tirar o mouse".
        HoverHandler {
            onHoveredChanged: DashboardState.setPointerInside(hovered)
        }

        FocusScope {
            id: contentScope

            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                leftMargin: ThemeManager.spacing.large
                rightMargin: ThemeManager.spacing.large
                bottomMargin: ThemeManager.spacing.large
            }
            height: tabs.height + ThemeManager.spacing.normal + pages.height
            focus: true

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
