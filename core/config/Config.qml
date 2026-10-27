pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Preferências do usuário, persistidas em ~/.local/state/quickshell/.../config.json.
// Qualquer alteração numa propriedade é gravada no disco automaticamente.
Singleton {
    id: root

    property alias theme: adapter.theme
    property alias doNotDisturb: adapter.doNotDisturb
    property alias dashboardTab: adapter.dashboardTab
    property alias weatherLocation: adapter.weatherLocation
    property alias transparencyOverride: adapter.transparencyOverride
    property alias blurOverride: adapter.blurOverride
    property alias animationScale: adapter.animationScale
    property alias notificationTimeout: adapter.notificationTimeout
    property alias settingsTopic: adapter.settingsTopic
    property alias outlines: adapter.outlines
    property alias barPeek: adapter.barPeek
    property alias barShowDate: adapter.barShowDate
    property alias barOnEmpty: adapter.barOnEmpty
    property alias dashboardTabOrder: adapter.dashboardTabOrder
    property alias dashboardTabsHidden: adapter.dashboardTabsHidden
    property alias dashboardStartTab: adapter.dashboardStartTab
    property alias dashboardHoverOpen: adapter.dashboardHoverOpen
    property alias dashboardHoverClose: adapter.dashboardHoverClose
    property alias overviewHidden: adapter.overviewHidden
    property alias weekStart: adapter.weekStart
    property alias lyricsEnabled: adapter.lyricsEnabled
    property alias audioPulse: adapter.audioPulse
    property alias statsInterval: adapter.statsInterval
    property alias showGpu: adapter.showGpu
    property alias temperatureUnit: adapter.temperatureUnit
    property alias windUnit: adapter.windUnit
    property alias weatherRefresh: adapter.weatherRefresh
    property alias offline: adapter.offline
    property alias vagalumeKey: adapter.vagalumeKey
    property alias batteryShowPercent: adapter.batteryShowPercent
    property alias batteryLowLevel: adapter.batteryLowLevel
    property alias batteryCriticalLevel: adapter.batteryCriticalLevel
    property alias batteryNotifyFull: adapter.batteryNotifyFull
    property alias batteryNotifyPlug: adapter.batteryNotifyPlug
    property alias batteryCriticalAction: adapter.batteryCriticalAction
    property alias autoProfile: adapter.autoProfile
    property alias profileOnBattery: adapter.profileOnBattery
    property alias profileOnAC: adapter.profileOnAC
    property alias saverBelowEnabled: adapter.saverBelowEnabled
    property alias saverBelow: adapter.saverBelow
    property alias batteryLightMode: adapter.batteryLightMode
    property alias panelsTogether: adapter.panelsTogether
    property alias monitorSetups: adapter.monitorSetups
    property alias monitorsAtLogin: adapter.monitorsAtLogin
    property alias inputOptions: adapter.inputOptions
    property alias themeWallpapers: adapter.themeWallpapers
    property alias wallpaperMode: adapter.wallpaperMode
    property alias wallpaperMonitors: adapter.wallpaperMonitors
    property alias wallpaperFps: adapter.wallpaperFps
    property alias wallpaperBatteryStatic: adapter.wallpaperBatteryStatic
    property alias wallpaperStrict: adapter.wallpaperStrict
    property alias wallpaperFill: adapter.wallpaperFill
    property alias wallpaperFullRes: adapter.wallpaperFullRes
    property alias wallpaperFolder: adapter.wallpaperFolder
    property alias videoVariants: adapter.videoVariants
    property alias launcherStyle: adapter.launcherStyle
    property alias idleEnabled: adapter.idleEnabled
    property alias idleAC: adapter.idleAC
    property alias idleBattery: adapter.idleBattery
    property alias idleMedia: adapter.idleMedia
    property alias idleFullscreen: adapter.idleFullscreen
    property alias idleInhibit: adapter.idleInhibit
    property alias nightLightEnabled: adapter.nightLightEnabled
    property alias nightLightSchedule: adapter.nightLightSchedule
    property alias nightLightFrom: adapter.nightLightFrom
    property alias nightLightTo: adapter.nightLightTo
    property alias nightLightTemp: adapter.nightLightTemp
    property alias nightLightOverride: adapter.nightLightOverride
    property alias launcherFavorites: adapter.launcherFavorites
    property alias launcherUsage: adapter.launcherUsage
    property alias launcherHidden: adapter.launcherHidden
    property alias launcherSearchEngine: adapter.launcherSearchEngine
    property alias wallpaperVideoPrecache: adapter.wallpaperVideoPrecache
    property alias mouseDevices: adapter.mouseDevices
    property alias keyboardLayouts: adapter.keyboardLayouts
    property alias keyboardOptions: adapter.keyboardOptions
    property alias keyRemaps: adapter.keyRemaps
    property alias inputBinds: adapter.inputBinds
    property alias shellShortcuts: adapter.shellShortcuts
    property alias clipboardEnabled: adapter.clipboardEnabled
    property alias clipboardLimit: adapter.clipboardLimit
    property alias clipboardPersist: adapter.clipboardPersist
    property alias clipboardPaste: adapter.clipboardPaste
    property alias captureMode: adapter.captureMode
    property alias captureTarget: adapter.captureTarget
    property alias captureArea: adapter.captureArea
    property alias captureDelay: adapter.captureDelay
    property alias captureCursor: adapter.captureCursor
    property alias captureCopy: adapter.captureCopy
    property alias captureAudio: adapter.captureAudio
    property alias captureFps: adapter.captureFps
    property alias captureFolder: adapter.captureFolder
    property alias recordFolder: adapter.recordFolder

    FileView {
        path: Quickshell.statePath("config.json")
        blockLoading: true
        // Grava de forma síncrona: a gravação precisa terminar antes de o
        // watcher disparar o reload, senão ele lê o arquivo antigo e desfaz
        // as mudanças feitas no mesmo turno.
        blockWrites: true
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: adapter

            property string theme: "catppuccin-mocha"
            property bool doNotDisturb: false
            property string dashboardTab: "overview"
            // { name, latitude, longitude } da cidade escolhida na aba Clima
            property var weatherLocation: null
            // Ajustes do usuário por cima do tema; null = seguir o tema.
            //   transparencyOverride: { enabled, base, layers }
            //   blurOverride: { enabled, size, passes }
            property var transparencyOverride: null
            property var blurOverride: null
            // Velocidade das animações; negativo = seguir o tema.
            property real animationScale: -1
            // Tempo padrão dos popups de notificação, em ms.
            property int notificationTimeout: 5000
            property string settingsTopic: "glass"
            // Contorno nos cartões; null = seguir o tema.
            property var outlines: null
            // Barra (sempre se escondendo sozinha; aparece ao encostar o mouse
            // no topo): aparece por um instante ao trocar de workspace, e mostra a data.
            property bool barPeek: true
            property bool barShowDate: true
            // A barra fica à mostra quando o workspace não tem janelas.
            property bool barOnEmpty: true

            // Painel superior
            property var dashboardTabOrder: ["overview", "media", "performance", "weather"]
            property var dashboardTabsHidden: []
            // "last" (a última usada) ou o id de uma aba
            property string dashboardStartTab: "last"
            property bool dashboardHoverOpen: false
            property bool dashboardHoverClose: false
            // Cartões escondidos da visão geral: user, clock, weather, calendar, resources, media
            property var overviewHidden: []
            // Primeiro dia da semana no calendário: 0 domingo, 1 segunda
            property int weekStart: 0
            property bool lyricsEnabled: true
            property bool audioPulse: true
            // Intervalo da aba Desempenho, em ms
            property int statsInterval: 2000
            property bool showGpu: true
            // "c" ou "f"; "kmh" ou "ms"
            property string temperatureUnit: "c"
            property string windUnit: "kmh"
            // Atualização do clima, em minutos
            property int weatherRefresh: 30
            // Desliga tudo o que usa a internet (clima e letras)
            property bool offline: false
            // A chave do Vagalume, do próprio usuário; só vai ao lucernad pelo web.configure
            property string vagalumeKey: ""

            // Energia e bateria
            property bool batteryShowPercent: true
            // Avisos, em %
            property int batteryLowLevel: 15
            property int batteryCriticalLevel: 5
            property bool batteryNotifyFull: false
            property bool batteryNotifyPlug: false
            // No nível crítico: "none", "suspend", "hibernate" ou "poweroff"
            property string batteryCriticalAction: "none"
            // Trocar o perfil de energia ao tirar/pôr na tomada (0 economia, 1 equilibrado, 2 desempenho)
            property bool autoProfile: false
            property int profileOnBattery: 0
            property int profileOnAC: 1
            // Entrar em economia abaixo de um nível, na bateria
            property bool saverBelowEnabled: false
            property int saverBelow: 20
            // Na bateria: sem transparência/desfoque e animações mais rápidas
            property bool batteryLightMode: false
            // Painéis que ficam abertos junto das configurações (só o
            // dashboard; os outros são modais).
            property var panelsTogether: ["dashboard"]
            // Arranjos de monitores salvos, um por conjunto conectado
            // (Monitors.setup): { setup: { chaveDoMonitor: spec } }.
            property var monitorSetups: ({})
            // Gravar o arranjo num arquivo que o hyprland.lua inclui (vale no login).
            property bool monitorsAtLogin: false
            // Entrada. Só o que foi mudado nas configurações; o resto segue o
            // hyprland.lua. Opções: { "input.sensitivity": 0.2, ... }.
            property var inputOptions: ({})
            // Papel de parede escolhido por tema (ver ThemeManager.wallpaperFor).
            property var themeWallpapers: ({})
            // "auto" (animado se o papel tiver efeito), "animated" ou "static".
            property string wallpaperMode: "auto"
            // Por monitor: { "HDMI-A-1": { mode, source } }; source = id de outro tema.
            property var wallpaperMonitors: ({})
            // Quadros por segundo dos animados: 30 ou 60 (60 cai para 30 na bateria).
            property int wallpaperFps: 30
            // No modo auto, fora da tomada fica a imagem parada.
            property bool wallpaperBatteryStatic: true
            // Pausar também quando há janelas no workspace (sobra pouco à mostra).
            property bool wallpaperStrict: false
            // Imagens do usuário: "crop" (preenche cortando) ou "fit" (inteira).
            property string wallpaperFill: "crop"
            // Animado em resolução cheia (padrão: metade, ampliada).
            property bool wallpaperFullRes: false
            // Última pasta aberta no seletor de imagens.
            property string wallpaperFolder: ""
            // Versões convertidas de cada vídeo, uma por tela:
            // { "/caminho/original.mp4": { "2560x1080-c-30": { video, poster, used } } }.
            property var videoVariants: ({})
            // Launcher: "compact" (busca e lista), "full" (categorias, grade e
            // detalhes) ou "grid" (tela cheia, como uma gaveta de apps).
            property string launcherStyle: "compact"
            // Ociosidade: tempos (em segundos; 0 = nunca) para escurecer,
            // desligar a tela, bloquear e suspender, na tomada e na bateria.
            property bool idleEnabled: true
            property var idleAC: ({ dim: 240, off: 300, lock: 600, suspend: 0 })
            property var idleBattery: ({ dim: 120, off: 180, lock: 300, suspend: 900 })
            // Não contar ociosidade com mídia tocando ou app em tela cheia.
            property bool idleMedia: true
            property bool idleFullscreen: true
            // "Não apagar a tela": segura tudo até ser desligado.
            property bool idleInhibit: false
            // Luz noturna: "sun" (do pôr ao nascer do sol, pela cidade do
            // clima), "custom" (de/até, "HH:MM") ou "always". Temperatura em K.
            property bool nightLightEnabled: false
            property string nightLightSchedule: "sun"
            property string nightLightFrom: "20:00"
            property string nightLightTo: "06:30"
            property int nightLightTemp: 4000
            // Ligada ou desligada à mão até a próxima virada: { on, until } (ms).
            property var nightLightOverride: null
            // Apps fixados (ids), quantas vezes cada um foi aberto e os ocultos.
            property var launcherFavorites: []
            property var launcherUsage: ({})
            property var launcherHidden: []
            // Buscador da categoria Web.
            property string launcherSearchEngine: "duckduckgo"
            // Preparar vídeos também para resoluções comuns (na tomada, sem pressa).
            property bool wallpaperVideoPrecache: false
            // Velocidade própria por mouse: { nome: { sensitivity, accel_profile } }.
            property var mouseDevices: ({})
            // Layouts [{ layout, variant }] e opções do xkb; null = os do hyprland.lua.
            property var keyboardLayouts: null
            property var keyboardOptions: null
            // Teclas remapeadas: [{ from: "CAPS", to: { kind: "key"|"sym"|"none", value } }].
            property var keyRemaps: []
            // Botões e teclas mapeados para ações:
            // [{ trigger, mods, label, action: { id, keys?, command? } }].
            property var inputBinds: []
            // Atalhos do shell que o usuário mudou: { <id da ação>: [{ mods, trigger }] }
            // (os padrões estão em core/input/ShellShortcuts).
            property var shellShortcuts: ({})
            // Histórico da área de transferência: guardar, quantos, manter ao
            // reiniciar e colar direto ao escolher.
            property bool clipboardEnabled: true
            property int clipboardLimit: 100
            property bool clipboardPersist: true
            property bool clipboardPaste: true
            // Captura: o último modo ("shot" ou "record"), alvo ("area",
            // "window", "screen") e área (global); espera em segundos, cursor
            // na foto, copiar a foto, som da gravação ("none", "system",
            // "mic"), quadros por segundo e as pastas ("" = a padrão, dentro
            // de Imagens e Vídeos).
            property string captureMode: "shot"
            property string captureTarget: "area"
            property var captureArea: null
            property int captureDelay: 0
            property bool captureCursor: false
            property bool captureCopy: true
            property string captureAudio: "none"
            property int captureFps: 30
            property string captureFolder: ""
            property string recordFolder: ""
        }
    }
}
