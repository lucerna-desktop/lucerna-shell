pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// A sessão Lucerna vista pelo shell: o que o lucerna-session detectou
// ($XDG_RUNTIME_DIR/lucerna/session.json: GPU, DRM, modeset da NVIDIA,
// teclado, init) e os avisos que saem disso. A Tarefa 6 acrescenta o
// crash.json (a queda do shell) e o modo de segurança. Fora da sessão (sem o
// arquivo), não há aviso.
Singleton {
    id: root

    readonly property string runtimeDir: `${Quickshell.env("XDG_RUNTIME_DIR") || ""}/lucerna`
    // O session.json lido ({} sem o arquivo ou com JSON inválido).
    property var info: ({})
    // Só lê o arquivo e mostra os avisos depois do start() (o shell.qml o
    // chama ao subir; os testes usam só as funções puras).
    property bool started: false

    function start(): void {
        started = true;
    }

    // Os avisos da detecção, como [{ summary, body }]. Pura.
    function notices(info: var): var {
        const out = [];
        if (!info)
            return out;
        if ((info.gpu === "nvidia" || info.gpu === "hybrid") && info.nvidiaModeset !== true)
            out.push({
                summary: "A placa NVIDIA está sem o modeset do DRM",
                body: "Ligue nvidia-drm.modeset=1 nos parâmetros do kernel; sem ele, a placa da NVIDIA pode não funcionar no Lucerna."
            });
        return out;
    }

    // Mostra cada aviso uma vez por sessão: os já mostrados ficam no
    // PersistentProperties (um reload do shell não repete).
    function showNotices(): void {
        const shown = JSON.parse(persist.shown || "[]");
        for (const notice of notices(info)) {
            if (shown.includes(notice.summary))
                continue;
            shown.push(notice.summary);
            Quickshell.execDetached(["notify-send", "-a", "Lucerna", notice.summary, notice.body]);
        }
        persist.shown = JSON.stringify(shown);
    }

    PersistentProperties {
        id: persist

        reloadableId: "lucernaSession"

        property string shown: "[]"
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

    // Os avisos esperam o servidor de notificações (o do próprio shell) subir.
    Timer {
        id: noticeDelay

        interval: 3000
        onTriggered: root.showNotices()
    }
}
