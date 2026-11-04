pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Bloqueio e energia. No modo de desenvolvimento (LUCERNA_DEV=1) suspender,
// reiniciar e desligar são só simulados: dentro do container, com o D-Bus do
// sistema montado, o comando chegaria ao host.
// O logind (services/Logind) bloqueia e desbloqueia (loginctl lock-session e
// unlock-session) e avisa antes de dormir: o inibidor delay só sai com o
// bloqueio na tela (secure), em qualquer caminho de suspensão.
Singleton {
    id: root

    readonly property bool devMode: DevMode.active
    // Sobrevive ao recarregamento do shell: um reload não pode desbloquear a tela.
    readonly property bool locked: persist.locked
    // A marca do bloqueio sobrevive também à queda do shell: o qs novo (o
    // supervisor o sobe de novo) a lê ao iniciar e volta bloqueado. Enquanto
    // isso, o Hyprland mantém a tela da queda do bloqueio (allow_session_lock_restore).
    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || ""
    readonly property string lockMarker: runtimeDir ? `${runtimeDir}/lucerna/locked` : ""
    // O bloqueio está na tela (o WlSessionLock.secure, pelo LockscreenState).
    property bool secure: false
    // O logind avisou que vai dormir e o bloqueio ainda não está na tela: o
    // inibidor sai quando ele estiver.
    property bool sleepPending: false

    // A marca é gravada no lock() e esvaziada no unlock(), na hora (gravação
    // síncrona, sem processo à parte): um rm atrasado poderia levar a marca de
    // um bloqueio logo seguinte. Vazia conta como sem marca.
    function lock(): void {
        persist.locked = true;
        if (lockMarker)
            marker.setText("locked\n");
    }

    function unlock(): void {
        persist.locked = false;
        if (lockMarker)
            marker.setText("");
        Logind.setLockedHint(false);
    }

    function setSecure(on: bool): void {
        if (secure === on)
            return;
        secure = on;
        if (!on)
            return;
        Logind.setLockedHint(true);
        if (sleepPending) {
            sleepPending = false;
            Logind.releaseSleep();
        }
    }

    // O PrepareForSleep do logind. Antes de dormir: bloqueia e solta o
    // inibidor quando o bloqueio estiver na tela. Ao acordar: o inibidor de novo.
    function onSleep(start: bool): void {
        if (!start) {
            sleepPending = false;
            Logind.holdSleep();
            return;
        }
        lock();
        if (secure) {
            Logind.releaseSleep();
        } else {
            sleepPending = true;
        }
    }

    // O loginctl unlock-session desbloqueia, como no GNOME e no KDE: é também a
    // saída pelo TTY com o shell vivo.
    Connections {
        target: Logind

        function onLockRequested(): void {
            root.lock();
        }

        function onUnlockRequested(): void {
            root.unlock();
        }

        function onPrepareForSleep(start: bool): void {
            root.onSleep(start);
        }
    }

    // Chamada ao iniciar, com a marca lida: com ela, bloqueia. Sem ela, não
    // muda nada (nunca desbloqueia).
    function restoreLock(markerExists: bool): void {
        if (markerExists)
            lock();
    }

    PersistentProperties {
        id: persist

        reloadableId: "session"

        property bool locked: false
    }

    // Lido de forma síncrona na criação do serviço, antes de as janelas
    // dependerem do estado.
    FileView {
        id: marker

        path: root.lockMarker
        blockLoading: true
        blockWrites: true
        atomicWrites: true
        printErrors: false
    }

    Component.onCompleted: {
        restoreLock(lockMarker !== "" && marker.text().trim() !== "");
        if (Logind.enabled)
            Logind.holdSleep();
    }

    function suspend(): void {
        lock();
        run(["systemctl", "suspend"], "Suspender");
    }

    function reboot(): void {
        run(["systemctl", "reboot"], "Reiniciar");
    }

    function hibernate(): void {
        lock();
        run(["systemctl", "hibernate"], "Hibernar");
    }

    function poweroff(): void {
        run(["systemctl", "poweroff"], "Desligar");
    }

    function run(command: var, label: string): void {
        if (!DevMode.simulate(label))
            Quickshell.execDetached(command);
    }

    IpcHandler {
        target: "session"

        function lock(): void {
            root.lock();
        }

        function isLocked(): bool {
            return root.locked;
        }
    }
}
