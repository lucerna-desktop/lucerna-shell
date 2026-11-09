pragma ComponentBehavior: Bound
import QtQuick
import qs.core.pixel
import qs.core.theme
import qs.core.widgets
import qs.features.launcher.state

// Detalhes do item selecionado (estilo completo): ícone, nome, Abrir, as ações
// do app (do .desktop, com Ctrl+1…9), descrição, versão e desenvolvedor; num
// arquivo, a prévia, a pasta, o tamanho e a data. "Mais opções" guarda o resto.
Surface {
    id: root

    readonly property var item: LauncherState.current
    readonly property bool isApp: item?.kind === "app"
    readonly property bool isFile: item?.kind === "file"
    readonly property var info: isApp ? LauncherState.appInfo(item.id) : null
    readonly property var actions: isApp ? (item.entry.actions ?? []) : []
    property bool moreOpen: false

    onItemChanged: moreOpen = false

    function formatSize(bytes: real): string {
        const units = ["B", "KB", "MB", "GB", "TB"];
        let v = bytes;
        let i = 0;
        while (v >= 1024 && i < units.length - 1) {
            v /= 1024;
            i++;
        }
        return `${i ? v.toFixed(v < 10 ? 1 : 0).replace(".", ",") : v} ${units[i]}`;
    }

    function host(url: string): string {
        return (url ?? "").replace(/^https?:\/\//, "").replace(/\/.*$/, "");
    }

    level: 1
    radius: ThemeManager.radius.large

    Txt {
        anchors.centerIn: parent
        visible: !root.item
        text: "Nada selecionado"
        faint: true
    }

    Flickable {
        id: scroll

        visible: root.item !== null
        anchors.fill: parent
        anchors.margins: ThemeManager.spacing.large
        contentHeight: content.height
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: content

            width: scroll.width
            spacing: ThemeManager.spacing.large

            // Prévia grande de imagem
            Rectangle {
                visible: root.isFile && root.item?.type === "image"
                width: parent.width
                height: visible ? width * 0.62 : 0
                radius: ThemeManager.radius.normal
                color: ThemeManager.alpha(ThemeManager.colors.text, 0.05)
                clip: true

                Image {
                    anchors.fill: parent
                    source: parent.visible ? `file://${root.item.path}` : ""
                    sourceSize: Qt.size(ThemeManager.px(560), ThemeManager.px(360))
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }
            }

            // Cabeçalho
            Row {
                width: parent.width
                spacing: ThemeManager.spacing.normal

                ItemIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    item: root.item
                    size: ThemeManager.px(56)
                    highlighted: true
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - ThemeManager.px(56) - parent.spacing
                    spacing: ThemeManager.px(2)

                    Txt {
                        width: parent.width
                        text: root.item?.name ?? ""
                        font.pixelSize: ThemeManager.font.large + ThemeManager.px(2)
                        font.weight: Font.DemiBold
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }

                    Txt {
                        width: parent.width
                        visible: text !== ""
                        text: root.item?.description ?? ""
                        muted: true
                        font.pixelSize: ThemeManager.font.small + 1
                        elide: Text.ElideMiddle
                    }
                }
            }

            // Abrir
            Clickable {
                width: parent.width
                height: ThemeManager.px(44)
                radius: ThemeManager.radius.normal
                // O tom de contêiner, com o texto dele e o ícone no destaque.
                color: ThemeManager.colors.accentContainer
                pressScale: 0.97
                opacity: root.item?.kind === "web" && !LauncherState.searchText ? 0.45 : 1
                onClicked: LauncherState.activate(root.item)

                Txt {
                    anchors.centerIn: parent
                    text: root.item?.kind === "web" ? "Pesquisar" : "Abrir"
                    color: ThemeManager.colors.onAccentContainer
                    font.weight: Font.DemiBold
                }

                Icon {
                    anchors.right: parent.right
                    anchors.rightMargin: ThemeManager.spacing.normal
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "keyboard_return"
                    size: ThemeManager.px(18)
                    color: ThemeManager.colors.accent
                }
            }

            // Ações do app (do .desktop)
            Column {
                visible: root.actions.length > 0
                width: parent.width

                Repeater {
                    model: root.actions

                    delegate: Clickable {
                        id: actionRow

                        required property var modelData
                        required property int index

                        width: parent.width
                        height: ThemeManager.px(38)
                        radius: ThemeManager.radius.small + ThemeManager.px(2)
                        onClicked: LauncherState.runAction(root.item, actionRow.index)

                        Icon {
                            id: actionIcon

                            anchors.left: parent.left
                            anchors.leftMargin: ThemeManager.spacing.small
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "open_in_new"
                            size: ThemeManager.px(18)
                            color: ThemeManager.colors.textMuted
                        }

                        Txt {
                            anchors.left: actionIcon.right
                            anchors.leftMargin: ThemeManager.spacing.normal
                            anchors.right: shortcut.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: actionRow.modelData.name
                            elide: Text.ElideRight
                        }

                        Txt {
                            id: shortcut

                            anchors.right: parent.right
                            anchors.rightMargin: ThemeManager.spacing.small
                            anchors.verticalCenter: parent.verticalCenter
                            visible: actionRow.index < 9
                            text: `Ctrl+${actionRow.index + 1}`
                            faint: true
                            font.pixelSize: ThemeManager.font.small
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: Pixel.hairline(Window.window?.devicePixelRatio ?? 1)
                color: ThemeManager.colors.border
                opacity: 0.6
            }

            // Informações
            Repeater {
                model: {
                    const i = root.item;
                    if (!i)
                        return [];
                    if (i.kind === "app") {
                        const info = root.info ?? {};
                        return [
                            { label: "Descrição", value: i.entry.comment || info.summary || "" },
                            { label: "Versão", value: info.version ?? "" },
                            { label: "Desenvolvedor", value: info.developer || root.host(info.url) }
                        ].filter(r => r.value);
                    }
                    if (i.kind === "file")
                        return [
                            { label: "Pasta", value: i.description },
                            { label: "Tamanho", value: root.formatSize(i.size) },
                            { label: "Modificado", value: Qt.formatDateTime(new Date(i.modified * 1000), "dd/MM/yyyy 'às' HH:mm") }
                        ];
                    if (i.kind === "web")
                        return [{ label: "Buscador", value: i.name }];
                    return [{ label: "Tipo", value: i.description }];
                }

                delegate: Column {
                    id: infoRow

                    required property var modelData

                    width: content.width
                    spacing: ThemeManager.px(3)

                    Txt {
                        text: infoRow.modelData.label
                        font.weight: Font.DemiBold
                        font.pixelSize: ThemeManager.font.small + 1
                    }

                    Txt {
                        width: parent.width
                        text: infoRow.modelData.value
                        muted: true
                        wrapMode: Text.Wrap
                        font.pixelSize: ThemeManager.font.small + 1
                    }
                }
            }

            // Mais opções
            Column {
                visible: root.isApp || root.isFile
                width: parent.width

                Rectangle {
                    width: parent.width
                    height: Pixel.hairline(Window.window?.devicePixelRatio ?? 1)
                    color: ThemeManager.colors.border
                    opacity: 0.6
                }

                Clickable {
                    width: parent.width
                    height: ThemeManager.px(42)
                    radius: ThemeManager.radius.small + ThemeManager.px(2)
                    onClicked: root.moreOpen = !root.moreOpen

                    Icon {
                        id: moreIcon

                        anchors.left: parent.left
                        anchors.leftMargin: ThemeManager.spacing.small
                        anchors.verticalCenter: parent.verticalCenter
                        icon: Icons.settings
                        size: ThemeManager.px(18)
                        color: ThemeManager.colors.textMuted
                    }

                    Txt {
                        anchors.left: moreIcon.right
                        anchors.leftMargin: ThemeManager.spacing.normal
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Mais opções"
                    }

                    Icon {
                        anchors.right: parent.right
                        anchors.rightMargin: ThemeManager.spacing.small
                        anchors.verticalCenter: parent.verticalCenter
                        icon: Icons.expand
                        size: ThemeManager.px(20)
                        rotation: root.moreOpen ? 180 : -90
                        color: ThemeManager.colors.textMuted

                        Behavior on rotation { Anim { type: Anim.FastSpatial } }
                    }
                }

                Repeater {
                    model: root.moreOpen ? LauncherState.optionsFor(root.item) : []

                    delegate: Clickable {
                        id: optRow

                        required property var modelData

                        width: parent.width
                        height: ThemeManager.px(38)
                        radius: ThemeManager.radius.small + ThemeManager.px(2)
                        onClicked: optRow.modelData.run()

                        Icon {
                            id: optIcon

                            anchors.left: parent.left
                            anchors.leftMargin: ThemeManager.spacing.large
                            anchors.verticalCenter: parent.verticalCenter
                            icon: optRow.modelData.icon
                            size: ThemeManager.px(18)
                            color: ThemeManager.colors.accent
                        }

                        Txt {
                            anchors.left: optIcon.right
                            anchors.leftMargin: ThemeManager.spacing.normal
                            anchors.verticalCenter: parent.verticalCenter
                            text: optRow.modelData.label
                        }
                    }
                }
            }
        }
    }
}
