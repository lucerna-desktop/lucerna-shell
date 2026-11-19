pragma Singleton

import QtQuick
import Quickshell
import qs.core.config
import qs.services

// O modo de segurança: o supervisor sobe o shell com LUCERNA_SAFE_MODE=1
// depois de quedas seguidas. Nele valem os padrões (o tema, o fundo estático),
// e nada de entrada, monitores, atalhos ou settings.lua é aplicado ou gravado.
// A pílula (SafeModeBanner) avisa e dá as duas saídas.
Singleton {
    id: root

    readonly property bool active: Config.safeMode
    readonly property string logDir: `${Quickshell.env("XDG_STATE_HOME") || `${Quickshell.env("HOME")}/.local/state`}/lucerna/shell`
    // O registro da queda que levou ao modo (o crash.json); sem ele, o mais
    // recente da pasta, achado na hora.
    readonly property string crashLog: LucernaSession.lastCrashLog

    // Sai do modo: o supervisor para este qs e sobe um normal.
    function restartNormally(): void {
        Quickshell.execDetached(["lucerna-session", "shell", "restart"]);
    }

    // O terminal com o less no fim do registro (sem o less, o lucerna-session
    // troca pelo $PAGER ou por um tail). Sem o crash.json, o sh acha o mais
    // recente antes de abrir o terminal, para o less chegar como o comando.
    function openLog(): void {
        if (crashLog)
            Quickshell.execDetached(["lucerna-session", "open", "terminal", "less", "+G", crashLog]);
        else
            Quickshell.execDetached(["sh", "-c", 'exec lucerna-session open terminal less +G "$(ls -t "$1"/qs-*.log | head -n 1)"', "sh", logDir]);
    }
}
