pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// A sessão Lucerna vista pelo shell: o que o lucerna-session detectou
// ($XDG_RUNTIME_DIR/lucerna/session.json: GPU, DRM, modeset da NVIDIA,
// teclado, init), a última queda do shell (o crash.json que o supervisor
// grava antes de reiniciar) e os avisos que saem disso. Fora da sessão (sem
// os arquivos), não há aviso.
Singleton {
    id: root

    readonly property string runtimeDir: `${Quickshell.env("XDG_RUNTIME_DIR") || ""}/lucerna`
    // O session.json lido ({} sem o arquivo ou com JSON inválido).
    property var info: ({})
    // O crash.json lido (null sem o arquivo). É apagado depois de avisado.
    property var crash: null
    // O registro da última queda avisada (para o "Ver o registro" do modo de
    // segurança).
    property string lastCrashLog: ""
    // Só lê os arquivos e mostra os avisos depois do start() (o shell.qml o
    // chama ao subir; os testes usam só as funções puras).
    property bool started: false

    function start(): void {
        started = true;
    }

    // Os avisos, como [{ summary, body }]: a queda (crash.json) e os da
    // detecção (session.json). Pura.
    function notices(info: var, crash: var): var {
        const out = [];
        if (crash?.log) {
            const safe = crash.safe === true;
            out.push({
                summary: safe ? "O Lucerna está no modo de segurança" : "O Lucerna reiniciou depois de uma falha",
                body: `O registro está em ${crash.log}.` + (safe ? " Ele caiu várias vezes seguidas; as suas personalizações estão desligadas até reiniciar normalmente." : "")
            });
        }
        if (info && (info.gpu === "nvidia" || info.gpu === "hybrid") && info.nvidiaModeset !== true)
            out.push({
                summary: "A placa NVIDIA está sem o modeset do DRM",
                body: "Ligue nvidia-drm.modeset=1 nos parâmetros do kernel; sem ele, a placa da NVIDIA pode não funcionar no Lucerna."
            });
        return out;
    }

    // Os avisos da detecção, uma vez por sessão: os já mostrados ficam em
    // $XDG_RUNTIME_DIR/lucerna/notices.json, que sobrevive ao reinício do qs
    // pelo supervisor (e some com a sessão). O da queda, a cada queda: o
    // crash.json é apagado depois de avisado.
    function showNotices(): void {
        let shown = [];
        try {
            shown = JSON.parse(shownFile.text() || "[]");
        } catch (e) {
            shown = [];
        }
        const fresh = notices(info, null).filter(n => !shown.includes(n.summary));
        for (const notice of notices(null, crash).concat(fresh))
            Quickshell.execDetached(["notify-send", "-a", "Lucerna", notice.summary, notice.body]);
        if (fresh.length)
            shownFile.setText(JSON.stringify(shown.concat(fresh.map(n => n.summary))));
        if (crash) {
            lastCrashLog = crash.log ?? "";
            crash = null;
            Quickshell.execDetached(["rm", "-f", `${runtimeDir}/crash.json`]);
        }
    }

    FileView {
        path: root.started ? `${root.runtimeDir}/session.json` : ""
        printErrors: false
        onLoaded: {
            try {
                root.info = JSON.parse(text()) ?? {};
            } catch (e) {
                console.warn(`Lucerna: session.json inválido: ${e}`);
                root.info = {};
            }
            noticeDelay.restart();
        }
    }

    FileView {
        path: root.started ? `${root.runtimeDir}/crash.json` : ""
        printErrors: false
        onLoaded: {
            try {
                root.crash = JSON.parse(text()) ?? null;
            } catch (e) {
                console.warn(`Lucerna: crash.json inválido: ${e}`);
                root.crash = null;
            }
            noticeDelay.restart();
        }
    }

    FileView {
        id: shownFile

        path: root.started ? `${root.runtimeDir}/notices.json` : ""
        blockLoading: true
        blockWrites: true
        printErrors: false
    }

    // Os avisos esperam o servidor de notificações (o do próprio shell) subir.
    Timer {
        id: noticeDelay

        interval: 3000
        onTriggered: root.showNotices()
    }
}
