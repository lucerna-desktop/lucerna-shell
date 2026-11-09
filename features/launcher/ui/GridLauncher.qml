pragma ComponentBehavior: Bound
import QtQuick
import qs.core.pixel
import qs.core.theme
import qs.core.widgets
import qs.features.launcher.state

// Estilo tela cheia: como uma gaveta de apps. Vidro sobre a tela inteira, a
// busca no alto, as categorias de apps (Internet, Desenvolvimento, Jogos…)
// em botões e uma grade grande. Bom para achar olhando, sem digitar. Setas
// andam, Tab troca de categoria, Enter abre.
Item {
    id: root

    required property real progress

    function focusSearch(): void {
        search.focusInput();
    }

    // Vidro na tela toda (o Hyprland desfoca o que está atrás).
    Rectangle {
        anchors.fill: parent
        color: ThemeManager.glass(ThemeManager.colors.base, 0)
        opacity: root.progress
    }

    Item {
        id: content

        anchors.fill: parent
        opacity: root.progress
        scale: 1.04 - 0.04 * root.progress

        SearchField {
            id: search

            // No pixel físico (escala fracionária; ver Pixel).
            x: Pixel.snap((parent.width - width) / 2, Window.window?.devicePixelRatio ?? 1)
            y: Pixel.snap(Math.max(ThemeManager.px(40), parent.height * 0.08), Window.window?.devicePixelRatio ?? 1)
            width: Math.min(ThemeManager.px(640), parent.width - ThemeManager.px(80))
            height: ThemeManager.px(52)
            placeholder: "Buscar apps e ações  ·  / arquivos  ·  ? web"
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
                else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)
                    root.cycleChip(event.key === Qt.Key_Tab ? 1 : -1);
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                    LauncherState.activate(LauncherState.current);
                else
                    return;
                event.accepted = true;
            }
        }

        // Categorias de apps (somem durante a busca, que olha todos).
        Row {
            id: chips

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: search.bottom
            anchors.topMargin: ThemeManager.spacing.large
            spacing: ThemeManager.spacing.small
            opacity: LauncherState.query.trim() ? 0.35 : 1

            Behavior on opacity { Anim { type: Anim.Effects } }

            Repeater {
                model: LauncherState.usedAppCategories

                delegate: Clickable {
                    id: chip

                    required property var modelData
                    readonly property bool current: LauncherState.appCategory === modelData.id

                    width: chipText.implicitWidth + ThemeManager.spacing.large * 2
                    height: ThemeManager.px(34)
                    radius: height / 2
                    color: current ? ThemeManager.colors.accentContainer : ThemeManager.alpha(ThemeManager.colors.text, 0.08)
                    onClicked: {
                        LauncherState.appCategory = chip.modelData.id;
                        search.focusInput();
                    }

                    Behavior on color { ColorAnim {} }

                    Txt {
                        id: chipText

                        anchors.centerIn: parent
                        text: chip.modelData.label
                        color: chip.current ? ThemeManager.colors.onAccentContainer : ThemeManager.colors.text
                        font.weight: chip.current ? Font.DemiBold : Font.Normal
                    }
                }
            }
        }

        GridView {
            id: grid

            readonly property real cell: ThemeManager.px(150)
            readonly property int columns: Math.max(3, Math.min(8, Math.floor(Math.min(parent.width - ThemeManager.px(160), ThemeManager.px(1300)) / cell)))

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: chips.bottom
            anchors.topMargin: ThemeManager.spacing.large * 1.5
            anchors.bottom: hint.top
            anchors.bottomMargin: ThemeManager.spacing.large
            width: columns * cell
            cellWidth: cell
            cellHeight: cell
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

                width: grid.cell
                height: grid.cell

                Clickable {
                    anchors.fill: parent
                    anchors.margins: ThemeManager.px(6)
                    radius: ThemeManager.radius.large
                    color: cell.current ? ThemeManager.alpha(ThemeManager.colors.accent, 0.16) : "transparent"
                    pressScale: 0.94
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton)
                            menu.openFor(cell.modelData, mapToItem(root, mouse.x, mouse.y));
                        else
                            LauncherState.activate(cell.modelData);
                    }
                    onHoveredChanged: {
                        if (hovered)
                            LauncherState.select(cell.index);
                    }

                    ItemIcon {
                        id: tileIcon

                        anchors.horizontalCenter: parent.horizontalCenter
                        y: ThemeManager.px(18)
                        item: cell.modelData
                        size: ThemeManager.px(64)
                        highlighted: cell.current
                        scale: cell.current ? 1.08 : 1

                        Behavior on scale { Anim { type: Anim.FastSpatial } }
                    }

                    Txt {
                        anchors.top: tileIcon.bottom
                        anchors.topMargin: ThemeManager.spacing.normal
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: ThemeManager.px(6)
                        anchors.rightMargin: ThemeManager.px(6)
                        horizontalAlignment: Text.AlignHCenter
                        text: cell.modelData.name
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        font.pixelSize: ThemeManager.font.normal
                        font.weight: cell.current ? Font.DemiBold : Font.Normal
                    }
                }
            }

            Txt {
                anchors.centerIn: parent
                visible: LauncherState.items.length === 0
                text: "Nada encontrado"
                faint: true
                font.pixelSize: ThemeManager.font.large
            }
        }

        Txt {
            id: hint

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: ThemeManager.spacing.large + ThemeManager.px(8)
            text: "Enter abre  ·  Tab troca a categoria  ·  Ctrl+F favorito  ·  Ctrl+H ocultar  ·  clique direito: opções  ·  Esc fecha"
            faint: true
            font.pixelSize: ThemeManager.font.small
        }
    }

    ItemMenu {
        id: menu

        anchors.fill: parent
    }

    function cycleChip(step: int): void {
        const list = LauncherState.usedAppCategories;
        const i = list.findIndex(c => c.id === LauncherState.appCategory);
        const n = list.length;
        LauncherState.appCategory = list[((i + step) % n + n) % n].id;
    }
}
