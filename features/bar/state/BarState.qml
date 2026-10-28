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
// A barra tem um modelo só: uma aba fundida à borda de cima da moldura da
// tela (ver Frame); quando ela aparece, a moldura aparece junto, nos quatro
// lados, e as duas recolhem juntas. Fica escondida e aparece na tela onde o
// mouse encostou no topo (ou, por um instante, ao trocar de workspace). Some
// quando o mouse sai e quando um painel centralizado abre. Na área de trabalho
// vazia (sem janelas no workspace daquela tela), fica à mostra: não cobre
// nada. Sobre uma janela em tela cheia de verdade (um jogo, um vídeo; a
// maximizada não conta), só o mouse no topo a traz. Com um painel da
// moldura aberto, fica à mostra: por cima da central, clicável; com o painel
// superior, ela se transforma nele (ver Frame.morphOn). A ação `bar` (um
// atalho) a revela na tela com foco e a esconde no segundo toque. No modo jogo
// (com o item ligado), o mouse no topo e a troca de workspace não a trazem;
// a ação `bar` ainda traz.
Singleton {
    id: root

    readonly property bool showDate: Config.barShowDate

    // Visibilidade
    readonly property bool panelOpen: Panels.anyOpen
    property var revealedScreen: null
    property bool hovering: false
    // Revelada pela troca de workspace, não pelo mouse.
    property bool peeking: false
    // Revelada pela ação `bar` (o atalho), até o segundo toque ou o mouse sair
    // dela depois de passar por cima (a faixa do topo sozinha não conta).
    property var pinnedScreen: null
    property bool pinHovered: false
    // O modo jogo prende a barra: só a ação `bar` a revela.
    readonly property bool gameLocked: GameMode.active && Config.gameBar

    function shownOn(screen: var): bool {
        // O vazio e a tela cheia só são lidos quando decidem (getters).
        return decide({
            fused: Frame.fusedOn(screen),
            panelOpen: panelOpen,
            revealed: revealedScreen === screen,
            peeking: peeking,
            pinned: pinnedScreen === screen,
            gameLocked: gameLocked,
            get empty() {
                return Config.barOnEmpty && Hypr.isScreenEmpty(screen);
            },
            get fullscreen() {
                return Hypr.hasRealFullscreen(screen);
            }
        });
    }

    // A regra, sem os serviços: fundida a um painel da moldura, fica; com um
    // painel aberto, some; a ação `bar` sempre a traz; o mouse no topo também,
    // fora do modo jogo; a troca de workspace (também fora do modo jogo) e o
    // workspace vazio, só fora de uma tela cheia de verdade.
    function decide(s: var): bool {
        if (s.fused)
            return true;
        if (s.panelOpen)
            return false;
        if (s.pinned)
            return true;
        if (s.gameLocked)
            return s.empty && !s.fullscreen;
        if (s.revealed && !s.peeking)
            return true;
        return (s.revealed || s.empty) && !s.fullscreen;
    }

    // O topo da barra, encostada na borda de cima (aberta, `progress` 1) ou
    // acima da tela (0), descendo junto com a moldura.
    function pillY(height: real, progress: real): real {
        return -(1 - progress) * height;
    }

    // Mouse encostou no topo da tela (no modo jogo, não traz).
    function reveal(screen: var): void {
        if (gameLocked)
            return;
        revealedScreen = screen;
        peeking = false;
        hideDelay.stop();
    }

    function setHovering(on: bool): void {
        hovering = on;
        if (on && pinnedScreen !== null)
            pinHovered = true;
        if (on) {
            peeking = false;
            hideDelay.stop();
        } else {
            hideDelay.restart();
        }
    }

    // Aparece por um instante (troca de workspace). Com o mouse em cima dela
    // (a roda nos workspaces), vale o mouse: a tela cheia não a esconde.
    function peek(screen: var): void {
        if (panelOpen || gameLocked)
            return;
        revealedScreen = screen;
        peeking = !hovering;
        peekDelay.restart();
    }

    // A ação `bar`: revela na tela dada; na mesma tela, o segundo toque esconde.
    function togglePinned(screen: var): void {
        pinHovered = false;
        if (pinnedScreen === screen) {
            pinnedScreen = null;
            return;
        }
        pinnedScreen = screen;
        hideDelay.stop();
    }

    Timer {
        id: hideDelay

        interval: 450
        onTriggered: {
            if (!root.hovering) {
                root.revealedScreen = null;
                if (root.pinHovered) {
                    root.pinnedScreen = null;
                    root.pinHovered = false;
                }
            }
        }
    }

    // A ação `bar` vem pelo Panels (a feature input não importa a barra).
    Connections {
        target: Panels

        function onBarToggleRequested(screen: var): void {
            root.togglePinned(screen);
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

    // Modo jogo: um ícone discreto à esquerda do sino enquanto ligado; o
    // clique desliga (pelo daemon).
    readonly property bool gameIcon: GameMode.active
    readonly property string gameTooltip: {
        if (!GameMode.active)
            return "";
        const why = GameMode.reasonsText(GameMode.reasons);
        return why ? `Modo jogo ligado: ${why}. Clique para desligar.` : "Modo jogo ligado. Clique para desligar.";
    }

    function stopGame(): void {
        GameMode.set(false);
    }

    // Painéis
    readonly property bool dashboardOpen: Panels.isOpen("dashboard")

    // A barra se transforma no painel superior e deixa de receber o mouse (o
    // HoverHandler dela não vê a saída): ao abrir, o mouse conta como fora, e
    // ao fechar ela só fica se ainda tiver motivo para estar à mostra.
    onDashboardOpenChanged: {
        if (dashboardOpen) {
            hovering = false;
            hideDelay.restart();
        }
    }

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
