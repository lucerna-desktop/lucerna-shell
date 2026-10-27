pragma Singleton

import QtQuick
import Quickshell
import qs.core.config
import qs.core.format
import qs.core.frame
import qs.core.panels
import qs.core.widgets
import qs.services

// View model da barra: o que ela mostra e quando ela aparece.
//
// A barra fica escondida e aparece na tela onde o mouse encostou no topo
// (ou, por um instante, ao trocar de workspace). Some quando o mouse sai e
// quando um painel centralizado abre; não aparece por cima de uma janela em
// tela cheia. Na área de trabalho vazia (sem janelas no workspace daquela
// tela), fica à mostra: não cobre nada. Com um painel da moldura aberto (o
// painel superior ou a central, ver Frame), ela sobe e se funde à moldura, à
// mostra e clicável; ao fechar, descola e flutua um instante antes de sumir.
Singleton {
    id: root

    // Estilo: "pill" ou "island". Os estilos que saíram ("strip", "islands") e
    // qualquer valor desconhecido viram a pílula.
    readonly property string style: Config.barStyle === "island" ? "island" : "pill"
    readonly property bool showDate: Config.barShowDate

    // Visibilidade
    readonly property bool panelOpen: Panels.anyOpen
    property var revealedScreen: null
    property bool hovering: false
    property bool peeking: false
    // A ilha se expande (workspaces, data e ações) com o mouse em cima e ao
    // aparecer por troca de workspace; no resto do tempo mostra só a hora.
    readonly property bool expanded: hovering || peeking

    function shownOn(screen: var): bool {
        if (Frame.fusedOn(screen))
            return true;
        if (panelOpen)
            return false;
        if (revealedScreen !== screen && !(Config.barOnEmpty && Hypr.isScreenEmpty(screen)))
            return false;
        return !Hypr.hasFullscreen(screen);
    }

    // O topo da pílula: `gap` abaixo da borda flutuando, encostada nela fundida
    // (`fuse` de 0 a 1), e acima da tela escondida (`progress` 0).
    function pillY(gap: real, height: real, progress: real, fuse: real): real {
        return gap * (1 - Frame.clamp(fuse)) - (1 - progress) * (height + gap * 2);
    }

    // A tela onde a pílula está fundida (ou null). Ao descolar, ela fica à
    // mostra, flutuando, até o mouse sair (ou não entrar) dela.
    readonly property var fusedScreen: Quickshell.screens.find(s => Frame.fusedOn(s)) ?? null
    property var lastFused: null

    onFusedScreenChanged: unfuse(lastFused, fusedScreen)

    function unfuse(was: var, now: var): void {
        lastFused = now;
        if (!was || was === now)
            return;
        revealedScreen = was;
        if (!hovering)
            hideDelay.restart();
    }

    // Mouse encostou no topo da tela.
    function reveal(screen: var): void {
        revealedScreen = screen;
        hideDelay.stop();
    }

    function setHovering(on: bool): void {
        hovering = on;
        if (on)
            hideDelay.stop();
        else
            hideDelay.restart();
    }

    // Aparece por um instante (troca de workspace).
    function peek(screen: var): void {
        if (panelOpen)
            return;
        revealedScreen = screen;
        peeking = true;
        peekDelay.restart();
    }

    Timer {
        id: hideDelay

        interval: 450
        onTriggered: {
            if (!root.hovering)
                root.revealedScreen = null;
        }
    }

    Timer {
        id: peekDelay

        interval: 1400
        onTriggered: {
            root.peeking = false;
            if (!root.hovering)
                root.revealedScreen = null;
        }
    }

    Connections {
        target: Hypr

        function onFocusedWorkspaceIdChanged() {
            if (Config.barPeek)
                root.peek(Hypr.focusedScreen);
        }
    }

    // Workspaces: sempre mostra pelo menos `minWorkspaces`, mais os que existirem além disso.
    readonly property int minWorkspaces: 5
    readonly property var workspaceIds: {
        const highest = Math.max(minWorkspaces, Hypr.focusedWorkspaceId, ...Hypr.workspaces.map(w => w.id));
        return Array.from({ length: highest }, (_, i) => i + 1);
    }

    // "focused", "occupied" ou "empty"
    function workspaceState(id: int): string {
        if (Hypr.focusedWorkspaceId === id)
            return "focused";
        const ws = Hypr.workspace(id);
        return ws && ws.toplevels.values.length > 0 ? "occupied" : "empty";
    }

    function focusWorkspace(id: int): void {
        Hypr.focusWorkspace(id);
    }

    function cycleWorkspace(step: int): void {
        Hypr.cycleWorkspace(step);
    }

    // Relógio
    readonly property string time: Qt.formatTime(clock.date, "HH:mm")
    readonly property string date: clock.date.toLocaleDateString(Qt.locale("pt_BR"), "ddd, d 'de' MMM").replace(/\./g, "")

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    // Áudio
    readonly property bool audioAvailable: Audio.available
    readonly property bool muted: Audio.muted
    readonly property string volumeIcon: Audio.muted || Audio.volume === 0 ? Icons.volumeOff : Audio.volume < 0.34 ? Icons.volumeLow : Audio.volume < 0.67 ? Icons.volumeMedium : Icons.volumeHigh

    function scrollVolume(steps: real): void {
        Audio.changeVolume(steps * 0.05);
    }

    function toggleMute(): void {
        Audio.toggleMute();
    }

    // Rede
    readonly property bool networkAvailable: Network.available
    readonly property bool online: Network.kind !== "offline"
    readonly property string networkIcon: Network.kind === "wired" ? Icons.ethernet : Network.kind === "wifi" ? Icons.level(Icons.wifi, Network.signal) : Network.wifiEnabled ? Icons.offline : Icons.wifiOff

    // Bateria
    readonly property bool batteryAvailable: Battery.available
    readonly property int batteryPercent: Math.round(Battery.percentage * 100)
    readonly property bool batteryShowPercent: Config.batteryShowPercent
    readonly property bool batteryLow: Battery.isLow
    readonly property string batteryIcon: Battery.charging ? Icons.batteryCharging : batteryLow ? Icons.batteryAlert : Icons.level(Icons.battery, Battery.percentage)

    // Notificações
    readonly property int notificationCount: Notifications.count
    readonly property bool doNotDisturb: Notifications.doNotDisturb
    readonly property string bellIcon: doNotDisturb ? Icons.bellSleep : notificationCount > 0 ? Icons.bellBadge : Icons.bellOutline

    // Painéis
    readonly property bool dashboardOpen: Panels.isOpen("dashboard")

    function registerSurface(window: var): void {
        Panels.register(window);
    }

    function unregisterSurface(window: var): void {
        Panels.unregister(window);
    }

    function togglePanel(name: string): void {
        Panels.toggle(name);
    }

    // Abrir o painel superior ao parar o mouse sobre a hora (se ligado nas
    // configurações). O atraso evita abrir só porque o mouse passou por ali.
    function clockHovered(on: bool): void {
        if (on && Config.dashboardHoverOpen && !Panels.isOpen("dashboard") && !Panels.modalOpen)
            hoverOpenDelay.restart();
        else
            hoverOpenDelay.stop();
    }

    Timer {
        id: hoverOpenDelay

        interval: 280
        onTriggered: Panels.open("dashboard")
    }

    // Abre as Ações da central na entrada (ou fecha, se já estiverem abertas
    // por ela); as Notificações ficam como estão.
    function toggleEntry(entry: string): void {
        Panels.toggleActions(entry);
    }

    // O ícone da entrada aceso: as Ações abertas por ela.
    function entryOpen(entry: string): bool {
        return Panels.actionsAt(entry);
    }

    // O sino: só as Notificações da central.
    readonly property bool notificationsOpen: Panels.notificationsOpen

    function toggleNotifications(): void {
        Panels.toggleNotifications();
    }

    // Gravação de tela em andamento: o tempo, e parar pela barra.
    readonly property bool recording: Capture.recording
    property string recordingTime: "0:00"

    function stopRecording(): void {
        Capture.stopRecording();
    }

    Timer {
        running: root.recording
        repeat: true
        triggeredOnStart: true
        interval: 1000
        onTriggered: root.recordingTime = Format.clock((Date.now() - Capture.recordingSince) / 1000)
    }
}
