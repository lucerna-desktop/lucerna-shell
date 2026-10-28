pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.core.config
import qs.services

// Ociosidade, sem o hypridle: depois de um tempo sem mexer no mouse ou no
// teclado, escurece a tela, desliga (DPMS), bloqueia e suspende, cada etapa
// com seu tempo (um na tomada, outro na bateria; 0 = nunca). Qualquer entrada
// desfaz o escurecer e religa a tela. Não conta a ociosidade com mídia
// tocando, com um app em tela cheia, no modo jogo (opcional, cada um) nem com
// o "não apagar" ligado; os inibidores dos apps (um navegador tocando vídeo) também
// valem.
Singleton {
    id: root

    readonly property var times: Battery.available && Battery.onBattery ? (Config.idleBattery ?? {}) : (Config.idleAC ?? {})
    readonly property bool mediaPlaying: Media.players.some(p => p.isPlaying)
    readonly property bool fullscreen: Quickshell.screens.some(s => Hypr.hasFullscreen(s))
    // O modo jogo (com o item ligado nas configurações) segura a ociosidade.
    readonly property bool gameHeld: Config.gameIdle && GameMode.active
    readonly property var holds: ({
            enabled: Config.idleEnabled,
            inhibit: Config.idleInhibit,
            game: gameHeld,
            media: Config.idleMedia && mediaPlaying,
            fullscreen: Config.idleFullscreen && fullscreen
        })
    readonly property bool held: holds.inhibit || holds.game || holds.media || holds.fullscreen
    readonly property bool active: Config.idleEnabled && !held

    // Por que não está contando (para mostrar nas configurações).
    readonly property string holdReason: reasonFor(holds)

    // O primeiro motivo que segura, na ordem em que aparece; "" com a
    // ociosidade desligada ou contando.
    function reasonFor(h: var): string {
        if (!h.enabled)
            return "";
        if (h.inhibit)
            return "“Não apagar a tela” está ligado";
        if (h.game)
            return "O modo jogo está ligado";
        if (h.media)
            return "Há mídia tocando";
        if (h.fullscreen)
            return "Há um app em tela cheia";
        return "";
    }

    function stage(name: string): real {
        return Number(times[name] ?? 0);
    }

    readonly property bool dimmed: dimMonitor.isIdle

    IdleMonitor {
        id: dimMonitor

        enabled: root.active && root.stage("dim") > 0
        timeout: Math.max(1, root.stage("dim"))
        respectInhibitors: true
    }

    IdleMonitor {
        id: offMonitor

        enabled: root.active && root.stage("off") > 0
        timeout: Math.max(1, root.stage("off"))
        respectInhibitors: true
        onIsIdleChanged: Hypr.dpms(!isIdle)
    }

    IdleMonitor {
        id: lockMonitor

        enabled: root.active && root.stage("lock") > 0
        timeout: Math.max(1, root.stage("lock"))
        respectInhibitors: true
        onIsIdleChanged: {
            if (isIdle && !Session.locked)
                Session.lock();
        }
    }

    IdleMonitor {
        id: suspendMonitor

        enabled: root.active && root.stage("suspend") > 0
        timeout: Math.max(1, root.stage("suspend"))
        respectInhibitors: true
        onIsIdleChanged: {
            if (isIdle)
                Session.suspend();
        }
    }

    // Se a ociosidade parar de contar com a tela desligada (mídia começou,
    // "não apagar" ligado), a tela volta.
    onActiveChanged: {
        if (!active)
            Hypr.dpms(true);
    }

    IpcHandler {
        target: "idle"

        // "Não apagar a tela": inhibit(true|false) ou toggle.
        function inhibit(on: bool): void {
            Config.idleInhibit = on;
        }

        function toggle(): void {
            Config.idleInhibit = !Config.idleInhibit;
        }

        function status(): string {
            return !Config.idleEnabled ? "desligada" : root.held ? `segurada: ${root.holdReason}` : "contando";
        }
    }
}
