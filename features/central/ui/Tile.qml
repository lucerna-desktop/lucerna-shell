import QtQuick
import qs.core.pixel
import qs.core.theme
import qs.core.widgets

// Tile do painel de ações: o ícone num círculo, o título e a linha de estado;
// com `page`, a setinha à direita, separada por um traço fino. Ligado
// (`checked`), cheio na cor de destaque; desligado, o fundo neutro elevado.
// `alert` pinta o ícone na cor de erro (a bateria baixa). Emite `clicked` no
// corpo e `pageClicked` na setinha; sem `clickable`, só informa.
Clickable {
    id: root

    property string icon
    property string title
    property string status
    property bool checked: false
    property bool hasPage: false
    property bool alert: false
    property bool clickable: true

    signal pageClicked

    readonly property color foreground: checked ? ThemeManager.colors.accentText : ThemeManager.colors.text

    active: checked
    // Sobre a setinha, só o véu dela.
    hoverVeil: !more.hovered
    enabled: clickable
    opacity: 1
    height: 60
    radius: ThemeManager.radius.normal
    pressScale: 0.97
    color: checked ? ThemeManager.colors.accent : ThemeManager.glass(ThemeManager.colors.raised, 1)

    Rectangle {
        id: circle

        x: ThemeManager.spacing.small + 2
        anchors.verticalCenter: parent.verticalCenter
        width: 38
        height: 38
        radius: 19
        color: root.checked ? ThemeManager.alpha(ThemeManager.colors.accentText, 0.14) : ThemeManager.alpha(ThemeManager.colors.text, 0.07)

        Behavior on color { ColorAnim {} }

        Icon {
            anchors.centerIn: parent
            icon: root.icon
            size: 20
            filled: root.checked
            color: root.alert ? ThemeManager.colors.danger : root.checked ? ThemeManager.colors.accentText : ThemeManager.colors.textMuted

            Behavior on color { ColorAnim {} }
        }
    }

    Column {
        anchors.left: circle.right
        anchors.leftMargin: ThemeManager.spacing.small + 2
        anchors.right: root.hasPage ? divider.left : parent.right
        anchors.rightMargin: ThemeManager.spacing.small
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Txt {
            width: parent.width
            text: root.title
            color: root.foreground
            font.weight: Font.DemiBold
        }

        Txt {
            width: parent.width
            text: root.status
            color: root.checked ? ThemeManager.alpha(ThemeManager.colors.accentText, 0.75) : ThemeManager.colors.textMuted
            font.pixelSize: ThemeManager.font.small
        }
    }

    Rectangle {
        id: divider

        anchors.right: more.left
        anchors.verticalCenter: parent.verticalCenter
        visible: root.hasPage
        width: Pixel.hairline(Window.window?.devicePixelRatio ?? 1)
        height: parent.height * 0.5
        color: ThemeManager.alpha(root.foreground, 0.18)
    }

    Clickable {
        id: more

        anchors.right: parent.right
        anchors.rightMargin: 2
        anchors.verticalCenter: parent.verticalCenter
        visible: root.hasPage
        width: 34
        height: parent.height - 4
        radius: root.radius - 2
        active: root.checked
        color: "transparent"
        onClicked: root.pageClicked()

        Icon {
            anchors.centerIn: parent
            icon: Icons.chevronRight
            size: 20
            color: root.checked ? ThemeManager.colors.accentText : ThemeManager.colors.textMuted
        }
    }
}
