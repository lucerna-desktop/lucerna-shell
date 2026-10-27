pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core.config
import qs.core.panels
import qs.core.theme
import qs.core.widgets
import qs.services

// View model da tela de configurações. Tudo o que ela muda vai para a config
// (core/config): as features leem de lá, então nenhuma depende desta tela.
Singleton {
    id: root

    readonly property bool open: Panels.isOpen("settings")
    // Fica no monitor onde abriu (mudar o arranjo move o foco); se ele sumir,
    // vai para o que tem foco.
    property var openedOn: null
    readonly property var screen: openedOn && Quickshell.screens.includes(openedOn) ? openedOn : Hypr.focusedScreen

    onOpenChanged: {
        if (open)
            openedOn = Hypr.focusedScreen;
    }

    // Tópicos da lista à esquerda. `soon` marca os que ainda não têm opções.
    readonly property var topics: [
        { id: "appearance", icon: Icons.palette, label: "Aparência", description: "Tema e animações" },
        { id: "wallpaper", icon: Icons.wallpaper, label: "Papel de parede", description: "Por tema, animado ou seu" },
        { id: "displays", icon: Icons.monitor, label: "Monitores", description: "Disposição, resolução e escala" },
        { id: "idle", icon: "timer", label: "Tela e ociosidade", description: "Brilho, escurecer, desligar e bloquear" },
        { id: "nightlight", icon: "nightlight", label: "Luz noturna", description: "Cores quentes à noite" },
        { id: "mouse", icon: Icons.mouse, label: "Mouse", description: "Ponteiro, rolagem e botões" },
        { id: "keyboard", icon: Icons.keyboard, label: "Teclado", description: "Layouts, teclas e atalhos" },
        { id: "clipboard", icon: "content_paste", label: "Área de transferência", description: "Histórico do que foi copiado" },
        { id: "capture", icon: "screenshot_region", label: "Captura de tela", description: "Fotos, gravações e pastas" },
        { id: "glass", icon: Icons.blur, label: "Transparência e desfoque", description: "O vidro dos painéis" },
        { id: "notifications", icon: Icons.bell, label: "Notificações", description: "Popups e não perturbe" },
        { id: "panels", icon: Icons.panels, label: "Painéis", description: "O painel superior junto das configurações" },
        { id: "launcher", icon: Icons.apps, label: "Launcher", description: "Estilo, busca e favoritos" },
        { id: "bar", icon: Icons.toolbar, label: "Barra", description: "O que mostra e quando aparece" },
        { id: "dashboard", icon: Icons.dashboard, label: "Painel superior", description: "Abas, cartões, clima e privacidade" },
        { id: "power", icon: Icons.bolt, label: "Energia e bateria", description: "Avisos, perfil e modo leve" },
        { id: "shortcuts", icon: Icons.keyboard, label: "Atalhos", description: "As teclas do shell" },
        { id: "credits", icon: Icons.credits, label: "Créditos", description: "Inspiração, dados e base" },
        { id: "about", icon: Icons.info, label: "Sobre", description: "Versões e sistema" }
    ]
    readonly property int currentIndex: Math.max(0, topics.findIndex(t => t.id === Config.settingsTopic))
    readonly property var current: topics[currentIndex]

    // Créditos: quem inspirou, de onde vêm os dados e o que o Lucerna usa.
    readonly property var credits: [
        {
            title: "Inspiração",
            items: [
                { name: "Caelestia Shell", detail: "O painel superior, a aba Clima e as curvas de animação do Material 3; GPL-3.0", url: "https://github.com/caelestia-dots/shell" }
            ]
        },
        {
            title: "Dados",
            items: [
                { name: "Open-Meteo", detail: "Previsão do tempo e busca de cidade; dados sob a licença CC BY 4.0", url: "https://open-meteo.com/" },
                { name: "LRCLIB", detail: "Letras sincronizadas", url: "https://lrclib.net/" },
                { name: "Vagalume", detail: "Letras, só com a chave de quem usa", url: "https://www.vagalume.com.br/" }
            ]
        },
        {
            title: "Base",
            items: [
                { name: "Quickshell", detail: "O toolkit em QML em que o shell é feito", url: "https://quickshell.org/" },
                { name: "Hyprland", detail: "O compositor Wayland", url: "https://hyprland.org/" },
                { name: "Material Symbols", detail: "A fonte dos ícones, do Google; Apache 2.0", url: "https://fonts.google.com/icons" }
            ]
        }
    ]

    // Abre o link no navegador; só https.
    function openLink(url: string): void {
        if (url.startsWith("https://"))
            Qt.openUrlExternally(url);
    }

    function close(): void {
        Panels.dismiss("settings");
    }

    function setTopic(index: int): void {
        const n = topics.length;
        Config.settingsTopic = topics[(index % n + n) % n].id;
    }

    function openTopic(id: string): void {
        if (topics.some(t => t.id === id))
            Config.settingsTopic = id;
        Panels.open("settings");
    }

    // Aparência
    readonly property var themes: ThemeManager.themes
    readonly property string theme: ThemeManager.current
    readonly property var animationOptions: [
        { label: "Desligadas", value: 0 },
        { label: "Rápidas", value: 0.6 },
        { label: "Normais", value: 1 },
        { label: "Suaves", value: 1.5 }
    ]
    readonly property real animationScale: Config.animationScale >= 0 ? Config.animationScale : 1

    function applyTheme(id: string): void {
        ThemeManager.apply(id);
    }

    function setAnimationScale(value: real): void {
        Config.animationScale = value;
    }

    readonly property bool outlines: ThemeManager.outlines

    function setOutlines(on: bool): void {
        Config.outlines = on;
    }

    // Transparência e desfoque
    readonly property bool transparency: ThemeManager.transparency.enabled
    readonly property real panelOpacity: ThemeManager.transparency.base
    readonly property real cardOpacity: ThemeManager.transparency.layers
    readonly property bool blur: ThemeManager.blur.enabled
    readonly property int blurSize: ThemeManager.blur.size
    readonly property int blurPasses: ThemeManager.blur.passes
    readonly property bool glassCustomized: ThemeManager.transparency.customized || ThemeManager.blur.customized
    readonly property bool blurAvailable: Hypr.usingLua

    function setTransparency(on: bool): void {
        ThemeManager.setTransparency("enabled", on);
    }

    function setPanelOpacity(value: real): void {
        ThemeManager.setTransparency("base", Math.round(value * 100) / 100);
    }

    function setCardOpacity(value: real): void {
        ThemeManager.setTransparency("layers", Math.round(value * 100) / 100);
    }

    function setBlur(on: bool): void {
        ThemeManager.setBlur("enabled", on);
    }

    function setBlurSize(value: real): void {
        ThemeManager.setBlur("size", Math.round(value));
    }

    function setBlurPasses(value: real): void {
        ThemeManager.setBlur("passes", Math.round(value));
    }

    function resetGlass(): void {
        ThemeManager.resetGlass();
    }

    // Painel superior
    readonly property var dashboardTabInfo: ({
        overview: { label: "Painel", icon: Icons.dashboard },
        media: { label: "Mídia", icon: Icons.media },
        performance: { label: "Desempenho", icon: Icons.performance },
        weather: { label: "Clima", icon: Icons.weather }
    })
    readonly property var dashboardTabs: {
        const order = Config.dashboardTabOrder ?? [];
        const hidden = Config.dashboardTabsHidden ?? [];
        const ids = Object.keys(dashboardTabInfo).sort((a, b) => (order.indexOf(a) + 1 || 99) - (order.indexOf(b) + 1 || 99));
        return ids.map((id, i) => ({ id: id, label: dashboardTabInfo[id].label, icon: dashboardTabInfo[id].icon, visible: !hidden.includes(id), first: i === 0, last: i === ids.length - 1 }));
    }
    readonly property int visibleTabCount: dashboardTabs.filter(t => t.visible).length

    function moveTab(id: string, step: int): void {
        const ids = dashboardTabs.map(t => t.id);
        const i = ids.indexOf(id);
        const j = i + step;
        if (i < 0 || j < 0 || j >= ids.length)
            return;
        [ids[i], ids[j]] = [ids[j], ids[i]];
        Config.dashboardTabOrder = ids;
    }

    function setTabVisible(id: string, on: bool): void {
        const hidden = (Config.dashboardTabsHidden ?? []).filter(h => h !== id);
        // Pelo menos uma aba fica visível.
        if (!on && visibleTabCount <= 1)
            return;
        Config.dashboardTabsHidden = on ? hidden : [...hidden, id];
    }

    readonly property string startTab: Config.dashboardStartTab
    readonly property var startTabOptions: [
        { label: "A última", value: "last" },
        ...dashboardTabs.filter(t => t.visible).map(t => ({ label: t.label, value: t.id }))
    ]

    function setStartTab(value: string): void {
        Config.dashboardStartTab = value;
    }

    readonly property bool hoverOpen: Config.dashboardHoverOpen
    readonly property bool hoverClose: Config.dashboardHoverClose

    function setHoverOpen(on: bool): void {
        Config.dashboardHoverOpen = on;
    }

    function setHoverClose(on: bool): void {
        Config.dashboardHoverClose = on;
    }

    readonly property var overviewCards: [
        { id: "user", label: "Usuário", icon: Icons.person, description: "Foto, nome e tempo ligado, com atalhos para configurações e energia" },
        { id: "clock", label: "Relógio", icon: Icons.uptime, description: "Hora grande e data" },
        { id: "weather", label: "Clima resumido", icon: Icons.weather, description: "Temperatura e condição da cidade escolhida" },
        { id: "calendar", label: "Calendário", icon: Icons.calendar, description: "O mês, com o dia de hoje em destaque" },
        { id: "resources", label: "Recursos", icon: Icons.cpu, description: "CPU, memória e disco" },
        { id: "media", label: "Mídia", icon: Icons.media, description: "O que está tocando" }
    ].map(c => Object.assign(c, { visible: !(Config.overviewHidden ?? []).includes(c.id) }))

    function setCardVisible(id: string, on: bool): void {
        const hidden = (Config.overviewHidden ?? []).filter(h => h !== id);
        Config.overviewHidden = on ? hidden : [...hidden, id];
    }

    readonly property int weekStart: Config.weekStart

    function setWeekStart(day: int): void {
        Config.weekStart = day;
    }

    readonly property bool lyrics: Config.lyricsEnabled
    readonly property bool audioPulse: Config.audioPulse

    function setLyrics(on: bool): void {
        Config.lyricsEnabled = on;
    }

    function setAudioPulse(on: bool): void {
        Config.audioPulse = on;
    }

    readonly property int statsInterval: Config.statsInterval
    readonly property bool showGpu: Config.showGpu

    function setStatsInterval(ms: int): void {
        Config.statsInterval = ms;
    }

    function setShowGpu(on: bool): void {
        Config.showGpu = on;
    }

    readonly property string weatherPlace: Config.weatherLocation?.name ?? ""
    readonly property var cityResults: Weather.results
    readonly property bool citySearching: Weather.searching
    readonly property string citySearchError: Weather.searchError
    readonly property string temperatureUnit: Config.temperatureUnit
    readonly property string windUnit: Config.windUnit
    readonly property int weatherRefresh: Config.weatherRefresh

    function searchCity(name: string): void {
        Weather.search(name);
    }

    // A escolha emite `located`, que o DashboardState salva na config.
    function chooseCity(index: int): void {
        Weather.choose(index);
    }

    function refreshWeather(): void {
        Weather.refresh();
    }

    readonly property string vagalumeKey: Config.vagalumeKey

    // Grava a chave do Vagalume (aparada; vazia apaga) e devolve o erro, ou "".
    function setVagalumeKey(key: string): string {
        const value = key.trim();
        if (value !== "" && !/^[A-Za-z0-9_-]{1,128}$/.test(value))
            return "A chave só tem letras, números, - e _ (até 128).";
        Config.vagalumeKey = value;
        return "";
    }

    // Vazio com o módulo de rede funcionando; senão, o porquê.
    readonly property string webNote: Web.unavailableNote

    function setTemperatureUnit(unit: string): void {
        Config.temperatureUnit = unit;
    }

    function setWindUnit(unit: string): void {
        Config.windUnit = unit;
    }

    function setWeatherRefresh(minutes: int): void {
        Config.weatherRefresh = minutes;
    }

    readonly property bool offline: Config.offline

    function setOffline(on: bool): void {
        Config.offline = on;
    }

    // Energia e bateria
    readonly property bool hasBattery: Battery.available
    readonly property bool batteryShowPercent: Config.batteryShowPercent
    readonly property int batteryLowLevel: Config.batteryLowLevel
    readonly property int batteryCriticalLevel: Config.batteryCriticalLevel
    readonly property bool batteryNotifyFull: Config.batteryNotifyFull
    readonly property bool batteryNotifyPlug: Config.batteryNotifyPlug
    readonly property string batteryCriticalAction: Config.batteryCriticalAction
    readonly property bool autoProfile: Config.autoProfile
    readonly property int profileOnBattery: Config.profileOnBattery
    readonly property int profileOnAC: Config.profileOnAC
    readonly property bool saverBelowEnabled: Config.saverBelowEnabled
    readonly property int saverBelow: Config.saverBelow
    readonly property bool batteryLightMode: Config.batteryLightMode
    readonly property var profileOptions: [
        { label: Battery.profileNames[0], value: 0 },
        { label: Battery.profileNames[1], value: 1 },
        ...(Battery.hasPerformance ? [{ label: Battery.profileNames[2], value: 2 }] : [])
    ]
    readonly property var criticalActions: [
        { label: "Nada", value: "none" },
        { label: "Suspender", value: "suspend" },
        { label: "Hibernar", value: "hibernate" },
        { label: "Desligar", value: "poweroff" }
    ]

    function setBatteryShowPercent(on: bool): void {
        Config.batteryShowPercent = on;
    }

    // O nível crítico fica sempre abaixo do baixo.
    function setBatteryLowLevel(v: real): void {
        Config.batteryLowLevel = Math.round(v);
        if (Config.batteryCriticalLevel >= Config.batteryLowLevel)
            Config.batteryCriticalLevel = Math.max(1, Config.batteryLowLevel - 1);
    }

    function setBatteryCriticalLevel(v: real): void {
        Config.batteryCriticalLevel = Math.min(Math.round(v), Config.batteryLowLevel - 1);
    }

    function setBatteryNotifyFull(on: bool): void {
        Config.batteryNotifyFull = on;
    }

    function setBatteryNotifyPlug(on: bool): void {
        Config.batteryNotifyPlug = on;
    }

    function setBatteryCriticalAction(v: string): void {
        Config.batteryCriticalAction = v;
    }

    function setAutoProfile(on: bool): void {
        Config.autoProfile = on;
    }

    function setProfileOnBattery(v: int): void {
        Config.profileOnBattery = v;
    }

    function setProfileOnAC(v: int): void {
        Config.profileOnAC = v;
    }

    function setSaverBelowEnabled(on: bool): void {
        Config.saverBelowEnabled = on;
    }

    function setSaverBelow(v: real): void {
        Config.saverBelow = Math.round(v);
    }

    function setBatteryLightMode(on: bool): void {
        Config.batteryLightMode = on;
    }

    // Barra
    readonly property bool barPeek: Config.barPeek
    readonly property bool barShowDate: Config.barShowDate
    readonly property bool barOnEmpty: Config.barOnEmpty

    function setBarOnEmpty(on: bool): void {
        Config.barOnEmpty = on;
    }

    function setBarPeek(on: bool): void {
        Config.barPeek = on;
    }

    function setBarShowDate(on: bool): void {
        Config.barShowDate = on;
    }

    // Painéis: se o painel superior abre junto das configurações.
    readonly property var companionOptions: [
        { id: "dashboard", icon: Icons.dashboard, label: "Painel superior", description: "Calendário, mídia, desempenho e clima" }
    ]
    readonly property var panelsTogether: Config.panelsTogether ?? []

    function setTogether(id: string, on: bool): void {
        const rest = panelsTogether.filter(n => n !== id);
        Config.panelsTogether = on ? rest.concat([id]) : rest;
    }

    // Notificações
    readonly property bool doNotDisturb: Config.doNotDisturb
    readonly property real notificationSeconds: Config.notificationTimeout / 1000

    function setDoNotDisturb(on: bool): void {
        Config.doNotDisturb = on;
    }

    function setNotificationSeconds(seconds: real): void {
        Config.notificationTimeout = Math.round(seconds) * 1000;
    }

    function testNotification(): void {
        Quickshell.execDetached(["notify-send", "-a", "Lucerna", "Notificação de teste", `Ela some em ${Math.round(notificationSeconds)} s.`]);
    }

    // Sobre
    readonly property var about: [
        { label: "Hyprland", value: Hypr.version || "—" },
        { label: "Quickshell", value: SystemStats.quickshellVersion || "—" },
        { label: "Sistema", value: SystemStats.machineText(SystemStats.connected, SystemStats.osName) },
        { label: "Kernel", value: SystemStats.machineText(SystemStats.connected, SystemStats.kernel) },
        { label: "Máquina", value: SystemStats.machineText(SystemStats.connected, SystemStats.hostname) }
    ]

    IpcHandler {
        target: "settings"

        // Abre num tópico: appearance, glass, notifications, shortcuts, about...
        function open(topic: string): void {
            root.openTopic(topic);
        }
    }
}
