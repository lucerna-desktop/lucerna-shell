pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core.config

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

    // O qs dentro da sessão Lucerna (LUCERNA_SESSION=1) sem o supervisor
    // (LUCERNA_SUPERVISED vazia): o shell.qml sai sem abrir nada. Fora da
    // sessão Lucerna, o qs sobe como sempre. Pura.
    function unsupervised(session: string, supervised: string): bool {
        return session === "1" && supervised === "";
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

    // Os apps padrão (terminal, navegador, arquivos): os instalados de cada
    // tipo, do `lucerna-session detect-apps` (na ordem de preferência dele; o
    // primeiro é o automático), e o ~/.config/lucerna/apps.conf, que o
    // `lucerna-session open` lê. Sem o lucerna-session, as listas ficam vazias.
    property var apps: ({ terminal: [], browser: [], files: [] })
    readonly property var appKinds: ["terminal", "browser", "files"]

    function parseApps(text: string): var {
        let data = {};
        try {
            data = JSON.parse(text) ?? {};
        } catch (e) {
            data = {};
        }
        const out = {};
        for (const kind of appKinds)
            out[kind] = Array.isArray(data[kind]) ? data[kind].map(String) : [];
        return out;
    }

    // O texto do apps.conf: uma linha TIPO=app por escolha; vazio (o
    // automático) não entra.
    function appsConf(chosen: var): string {
        const lines = ["# Gerado pelo Lucerna (Configurações → Atalhos). Vazio = automático."];
        for (const kind of appKinds) {
            const value = String(chosen?.[kind] ?? "").replace(/[\r\n]+/g, " ").trim();
            if (value)
                lines.push(`${kind}=${value}`);
        }
        return lines.join("\n") + "\n";
    }

    function detectApps(): void {
        appsProbe.running = true;
    }

    // Grava o apps.conf (nunca no modo de segurança).
    function writeApps(chosen: var): void {
        if (Config.safeMode)
            return;
        const dir = `${Quickshell.env("XDG_CONFIG_HOME") || `${Quickshell.env("HOME")}/.config`}/lucerna`;
        appsWriter.command = ["sh", "-c", 'mkdir -p "$1" && printf "%s" "$2" > "$1/apps.conf.tmp" && mv -f "$1/apps.conf.tmp" "$1/apps.conf"', "sh", dir, appsConf(chosen)];
        appsWriter.running = true;
    }

    Process {
        id: appsProbe

        command: ["sh", "-c", "command -v lucerna-session > /dev/null && exec lucerna-session detect-apps"]
        stdout: StdioCollector {
            onStreamFinished: root.apps = root.parseApps(text)
        }
    }

    Process {
        id: appsWriter

        onExited: code => {
            if (code !== 0)
                console.warn(`Lucerna: não consegui gravar o apps.conf (código ${code})`);
        }
    }

    // Os avisos esperam o servidor de notificações (o do próprio shell) subir.
    Timer {
        id: noticeDelay

        interval: 3000
        onTriggered: root.showNotices()
    }
}
