import QtQuick
import Quickshell
import qs.core.frame
import qs.core.theme
import qs.core.widgets
import qs.features.notifications.state

// Popups no canto superior direito do monitor com foco, dentro da janela da
// forma de cada tela (ver core/widgets/FrameWindow), em coordenadas da tela e
// abaixo dos painéis. Entram e saem deslizando pela direita; os de baixo se
// reacomodam com mola. Continuam cartões soltos (fora da forma), desfocados
// pela regra da janela da forma ("lucerna-panel-frame").
//
// A coluna vai até o pé da tela, mas só a área dos cartões recebe cliques (a
// área de entrada), e ela só existe enquanto há popups (mais o tempo da
// animação de saída do último), só na tela deles. O resumo do modo jogo é um
// cartão próprio no topo da pilha, que abre as notificações no clique.
Item {
    id: root

    required property var screen
    readonly property bool here: NotificationsState.screen === screen
    readonly property bool hasPopups: NotificationsState.popups.length > 0 || NotificationsState.summary !== null
    // Há popups, ou a saída do último ainda anima. Só cai no fim do `linger`
    // (nunca no meio da troca do `hasPopups`): a lista não pode perder o
    // modelo antes da saída.
    property bool live: false
    // Com a central aberta, os cartões esperam escondidos (o prazo não corre).
    readonly property bool shown: live && here && !NotificationsState.popupsHidden

    Component.onCompleted: live = hasPopups
    onHasPopupsChanged: {
        if (hasPopups)
            live = true;
        else
            linger.restart();
    }

    Timer {
        id: linger

        interval: 600
        onTriggered: root.live = root.hasPopups
    }

    anchors.fill: parent
    visible: shown

    // A área dos cartões, em coordenadas da tela: o contentItem da lista, do
    // começo do conteúdo (o resumo, que fica acima da origem, no `originY`)
    // até o fim.
    FrameInput {
        screen: root.screen
        active: root.shown
        rect: Qt.rect(list.x + list.contentItem.x, list.y + list.contentItem.y + list.originY, list.contentItem.width, list.contentHeight)
    }

    ListView {
        id: list

        // Fora da moldura: a espessura dela e o espaço de sempre, que deixam o
        // cartão fora do arco do canto (Frame.cornerClear), à mostra ou não.
        readonly property real margin: Frame.thickness + ThemeManager.spacing.small

        x: root.width - width - margin
        y: margin
        width: 380
        height: root.height - margin
        // Os cartões que saem pela direita somem na beira da coluna, como na
        // antiga janela dos popups.
        clip: true
        spacing: ThemeManager.spacing.small
        interactive: false

        // O cabeçalho fica dentro do contentItem: a máscara já o inclui.
        header: Item {
            width: ListView.view.width
            height: NotificationsState.summary ? summaryCard.height + ThemeManager.spacing.small : 0
            visible: NotificationsState.summary !== null

            Surface {
                id: summaryCard

                width: parent.width
                level: 0
                implicitHeight: summaryRow.implicitHeight + ThemeManager.spacing.normal * 2
                radius: ThemeManager.radius.normal
                border.color: ThemeManager.colors.border
                border.width: ThemeManager.outlines ? 1 : 0

                Clickable {
                    anchors.fill: parent
                    radius: parent.radius
                    onClicked: NotificationsState.openSummary()
                }

                Row {
                    id: summaryRow

                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        margins: ThemeManager.spacing.normal
                    }
                    spacing: ThemeManager.spacing.normal

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "sports_esports"
                        size: 22
                        color: ThemeManager.colors.accent
                    }

                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 22 - ThemeManager.spacing.normal
                        text: NotificationsState.summaryText
                        wrapMode: Text.Wrap
                    }
                }
            }
        }

        // Só na tela dos popups: nas outras, nenhum cartão.
        model: root.live && root.here ? popupsModel : []

        delegate: NotificationCard {
            required property var modelData

            width: ListView.view.width
            notification: modelData
            popup: true
            timeText: NotificationsState.timeLabel(modelData)
            timeout: NotificationsState.timeoutFor(modelData)
            // Com a central aberta os cartões somem, mas o prazo não corre.
            held: NotificationsState.popupsHidden
            onExpired: NotificationsState.hidePopup(modelData)
            onDismissRequested: NotificationsState.dismiss(modelData)
            onActionInvoked: action => NotificationsState.invoke(modelData, action)
        }

        add: Transition {
            ParallelAnimation {
                Anim { property: "x"; from: 64; to: 0; type: Anim.Spatial }
                Anim { property: "opacity"; from: 0; to: 1; type: Anim.Effects }
            }
        }

        remove: Transition {
            ParallelAnimation {
                Anim { property: "x"; to: 96; type: Anim.EmphasizedAccel }
                Anim { property: "opacity"; to: 0; type: Anim.EmphasizedAccel }
            }
        }

        displaced: Transition {
            Anim { properties: "x,y"; type: Anim.Spatial }
            Anim { property: "opacity"; to: 1; type: Anim.Effects }
        }
    }

    ScriptModel {
        id: popupsModel

        values: NotificationsState.popups
    }
}
