pragma Singleton

import QtQuick
import Quickshell
import qs.core.config
import qs.core.panels
import qs.core.widgets
import qs.services

// Mostra o OSD quando o volume ou o brilho mudam, venha a mudança de onde vier
// (atalho, outro app, a própria barra). Com a central aberta, não: ele sairia
// da mesma borda, por cima dela, e os controles dela já mostram o valor.
// O tipo "game" avisa a entrada e a saída do modo jogo (sem valor nem barra),
// só numa troca vista com o lucernad conectado e com o item ligado.
Singleton {
    id: root

    property string kind: "volume"
    property bool shown: false
    // Ignora os valores iniciais, lidos na partida.
    property bool armed: false

    // Fica no monitor onde apareceu enquanto está à mostra (ver
    // Panels.screenFor).
    property var shownOn: null
    readonly property var screen: Panels.screenFor(shownOn, Quickshell.screens, Hypr.focusedScreen)
    readonly property real value: kind === "volume" ? Audio.volume : kind === "brightness" ? Brightness.shownValue : 0
    // O modo jogo do último aviso "game".
    property bool gameOn: false
    readonly property string text: kind === "game" ? (gameOn ? "Modo jogo ligado" : "Modo jogo desligado") : ""
    readonly property bool muted: kind === "volume" && Audio.muted
    readonly property int percent: Math.round(value * 100)
    readonly property string icon: kind === "game" ? "sports_esports" : kind === "brightness"
        ? (value < 0.34 ? Icons.brightnessLow : value < 0.67 ? Icons.brightnessMedium : Icons.brightnessHigh)
        : (muted || value === 0 ? Icons.volumeOff : value < 0.34 ? Icons.volumeLow : value < 0.67 ? Icons.volumeMedium : Icons.volumeHigh)

    function show(which: string): void {
        if (!armed || Panels.isOpen("central"))
            return;
        kind = which;
        if (!shown)
            shownOn = Hypr.focusedScreen;
        shown = true;
        hideTimer.restart();
    }

    function showGame(on: bool): void {
        gameOn = on;
        show("game");
    }

    // Uma troca do modo jogo vista pelo GameMode (nunca o primeiro estado).
    function gameChanged(on: bool): void {
        if (Config.gameNotices)
            showGame(on);
    }

    Connections {
        target: GameMode

        function onChangedByDaemon(active: bool): void {
            root.gameChanged(active);
        }
    }

    Connections {
        target: Audio

        function onVolumeChanged() {
            root.show("volume");
        }

        function onMutedChanged() {
            root.show("volume");
        }
    }

    Connections {
        target: Brightness

        // Só com a integrada presente e sem erro: o value não muda sem ela.
        function onValueChanged() {
            if (Brightness.hasPanel)
                root.show("brightness");
        }

        function onAdjusted() {
            root.show("brightness");
        }
    }

    Timer {
        running: true
        interval: 1500
        onTriggered: root.armed = true
    }

    Timer {
        id: hideTimer

        interval: root.kind === "game" ? 2200 : 1600
        onTriggered: root.shown = false
    }
}
