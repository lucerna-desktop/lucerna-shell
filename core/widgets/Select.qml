pragma ComponentBehavior: Bound

import QtQuick
import qs.core.pixel
import qs.core.theme

// Escolha numa lista longa (resoluções, taxas, layouts): um campo que mostra a
// opção atual e, ao clicar, abre a lista ali mesmo, empurrando o que vem
// abaixo. Com `searchable`, a lista abre com um campo de busca.
// options: [{ label, value, detail? }]
Item {
    id: root

    required property var options
    property var value
    property bool expanded: false
    // Linhas visíveis antes de a lista rolar.
    property int visibleRows: 6
    property bool searchable: false
    // Texto do campo quando nada está escolhido.
    property string placeholder: "—"

    signal selected(var value)

    readonly property int currentIndex: options.findIndex(o => o.value === value)
    readonly property real rowHeight: 36
    readonly property string query: search.text.trim().toLowerCase()
    readonly property var shown: query ? options.filter(o => `${o.label} ${o.detail ?? ""} ${o.value}`.toLowerCase().includes(query)) : options
    readonly property real searchHeight: searchable ? 40 + ThemeManager.spacing.small : 0
    readonly property real listHeight: Math.max(1, Math.min(shown.length, visibleRows)) * rowHeight

    implicitHeight: field.height + (expanded ? searchHeight + listHeight + ThemeManager.spacing.small : 0)

    onExpandedChanged: {
        search.text = "";
        if (expanded && searchable)
            search.forceActiveFocus();
    }
    clip: true

    Behavior on implicitHeight { Anim { type: Anim.FastSpatial } }

    Clickable {
        id: field

        width: parent.width
        height: 40
        radius: height / 2
        color: ThemeManager.alpha(ThemeManager.colors.text, 0.05)
        border.width: root.expanded ? 2 : ThemeManager.outlines ? Pixel.hairline(Window.window?.devicePixelRatio ?? 1) : 0
        border.color: root.expanded ? ThemeManager.colors.accent : ThemeManager.colors.border
        onClicked: root.expanded = !root.expanded

        Txt {
            anchors.left: parent.left
            anchors.leftMargin: ThemeManager.spacing.large
            anchors.right: chevron.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.options[root.currentIndex]?.label ?? root.placeholder
            color: root.currentIndex < 0 ? ThemeManager.colors.textMuted : ThemeManager.colors.text
            elide: Text.ElideRight
        }

        Icon {
            id: chevron

            anchors.right: parent.right
            anchors.rightMargin: ThemeManager.spacing.normal
            anchors.verticalCenter: parent.verticalCenter
            icon: Icons.expand
            size: 20
            color: ThemeManager.colors.textMuted
            rotation: root.expanded ? 180 : 0

            Behavior on rotation { Anim { type: Anim.FastSpatial } }
        }
    }

    Rectangle {
        y: field.height + ThemeManager.spacing.small
        visible: root.searchable
        width: parent.width
        height: 40
        radius: 20
        color: ThemeManager.alpha(ThemeManager.colors.text, 0.06)
        border.width: search.activeFocus ? 2 : 0
        border.color: ThemeManager.colors.accent

        Icon {
            id: searchIcon

            anchors.left: parent.left
            anchors.leftMargin: ThemeManager.spacing.normal + 2
            anchors.verticalCenter: parent.verticalCenter
            icon: Icons.magnify
            size: 18
            color: ThemeManager.colors.textMuted
        }

        TextInput {
            id: search

            anchors.left: searchIcon.right
            anchors.right: parent.right
            anchors.leftMargin: ThemeManager.spacing.small
            anchors.rightMargin: ThemeManager.spacing.normal
            anchors.verticalCenter: parent.verticalCenter
            color: ThemeManager.colors.text
            font.family: ThemeManager.font.sans
            font.variableAxes: ThemeManager.fontAxes(Font.Normal)
            font.pixelSize: ThemeManager.font.normal
            clip: true
            Keys.onEscapePressed: root.expanded = false
            onAccepted: {
                if (root.shown.length) {
                    root.expanded = false;
                    root.selected(root.shown[0].value);
                }
            }

            Txt {
                anchors.verticalCenter: parent.verticalCenter
                visible: !search.text
                text: "Buscar"
                faint: true
            }
        }
    }

    Flickable {
        id: list

        y: field.height + ThemeManager.spacing.small + root.searchHeight
        width: parent.width
        height: root.listHeight
        contentHeight: column.height
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        visible: root.expanded || root.implicitHeight > field.height + 1

        // Abre já mostrando a opção atual.
        onVisibleChanged: {
            if (visible)
                contentY = Math.max(0, Math.min(root.currentIndex * root.rowHeight - root.rowHeight * 2, contentHeight - height));
        }

        Column {
            id: column

            width: parent.width

            Repeater {
                model: root.shown

                delegate: Clickable {
                    id: option

                    required property var modelData
                    required property int index
                    readonly property bool current: modelData.value === root.value

                    width: column.width
                    height: root.rowHeight
                    radius: ThemeManager.radius.normal
                    color: current ? ThemeManager.alpha(ThemeManager.colors.accent, 0.14) : "transparent"
                    onClicked: {
                        root.expanded = false;
                        if (!current)
                            root.selected(modelData.value);
                    }

                    Txt {
                        anchors.left: parent.left
                        anchors.leftMargin: ThemeManager.spacing.large
                        anchors.right: parent.right
                        anchors.rightMargin: ThemeManager.spacing.large + 20
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: option.modelData.detail ? `${option.modelData.label}  ·  ${option.modelData.detail}` : option.modelData.label
                        color: option.current ? ThemeManager.colors.accent : ThemeManager.colors.text
                        font.weight: option.current ? Font.DemiBold : Font.Normal
                    }

                    Icon {
                        anchors.right: parent.right
                        anchors.rightMargin: ThemeManager.spacing.normal
                        anchors.verticalCenter: parent.verticalCenter
                        visible: option.current
                        icon: Icons.check
                        size: 18
                        color: ThemeManager.colors.accent
                    }
                }
            }
        }
    }
}
