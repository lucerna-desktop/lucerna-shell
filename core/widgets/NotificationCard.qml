pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import qs.core.pixel
import qs.core.theme

// Cartão de uma notificação, usado nos popups e na central. Em modo popup,
// uma linha de acento mostra o tempo restante (pausa com o mouse em cima e
// enquanto `held`, com o popup escondido).
Surface {
    id: card

    // A notificação pode ser destruída enquanto o cartão ainda anima a saída;
    // por isso todo acesso a ela tolera null.
    required property var notification
    property bool popup: false
    // Quem usa informa o texto do horário e o prazo (0 = sem contagem) e reage
    // aos sinais; o cartão não conhece estado nenhum.
    property string timeText: ""
    property int timeout: 0
    // Segura o prazo: o popup está escondido (a central aberta) e não conta.
    property bool held: false
    // O prazo correndo agora.
    readonly property bool counting: countdown.running && !countdown.paused
    readonly property bool critical: notification?.urgency === NotificationUrgency.Critical
    readonly property string image: {
        if (!notification)
            return "";
        if (notification.image)
            return notification.image;
        const icon = notification.appIcon;
        if (!icon)
            return "";
        if (icon.startsWith("/"))
            return `file://${icon}`;
        return icon.includes("://") ? icon : Quickshell.iconPath(icon, true);
    }

    signal dismissRequested
    signal actionInvoked(var action)

    signal expired

    raisedLevel: !popup
    level: popup ? 0 : 1
    radius: ThemeManager.radius.normal
    border.color: critical ? ThemeManager.colors.danger : ThemeManager.colors.border
    border.width: critical ? ThemeManager.px(2) : ThemeManager.outlines ? Pixel.hairline(Window.window?.devicePixelRatio ?? 1) : 0
    implicitHeight: layout.implicitHeight + ThemeManager.spacing.normal * 2
    clip: true

    HoverHandler {
        id: hover
    }

    NumberAnimation on remaining {
        id: countdown

        running: card.timeout > 0
        paused: running && (hover.hovered || card.held)
        from: 1
        to: 0
        duration: card.timeout
        onFinished: card.expired()
    }

    property real remaining: 1

    RowLayout {
        id: layout

        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: ThemeManager.spacing.normal
        }
        spacing: ThemeManager.spacing.normal

        ClippingRectangle {
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: ThemeManager.px(40)
            Layout.preferredHeight: ThemeManager.px(40)
            visible: card.image !== ""
            radius: ThemeManager.radius.small
            color: "transparent"

            Image {
                anchors.fill: parent
                source: card.image
                sourceSize: Qt.size(ThemeManager.px(80), ThemeManager.px(80))
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: ThemeManager.px(2)

            RowLayout {
                Layout.fillWidth: true
                spacing: ThemeManager.spacing.small

                Txt {
                    Layout.fillWidth: true
                    text: card.notification?.appName || "Notificação"
                    faint: true
                    font.pixelSize: ThemeManager.font.small
                }

                Txt {
                    text: card.timeText
                    faint: true
                    font.pixelSize: ThemeManager.font.small
                }

                IconButton {
                    icon: Icons.close
                    iconSize: ThemeManager.px(13)
                    implicitWidth: ThemeManager.px(20)
                    implicitHeight: ThemeManager.px(20)
                    foreground: ThemeManager.colors.textMuted
                    onClicked: card.dismissRequested()
                }
            }

            Txt {
                Layout.fillWidth: true
                text: card.notification?.summary ?? ""
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
                maximumLineCount: 2
            }

            Txt {
                Layout.fillWidth: true
                visible: text !== ""
                text: card.notification?.body ?? ""
                textFormat: Text.StyledText
                muted: true
                wrapMode: Text.Wrap
                maximumLineCount: card.popup ? 4 : 8
                linkColor: ThemeManager.colors.accent
                onLinkActivated: link => Qt.openUrlExternally(link)
            }

            Flow {
                Layout.fillWidth: true
                Layout.topMargin: ThemeManager.spacing.tiny
                visible: (card.notification?.actions.length ?? 0) > 0
                spacing: ThemeManager.spacing.tiny

                Repeater {
                    model: card.notification?.actions ?? []

                    delegate: Clickable {
                        id: action

                        required property var modelData

                        implicitWidth: actionLabel.implicitWidth + ThemeManager.spacing.normal * 2
                        implicitHeight: ThemeManager.px(28)
                        radius: height / 2
                        color: ThemeManager.alpha(ThemeManager.colors.accent, 0.14)
                        onClicked: card.actionInvoked(modelData)

                        Txt {
                            id: actionLabel

                            anchors.centerIn: parent
                            text: action.modelData.text
                            font.pixelSize: ThemeManager.font.small
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        visible: card.timeout > 0
        anchors.bottom: parent.bottom
        x: card.radius
        width: (parent.width - card.radius * 2) * card.remaining
        height: ThemeManager.px(2)
        radius: height / 2
        color: card.critical ? ThemeManager.colors.danger : ThemeManager.colors.accent
        opacity: 0.8
    }
}
