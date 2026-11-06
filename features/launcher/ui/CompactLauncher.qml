pragma ComponentBehavior: Bound
import QtQuick
import qs.core.pixel
import qs.core.theme
import qs.core.widgets
import qs.features.launcher.state

// Estilo compacto: o campo de busca e uma lista curta de apps e ações, no alto
// da tela. Setas navegam, Enter abre, clique direito mostra as opções; "/"
// no começo busca arquivos e "?" pesquisa na web.
Item {
    id: root

    required property real progress

    function focusSearch(): void {
        search.focusInput();
    }

    Surface {
        id: box

        // No pixel físico (escala fracionária; ver Pixel).
        x: Pixel.snap((parent.width - width) / 2, Window.window?.devicePixelRatio ?? 1)
        y: Pixel.snap(parent.height * 0.22 + (1 - root.progress) * ThemeManager.px(16), Window.window?.devicePixelRatio ?? 1)
        width: ThemeManager.px(560)
        level: 0
        height: column.implicitHeight + ThemeManager.spacing.normal * 2

        Column {
            id: column

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: ThemeManager.spacing.normal
            }
            spacing: ThemeManager.spacing.small

            SearchField {
                id: search

                width: parent.width
                height: ThemeManager.px(44)
                placeholder: "Buscar apps e ações  ·  / arquivos  ·  ? web"
                onKey: event => {
                    if (LauncherState.handleShortcut(event)) {
                        event.accepted = true;
                        return;
                    }
                    const count = LauncherState.items.length;
                    if (!count && event.key !== Qt.Key_Return)
                        return;
                    if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab)
                        LauncherState.select((LauncherState.selected + 1) % count);
                    else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab)
                        LauncherState.select((LauncherState.selected - 1 + count) % count);
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                        LauncherState.activate(LauncherState.current);
                    else
                        return;
                    event.accepted = true;
                }
            }

            Item {
                width: parent.width
                height: results.implicitHeight
                visible: LauncherState.items.length > 0

                // Destaque único que desliza, com mola, até o item selecionado.
                Rectangle {
                    readonly property Item target: resultItems.count > 0 ? resultItems.itemAt(LauncherState.selected) : null

                    width: parent.width
                    height: target?.height ?? ThemeManager.px(48)
                    y: target?.y ?? 0
                    radius: ThemeManager.radius.normal
                    color: ThemeManager.alpha(ThemeManager.colors.accent, 0.14)

                    Behavior on y { Anim { type: Anim.FastSpatial } }
                }

                Column {
                    id: results

                    width: parent.width

                    Repeater {
                        id: resultItems

                        model: LauncherState.items

                        delegate: ResultItem {
                            required property var modelData
                            required property int index

                            width: column.width
                            result: modelData
                            order: index
                            selected: index === LauncherState.selected
                            onHoveredChanged: {
                                if (hovered)
                                    LauncherState.select(index);
                            }
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton)
                                    menu.openFor(modelData, mapToItem(root, mouse.x, mouse.y));
                                else
                                    LauncherState.activate(modelData);
                            }
                        }
                    }
                }
            }

            Txt {
                visible: LauncherState.items.length === 0
                width: parent.width
                height: ThemeManager.px(48)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: LauncherState.prefixMode === "files" && !LauncherState.searchText ? "Digite o nome do arquivo" : LauncherState.prefixMode === "files" && LauncherState.searchingFiles ? "Procurando…" : "Nada encontrado"
                faint: true
            }
        }
    }

    ItemMenu {
        id: menu

        anchors.fill: parent
    }
}
