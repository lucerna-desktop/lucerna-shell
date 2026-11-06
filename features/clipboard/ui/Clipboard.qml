pragma ComponentBehavior: Bound

import QtQuick
import qs.core.theme
import qs.core.widgets
import qs.features.clipboard.state

// Painel do histórico da área de transferência (Super+V). Setas escolhem,
// Enter cola, Ctrl+P fixa, Shift+Del apaga, Tab troca o filtro; Esc ou clique
// fora fecham.
OverlayPanel {
    id: panel

    name: "clipboard"
    open: ClipboardState.open
    screen: ClipboardState.screen
    onDismissed: ClipboardState.close()

    onOpenChanged: {
        if (open)
            Qt.callLater(() => search.focusInput());
    }

    Surface {
        id: window

        level: 0
        x: panel.snap((parent.width - width) / 2)
        y: panel.snap((parent.height - height) / 2 + (1 - panel.progress) * ThemeManager.px(24))
        width: Math.min(ThemeManager.px(640), parent.width - ThemeManager.px(80))
        height: Math.min(ThemeManager.px(700), parent.height - ThemeManager.px(140))
        radius: ThemeManager.radius.large + ThemeManager.px(4)

        readonly property real pad: ThemeManager.spacing.large

        Item {
            id: header

            x: window.pad
            y: window.pad
            width: window.width - window.pad * 2
            height: ThemeManager.px(32)

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: ThemeManager.spacing.small

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "content_paste"
                    filled: true
                    color: ThemeManager.colors.accent
                }

                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Área de transferência"
                    font.pixelSize: ThemeManager.font.large
                    font.weight: Font.DemiBold
                }

                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: ClipboardState.count > 0
                    text: `${ClipboardState.count}`
                    faint: true
                }
            }

            IconButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                icon: Icons.settings
                iconSize: ThemeManager.px(18)
                onClicked: ClipboardState.openSettings()
            }
        }

        SearchBox {
            id: search

            x: window.pad
            y: header.y + header.height + ThemeManager.spacing.normal
            width: window.width - window.pad * 2
            placeholder: "Buscar no histórico"
            text: ClipboardState.query
            onEdited: t => ClipboardState.query = t
            onKey: event => {
                const ctrl = event.modifiers & Qt.ControlModifier;
                if (event.key === Qt.Key_Down)
                    ClipboardState.move(1);
                else if (event.key === Qt.Key_Up)
                    ClipboardState.move(-1);
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                    ClipboardState.activate(ClipboardState.current);
                else if (ctrl && event.key === Qt.Key_P)
                    ClipboardState.togglePin(ClipboardState.current);
                else if ((event.modifiers & Qt.ShiftModifier) && event.key === Qt.Key_Delete)
                    ClipboardState.remove(ClipboardState.current);
                else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                    const f = ClipboardState.filters;
                    const i = f.findIndex(o => o.value === ClipboardState.filter);
                    ClipboardState.filter = f[(i + (event.key === Qt.Key_Tab ? 1 : f.length - 1)) % f.length].value;
                } else
                    return;
                event.accepted = true;
            }
        }

        SegmentedControl {
            id: filters

            x: window.pad
            y: search.y + search.height + ThemeManager.spacing.normal
            width: window.width - window.pad * 2
            options: ClipboardState.filters
            value: ClipboardState.filter
            onSelected: v => {
                ClipboardState.filter = v;
                search.focusInput();
            }
        }

        ListView {
            id: list

            x: window.pad - ThemeManager.spacing.small
            y: filters.y + filters.height + ThemeManager.spacing.normal
            width: window.width - (window.pad - ThemeManager.spacing.small) * 2
            height: hintBar.y - y - ThemeManager.spacing.small
            clip: true
            spacing: ThemeManager.px(2)
            boundsBehavior: Flickable.StopAtBounds
            model: ClipboardState.items
            currentIndex: ClipboardState.selected
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
            onAtYEndChanged: {
                if (atYEnd)
                    ClipboardState.more();
            }

            delegate: ClipboardItem {
                required property var modelData
                required property int index

                width: list.width
                entry: modelData
                current: index === ClipboardState.selected
                onChosen: ClipboardState.activate(modelData)
                onHoveredIn: ClipboardState.select(index)
            }

            EmptyState {
                anchors.centerIn: parent
                width: parent.width - ThemeManager.px(60)
                visible: ClipboardState.items.length === 0 && ClipboardState.emptyKind === "unavailable"
                icon: "content_paste_off"
                text: ClipboardState.unavailableText
            }

            Column {
                anchors.centerIn: parent
                width: parent.width - ThemeManager.px(60)
                visible: ClipboardState.items.length === 0 && ClipboardState.emptyKind !== "unavailable"
                spacing: ThemeManager.spacing.small

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    icon: !ClipboardState.enabled ? "content_paste_off" : ClipboardState.query ? Icons.magnify : "content_paste"
                    size: ThemeManager.px(36)
                    color: ThemeManager.colors.textFaint
                }

                Txt {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    faint: true
                    text: !ClipboardState.enabled ? "O histórico está desligado nas configurações"
                        : ClipboardState.query || ClipboardState.filter !== "all" ? "Nada encontrado"
                        : "Nada copiado ainda. O que você copiar aparece aqui"
                }
            }
        }

        Item {
            id: hintBar

            x: window.pad
            y: window.height - height - window.pad
            width: window.width - window.pad * 2
            height: ThemeManager.px(36)

            Txt {
                anchors.left: parent.left
                anchors.right: clear.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Enter cola · Ctrl+P fixa · Shift+Del apaga · Tab filtra"
                faint: true
                elide: Text.ElideRight
                font.pixelSize: ThemeManager.font.small
            }

            TonalButton {
                id: clear

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                enabled: ClipboardState.clearable
                icon: "delete_sweep"
                text: "Limpar"
                onClicked: {
                    ClipboardState.clear();
                    search.focusInput();
                }
            }
        }
    }
}
