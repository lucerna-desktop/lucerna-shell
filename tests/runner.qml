// Harness dos testes de unidade (tests/*.test.js). O ci/unit.sh copia este
// arquivo e os testes para a raiz de uma cópia do repositório, ao lado do
// shell.qml (para os imports qs.* resolverem), e roda com o qs. Cada arquivo
// de teste tem run(t); `t` traz test, check, eq, near, object, enums e os
// singletons. Saída: PASS ou FAIL por caso, "SUITE <nome> casos=N" por suíte e,
// no fim, "RESULT passed=N failed=M".
import QtQuick
import Quickshell
import Quickshell.Bluetooth as QsBluetooth
import Quickshell.Networking as QsNet
import Quickshell.Services.Notifications as QsNotifications
import qs.core.carousel
import qs.core.config
import qs.core.format
import qs.core.frame
import qs.core.input
import qs.core.launcher
import qs.core.nightlight
import qs.core.panels
import qs.core.shapes
import qs.core.theme
import qs.core.time
import qs.core.widgets
import qs.features.bar.state
import qs.features.central.state
import qs.features.clipboard.state
import qs.features.dashboard.state
import qs.features.idle.state
import qs.features.input.state
import qs.features.notifications.state
import qs.features.osd.state
import qs.features.settings.state
import qs.features.themeSwitcher.state
import qs.features.wallpaper.state
import qs.services
import qs.services.lucerna
import "appinfo.test.js" as AppInfoTest
import "audio.test.js" as AudioTest
import "audiostreams.test.js" as AudioStreamsTest
import "bar.test.js" as BarTest
import "battery.test.js" as BatteryTest
import "blobshapes.test.js" as BlobShapesTest
import "bluetooth.test.js" as BluetoothTest
import "brightness.test.js" as BrightnessTest
import "capture.test.js" as CaptureTest
import "carousel.test.js" as CarouselTest
import "central.test.js" as CentralTest
import "clipboard.test.js" as ClipboardTest
import "clipboardstate.test.js" as ClipboardStateTest
import "format.test.js" as FormatTest
import "idle.test.js" as IdleTest
import "gamemode.test.js" as GameModeTest
import "gamemodestate.test.js" as GameModeStateTest
import "frame.test.js" as FrameTest
import "input.test.js" as InputTest
import "inputactions.test.js" as InputActionsTest
import "lucernaclient.test.js" as LucernaClientTest
import "lyrics.test.js" as LyricsTest
import "media.test.js" as MediaTest
import "monitors.test.js" as MonitorsTest
import "network.test.js" as NetworkTest
import "nightschedule.test.js" as NightScheduleTest
import "notifications.test.js" as NotificationsTest
import "osd.test.js" as OsdTest
import "overview.test.js" as OverviewTest
import "panels.test.js" as PanelsTest
import "performance.test.js" as PerformanceTest
import "searchengines.test.js" as SearchEnginesTest
import "session.test.js" as SessionTest
import "shellshortcuts.test.js" as ShellShortcutsTest
import "spectrum.test.js" as SpectrumTest
import "sun.test.js" as SunTest
import "systemstats.test.js" as SystemStatsTest
import "theme.test.js" as ThemeTest
import "themeswitcher.test.js" as ThemeSwitcherTest
import "videowallpapers.test.js" as VideoWallpapersTest
import "wallpaper.test.js" as WallpaperTest
import "web.test.js" as WebTest
import "weather.test.js" as WeatherTest
import "weatherstate.test.js" as WeatherStateTest
import "credits.test.js" as CreditsTest

