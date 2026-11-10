pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pam
import qs.services

// View model da tela de bloqueio: autenticação por PAM (senha do usuário,
// config em ../pam/password) e relógio.
Singleton {
    id: root

    readonly property bool locked: Session.locked
    readonly property string user: Quickshell.env("USER") || Quickshell.env("LOGNAME") || ""
    property bool busy: false
    property string error: ""
    property string pendingPassword: ""

    readonly property string time: Qt.formatTime(clock.date, "HH:mm")
    readonly property string date: clock.date.toLocaleDateString(Qt.locale("pt_BR"), "dddd, d 'de' MMMM")

    signal failed

    onLockedChanged: {
        error = "";
        busy = false;
        if (pam.active)
            pam.abort();
    }

    // O bloqueio chegou à tela (ou saiu): o WlSessionLock.secure, do Lockscreen.
    function setSecure(on: bool): void {
        Session.setSecure(on);
    }

    function submit(password: string): void {
        if (busy || password === "")
            return;
        busy = true;
        error = "";
        pendingPassword = password;
        if (!pam.start()) {
            busy = false;
            error = "Não foi possível iniciar a autenticação";
        }
    }

    SystemClock {
        id: clock

        precision: SystemClock.Seconds
    }

    PamContext {
        id: pam

        configDirectory: "../pam"
        config: "password"

        onResponseRequiredChanged: {
            if (!responseRequired)
                return;
            respond(root.pendingPassword);
            root.pendingPassword = "";
        }

        onCompleted: result => {
            root.busy = false;
            root.pendingPassword = "";
            if (result === PamResult.Success) {
                Session.unlock();
            } else {
                root.error = result === PamResult.MaxTries ? "Tentativas demais, aguarde" : "Senha incorreta";
                root.failed();
            }
        }

        onError: error => {
            root.error = "Erro na autenticação";
            console.warn("Lockscreen: erro do PAM:", PamError.toString(error));
        }
    }
}
