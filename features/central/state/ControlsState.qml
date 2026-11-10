pragma Singleton

import QtQuick
import Quickshell
import qs.core.config
import qs.core.nightlight
import qs.core.panels
import qs.core.widgets
import qs.services

// View model do painel de ações da central: os tiles (Wi-Fi, Bluetooth, saída
// de áudio, bateria, microfone, luz noturna, não perturbe e não apagar a tela)
// e o brilho da tela em foco. O volume vem do SoundState.
Singleton {
    id: root

    // A tela em foco: a externa desse monitor, se tiver DDC; senão a integrada.
    readonly property var screenBrightness: Brightness.focusedScreen
    readonly property bool hasBrightness: screenBrightness !== null
    readonly property real brightness: screenBrightness?.value ?? 0

    // A tela em que o arrasto do slider começou ("" fora dele). Um 1003 no
    // meio do arrasto tira a tela do foco: o resto dele não passa para a
    // próxima tela, que o usuário não escolheu.
    property string dragged: ""

    // `dragging`: o valor vem do arrasto (o teclado e a roda vão sempre à
    // tela em foco).
    function setBrightness(value: real, dragging: bool): void {
        const id = screenBrightness?.id ?? "";
        if (dragging && dragged === "")
            dragged = id;
        if (id !== "" && (!dragging || dragged === id))
            Brightness.setScreen(id, value);
    }

    // O arrasto acabou.
    function dropBrightness(): void {
        dragged = "";
    }

    // Os tiles do que existe agora, na ordem do grid.
    readonly property var tiles: tilesFor(Object.assign({ nightlight: NightLight.available, awake: Config.idleEnabled }, CentralState.has))

    // Um tile: { id, title, status (a linha de estado), icon, checked (cheio),
    // page (a da setinha, "" sem página), toggles (o corpo liga e desliga; sem
    // ele, o corpo abre a página), clickable, alert (o ícone na cor de erro) }.
    function tile(id: string, title: string, status: string, icon: string, checked: bool, page: string, toggles: bool): var {
        return { id, title, status, icon, checked, page, toggles, clickable: toggles || page !== "", alert: false };
    }

    // `has`: o CentralState.has mais `nightlight` (o hyprsunset) e `awake` (a
    // ociosidade do shell). O que não existe some; sem placa Wi-Fi, o tile
    // vira "Rede", que só informa.
    function tilesFor(has: var): var {
        const onOff = on => on ? "Ligado" : "Desligado";
        const battery = tile("battery", PowerState.title, PowerState.status, PowerState.icon, false, "battery", false);
        battery.alert = PowerState.hasBattery && PowerState.low;
        return [
            has.wifi ? tile("wifi", "Wi-Fi", WifiState.summary, WifiState.icon, WifiState.enabled && !WifiState.hardwareBlocked, "wifi", true) : tile("network", "Rede", WifiState.summary, WifiState.icon, false, "", false),
            ...(has.bluetooth ? [tile("bluetooth", "Bluetooth", BluetoothState.summary, BluetoothState.icon, BluetoothState.enabled, "bluetooth", true)] : []),
            ...(has.output ? [tile("output", "Saída de áudio", SoundState.outputName, SoundState.volumeIcon, false, "output", false)] : []),
            ...(has.power ? [battery] : []),
            ...(has.input ? [tile("input", "Microfone", SoundState.micMuted ? "Mudo" : SoundState.inputName, SoundState.micIcon, !SoundState.micMuted, "input", true)] : []),
            ...(has.nightlight ? [tile("nightlight", "Luz noturna", NightSchedule.on ? "Ligada" : "Desligada", "nightlight", NightSchedule.on, "", true)] : []),
            tile("dnd", "Não perturbe", onOff(Config.doNotDisturb), Icons.bellSleep, Config.doNotDisturb, "", true),
            ...(has.awake ? [tile("awake", "Não apagar a tela", onOff(Config.idleInhibit), "coffee", Config.idleInhibit, "", true)] : [])
        ];
    }

    // Clique no corpo de um tile: liga ou desliga o recurso; sem liga/desliga
    // (e com o Wi-Fi bloqueado), abre a página.
    function activate(id: string): void {
        if (id === "wifi" && WifiState.hardwareBlocked)
            CentralState.setPage("wifi");
        else if (id === "wifi")
            WifiState.setEnabled(!WifiState.enabled);
        else if (id === "bluetooth")
            BluetoothState.setEnabled(!BluetoothState.enabled);
        else if (id === "output" || id === "battery")
            CentralState.setPage(id);
        else if (id === "input")
            SoundState.toggleMicMute();
        else if (id === "nightlight")
            NightSchedule.setOn(!NightSchedule.on);
        else if (id === "dnd")
            Config.doNotDisturb = !Config.doNotDisturb;
        else if (id === "awake")
            Config.idleInhibit = !Config.idleInhibit;
    }

    function openSettings(): void {
        Panels.open("settings");
    }
}
