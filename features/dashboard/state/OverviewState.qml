pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core.config
import qs.core.format
import qs.core.input
import qs.core.nightlight
import qs.core.panels
import qs.core.widgets
import qs.services

// View model da aba Painel: usuário, relógio, calendário e resumos.
Singleton {
    id: root

    readonly property var locale: Qt.locale("pt_BR")

    // Cartões visíveis (escolhidos nas configurações).
    readonly property var hidden: Config.overviewHidden ?? []

    function shows(card: string): bool {
        return !hidden.includes(card);
    }

    // Usuário e sistema
    readonly property string user: Quickshell.env("USER") || "você"
    // Sem o lucernad, "—" (e não o nome de uma conexão anterior).
    readonly property string hostname: SystemStats.machineText(SystemStats.connected, SystemStats.hostname)
    // Os recursos e o tempo ligado só com o módulo de sistema respondendo.
    readonly property bool statsAvailable: SystemStats.available
    // Foto do usuário em ~/.face, se existir (o mesmo arquivo que o GDM e o SDDM usam).
    readonly property string facePath: `${Quickshell.env("HOME")}/.face`
    property bool hasFace: false
    readonly property string face: hasFace ? `file://${facePath}` : ""

    FileView {
        path: root.facePath
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.hasFace = true
        onLoadFailed: root.hasFace = false
    }
    readonly property string uptime: statsAvailable && SystemStats.uptime > 0 ? `ligado há ${Format.duration(SystemStats.uptime)}` : ""

    // Relógio
    readonly property string time: Qt.formatTime(clock.date, "HH:mm")
    readonly property string weekday: Format.capitalize(clock.date.toLocaleDateString(locale, "dddd"))
    readonly property string date: clock.date.toLocaleDateString(locale, "d 'de' MMMM")

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    // Calendário: mês mostrado (deslocamento em relação ao atual) e 42 células.
    property int monthOffset: 0
    // O dia de hoje em inteiros: só notificam quando o dia vira, não a cada minuto
    // do relógio, e o calendário depende só deles (não é recriado a cada minuto).
    readonly property int todayYear: clock.date.getFullYear()
    readonly property int todayMonth: clock.date.getMonth()
    readonly property int todayDay: clock.date.getDate()
    readonly property var shownMonth: new Date(todayYear, todayMonth + monthOffset, 1)
    readonly property string monthTitle: Format.capitalize(shownMonth.toLocaleDateString(locale, "MMMM 'de' yyyy"))
    readonly property int weekStart: Config.weekStart
    // Cabeçalho: a inicial de cada dia da semana, na ordem de `start` (0 = domingo), e se é domingo.
    function weekdayCells(start: int): var {
        return [0, 1, 2, 3, 4, 5, 6].map(i => {
            const dow = (i + start) % 7;
            return { initial: locale.dayName(dow, Locale.NarrowFormat).toUpperCase(), sunday: dow === 0 };
        });
    }

    readonly property var weekdays: weekdayCells(weekStart)

    // As 42 células do mês `first` (dia 1), começando em weekStart (0 = domingo):
    // dia, se é do mês, se é hoje (`today`, um Date) e se cai num domingo.
    function monthCells(first: date, start: int, today: date): var {
        const lead = (first.getDay() - start + 7) % 7;
        const todayKey = today.toDateString();
        return Array.from({ length: 42 }, (_, i) => {
            const d = new Date(first.getFullYear(), first.getMonth(), 1 - lead + i);
            return { day: d.getDate(), inMonth: d.getMonth() === first.getMonth(), today: d.toDateString() === todayKey, sunday: d.getDay() === 0 };
        });
    }

    readonly property var calendarDays: monthCells(shownMonth, weekStart, new Date(todayYear, todayMonth, todayDay))

    function shiftMonth(step: int): void {
        monthOffset += step;
    }

    function resetMonth(): void {
        monthOffset = 0;
    }

    // Resumos
    readonly property real cpu: SystemStats.cpuUsage
    readonly property real memory: SystemStats.memTotal > 0 ? SystemStats.memUsed / SystemStats.memTotal : 0
    readonly property real disk: SystemStats.disks.length ? SystemStats.disks[0].used / SystemStats.disks[0].size : 0

    readonly property bool hasWeather: Weather.current !== null
    readonly property string weatherIcon: hasWeather ? Icons.forWeather(Weather.current.code, Weather.current.isDay) : Icons.weather
    readonly property string weatherTemp: hasWeather ? WeatherState.temperature(Weather.current.temp) : "—"
    readonly property string weatherText: Config.offline ? "Modo offline" : !Web.available ? "Indisponível" : hasWeather ? WeatherState.describe(Weather.current.code) : (Config.weatherLocation ? "Carregando…" : "Escolha a cidade nas configurações")
    readonly property string weatherPlace: Weather.location?.name.split(",")[0] ?? ""

    readonly property bool hasMedia: Media.available
    readonly property string mediaTitle: Media.title || "Nada tocando"
    readonly property string mediaArtist: Media.artist
    readonly property string mediaArt: Media.artUrl
    readonly property bool mediaPlaying: Media.playing

    function togglePlaying(): void {
        Media.togglePlaying();
    }

    readonly property int playerCount: Media.players.length

    function cyclePlayer(): void {
        Media.cycle();
    }

    function nextTrack(): void {
        Media.next();
    }

    function previousTrack(): void {
        Media.previous();
    }

    // Atalhos no cartão do usuário (a barra não tem mais esses botões).
    function openSettings(): void {
        Panels.open("settings");
    }

    function openPower(): void {
        Panels.open("power");
    }

    // Barra de ações rápidas, embaixo da aba. Os apps integrados ao Lucerna
    // entram nela (à esquerda, depois destas ações) quando existirem.
    //
    // À esquerda, ações de um clique: { id, label (a dica e o nome acessível),
    // icon, active (aceso) }. `has`: shot e record (o grim e o wf-recorder) e
    // recording (gravando agora: o botão vira "parar"). O que não existe some.
    function actionsFor(has: var): var {
        const icon = id => InputActions.find(id)?.icon ?? "";
        return [
            ...(has.shot ? [{ id: "capture", label: "Captura de tela", icon: icon("capture"), active: false }] : []),
            ...(has.record ? [{ id: "record", label: has.recording ? "Parar a gravação" : "Gravar a tela", icon: icon("record"), active: has.recording }] : []),
            { id: "clipboard", label: "Área de transferência", icon: icon("clipboard"), active: false },
            { id: "themes", label: "Papéis de parede e temas", icon: icon("themes"), active: false },
            { id: "overview", label: "Visão geral dos workspaces", icon: icon("overview"), active: false }
        ];
    }

    readonly property var quickActions: actionsFor({ shot: Capture.canShoot, record: Capture.canRecord, recording: Capture.recording })

    // Cada ação abre o painel dela, que é modal: o painel superior fecha
    // junto, como pelos atalhos. A captura abre na seleção de área; a
    // gravação, no modo vídeo (gravando, para).
    function runAction(id: string): void {
        switch (id) {
        case "capture":
            Config.captureMode = "shot";
            Config.captureTarget = "area";
            Panels.open("capture");
            break;
        case "record":
            if (Capture.recording) {
                Capture.stopRecording();
            } else {
                Config.captureMode = "record";
                Panels.open("capture");
            }
            break;
        case "clipboard":
        case "themes":
        case "overview":
            Panels.open(id);
            break;
        }
    }

    // À direita, chaves: { id, label, icon, on (acesa), enabled }. `has`:
    // nightlight (o hyprsunset; sem ele, a chave some) e awake (a ociosidade
    // do shell, que a cafeína segura; desligada, a cafeína fica apagada, sem
    // clique, e a dica diz como ligar); game (o modo jogo do lucernad
    // disponível; sem ele, a chave apagada, com o motivo) e gameOn (ligado).
    function togglesFor(has: var): var {
        return [
            ...(has.nightlight ? [{ id: "nightlight", label: "Luz noturna", icon: "nightlight", on: NightSchedule.on, enabled: true }] : []),
            { id: "dnd", label: "Não perturbe", icon: Icons.bellSleep, on: Config.doNotDisturb, enabled: true },
            has.game ? { id: "game", label: "Modo jogo", icon: "sports_esports", on: has.gameOn === true, enabled: true } : { id: "game", label: "Modo jogo: indisponível sem o lucernad", icon: "sports_esports", on: false, enabled: false },
            { id: "offline", label: "Modo offline", icon: "cloud_off", on: Config.offline, enabled: true },
            has.awake ? { id: "awake", label: "Cafeína: não apagar nem bloquear a tela", icon: "coffee", on: Config.idleInhibit, enabled: true } : { id: "awake", label: "Cafeína: ligue a ociosidade nas configurações para usar", icon: "coffee", on: false, enabled: false }
        ];
    }

    readonly property var quickToggles: togglesFor({ nightlight: NightLight.available, awake: Config.idleEnabled, game: GameMode.available, gameOn: GameMode.active })

    function toggle(id: string): void {
        if (id === "nightlight")
            NightSchedule.setOn(!NightSchedule.on);
        else if (id === "dnd")
            Config.doNotDisturb = !Config.doNotDisturb;
        else if (id === "game" && GameMode.available)
            GameMode.toggle();
        else if (id === "offline")
            Config.offline = !Config.offline;
        else if (id === "awake" && Config.idleEnabled)
            Config.idleInhibit = !Config.idleInhibit;
    }
}
