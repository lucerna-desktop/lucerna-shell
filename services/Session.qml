pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Bloqueio e energia. No modo de desenvolvimento (LUCERNA_DEV=1) suspender,
// reiniciar e desligar são só simulados: dentro do container, com o D-Bus do
// sistema montado, o comando chegaria ao host.
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

    Component.onCompleted: restoreLock(lockMarker !== "" && marker.text().trim() !== "")

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
