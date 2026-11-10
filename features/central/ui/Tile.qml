import QtQuick
import qs.core.pixel
import qs.core.theme
import qs.core.widgets

// Tile do painel de ações: o ícone num círculo, o título e a linha de estado;
// com `page`, a setinha à direita, separada por um traço fino. Ligado
// (`checked`), no tom de contêiner do destaque, com o texto dele e o ícone na
// cor de destaque; desligado, o fundo neutro elevado.
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

    readonly property color foreground: checked ? ThemeManager.colors.onAccentContainer : ThemeManager.colors.text

    active: checked
    // Sobre a setinha, só o véu dela.
    hoverVeil: !more.hovered
    enabled: clickable
    opacity: 1
    height: ThemeManager.px(60)
    radius: ThemeManager.radius.normal
    pressScale: 0.97
    color: checked ? ThemeManager.colors.accentContainer : ThemeManager.glass(ThemeManager.colors.raised, 1)

    Rectangle {
        id: circle

        x: ThemeManager.spacing.small + ThemeManager.px(2)
        anchors.verticalCenter: parent.verticalCenter
        width: ThemeManager.px(38)
        height: ThemeManager.px(38)
        radius: width / 2
        // Ligado, um toque do base (como o véu do hover): só afasta o fundo do
        // ícone. O teste garante o ícone a 3:1 desse círculo (o contêiner com
        // o base a 10% por cima), não só do contêiner.
        color: root.checked ? ThemeManager.alpha(ThemeManager.colors.base, 0.1) : ThemeManager.alpha(ThemeManager.colors.text, 0.07)

        Behavior on color { ColorAnim {} }

        Icon {
            anchors.centerIn: parent
            icon: root.icon
            size: ThemeManager.px(20)
            filled: root.checked
            color: root.alert ? ThemeManager.colors.danger : root.checked ? ThemeManager.colors.accentIcon : ThemeManager.colors.textMuted

            Behavior on color { ColorAnim {} }
        }
    }

    Column {
        anchors.left: circle.right
        anchors.leftMargin: ThemeManager.spacing.small + ThemeManager.px(2)
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
            // Sobre o contêiner, o texto cheio: com opacidade, cairia abaixo
            // de 4,5:1 (o contêiner já fica no limite).
            color: root.checked ? ThemeManager.colors.onAccentContainer : ThemeManager.colors.textMuted
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
        anchors.rightMargin: ThemeManager.px(2)
        anchors.verticalCenter: parent.verticalCenter
        visible: root.hasPage
        width: ThemeManager.px(34)
        height: parent.height - ThemeManager.px(4)
        radius: root.radius - ThemeManager.px(2)
        active: root.checked
        color: "transparent"
        onClicked: root.pageClicked()

        Icon {
            anchors.centerIn: parent
            icon: Icons.chevronRight
            size: ThemeManager.px(20)
            color: root.checked ? ThemeManager.colors.onAccentContainer : ThemeManager.colors.textMuted
        }
    }
}