ShellRoot {
    id: root

    property int passed: 0
    property int failed: 0
    property string current: ""
    property bool currentFailed: false

    // Um item por arquivo em tests/*.test.js, com o nome do arquivo sem
    // .test.js: o ci/unit.sh exige uma linha "SUITE <nome> casos=N" (N > 0) de cada.
    readonly property var suites: [
        ["spectrum", SpectrumTest],
        ["sun", SunTest],
        ["format", FormatTest],
        ["carousel", CarouselTest],
        ["blobshapes", BlobShapesTest],
        ["shellshortcuts", ShellShortcutsTest],
        ["inputactions", InputActionsTest],
        ["nightschedule", NightScheduleTest],
        ["theme", ThemeTest],
        ["panels", PanelsTest],
        ["frame", FrameTest],
        ["bar", BarTest],
        ["central", CentralTest],
        ["overview", OverviewTest],
        ["performance", PerformanceTest],
        ["searchengines", SearchEnginesTest],
        ["clipboard", ClipboardTest],
        ["clipboardstate", ClipboardStateTest],
        ["capture", CaptureTest],
        ["brightness", BrightnessTest],
        ["monitors", MonitorsTest],
        ["input", InputTest],
        ["systemstats", SystemStatsTest],
        ["videowallpapers", VideoWallpapersTest],
        ["wallpaper", WallpaperTest],
        ["lyrics", LyricsTest],
        ["notifications", NotificationsTest],
        ["osd", OsdTest],
        ["network", NetworkTest],
        ["bluetooth", BluetoothTest],
        ["audio", AudioTest],
        ["audiostreams", AudioStreamsTest],
        ["battery", BatteryTest],
        ["appinfo", AppInfoTest],
        ["media", MediaTest],
        ["session", SessionTest],
        ["weather", WeatherTest],
        ["weatherstate", WeatherStateTest],
        ["credits", CreditsTest],
        ["web", WebTest],
        ["gamemode", GameModeTest],
        ["gamemodestate", GameModeStateTest],
        ["idle", IdleTest],
        ["themeswitcher", ThemeSwitcherTest],
        ["lucernaclient", LucernaClientTest]
    ]

    function fail(message: string): void {
        currentFailed = true;
        console.error(`FAIL ${current}: ${message}`);
    }

    // A mensagem de check, eq e near é opcional: tipada como string, a que
    // falta chegaria como o texto "undefined".
    function check(condition: bool, message: var): void {
        if (!condition)
            fail(message || "condição falsa");
    }

    function eq(actual: var, expected: var, message: var): void {
        const a = JSON.stringify(actual);
        const e = JSON.stringify(expected);
        if (a !== e)
            fail(`${message ? `${message}: ` : ""}esperado ${e}, veio ${a}`);
    }

    function near(actual: real, expected: real, tolerance: real, message: var): void {
        if (!(Math.abs(actual - expected) <= tolerance))
            fail(`${message ? `${message}: ` : ""}esperado ${expected} ± ${tolerance}, veio ${actual}`);
    }

    function test(name: string, body: var): void {
        current = name;
        currentFailed = false;
        try {
            const result = body();
            if (result && typeof result.then === "function")
                fail("caso assíncrono não suportado");
        } catch (e) {
            fail(`exceção: ${e}`);
        }
        if (currentFailed) {
            failed++;
        } else {
            passed++;
            console.info(`PASS ${name}`);
        }
    }

    // Um QtObject novo, para testes que registram objetos (Panels.register).
    function object(): var {
        return dummy.createObject(root);
    }

    // Um cartão de notificação solto (sem notificação), com as propriedades
    // iniciais, como o delegate dos popups o cria; para o prazo do popup.
    function card(props: var): var {
        return notificationCard.createObject(root, props);
    }

    // Um cliente do protocolo solto (app "teste", sem socketPath: nunca conecta).
    function lucernaClient(): var {
        return lucernaClientComponent.createObject(root);
    }

    // O web.weather do Formato, com 7 dias; um objeto novo a cada chamada.
    function weatherSample(): var {
        const codes = [95, 3, 2, 1, 0, 61, 80];
        return {
            location: { name: "Cacaulândia, Rondônia, BR", latitude: -10.3375, longitude: -62.8986 },
            state: "ready",
            updatedAt: 1792847400,
            current: { temperature: 31.2, apparent: 35.0, humidity: 58, wind: 7.6, code: 2, isDay: true },
            daily: codes.map((code, i) => ({
                date: `2026-10-${24 + i}`,
                code: code,
                min: i === 0 ? 22.1 : 21 + i,
                max: i === 0 ? 33.4 : 30 + i,
                precipitation: i === 0 ? 80 : 10 * i
            })),
            sunrise: "2026-10-24T05:41",
            sunset: "2026-10-24T18:03"
        };
    }

    function enums(): var {
        return {
            wifiOpen: QsNet.WifiSecurityType.Open,
            wifiOwe: QsNet.WifiSecurityType.Owe,
            btConnected: QsBluetooth.BluetoothDeviceState.Connected,
            btConnecting: QsBluetooth.BluetoothDeviceState.Connecting,
            btDisconnecting: QsBluetooth.BluetoothDeviceState.Disconnecting,
            urgencyNormal: QsNotifications.NotificationUrgency.Normal,
            urgencyCritical: QsNotifications.NotificationUrgency.Critical
        };
    }

    // O `t` de cada suíte. Os singletons vêm por getters: só é criado o que o
    // teste usa (cada um sobe o seu Process, D-Bus ou PipeWire).
    function context(): var {
        return {
            test: root.test,
            check: root.check,
            eq: root.eq,
            near: root.near,
            object: root.object,
            card: root.card,
            lucernaClient: root.lucernaClient,
            enums: root.enums(),
            get Config() { return Config; },
            get Format() { return Format; },
            get Carousel() { return Carousel; },
            get BlobShapes() { return BlobShapes; },
            get InputActions() { return InputActions; },
            get ShellShortcuts() { return ShellShortcuts; },
            get SearchEngines() { return SearchEngines; },
            get NightSchedule() { return NightSchedule; },
            get Panels() { return Panels; },
            get Frame() { return Frame; },
            get BarState() { return BarState; },
            get CentralState() { return CentralState; },
            get DashboardState() { return DashboardState; },
            get Hypr() { return Hypr; },
            get screens() { return Quickshell.screens; },
            get ClipboardState() { return ClipboardState; },
            get ControlsState() { return ControlsState; },
            get NotificationsState() { return NotificationsState; },
            get OsdState() { return OsdState; },
            get PowerState() { return PowerState; },
            get OverviewState() { return OverviewState; },
            get PerformanceState() { return PerformanceState; },
            get ThemeManager() { return ThemeManager; },
            get Sun() { return Sun; },
            get AppInfo() { return AppInfo; },
            get Audio() { return Audio; },
            get AudioStreams() { return AudioStreams; },
            get Battery() { return Battery; },
            get Bluetooth() { return Bluetooth; },
            get Brightness() { return Brightness; },
            get Capture() { return Capture; },
            get Clipboard() { return Clipboard; },
            get Input() { return Input; },
            get Lyrics() { return Lyrics; },
            get Media() { return Media; },
            get Monitors() { return Monitors; },
            get Network() { return Network; },
            get Notifications() { return Notifications; },
            get Session() { return Session; },
            get Spectrum() { return Spectrum; },
            get SystemStats() { return SystemStats; },
            get VideoWallpapers() { return VideoWallpapers; },
            get Weather() { return Weather; },
            get Web() { return Web; },
            get GameMode() { return GameMode; },
            get IdleState() { return IdleState; },
            get InputState() { return InputState; },
            get MediaState() { return MediaState; },
            get SettingsState() { return SettingsState; },
            get GameModeState() { return GameModeState; },
            get WeatherState() { return WeatherState; },
            weatherSample: root.weatherSample,
            get ThemeSwitcherState() { return ThemeSwitcherState; },
            get WallpaperState() { return WallpaperState; }
        };
    }

    Component {
        id: dummy

        QtObject {}
    }

    Component {
        id: lucernaClientComponent

        LucernaClient {
            app: "teste"
            socketPath: ""
        }
    }

    Component {
        id: notificationCard

        NotificationCard {
            notification: null
        }
    }

    Component.onCompleted: {
        for (const [name, suite] of suites) {
            const before = passed + failed;
            let broke = false;
            try {
                suite.run(context());
            } catch (e) {
                broke = true;
                console.error(`FAIL ${name}: a suíte quebrou fora de um caso: ${e}`);
            }
            console.info(`SUITE ${name} casos=${passed + failed - before}`);
            if (broke)
                failed++;
        }
        if (passed + failed === 0) {
            failed++;
            console.error("FAIL nenhum caso rodou");
        }
        // @cov-dump
        console.info(`RESULT passed=${passed} failed=${failed}`);
        // No onCompleted o Qt.exit é ignorado; depois do evento, vale.
        Qt.callLater(() => Qt.exit(failed > 0 ? 1 : 0));
    }
}
