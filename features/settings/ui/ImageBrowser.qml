pragma ComponentBehavior: Bound

import QtQuick
import Qt.labs.folderlistmodel
import qs.core.theme
import qs.core.widgets
import qs.features.settings.state

// Escolher uma imagem do computador: lugares rápidos, a pasta atual (com
// subir) e as pastas e imagens dela em miniaturas.
Surface {
    id: root

    width: parent.width
    height: content.height + ThemeManager.spacing.large * 2
    color: ThemeManager.alpha(ThemeManager.colors.accent, 0.05)

    Column {
        id: content

        x: ThemeManager.spacing.large
        y: ThemeManager.spacing.large
        width: parent.width - x * 2
        spacing: ThemeManager.spacing.normal

        // Lugares
        Flow {
            width: parent.width
            spacing: ThemeManager.spacing.small

            Repeater {
                model: WallpaperSettings.places

                delegate: Clickable {
                    required property var modelData
                    readonly property bool current: WallpaperSettings.folder === modelData.path

                    width: place.implicitWidth + ThemeManager.spacing.large * 2
                    height: ThemeManager.px(32)
                    radius: height / 2
                    color: current ? ThemeManager.alpha(ThemeManager.colors.accent, 0.2) : ThemeManager.alpha(ThemeManager.colors.text, 0.06)
                    onClicked: WallpaperSettings.openFolder(modelData.path)

                    Txt {
                        id: place

                        anchors.centerIn: parent
                        text: parent.modelData.label
                        color: parent.current ? ThemeManager.colors.accent : ThemeManager.colors.text
                        font.pixelSize: ThemeManager.font.small + 1
                    }
                }
            }
        }

        // Pasta atual
        Row {
            width: parent.width
            spacing: ThemeManager.spacing.small

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "arrow_upward"
                iconSize: ThemeManager.px(18)
                enabled: WallpaperSettings.folder !== "/"
                onClicked: WallpaperSettings.up()
            }

            Txt {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - ThemeManager.px(80)
                text: WallpaperSettings.folder.replace(WallpaperSettings.home, "~")
                elide: Text.ElideMiddle
                muted: true
                font.family: ThemeManager.font.mono
                font.pixelSize: ThemeManager.font.small + 1
            }
        }

        GridView {
            id: grid

            readonly property int columns: Math.max(2, Math.floor(width / ThemeManager.px(150)))

            width: parent.width
            height: ThemeManager.px(330)
            clip: true
            cellWidth: width / columns
            cellHeight: cellWidth * 9 / 16 + ThemeManager.px(30)
            boundsBehavior: Flickable.StopAtBounds

            model: FolderListModel {
                id: files

                folder: `file://${WallpaperSettings.folder}`
                nameFilters: WallpaperSettings.imageFilters
                showDirsFirst: true
                showHidden: false
                sortField: FolderListModel.Name
            }

            delegate: Clickable {
                id: entry

                required property string fileName
                required property string filePath
                required property bool fileIsDir

                width: grid.cellWidth - ThemeManager.px(6)
                height: grid.cellHeight - ThemeManager.px(6)
                radius: ThemeManager.radius.small + ThemeManager.px(2)
                color: hovered ? ThemeManager.alpha(ThemeManager.colors.text, 0.08) : "transparent"
                onClicked: entry.fileIsDir ? WallpaperSettings.openFolder(entry.filePath) : WallpaperSettings.chooseImage(entry.filePath)

                Rectangle {
                    id: thumb

                    x: ThemeManager.px(4)
                    y: ThemeManager.px(4)
                    width: parent.width - ThemeManager.px(8)
                    height: width * 9 / 16
                    radius: ThemeManager.radius.small
                    color: ThemeManager.alpha(ThemeManager.colors.text, 0.05)
                    clip: true

                    Icon {
                        anchors.centerIn: parent
                        visible: entry.fileIsDir
                        icon: "folder"
                        filled: true
                        size: ThemeManager.px(34)
                        color: ThemeManager.colors.accent
                    }

                    Image {
                        anchors.fill: parent
                        visible: !entry.fileIsDir
                        source: entry.fileIsDir ? "" : `file://${entry.filePath}`
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(ThemeManager.px(240), ThemeManager.px(135))
                        asynchronous: true
                    }
                }

                Txt {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: thumb.bottom
                    anchors.margins: ThemeManager.px(6)
                    anchors.topMargin: ThemeManager.px(3)
                    horizontalAlignment: Text.AlignHCenter
                    text: entry.fileName
                    elide: Text.ElideMiddle
                    font.pixelSize: ThemeManager.font.small
                }
            }

            Txt {
                anchors.centerIn: parent
                visible: files.status === FolderListModel.Ready && files.count === 0
                text: "Nenhuma imagem nesta pasta"
                faint: true
            }
        }

        Row {
            anchors.right: parent.right

            TonalButton {
                text: "Cancelar"
                onClicked: WallpaperSettings.browsing = false
            }
        }
    }
}
