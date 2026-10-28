pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Servidor de notificações do shell (org.freedesktop.Notifications).
// `list` guarda tudo o que ainda não foi dispensado; `popups` é o que está
// aparecendo na tela agora.
Singleton {
    id: root

    // Tipado como ObjectModel: pelo tipo do server.trackedNotifications, o qmllint 6.12 não acha o `values`.
    // Interna: existe só para o tipo que o qmllint pede; os consumidores usam a lista abaixo.
    readonly property ObjectModel trackedModel: server.trackedNotifications
    readonly property var list: trackedModel.values.slice().reverse()
    readonly property int count: list.length
    property var popups: []
    property bool doNotDisturb: false
    // Horário de chegada (ms) por id. Persiste entre recarregamentos, como as
    // próprias notificações; guardado como JSON porque objetos JS não passam de
    // uma geração para outra.
    property var receivedAt: ({})

    // Tempo dos popups sem prazo definido pelo app, em ms (ajustável).
    property int defaultTimeout: 5000

    function hidePopup(notification: var): void {
        popups = popups.filter(n => n !== notification);
    }

    function clearPopups(): void {
        popups = [];
    }

    function dismiss(notification: var): void {
        notification.dismiss();
    }

    function clearAll(): void {
        for (const n of trackedModel.values.slice())
            n.dismiss();
    }

    // Se uma notificação que chega vira popup: sempre, menos com o não
    // perturbe (do usuário ou do modo jogo); a crítica aparece mesmo assim.
    function popsUp(notification: var): bool {
        return !doNotDisturb || notification.urgency === NotificationUrgency.Critical;
    }

    // Milissegundos que o popup fica na tela; 0 = até o usuário fechar.
    function timeoutFor(notification: var): int {
        if (notification.urgency === NotificationUrgency.Critical)
            return 0;
        return notification.expireTimeout > 0 ? notification.expireTimeout : defaultTimeout;
    }

    function timeOf(notification: var): var {
        return new Date(receivedAt[notification.id] ?? Date.now());
    }

    PersistentProperties {
        id: persist

        reloadableId: "notifications"

        property string receivedAt: "{}"

        onLoaded: {
            try {
                root.receivedAt = JSON.parse(receivedAt);
            } catch (e) {
                root.receivedAt = {};
            }
        }
    }

    NotificationServer {
        id: server

        keepOnReload: true
        persistenceSupported: true
        actionsSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: true

        onNotification: notification => {
            notification.tracked = true;
            notification.closed.connect(() => root.hidePopup(notification));
            // Reemitida depois de um reload: já foi vista, só volta para a lista.
            if (notification.lastGeneration)
                return;
            root.receivedAt[notification.id] = Date.now();
            persist.receivedAt = JSON.stringify(root.receivedAt);
            if (root.popsUp(notification))
                root.popups = [notification, ...root.popups.filter(n => n.id !== notification.id)];
        }
    }
}
