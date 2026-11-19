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
// eval. A seção "scale" é a do modo "Escala pelos apps" (AppsScale): o global
// lucerna_scale_mode, que deixa os monitores em 1 na escala automática da
// base, e o ambiente dos apps. O shell nunca escreve no hyprland.lua do usuário.
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

    // O que a gravação faz com o texto composto: "write" (grava), "wait"
    // (outra gravação em curso: tenta depois), "done" (já está no disco: só o
    // reload pedido) ou "failed" (é o texto que acabou de falhar: não tenta
    // de novo sozinho, até uma seção mudar ou um reload ser pedido).
    function writeStep(text: string, onDisk: string, failedText: string, busy: bool): string {
        if (text === onDisk)
            return "done";
        if (text === failedText)
            return "failed";
        return busy ? "wait" : "write";
    }

    // O comando da gravação: o texto vai em pedaços de até 16384 caracteres
    // (48 KiB em UTF-8, no pior caso: 3 bytes por caractere; um par de surrogates dá 4 bytes em 2), que o printf junta. Um argumento só vai
    // até 128 KiB (MAX_ARG_STRLEN): o settings.lua inteiro num argumento não
    // seria gravado a partir desse tamanho. Um pedaço não termina no meio de
    // um par de surrogates (um emoji num comentário ou num nome).
    function writeCommand(file: string, text: string): var {
        const parts = [];
        for (let i = 0; i < text.length;) {
            let end = Math.min(text.length, i + 16384);
            const last = text.charCodeAt(end - 1);
            if (end < text.length && last >= 0xD800 && last <= 0xDBFF)
                end--;
            parts.push(text.slice(i, end));
            i = end;
        }
        return ["sh", "-c", 'f=$1; shift; mkdir -p "$(dirname "$f")" && printf "%s" "$@" > "$f.tmp" && mv -f "$f.tmp" "$f"', "sh", file].concat(parts.length ? parts : [""]);
    }

    function write(): void {
        if (!writable)
            return;
        const text = compose(sections);
        const step = writeStep(text, written, failed, writer.running);
        if (step === "done") {
            reloadIfAsked();
        } else if (step === "failed") {
            reloadAsked = false;
        } else if (step === "wait") {
            writeDelay.restart();
        } else {
            writer.text = text;
            writer.command = writeCommand(path, text);
            writer.running = true;
        }
    }

    // O fim de uma gravação. Outra mudança pode ter chegado durante ela: o
    // texto novo é gravado, e o reload pedido espera essa gravação. Sem texto
    // novo, gravada, o reload pedido sai; falhou, o reload cai: o Hyprland
    // leria o arquivo velho e desfaria o que o hyprctl eval já pôs (o próximo
    // pedido de reload tenta gravar de novo).
    function finished(ok: bool, text: string): void {
        if (ok) {
            written = text;
            failed = "";
        } else {
            failed = text;
            console.warn(`Lucerna: não consegui gravar ${path}; o Hyprland não recarrega com o arquivo velho`);
        }
        const next = compose(sections);
        if (next !== written && next !== failed)
            writeDelay.restart();
        else if (ok)
            reloadIfAsked();
        else
            reloadAsked = false;
    }

    Timer {
        id: writeDelay

        interval: 300
        onTriggered: root.write()
    }

    Process {
        id: writer

        property string text: ""

        onExited: code => root.finished(code === 0, writer.text)
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
        // Uma gravação que falhou é tentada de novo antes do reload.
        failed = "";
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
