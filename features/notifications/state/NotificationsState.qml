pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.core.config
import qs.core.format
import qs.core.panels
import qs.services

// View model das notificações: os popups (a lista fica na central) e o IPC.
Singleton {
    id: root

    // Os popups ficam no canto das Ações: com qualquer um dos dois painéis da
    // central aberto, esperam escondidos (ficariam por cima deles).
    readonly property bool popupsHidden: Panels.isOpen("central")
    // As Notificações mostram a lista: abri-las e fechá-las contam como ter
    // visto os popups. Com só as Ações, o que chega fica para depois.
    readonly property bool listOpen: Panels.notificationsOpen

    onListOpenChanged: {
        Notifications.clearPopups();
        dismissSummary();
    }

    // O que chega com as Notificações abertas já está na lista: sai na hora,
    // sem sobrar popup para piscar quando elas fecham.
    Connections {
        target: Notifications

        function onPopupsChanged(): void {
            if (root.listOpen && Notifications.popups.length > 0)
                Notifications.clearPopups();
        }
    }
    readonly property var popups: Notifications.popups
    // Os popups ficam no monitor onde o primeiro apareceu enquanto houver
    // algum à mostra, e até a próxima leva (a saída do último anima lá; ver
    // Panels.screenFor).
    property var shownOn: null
    property bool hadPopups: false
    readonly property var screen: Panels.screenFor(shownOn, Quickshell.screens, Hypr.focusedScreen)

    onPopupsChanged: {
        const has = popups.length > 0;
        if (has && !hadPopups)
            shownOn = Hypr.focusedScreen;
        hadPopups = has;
    }
    readonly property var list: Notifications.list
    readonly property bool doNotDisturb: Config.doNotDisturb

    // O "não perturbe" do serviço: o do usuário (salvo na config) ou o do modo
    // jogo, um segundo interruptor que não grava nada (o do usuário continua
    // dele quando o modo sai).
    function quietFor(userDnd: bool, gameActive: bool, gameQuiet: bool): bool {
        return userDnd || (gameActive && gameQuiet);
    }

    // O resumo do modo jogo: ao sair dele (uma troca vista, nunca o primeiro
    // estado), um cartão na pilha de popups conta as notificações não críticas
    // que chegaram desde o `since` da sessão (as críticas já apareceram). Conta
    // pela lista e pelo horário de chegada persistido, então sobrevive a um
    // reinício do shell no meio do jogo. `summary`: { count, apps, more } ou null.
    property var summary: null
    readonly property string summaryText: summary ? summaryTextOf(summary) : ""

    // { app, critical, at } de cada notificação da lista.
    function summaryItems(list: var): var {
        return Array.from(list ?? []).map(n => ({
                    app: String(n.appName ?? ""),
                    critical: isCritical(n),
                    at: Number(Notifications.receivedAt[n.id] ?? 0)
                }));
    }

    // Puro: as não críticas com `at` entre `since` e `now`, até três apps (na
    // ordem de chegada) e quantos outros; null sem nenhuma.
    function summaryOf(items: var, since: real, now: real): var {
        const counted = Array.from(items ?? []).filter(i => !i.critical && i.at >= since && i.at <= now).sort((a, b) => a.at - b.at);
        if (counted.length === 0)
            return null;
        const apps = [];
        for (const i of counted) {
            const app = i.app || "Notificação";
            if (!apps.includes(app))
                apps.push(app);
        }
        return {
            count: counted.length,
            apps: apps.slice(0, 3),
            more: Math.max(0, apps.length - 3)
        };
    }

    // "Enquanto você jogava: 4 notificações — Discord, Steam e mais 1".
    function summaryTextOf(s: var): string {
        const names = Array.from(s.apps);
        let who = "";
        if (s.more > 0)
            who = `${names.join(", ")} e mais ${s.more}`;
        else if (names.length > 1)
            who = `${names.slice(0, -1).join(", ")} e ${names[names.length - 1]}`;
        else
            who = names[0] ?? "";
        const count = s.count === 1 ? "1 notificação" : `${s.count} notificações`;
        return `Enquanto você jogava: ${count} — ${who}`;
    }

    function showSummary(since: real, list: var): void {
        if (since <= 0)
            return;
        summary = summaryOf(summaryItems(list), since, Date.now());
        if (summary)
            summaryTimer.restart();
    }

    function dismissSummary(): void {
        summary = null;
        summaryTimer.stop();
    }

    // O clique no cartão abre o painel das notificações.
    function openSummary(): void {
        dismissSummary();
        Panels.openNotifications();
    }

    // Uma troca do modo jogo vista pelo GameMode: ao sair, o resumo, só com o
    // não perturbe do modo e os avisos ligados (sem o não perturbe, as
    // notificações já apareceram como popup).
    function gameChanged(active: bool, list: var): void {
        if (!active && Config.gameQuiet && Config.gameNotices)
            showSummary(GameMode.lastSince, list);
    }

    Connections {
        target: GameMode

        function onChangedByDaemon(active: bool): void {
            root.gameChanged(active, Notifications.list);
        }
    }

    Timer {
        id: summaryTimer

        interval: Notifications.defaultTimeout
        onTriggered: root.dismissSummary()
    }

    // O tempo dos popups é salvo na config e repassado ao serviço.
    Binding {
        target: Notifications
        property: "doNotDisturb"
        value: root.quietFor(Config.doNotDisturb, GameMode.active, Config.gameQuiet)
    }

    Binding {
        target: Notifications
        property: "defaultTimeout"
        value: Config.notificationTimeout
    }

    IpcHandler {
        target: "notifications"

        // O painel das Notificações da central.
        function open(): void {
            Panels.openNotifications();
        }

        function toggle(): void {
            Panels.toggleNotifications();
        }

        function close(): void {
            Panels.closeNotifications();
        }

        function clear(): void {
            root.clearAll();
        }

        function toggleDnd(): void {
            root.toggleDoNotDisturb();
        }

        function count(): int {
            return root.list.length;
        }
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    function toggleDoNotDisturb(): void {
        Config.doNotDisturb = !Config.doNotDisturb;
    }

    function dismiss(notification: var): void {
        Notifications.dismiss(notification);
    }

    function clearAll(): void {
        Notifications.clearAll();
    }

    function hidePopup(notification: var): void {
        Notifications.hidePopup(notification);
    }

    function timeoutFor(notification: var): int {
        return Notifications.timeoutFor(notification);
    }

    function isCritical(notification: var): bool {
        return notification.urgency === NotificationUrgency.Critical;
    }

    function invoke(notification: var, action: var): void {
        action.invoke();
        if (!notification.resident)
            Notifications.dismiss(notification);
    }

    // "agora", "há 5 min", "14:03" ou "12/09"
    function timeLabel(notification: var): string {
        return Format.since(Notifications.timeOf(notification), clock.date);
    }

    // Imagem da notificação (foto, capa) ou ícone do app; "" se nenhum.
    function imageFor(notification: var): string {
        if (notification.image)
            return notification.image;
        const icon = notification.appIcon;
        if (!icon)
            return "";
        if (icon.startsWith("/"))
            return `file://${icon}`;
        if (icon.includes("://"))
            return icon;
        return Quickshell.iconPath(icon, true);
    }
}
