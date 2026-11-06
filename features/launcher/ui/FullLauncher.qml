pragma ComponentBehavior: Bound
import QtQuick
import qs.core.pixel
import qs.core.theme
import qs.core.widgets
import qs.features.launcher.state

// Estilo completo: busca no alto, categorias e favoritos à esquerda, resultados
// em grade no meio e os detalhes do selecionado à direita. Setas andam pela
// grade, Tab troca de categoria, Enter abre e Ctrl+1…9 rodam as ações do app.
Item {
    id: root

    // A escala da janela (fracionária: 1,25), para as linhas finas (ver Pixel).
    readonly property real dpr: Window.window?.devicePixelRatio ?? 1

    required property real progress

    function focusSearch(): void {
        search.focusInput();
    }

    readonly property real pad: ThemeManager.spacing.large
    readonly property real sideWidth: 230
    readonly property real detailsWidth: 320

    Surface {
        id: window

        // Centrada no pixel físico (escala fracionária; ver Pixel).
        x: Pixel.snap((parent.width - width) / 2, root.dpr)
        y: Pixel.snap((parent.height - height) / 2, root.dpr)
        width: Math.min(1200, parent.width - 80)
        height: Math.min(740, parent.height - 120)
        level: 0
        radius: ThemeManager.radius.large + 4
        scale: 0.95 + 0.05 * root.progress

        SearchField {
            id: search

            x: root.pad
            y: root.pad
            width: details.x - root.pad * 2
            placeholder: LauncherState.category === "web" ? "Pesquisar na web" : LauncherState.fileCategory ? "Buscar arquivos pelo nome" : "Buscar aplicativos e ações"
            onKey: event => {
                if (LauncherState.handleShortcut(event)) {
                    event.accepted = true;
                    return;
                }
                const columns = grid.columns;
                if (event.key === Qt.Key_Right)
                    LauncherState.move(1);
                else if (event.key === Qt.Key_Left)
                    LauncherState.move(-1);
                else if (event.key === Qt.Key_Down)
                    LauncherState.move(columns);
                else if (event.key === Qt.Key_Up)
                    LauncherState.move(-columns);
                else if (event.key === Qt.Key_Tab)
                    LauncherState.cycleCategory(1);
                else if (event.key === Qt.Key_Backtab)
                    LauncherState.cycleCategory(-1);
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                    LauncherState.activate(LauncherState.current);
                else if ((event.modifiers & Qt.ControlModifier) && event.key >= Qt.Key_1 && event.key <= Qt.Key_9)
                    LauncherState.runAction(LauncherState.current, event.key - Qt.Key_1);
                else
                    return;
                event.accepted = true;
            }
        }

        // Categorias e favoritos
        Column {
            id: side

            x: root.pad
            y: search.y + search.height + root.pad
            width: root.sideWidth
            spacing: 2

            Repeater {
                model: LauncherState.categories

                delegate: Clickable {
                    id: catRow

                    required property var modelData
                    readonly property bool current: LauncherState.category === modelData.id

                    width: side.width
                    height: 42
                    radius: ThemeManager.radius.normal
                    color: current ? ThemeManager.alpha(ThemeManager.colors.accent, 0.16) : "transparent"
                    onClicked: {
                        LauncherState.setCategory(catRow.modelData.id);
                        search.focusInput();
                    }

                    Icon {
                        id: catIcon

                        anchors.left: parent.left
                        anchors.leftMargin: ThemeManager.spacing.normal
                        anchors.verticalCenter: parent.verticalCenter
                        icon: catRow.modelData.icon
                        filled: catRow.current
                        size: 20
                        color: catRow.current ? ThemeManager.colors.accent : ThemeManager.colors.textMuted
                    }

                    Txt {
                        anchors.left: catIcon.right
                        anchors.leftMargin: ThemeManager.spacing.normal
                        anchors.verticalCenter: parent.verticalCenter
                        text: catRow.modelData.label
                        font.weight: catRow.current ? Font.DemiBold : Font.Normal
                    }
                }
            }

            Item {
                width: 1
                height: ThemeManager.spacing.normal
            }

            Rectangle {
                width: side.width
                height: Pixel.hairline(root.dpr)
                color: ThemeManager.colors.border
                opacity: 0.6
            }

            Item {
                width: 1
                height: ThemeManager.spacing.small
            }

            Txt {
                visible: LauncherState.favoriteApps.length > 0
                leftPadding: ThemeManager.spacing.normal
                bottomPadding: 4
                text: LauncherState.hasPinned ? "Favoritos" : "Mais usados"
                faint: true
                font.pixelSize: ThemeManager.font.small
                font.weight: Font.DemiBold
            }

            Repeater {
                model: LauncherState.favoriteApps

                delegate: Clickable {
                    id: favRow

                    required property var modelData

                    width: side.width
                    height: 38
                    radius: ThemeManager.radius.normal
                    onClicked: LauncherState.activate(LauncherState.fromApp(favRow.modelData))

                    ItemIcon {
                        id: favIcon

                        anchors.left: parent.left
                        anchors.leftMargin: ThemeManager.spacing.normal
                        anchors.verticalCenter: parent.verticalCenter
                        item: LauncherState.fromApp(favRow.modelData)
                        size: 22
                    }

                    Txt {
                        anchors.left: favIcon.right
                        anchors.leftMargin: ThemeManager.spacing.normal
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: favRow.modelData.name
                        elide: Text.ElideRight
                        font.pixelSize: ThemeManager.font.small + 1
                    }
                }
            }
        }

        Rectangle {
            x: side.x + side.width + root.pad / 2
            y: side.y
            width: Pixel.hairline(root.dpr)
            height: window.height - side.y - root.pad
            color: ThemeManager.colors.border
            opacity: 0.5
        }

        // Resultados
        GridView {
            id: grid

            readonly property int columns: Math.max(2, Math.floor(width / 140))

            x: side.x + side.width + root.pad
            y: side.y
            width: details.x - x - root.pad
            height: window.height - y - root.pad
            cellWidth: width / columns
            cellHeight: 128
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: LauncherState.items
            currentIndex: LauncherState.selected
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)

            delegate: Item {
                id: cell

                required property var modelData
                required property int index
                readonly property bool current: index === LauncherState.selected

                width: grid.cellWidth
                height: grid.cellHeight

                Clickable {
                    anchors.fill: parent
                    anchors.margins: 5
                    radius: ThemeManager.radius.normal
                    color: cell.current ? ThemeManager.alpha(ThemeManager.colors.accent, 0.14) : "transparent"
                    border.width: cell.current ? Pixel.hairline(root.dpr) : 0
                    border.color: ThemeManager.alpha(ThemeManager.colors.accent, 0.6)
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton) {
                            LauncherState.select(cell.index);
                            menu.openFor(cell.modelData, mapToItem(root, mouse.x, mouse.y));
                        } else if (cell.current) {
                            LauncherState.activate(cell.modelData);
                        } else {
                            LauncherState.select(cell.index);
                        }
                    }

                    ItemIcon {
                        id: tileIcon

                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 16
                        item: cell.modelData
                        size: 52
                        highlighted: cell.current
                    }

                    Txt {
                        anchors.top: tileIcon.bottom
                        anchors.topMargin: ThemeManager.spacing.small
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        horizontalAlignment: Text.AlignHCenter
                        text: cell.modelData.name
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        font.pixelSize: ThemeManager.font.small + 1
                        font.weight: cell.current ? Font.DemiBold : Font.Normal
                        color: cell.current ? ThemeManager.colors.accent : ThemeManager.colors.text
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                visible: LauncherState.items.length === 0
                spacing: ThemeManager.spacing.small

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    icon: LauncherState.searchingFiles && LauncherState.fileCategory ? "hourglass_top" : LauncherState.fileCategory && !LauncherState.query ? "history" : Icons.magnify
                    size: 36
                    color: ThemeManager.colors.textFaint
                }

                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: LauncherState.searchingFiles && LauncherState.fileCategory ? "Procurando…" : LauncherState.fileCategory && !LauncherState.query ? "Nenhum arquivo recente. Digite para buscar" : "Nada encontrado"
                    faint: true
                }
            }
        }

        DetailsPanel {
            id: details

            x: window.width - width - root.pad
            y: root.pad
            width: root.detailsWidth
            height: window.height - root.pad * 2
        }
    }

    ItemMenu {
        id: menu

        anchors.fill: parent
    }
}
