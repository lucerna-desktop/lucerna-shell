import QtQuick
import qs.core.pixel
import qs.core.theme

// Campo de busca: lupa, texto e um botão de limpar. Controlado: emite
// `edited` e quem usa decide `text`. As teclas que não são de digitar (setas,
// Enter, Tab…) vão para `key`.
Rectangle {
    id: root

    property string text: ""
    property string placeholder: "Buscar"
    property int textSize: ThemeManager.font.large

    signal edited(string text)
    signal key(var event)

    function focusInput(): void {
        input.forceActiveFocus();
    }

    implicitHeight: ThemeManager.px(48)
    radius: ThemeManager.radius.normal
    color: ThemeManager.colors.raised
    border.width: input.activeFocus ? Pixel.hairline(Window.window?.devicePixelRatio ?? 1) : 0
    border.color: ThemeManager.alpha(ThemeManager.colors.accent, 0.5)

    Icon {
        id: searchIcon

        anchors.left: parent.left
        anchors.leftMargin: ThemeManager.spacing.normal + ThemeManager.px(2)
        anchors.verticalCenter: parent.verticalCenter
        icon: Icons.magnify
        size: ThemeManager.px(22)
        color: ThemeManager.colors.accent
    }

    TextInput {
        id: input

        anchors {
            left: searchIcon.right
            right: clear.left
            leftMargin: ThemeManager.spacing.normal
            rightMargin: ThemeManager.spacing.small
            verticalCenter: parent.verticalCenter
        }
        text: root.text
        color: ThemeManager.colors.text
        selectionColor: ThemeManager.alpha(ThemeManager.colors.accent, 0.35)
        selectedTextColor: ThemeManager.colors.text
        font.family: ThemeManager.font.sans
        font.variableAxes: ThemeManager.fontAxes(Font.Normal)
        font.pixelSize: root.textSize
        clip: true
        focus: true
        onTextEdited: root.edited(text)
        Keys.onPressed: event => root.key(event)

        Txt {
            anchors.verticalCenter: parent.verticalCenter
            visible: !input.text
            text: root.placeholder
            faint: true
            font.pixelSize: root.textSize
        }
    }

    IconButton {
        id: clear

        anchors.right: parent.right
        anchors.rightMargin: ThemeManager.spacing.small
        anchors.verticalCenter: parent.verticalCenter
        visible: input.text !== ""
        icon: "cancel"
        iconSize: ThemeManager.px(18)
        onClicked: {
            root.edited("");
            input.forceActiveFocus();
        }
    }
}
