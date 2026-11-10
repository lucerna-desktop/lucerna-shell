import QtQuick
import qs.core.theme
import qs.core.widgets

// Área que espera um botão do mouse ou uma tecla. `mode`: "mouse" (o botão é
// apertado com o mouse em cima dela) ou "key" (a tecla, com ela focada).
// Esquerdo e direito do mouse não contam: seguem clicando normalmente.
Rectangle {
    id: root

    property string mode: "key"
    property string text: mode === "mouse" ? "Com o mouse aqui em cima, aperte o botão" : "Aperte a tecla ou a combinação"
    property string hint: ""

    signal button(int qtButton, int modifiers)
    signal key(int qtKey, int code, int modifiers)

    implicitHeight: ThemeManager.px(96)
    radius: ThemeManager.radius.normal
    color: ThemeManager.alpha(ThemeManager.colors.accent, area.containsMouse || keys.activeFocus ? 0.12 : 0.07)
    border.width: ThemeManager.px(2)
    border.color: ThemeManager.alpha(ThemeManager.colors.accent, 0.55)

    Component.onCompleted: {
        if (mode === "key")
            keys.forceActiveFocus();
    }

    // Pulsa enquanto espera.
    SequentialAnimation on opacity {
        loops: Animation.Infinite
        running: root.visible

        NumberAnimation { to: 0.75; duration: 900; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
    }

    Column {
        anchors.centerIn: parent
        width: parent.width - ThemeManager.spacing.large * 2
        spacing: ThemeManager.px(4)

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            icon: root.mode === "mouse" ? Icons.mouse : Icons.keyboard
            filled: true
            size: ThemeManager.px(26)
            color: ThemeManager.colors.accent
        }

        Txt {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: root.text
            font.weight: Font.DemiBold
        }

        Txt {
            width: parent.width
            visible: text !== ""
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: root.hint
            muted: true
            font.pixelSize: ThemeManager.font.small
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        onPressed: event => {
            if (root.mode === "mouse") {
                if (event.button === Qt.LeftButton || event.button === Qt.RightButton)
                    root.hint = "O esquerdo e o direito não podem ser mapeados; use o do meio ou os laterais";
                else
                    root.button(event.button, event.modifiers);
            } else {
                keys.forceActiveFocus();
            }
        }
    }

    Item {
        id: keys

        anchors.fill: parent
        focus: root.mode === "key"
        Keys.onPressed: event => {
            event.accepted = true;
            root.key(event.key, event.nativeScanCode, event.modifiers);
        }
    }
}
