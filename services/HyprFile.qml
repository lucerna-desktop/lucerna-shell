pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core.config

// O arquivo do Hyprland controlado pelo shell: ~/.config/lucerna/hypr/settings.lua.
// Na sessão Lucerna (o lucerna-session põe LUCERNA_SESSION=1), a base carrega
// este arquivo antes do ~/.config/hypr/hyprland.lua do usuário: o que se
// ajusta nas Configurações vale desde o login, e o arquivo do usuário, lido
// depois, vence. Cada parte das Configurações escreve a sua seção (theme,
// input, keyboard, binds, monitors...) com o mesmo Lua que manda pelo hyprctl
// eval. O shell nunca escreve no hyprland.lua do usuário.
Singleton {
    id: root

    readonly property bool layered: Quickshell.env("LUCERNA_SESSION") === "1"
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || `${Quickshell.env("HOME")}/.config`
    readonly property string path: `${configHome}/lucerna/hypr/settings.lua`
    // O ponto único do modo de segurança: com ele, nada é escrito (o Hyprland
    // segue com o settings.lua que já existia).
    readonly property bool writable: !Config.safeMode

    readonly property string header: "-- Gerado pelo Lucerna (Configurações). Não edite: é reescrito. O seu arquivo é o ~/.config/hypr/hyprland.lua."

    // Seção → Lua. Começa com o que já está no arquivo: uma seção que ainda
    // não foi recalculada nesta execução não se perde na próxima gravação.
    property var sections: ({})
    // O texto no disco (o lido ao iniciar ou o último gravado) e o que não
    // conseguiu ser gravado (não tenta de novo até uma seção mudar).
    property string written: ""
    property string failed: ""

    function setSection(name: string, lua: string): void {
        if (!writable)
            return;
        if ((sections[name] ?? "") === lua)
            return;
        const next = Object.assign({}, sections);
        next[name] = lua;
        sections = next;
        writeDelay.restart();
    }

    // O cabeçalho e as seções em ordem alfabética, cada uma com "-- [nome]";
    // as vazias saem.
    function compose(all: var): string {
        const parts = Object.keys(all).sort().filter(name => all[name]).map(name => `-- [${name}]\n${all[name]}\n`);
        return [`${header}\n`].concat(parts).join("\n");
    }

    // O contrário do compose: as seções de um arquivo gerado.
    function parse(text: string): var {
        const out = {};
        let name = "";
        let lines = [];
        const close = () => {
            if (name)
                out[name] = lines.join("\n").replace(/\n+$/, "");
        };
        for (const line of text.split("\n")) {
            const m = /^-- \[([a-z0-9_]+)\]$/.exec(line);
            if (m) {
                close();
                name = m[1];
                lines = [];
            } else if (name) {
                lines.push(line);
            }
        }
        close();
        return out;
    }

    function write(): void {
        if (!writable)
            return;
        const text = compose(sections);
        if (text === written || text === failed) {
            reloadIfAsked();
            return;
        }
        if (writer.running) {
            writeDelay.restart();
            return;
        }
        writer.text = text;
        writer.command = ["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf "%s" "$2" > "$1.tmp" && mv -f "$1.tmp" "$1"', "sh", path, text];
        writer.running = true;
    }

    Timer {
        id: writeDelay

        interval: 300
        onTriggered: root.write()
    }

    Process {
        id: writer

        property string text: ""

        onExited: code => {
            if (code === 0) {
                root.written = writer.text;
                root.failed = "";
            } else {
                root.failed = writer.text;
                console.warn(`Lucerna: não consegui gravar ${root.path} (código ${code})`);
            }
            // Outra mudança pode ter chegado durante a gravação.
            const text = root.compose(root.sections);
            if (text !== root.written && text !== root.failed)
                writeDelay.restart();
            else
                root.reloadIfAsked();
        }
    }

    FileView {
        path: root.path
        blockLoading: true
        printErrors: false
        onLoaded: {
            root.written = text();
            root.sections = Object.assign(root.parse(root.written), root.sections);
        }
    }

    // Recarregar o Hyprland (hyprctl reload). Na sessão Lucerna, o reload lê
    // este arquivo: espera as seções assentarem e o arquivo ser gravado, senão
    // valeria o texto antigo. Fora dela (ou sem gravar), recarrega na hora.
    property bool reloadAsked: false

    function reload(): void {
        if (!layered || !writable) {
            Quickshell.execDetached(["hyprctl", "reload"]);
            return;
        }
        reloadAsked = true;
        reloadDelay.restart();
    }

    function reloadIfAsked(): void {
        if (!reloadAsked)
            return;
        reloadAsked = false;
        Quickshell.execDetached(["hyprctl", "reload"]);
    }

    Timer {
        id: reloadDelay

        interval: 500
        onTriggered: {
            writeDelay.stop();
            root.write();
        }
    }

    // O arquivo antigo do arranjo no login (~/.config/hypr/lucerna-monitors.lua,
    // que o hyprland.lua do usuário pode incluir). Na sessão Lucerna, o arranjo
    // vai na seção "monitors" deste arquivo: o antigo, se foi gerado pelo
    // Lucerna, vira só um aviso (o include continua inofensivo). Um arquivo
    // escrito à mão fica intocado.
    readonly property string legacyPath: `${configHome}/hypr/lucerna-monitors.lua`
    readonly property string legacyNotice: "-- Gerado pelo Lucerna: o arranjo de monitores agora fica em ~/.config/lucerna/hypr/settings.lua.\n"

    function isLegacyGenerated(text: string): bool {
        return text.split("\n")[0].startsWith("-- Gerado pelo Lucerna");
    }

    function migrateLegacy(): void {
        if (writable)
            legacyReader.running = true;
    }

    Process {
        id: legacyReader

        command: ["sh", "-c", 'cat "$1" 2> /dev/null', "sh", root.legacyPath]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.isLegacyGenerated(text) && text !== root.legacyNotice) {
                    legacyWriter.command = ["sh", "-c", 'printf "%s" "$2" > "$1.tmp" && mv -f "$1.tmp" "$1"', "sh", root.legacyPath, root.legacyNotice];
                    legacyWriter.running = true;
                }
            }
        }
    }

    Process {
        id: legacyWriter
    }

    Component.onCompleted: {
        if (layered)
            migrateLegacy();
    }
}
