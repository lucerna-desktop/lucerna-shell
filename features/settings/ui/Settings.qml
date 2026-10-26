pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.core.theme
import qs.core.widgets
import qs.features.settings.state

// Tela de configurações: tópicos à esquerda, conteúdo à direita. Setas ↑/↓
// trocam de tópico; Esc ou clique fora fecham. Abrir fecha o painel superior
// e a central; o painel superior aberto depois fica por cima (ver Panels).
OverlayPanel {
    id: panel

    name: "settings"
    open: SettingsState.open
    screen: SettingsState.screen
    inputItem: window
    onDismissed: SettingsState.close()

    onOpenChanged: {
        if (open)
            topicPane.forceActiveFocus();
    }

    Surface {
        id: window

        level: 0
        anchors.centerIn: parent
        width: Math.min(980, parent.width - 80)
        height: Math.min(640, parent.height - 120)
        radius: ThemeManager.radius.large + 4
        scale: 0.94 + 0.06 * panel.progress

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // Lista de tópicos, à esquerda
            FocusScope {
                id: topicPane

                Layout.preferredWidth: 280
                Layout.fillHeight: true
                focus: true

                Keys.onUpPressed: SettingsState.setTopic(SettingsState.currentIndex - 1)
                Keys.onDownPressed: SettingsState.setTopic(SettingsState.currentIndex + 1)
                Keys.onTabPressed: SettingsState.setTopic(SettingsState.currentIndex + 1)
                Keys.onBacktabPressed: SettingsState.setTopic(SettingsState.currentIndex - 1)

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    topLeftRadius: window.radius
                    bottomLeftRadius: window.radius
                    color: ThemeManager.alpha(ThemeManager.colors.base, 0.35)
                }

                Row {
                    id: heading

                    x: ThemeManager.spacing.large
                    y: ThemeManager.spacing.large + 4
                    spacing: ThemeManager.spacing.normal

                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 27
                        height: 35
                        source: ThemeManager.logo
                        sourceSize: Qt.size(width * 2, height * 2)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                    }

                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Configurações"
                        font.pixelSize: ThemeManager.font.large + 2
                        font.weight: Font.DemiBold
                    }
                }

                // Rola quando a janela fica baixa (telas pequenas).
                Flickable {
                    id: topicScroller

                    anchors {
                        top: heading.bottom
                        left: parent.left
                        right: parent.right
                        bottom: hint.top
                        topMargin: ThemeManager.spacing.large
                        leftMargin: ThemeManager.spacing.normal
                        rightMargin: ThemeManager.spacing.normal
                        bottomMargin: ThemeManager.spacing.small
                    }
                    contentHeight: topicList.height
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    // Mantém o tópico atual à vista ao navegar pelas setas.
                    readonly property Item currentRow: topicRows.count > 0 ? topicRows.itemAt(SettingsState.currentIndex) : null

                    function reveal(): void {
                        // Deixa um tópico de contexto antes e depois do atual.
                        let y = contentY;
                        const around = currentRow?.height ?? 0;
                        if (currentRow && currentRow.y - around < y)
                            y = currentRow.y - around;
                        else if (currentRow && currentRow.y + currentRow.height + around > y + height)
                            y = currentRow.y + currentRow.height + around - height;
                        contentY = Math.max(0, Math.min(y, contentHeight - height));
                    }

                    onCurrentRowChanged: reveal()
                    onHeightChanged: reveal()
                    onContentHeightChanged: reveal()

                    Behavior on contentY { Anim { type: Anim.Spatial } }

                    Item {
                        id: topicList

                        width: parent.width
                        height: topics.height

                        // Seleção: uma pílula que desliza com mola até o tópico.
                        Rectangle {
                            readonly property Item target: topicRows.count > 0 ? topicRows.itemAt(SettingsState.currentIndex) : null

                            width: parent.width
                            height: target?.height ?? 44
                            y: target?.y ?? 0
                            radius: ThemeManager.radius.normal + 2
                            color: ThemeManager.alpha(ThemeManager.colors.accent, 0.12)

                            Behavior on y { Anim { type: Anim.FastSpatial } }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: 3
                                height: parent.height * 0.5
                                radius: 1.5
                                color: ThemeManager.colors.accent
                            }
                        }

                        Column {
                            id: topics

                            width: parent.width
                            spacing: 2

                            Repeater {
                                id: topicRows

                                model: SettingsState.topics

                                delegate: Clickable {
                                    id: row

                                    required property var modelData
                                    required property int index
                                    readonly property bool current: index === SettingsState.currentIndex

                                    width: topics.width
                                    height: 44
                                    radius: ThemeManager.radius.normal + 2
                                    onClicked: SettingsState.setTopic(index)

                                    // Ícone num ladrilho: acende (preenche e ganha a cor de acento) quando é o atual.
                                    Rectangle {
                                        id: tile

                                        x: ThemeManager.spacing.normal
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 34
                                        height: 34
                                        radius: row.current ? 17 : 10
                                        color: row.current ? ThemeManager.colors.accent : ThemeManager.alpha(ThemeManager.colors.text, 0.06)

                                        Behavior on radius { Anim { type: Anim.FastSpatial } }
                                        Behavior on color { ColorAnim {} }

                                        Icon {
                                            anchors.centerIn: parent
                                            icon: row.modelData.icon
                                            filled: row.current || row.hovered
                                            size: 19
                                            color: row.current ? ThemeManager.colors.accentText : row.modelData.soon ? ThemeManager.colors.textFaint : ThemeManager.colors.textMuted
                                            scale: row.current ? 1.08 : 1

                                            Behavior on color { ColorAnim {} }
                                            Behavior on scale { Anim { type: Anim.FastSpatial } }
                                        }
                                    }

                                    Column {
                                        anchors.left: tile.right
                                        anchors.leftMargin: ThemeManager.spacing.normal
                                        anchors.right: parent.right
                                        anchors.rightMargin: ThemeManager.spacing.small
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 1

                                        Txt {
                                            width: parent.width
                                            text: row.modelData.label
                                            font.weight: row.current ? Font.DemiBold : Font.Normal
                                            color: row.modelData.soon && !row.current ? ThemeManager.colors.textMuted : ThemeManager.colors.text
                                        }

                                        Txt {
                                            width: parent.width
                                            text: row.modelData.soon ? "Em breve" : row.modelData.description
                                            faint: true
                                            font.pixelSize: ThemeManager.font.small
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Txt {
                    id: hint

                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: ThemeManager.spacing.large
                    text: "Esc fecha · ↑ ↓ navegam"
                    faint: true
                    font.pixelSize: ThemeManager.font.small
                }
            }

            // Divisória só com contorno ligado; sem ele, o tom da lista de tópicos separa.
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                color: ThemeManager.colors.border
                visible: ThemeManager.outlines
            }

            // Conteúdo
            Item {
                id: contentArea

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                Flickable {
                    id: scroller

                    anchors.fill: parent
                    contentHeight: page.y + page.height + ThemeManager.spacing.large * 2
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    Column {
                        id: pageHeader

                        x: ThemeManager.spacing.large + 8
                        y: ThemeManager.spacing.large + 6
                        width: scroller.width - x * 2
                        spacing: 4

                        Txt {
                            text: SettingsState.current.label
                            font.pixelSize: ThemeManager.font.huge - 18
                            font.weight: Font.DemiBold
                        }

                        Txt {
                            text: SettingsState.current.description
                            muted: true
                        }
                    }

                    Loader {
                        id: page

                        x: pageHeader.x
                        y: pageHeader.y + pageHeader.height + ThemeManager.spacing.large
                        width: pageHeader.width

                        sourceComponent: ({
                            appearance: appearancePage,
                            glass: glassPage,
                            notifications: notificationsPage,
                            bar: barPage,
                            launcher: launcherPage,
                            dashboard: dashboardPage,
                            power: powerPage,
                            panels: panelsPage,
                            displays: displaysPage,
                            wallpaper: wallpaperPage,
                            mouse: mousePage,
                            idle: idlePage,
                            nightlight: nightLightPage,
                            clipboard: clipboardPage,
                            capture: capturePage,
                            keyboard: keyboardPage,
                            shortcuts: shortcutsPage,
                            credits: creditsPage,
                            about: aboutPage
                        })[SettingsState.current.id] ?? soonPage

                        // Cada página entra subindo e aparecendo.
                        onLoaded: {
                            scroller.contentY = 0;
                            enter.restart();
                        }

                        transform: Translate {
                            id: pageOffset
                        }

                        ParallelAnimation {
                            id: enter

                            Anim { target: page; property: "opacity"; from: 0; to: 1; type: Anim.Effects }
                            Anim { target: pageOffset; property: "y"; from: 22; to: 0; type: Anim.Spatial }
                        }
                    }
                }

                // Indicador de rolagem discreto
                Rectangle {
                    visible: scroller.contentHeight > scroller.height
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    y: scroller.visibleArea.yPosition * scroller.height
                    width: 4
                    height: scroller.visibleArea.heightRatio * scroller.height
                    radius: 2
                    color: ThemeManager.colors.textFaint
                    opacity: scroller.moving ? 0.8 : 0.3

                    Behavior on opacity { Anim { type: Anim.Effects } }
                }
            }
        }
    }

    Component {
        id: appearancePage

        AppearancePage {}
    }

    Component {
        id: glassPage

        GlassPage {}
    }

    Component {
        id: idlePage

        IdlePage {}
    }

    Component {
        id: capturePage

        CapturePage {}
    }

    Component {
        id: clipboardPage

        ClipboardPage {}
    }

    Component {
        id: nightLightPage

        NightLightPage {}
    }

    Component {
        id: mousePage

        MousePage {}
    }

    Component {
        id: keyboardPage

        KeyboardPage {}
    }

    Component {
        id: wallpaperPage

        WallpaperPage {}
    }

    Component {
        id: displaysPage

        MonitorsPage {}
    }

    Component {
        id: panelsPage

        PanelsPage {}
    }

    Component {
        id: powerPage

        PowerPage {}
    }

    Component {
        id: dashboardPage

        DashboardPage {}
    }

    Component {
        id: launcherPage

        LauncherPage {}
    }

    Component {
        id: barPage

        BarPage {}
    }

    Component {
        id: notificationsPage

        NotificationsPage {}
    }

    Component {
        id: shortcutsPage

        ShortcutsPage {}
    }

    Component {
        id: creditsPage

        CreditsPage {}
    }

    Component {
        id: aboutPage

        AboutPage {}
    }

    Component {
        id: soonPage

        SoonPage {
            topic: SettingsState.current
        }
    }
}
