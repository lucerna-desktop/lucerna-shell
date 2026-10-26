pragma Singleton

import Quickshell

// Ícones do shell: nomes de ligadura da fonte Material Symbols Rounded.
// Escrever o nome como texto, com essa fonte, desenha o ícone.
Singleton {
    readonly property string apps: "apps"
    readonly property string magnify: "search"
    readonly property string terminal: "terminal"
    readonly property string application: "widgets"
    readonly property string close: "close"
    readonly property string check: "check"
    readonly property string arrowRight: "arrow_forward"
    readonly property string chevronLeft: "chevron_left"
    readonly property string chevronRight: "chevron_right"
    readonly property string refresh: "refresh"
    readonly property string edit: "edit"
    readonly property string location: "location_on"

    readonly property string volumeHigh: "volume_up"
    readonly property string volumeMedium: "volume_down"
    readonly property string volumeLow: "volume_mute"
    readonly property string volumeOff: "volume_off"

    readonly property string brightnessLow: "brightness_low"
    readonly property string brightnessMedium: "brightness_medium"
    readonly property string brightnessHigh: "brightness_high"

    readonly property var wifi: ["signal_wifi_0_bar", "network_wifi_1_bar", "network_wifi_2_bar", "network_wifi_3_bar", "signal_wifi_4_bar"]
    readonly property string wifiOff: "wifi_off"
    readonly property string ethernet: "lan"
    readonly property string offline: "signal_wifi_bad"

    readonly property var battery: ["battery_0_bar", "battery_1_bar", "battery_2_bar", "battery_3_bar", "battery_4_bar", "battery_5_bar", "battery_6_bar", "battery_full"]
    readonly property string batteryCharging: "battery_charging_full"
    readonly property string batteryAlert: "battery_alert"

    readonly property string bell: "notifications"
    readonly property string bellOutline: "notifications"
    readonly property string bellBadge: "notifications_active"
    readonly property string bellSleep: "notifications_paused"
    readonly property string clearAll: "clear_all"

    readonly property string palette: "palette"
    readonly property string power: "power_settings_new"
    readonly property string lock: "lock"
    readonly property string lockOpen: "lock_open"
    readonly property string sleep: "bedtime"
    readonly property string restart: "restart_alt"
    readonly property string logout: "logout"

    // Painel superior
    readonly property string dashboard: "dashboard"
    readonly property string media: "music_note"
    readonly property string performance: "speed"
    readonly property string weather: "cloud"
    readonly property string cpu: "developer_board"
    readonly property string memory: "memory_alt"
    readonly property string storage: "hard_drive"
    readonly property string gpu: "videogame_asset"
    readonly property string network: "swap_vert"
    readonly property string download: "download"
    readonly property string upload: "upload"
    readonly property string temperature: "device_thermostat"
    readonly property string uptime: "schedule"
    readonly property string calendar: "calendar_month"
    readonly property string person: "person"
    readonly property string play: "play_arrow"
    readonly property string pause: "pause"
    readonly property string next: "skip_next"
    readonly property string previous: "skip_previous"
    readonly property string lyrics: "lyrics"
    readonly property string album: "album"
    readonly property string musicOff: "music_off"
    readonly property string humidity: "humidity_percentage"
    readonly property string wind: "air"
    readonly property string sunrise: "wb_twilight"
    readonly property string sunset: "bedtime"
    readonly property string rain: "water_drop"

    // Central
    readonly property string wifiOn: "wifi"
    readonly property string bluetooth: "bluetooth"
    readonly property string bluetoothConnected: "bluetooth_connected"
    readonly property string bluetoothOff: "bluetooth_disabled"
    readonly property string bluetoothSearching: "bluetooth_searching"
    readonly property string mic: "mic"
    readonly property string micOff: "mic_off"
    readonly property string speaker: "speaker"
    readonly property string sound: "graphic_eq"
    readonly property string central: "tune"
    // As Ações e as Notificações juntas.
    readonly property string centralBoth: "view_sidebar"
    readonly property string panels: "stacks"
    readonly property string monitor: "desktop_windows"
    readonly property string resolution: "aspect_ratio"
    readonly property string refreshRate: "speed"
    readonly property string zoom: "zoom_in"
    readonly property string rotate: "screen_rotation"
    readonly property string mirror: "screen_share"
    readonly property string vrr: "motion_blur"
    readonly property string colorDepth: "gradient"
    readonly property string identify: "looks_one"
    readonly property string expand: "expand_more"
    readonly property string volumeUp: "volume_up"
    readonly property string volumeDown: "volume_down"
    readonly property string fullscreen: "fullscreen"
    readonly property string float: "picture_in_picture"
    readonly property string pin: "keep"
    readonly property string previousWorkspace: "first_page"
    readonly property string nextWorkspace: "last_page"
    readonly property string block: "block"
    readonly property string mouse: "mouse"
    readonly property string touchpad: "touchpad_mouse"
    readonly property string add: "add"
    readonly property string swap: "swap_horiz"
    readonly property string layout: "language"
    readonly property string repeat: "keyboard_double_arrow_right"
    readonly property string pointerSpeed: "speed"
    readonly property string scroll: "swipe_vertical"
    readonly property string tap: "touch_app"
    readonly property string leftHanded: "back_hand"
    readonly property string focusMouse: "ads_click"
    readonly property string numlock: "dialpad"
    readonly property string compose: "keyboard_command_key"
    readonly property string record: "radio_button_checked"
    readonly property string unlink: "link_off"
    readonly property string trash: "delete"
    readonly property string sync: "sync"
    readonly property string eco: "eco"
    readonly property string balance: "balance"
    readonly property string rocket: "rocket_launch"
    readonly property string bolt: "electric_bolt"

    // Ícone de um dispositivo Bluetooth, pelo tipo que o BlueZ informa (ex.: "audio-headset").
    function forDevice(kind: string): string {
        const k = kind ?? "";
        if (k.includes("headset"))
            return "headset_mic";
        if (k.includes("headphone") || k.includes("audio-card"))
            return "headphones";
        if (k.includes("speaker") || k.startsWith("audio"))
            return "speaker";
        if (k.includes("mouse"))
            return "mouse";
        if (k.includes("keyboard"))
            return "keyboard";
        if (k.includes("gaming") || k.includes("joystick"))
            return "gamepad";
        if (k.includes("phone"))
            return "smartphone";
        if (k.includes("watch"))
            return "watch";
        if (k.includes("computer"))
            return "computer";
        if (k.includes("video") || k.includes("display"))
            return "tv";
        return "bluetooth";
    }

    // Configurações
    readonly property string settings: "settings"
    readonly property string tune: "tune"
    readonly property string blur: "blur_on"
    readonly property string blurOff: "blur_off"
    readonly property string opacity: "opacity"
    readonly property string animation: "animation"
    readonly property string toolbar: "toolbar"
    readonly property string keyboard: "keyboard_command_key"
    readonly property string info: "info"
    readonly property string restore: "settings_backup_restore"
    readonly property string timer: "timer"
    readonly property string soon: "auto_awesome"
    readonly property string wallpaper: "wallpaper"

    // Escolhe o ícone de uma escala (lista) conforme uma fração de 0 a 1.
    function level(list: var, fraction: real): string {
        const i = Math.round(Math.max(0, Math.min(1, fraction)) * (list.length - 1));
        return list[i];
    }

    // Ícone do código de tempo WMO (usado pela Open-Meteo).
    function forWeather(code: int, isDay: bool): string {
        if (code === 0)
            return isDay ? "sunny" : "clear_night";
        if (code <= 2)
            return isDay ? "partly_cloudy_day" : "partly_cloudy_night";
        if (code === 3)
            return "cloud";
        if (code <= 48)
            return "foggy";
        if (code <= 57)
            return "rainy_light";
        if (code <= 65 || (code >= 80 && code <= 82))
            return code === 65 || code === 82 ? "rainy_heavy" : "rainy";
        if (code <= 67)
            return "weather_hail";
        if (code <= 77 || code === 85 || code === 86)
            return "weather_snowy";
        return "thunderstorm";
    }
}
