pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core.config
import qs.core.panels
import qs.core.widgets
import qs.services

// View model do painel superior: abertura, abas e quais serviços ligar. Cada
// serviço só coleta enquanto a aba que o mostra está visível.
Singleton {
    id: root

    readonly property bool open: Panels.isOpen("dashboard")
    readonly property var screen: Hypr.focusedScreen
    readonly property real topOffset: Panels.topInset
    // A altura comum das abas: o painel não pula ao trocar de aba. O
    // Desempenho cabe nela com os anéis do disco e da memória de 109 px.
    readonly property int pageHeight: 300

    // Todas as abas; `tabs` são as visíveis, na ordem escolhida nas configurações.
    readonly property var allTabs: [
        { id: "overview", icon: Icons.dashboard, label: "Painel" },
        { id: "media", icon: Icons.media, label: "Mídia" },
        { id: "performance", icon: Icons.performance, label: "Desempenho" },
        { id: "weather", icon: Icons.weather, label: "Clima" }
    ]
    readonly property var tabs: {
        const order = Config.dashboardTabOrder ?? [];
        const hidden = Config.dashboardTabsHidden ?? [];
        const sorted = allTabs.slice().sort((a, b) => (order.indexOf(a.id) + 1 || 99) - (order.indexOf(b.id) + 1 || 99));
        const visible = sorted.filter(t => !hidden.includes(t.id));
        return visible.length ? visible : [allTabs[0]];
    }
    readonly property int currentIndex: Math.max(0, tabs.findIndex(t => t.id === Config.dashboardTab))
    readonly property string current: tabs[currentIndex].id

    // Ao abrir: a última aba usada ou uma fixa.
    onOpenChanged: {
        if (open && Config.dashboardStartTab !== "last" && tabs.some(t => t.id === Config.dashboardStartTab))
            Config.dashboardTab = Config.dashboardStartTab;
        if (!open) {
            pointerInside = false;
            pointerEntered = false;
        }
    }

    // Fechar ao tirar o mouse: só depois de o mouse ter entrado no painel
    // (com a barra fixa ele abre abaixo do cursor, que está na hora).
    property bool pointerInside: false
    property bool pointerEntered: false

    function setPointerInside(inside: bool): void {
        pointerInside = inside;
        if (inside) {
            pointerEntered = true;
            leaveDelay.stop();
        } else if (open && pointerEntered && Config.dashboardHoverClose) {
            leaveDelay.restart();
        }
    }

    Timer {
        id: leaveDelay

        interval: 500
        onTriggered: {
            if (root.open && !root.pointerInside)
                Panels.dismiss("dashboard");
        }
    }

    function close(): void {
        Panels.dismiss("dashboard");
    }

    function setTab(index: int): void {
        const count = tabs.length;
        Config.dashboardTab = tabs[(index % count + count) % count].id;
    }

    function openTab(id: string): void {
        if (tabs.some(t => t.id === id))
            Config.dashboardTab = id;
        Panels.open("dashboard");
    }

    function isShowing(id: string): bool {
        return open && current === id;
    }

    Binding {
        target: SystemStats
        property: "active"
        value: root.isShowing("overview") || root.isShowing("performance")
    }

    Binding {
        target: SystemStats
        property: "interval"
        value: Config.statsInterval
    }

    Binding {
        target: SystemStats
        property: "gpuEnabled"
        value: Config.showGpu
    }

    // Offline, a letra guardada continua aparecendo: o daemon é que não vai à rede.
    Binding {
        target: Lyrics
        property: "active"
        value: root.isShowing("media") && Config.lyricsEnabled
    }

    // A configuração da rede externa, mandada ao lucernad pelo Web.
    Binding {
        target: Web
        property: "offline"
        value: Config.offline
    }

    Binding {
        target: Web
        property: "vagalumeKey"
        value: Config.vagalumeKey
    }

    Binding {
        target: Web
        property: "location"
        value: Config.weatherLocation
    }

    Binding {
        target: Web
        property: "refreshMinutes"
        value: Config.weatherRefresh
    }

    Binding {
        target: Media
        property: "trackPosition"
        value: root.isShowing("overview") || root.isShowing("media")
    }

    // O ponto único de leitura do espectro para a feature (o card da aba
    // Painel e a aba Mídia): as faixas e quantas são (vêm do lucernad).
    readonly property var spectrum: Spectrum.values
    readonly property int spectrumBars: Spectrum.bars
    // O card da aba Painel, espelhado com as mesmas barras: as faixas de duas
    // em duas (graves no topo dos dois lados, agudos embaixo).
    readonly property var spectrumPaired: Spectrum.pairMax(Spectrum.values)
    readonly property int spectrumPairedBars: Math.ceil(Spectrum.bars / 2)

    // O espectro em volta da capa, tocando: no card da aba Painel e na aba
    // Mídia (se ligado nas configurações). Uma assinatura só atende as duas.
    readonly property bool overviewMediaLive: root.isShowing("overview") && OverviewState.shows("media") && Media.playing
    readonly property bool mediaTabLive: root.isShowing("media") && Config.audioPulse && Media.playing

    Binding {
        target: Spectrum
        property: "active"
        value: root.overviewMediaLive || root.mediaTabLive
    }

    Binding {
        target: Weather
        property: "active"
        value: root.isShowing("overview") || root.isShowing("weather")
    }

    // A cidade escolhida é salva na config; o Web a manda ao lucernad.
    Connections {
        target: Weather

        function onLocated(location) {
            Config.weatherLocation = location;
        }
    }

    IpcHandler {
        target: "dashboard"

        // Abre numa aba: overview, media, performance ou weather.
        function open(tab: string): void {
            root.openTab(tab);
        }

        function toggle(): void {
            Panels.toggle("dashboard");
        }
    }
}
