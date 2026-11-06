pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core.config
import qs.core.theme

// O modo "Escala pelos apps" (Configurações → Monitores): o compositor fica
// em 1 (mais leve para a GPU) e cada toolkit aumenta os próprios apps:
// - o ambiente da sessão (QT_SCALE_FACTOR, GDK_SCALE, GDK_DPI_SCALE, o tamanho
//   do cursor), no ~/.config/lucerna/session.env que o lucerna-session lê no
//   login e, na hora, pelo hl.env da seção "scale" do arquivo do Hyprland do
//   shell (HyprFile), que vale para os apps abertos dali em diante;
// - o Chromium, o Chrome e o Electron, pelo --force-device-scale-factor nos
//   ~/.config/{electron,chromium,chrome}-flags.conf (só a linha marcada);
// - o GTK, pelo gtk-xft-dpi dos ~/.config/gtk-{3,4}.0/settings.ini;
// - os apps X11, pelo Xft.dpi do ~/.config/lucerna/Xresources (xrdb).
// Cada arquivo ganha uma cópia .lucerna-bak antes da primeira mudança, e os
// valores de antes ficam no ~/.config/lucerna/scale-backup.json: voltar para
// a escala do monitor (restore) devolve tudo. No modo de segurança, nada.
// O próprio shell não usa esse ambiente: o supervisor tira o QT_SCALE_FACTOR
// dele, e a escala dele é a interna (ThemeManager.scale).
Singleton {
    id: root

    // O fator em uso: o dos apps no modo, senão 1 (as bordas do Hyprland
    // acompanham: ThemeSwitcherState).
    readonly property real factor: Config.scaleMode === "apps" ? Config.appsScale : 1
    readonly property bool writable: HyprFile.writable
    readonly property string configHome: HyprFile.configHome
    // Há xrdb (sem ele, os apps X11 ficam sem o ajuste das fontes).
    property bool hasXrdb: false

    readonly property var envNames: ["QT_SCALE_FACTOR", "GDK_SCALE", "GDK_DPI_SCALE", "XCURSOR_SIZE", "HYPRCURSOR_SIZE"]
    readonly property var flagFiles: ["electron-flags.conf", "chromium-flags.conf", "chrome-flags.conf"]
    readonly property var gtkFiles: ["gtk-3.0/settings.ini", "gtk-4.0/settings.ini"]
    readonly property string sessionEnvFile: "lucerna/session.env"
    readonly property string xresourcesFile: "lucerna/Xresources"
    readonly property var ownFiles: [sessionEnvFile, xresourcesFile]
    readonly property var files: flagFiles.concat(gtkFiles, ownFiles)
    readonly property string backupFile: "lucerna/scale-backup.json"
    readonly property string marker: "# lucerna: escala pelos apps"
    readonly property string generated: "Gerado pelo Lucerna (Configurações → Monitores, Escala pelos apps)"

    // O ambiente dos apps no fator f. O GTK só escala por inteiros: até 2, o
    // GDK_SCALE fica em 1 e o GDK_DPI_SCALE aumenta o texto.
    function envFor(f: real): var {
        if (f === 1)
            return {};
        const gdk = f >= 2 ? Math.floor(f) : 1;
        const cursor = Math.round(24 * f);
        return {
            QT_SCALE_FACTOR: f,
            GDK_SCALE: gdk,
            GDK_DPI_SCALE: Math.round(f / gdk * 10000) / 10000,
            XCURSOR_SIZE: cursor,
            HYPRCURSOR_SIZE: cursor
        };
    }

    // O ~/.config/lucerna/session.env: um NOME=valor por linha, sem aspas (o
    // lucerna-session guarda o valor como texto, aspas inclusive).
    function sessionEnvText(env: var): string {
        const lines = [`# ${generated}. É reescrito; ao voltar para a escala do monitor, volta ao que era.`];
        for (const name of Object.keys(env))
            lines.push(`${name}=${env[name]}`);
        return `${lines.join("\n")}\n`;
    }

    // A seção "scale" do arquivo do Hyprland do shell. O global
    // lucerna_scale_mode deixa os monitores em 1 na escala automática da base;
    // bordas, espaços e arredondamento (a base: 2, 4 e 10; o tema por cima)
    // crescem junto com os apps.
    function hyprLua(f: real, hypr: var): string {
        const env = envFor(f);
        const r = v => Math.round(v * f);
        // Sem comentário na frente: o mesmo texto vai pelo hyprctl eval, que
        // leria um "--" no começo como opção dele.
        const lines = ['lucerna_scale_mode = "apps"'];
        for (const name of Object.keys(env))
            lines.push(`hl.env("${name}", "${env[name]}")`);
        lines.push(`hl.config({ xwayland = { force_zero_scaling = true }, general = { border_size = ${r(hypr?.borderSize ?? 2)}, gaps_in = ${r(4)}, gaps_out = ${r(10)} }, decoration = { rounding = ${r(hypr?.rounding ?? 10)} } })`);
        return lines.join("\n");
    }

    // As linhas de um texto e se ele terminava com uma quebra (para devolver
    // igual).
    function splitLines(text: string): var {
        const trailing = text.endsWith("\n");
        return { lines: text === "" ? [] : (trailing ? text.slice(0, -1) : text).split("\n"), trailing: trailing || text === "" };
    }

    // As flags do Chromium/Electron: tira a nossa marca e a linha seguinte; com
    // f > 1, põe de novo no fim. O resto fica como estava.
    function flagsText(existing: string, f: real): string {
        const split = splitLines(existing);
        const out = [];
        for (let i = 0; i < split.lines.length; i++) {
            if (split.lines[i].trim() === marker) {
                i++;
                continue;
            }
            out.push(split.lines[i]);
        }
        if (f > 1)
            out.push(marker, `--force-device-scale-factor=${f}`);
        if (!out.length)
            return "";
        return out.join("\n") + (split.trailing ? "\n" : "");
    }

    // O valor de uma chave numa seção de um .ini (null se não há).
    function iniValue(text: string, section: string, key: string): var {
        let inside = false;
        for (const line of text.split("\n")) {
            const head = /^\s*\[(.*)\]\s*$/.exec(line);
            if (head) {
                inside = head[1] === section;
                continue;
            }
            const m = new RegExp(`^\\s*${key}\\s*=\\s*(.*?)\\s*$`).exec(line);
            if (inside && m)
                return m[1];
        }
        return null;
    }

    // O gtk-xft-dpi (o DPI vezes 1024) na seção [Settings], sem mexer no resto:
    // troca o valor no lugar, ou entra logo abaixo do cabeçalho, ou a seção é
    // criada no fim. Com f === 1, volta o `original` (sem ele, a chave sai).
    function gtkIniText(existing: string, f: real, original: var): string {
        const key = "gtk-xft-dpi";
        const value = f === 1 ? original : String(Math.round(96 * 1024 * f));
        const split = splitLines(existing);
        const lines = split.lines.slice();
        let header = -1;
        let at = -1;
        let inside = false;
        for (let i = 0; i < lines.length; i++) {
            const head = /^\s*\[(.*)\]\s*$/.exec(lines[i]);
            if (head) {
                inside = head[1] === "Settings";
                if (inside && header < 0)
                    header = i;
                continue;
            }
            if (inside && at < 0 && new RegExp(`^\\s*${key}\\s*=`).test(lines[i]))
                at = i;
        }
        if (value === null || value === undefined) {
            if (at >= 0)
                lines.splice(at, 1);
        } else if (at >= 0) {
            lines[at] = lines[at].replace(/=(\s*).*$/, `=$1${value}`);
        } else if (header >= 0) {
            lines.splice(header + 1, 0, `${key}=${value}`);
        } else {
            lines.push("[Settings]", `${key}=${value}`);
        }
        if (!lines.length)
            return "";
        return lines.join("\n") + (split.trailing ? "\n" : "");
    }

    function xresourcesText(f: real): string {
        return `! ${generated}.\nXft.dpi: ${Math.round(96 * f)}\n`;
    }

    // Os espaços do Hyprland como o getoption os dá ("4 4 4 4") em Lua: um
    // número se os quatro lados são iguais, senão a tabela.
    function gapsLua(css: string): string {
        const text = String(css).trim();
        const n = text ? text.split(/\s+/).map(Number) : [];
        if (!n.length || n.some(v => !Number.isFinite(v)))
            return "";
        const [top, right = top, bottom = top, left = right] = n;
        if (top === right && top === bottom && top === left)
            return String(top);
        return `{ top = ${top}, right = ${right}, bottom = ${bottom}, left = ${left} }`;
    }

    // O Lua da volta, mandado na hora (o arquivo perde a seção "scale"): o
    // ambiente de antes (o que não havia fica vazio: o hl.env não desfaz uma
    // variável) e os espaços de antes. Bordas e arredondamento voltam pelo
    // tema (ThemeSwitcherState, com o fator 1).
    function restoreLua(backup: var): string {
        const lines = ["lucerna_scale_mode = nil"];
        for (const name of envNames)
            lines.push(`hl.env("${name}", ${JSON.stringify(String(backup?.env?.[name] ?? ""))})`);
        const gapsIn = gapsLua(backup?.gaps?.in ?? "") || "4";
        const gapsOut = gapsLua(backup?.gaps?.out ?? "") || "10";
        lines.push(`hl.config({ general = { gaps_in = ${gapsIn}, gaps_out = ${gapsOut} } })`);
        return lines.join("\n");
    }

    // A saída do leitor: registros "\x1e<nome>\x1f<corpo>". Arquivos: o corpo
    // começa com 1 (e o conteúdo) ou 0 (não existe). Os extras começam com @.
    function parseRead(text: string): var {
        const out = { files: {}, xrdb: false, xftDpi: null, gapsIn: "", gapsOut: "" };
        for (const record of text.split("\x1e").slice(1)) {
            const cut = record.indexOf("\x1f");
            if (cut < 0)
                continue;
            const name = record.slice(0, cut);
            const body = record.slice(cut + 1);
            if (name === "@xrdb") {
                out.xrdb = body.startsWith("1");
                out.xftDpi = body.slice(1).trim() || null;
            } else if (name === "@gaps_in" || name === "@gaps_out") {
                let css = "";
                try {
                    css = JSON.parse(body).css ?? "";
                } catch (e) {}
                out[name === "@gaps_in" ? "gapsIn" : "gapsOut"] = css;
            } else {
                out.files[name] = body.startsWith("1") ? body.slice(1) : null;
            }
        }
        return out;
    }

    // O que gravar para o fator f. `files`: nome (relativo ao ~/.config) →
    // texto, ou null se não existe. `backup`: o scale-backup.json (null na
    // primeira vez: ele é montado agora, com `live`, o estado de antes).
    // Devolve { fresh, backup, writes } (writes: nome → texto, ou null para
    // apagar; só o que muda).
    function planApply(files: var, backup: var, f: real, live: var): var {
        const fresh = !backup;
        const b = backup ?? {
            files: {},
            gtk: {},
            gtkSection: {},
            own: {},
            env: live.env,
            gaps: { in: live.gapsIn, out: live.gapsOut },
            xftDpi: live.xftDpi
        };
        if (fresh) {
            for (const name of root.files)
                b.files[name] = files[name] !== null && files[name] !== undefined;
            for (const name of gtkFiles) {
                b.gtk[name] = iniValue(files[name] ?? "", "Settings", "gtk-xft-dpi");
                b.gtkSection[name] = /^\s*\[Settings\]\s*$/m.test(files[name] ?? "");
            }
            for (const name of ownFiles)
                b.own[name] = files[name] ?? null;
        }
        const next = {};
        for (const name of flagFiles) {
            const text = flagsText(files[name] ?? "", f);
            next[name] = text === "" && !b.files[name] ? null : text;
        }
        for (const name of gtkFiles) {
            const text = gtkIniText(files[name] ?? "", f, b.gtk[name]);
            next[name] = text === "" && !b.files[name] ? null : text;
        }
        const env = envFor(f);
        next[sessionEnvFile] = Object.keys(env).length ? sessionEnvText(env) : b.own[sessionEnvFile];
        next[xresourcesFile] = xresourcesText(f);
        return { fresh: fresh, backup: b, writes: changes(files, next) };
    }

    // O que gravar para voltar. Com a cópia, cada arquivo volta ao de antes
    // (os toolkits pela marca e pelo valor guardado, mantendo o que a pessoa
    // mudou nesse meio-tempo). Sem ela, só sai o que é do Lucerna: a linha
    // marcada das flags e os arquivos gerados.
    function planRestore(files: var, backup: var): var {
        const b = backup ?? { files: {}, gtk: {}, gtkSection: {}, own: {} };
        const next = {};
        for (const name of flagFiles) {
            const text = flagsText(files[name] ?? "", 1);
            next[name] = text === "" && !b.files[name] ? null : text;
        }
        for (const name of gtkFiles) {
            if (!backup || files[name] === null || files[name] === undefined) {
                next[name] = files[name] ?? null;
                continue;
            }
            let text = gtkIniText(files[name], 1, b.gtk[name]);
            // A seção [Settings] que o modo criou, vazia, sai.
            if (!b.gtkSection[name])
                text = text.replace(/^\[Settings\]\n(?=\[|$)/m, "");
            next[name] = text === "" && !b.files[name] ? null : text;
        }
        for (const name of ownFiles) {
            if (backup)
                next[name] = b.own[name] ?? null;
            else
                next[name] = /^[#!] Gerado pelo Lucerna/.test(files[name] ?? "") ? null : files[name] ?? null;
        }
        return { writes: changes(files, next) };
    }

    // Só o que difere do que está no disco.
    function changes(files: var, next: var): var {
        const out = {};
        for (const name of Object.keys(next)) {
            if ((files[name] ?? null) !== next[name])
                out[name] = next[name];
        }
        return out;
    }

    // A aplicação: lê os arquivos, monta o plano, grava (com as cópias) e só
    // então avisa o Hyprland, o xrdb e o cursor. Um pedido durante outro
    // espera a vez (vale o último).
    property string busy: ""
    property var queued: null

    function apply(f: real): void {
        request({ op: "apply", f: f });
    }

    function restore(): void {
        request({ op: "restore", f: 1 });
    }

    function request(job: var): void {
        if (!writable)
            return;
        if (busy) {
            queued = job;
            return;
        }
        busy = job.op;
        reader.job = job;
        reader.command = ["sh", "-c", `cd "$1" || exit 1; shift
for n; do
    printf '\\036%s\\037' "$n"
    if [ -f "$n" ]; then printf 1; cat -- "$n"; else printf 0; fi
done
printf '\\036@xrdb\\037'
if command -v xrdb > /dev/null; then printf 1; xrdb -query 2> /dev/null | sed -n 's/^Xft\\.dpi:[[:space:]]*//p'; else printf 0; fi
printf '\\036@gaps_in\\037'; hyprctl getoption general:gaps_in -j 2> /dev/null
printf '\\036@gaps_out\\037'; hyprctl getoption general:gaps_out -j 2> /dev/null
:`, "sh", configHome, backupFile].concat(files);
        reader.running = true;
    }

    function finish(): void {
        busy = "";
        if (queued) {
            const job = queued;
            queued = null;
            request(job);
        }
    }

    Process {
        id: reader

        property var job: null

        stdout: StdioCollector {
            onStreamFinished: root.planned(reader.job, root.parseRead(text))
        }
    }

    function planned(job: var, read: var): void {
        let backup = null;
        try {
            backup = read.files[backupFile] ? JSON.parse(read.files[backupFile]) : null;
        } catch (e) {
            console.warn(`Lucerna: o ${backupFile} está ilegível; sigo sem ele`);
        }
        hasXrdb = read.xrdb;
        const live = { env: {}, gapsIn: read.gapsIn, gapsOut: read.gapsOut, xftDpi: read.xftDpi };
        for (const name of envNames)
            live.env[name] = Quickshell.env(name) ?? null;
        const plan = job.op === "apply" ? planApply(read.files, backup, job.f, live) : planRestore(read.files, backup);
        // Triplas nome, ação (w grava, rm apaga), texto. A cópia de antes vai primeiro.
        const args = [];
        if (job.op === "apply" && plan.fresh)
            args.push(backupFile, "w", JSON.stringify(plan.backup, null, 2) + "\n");
        for (const name of Object.keys(plan.writes))
            args.push(name, plan.writes[name] === null ? "rm" : "w", plan.writes[name] ?? "");
        if (job.op === "restore" && read.files[backupFile] !== null && read.files[backupFile] !== undefined)
            args.push(backupFile, "rm", "");
        writer.job = job;
        writer.backup = job.op === "apply" ? plan.backup : backup;
        // As cópias .lucerna-bak: só na primeira aplicação (sem o
        // scale-backup.json), de todos os arquivos que existem: o estado de
        // antes do modo. Uma troca de fator depois não copia de novo (seria a
        // cópia do que o próprio modo escreveu).
        writer.command = ["sh", "-c", `cd "$1" || exit 1; mode=$2; shift 2
if [ "$mode" = fresh ]; then
    for n in ${files.map(n => `'${n}'`).join(" ")}; do
        [ -f "$n" ] || continue
        cp -pL -- "$n" "$n.lucerna-bak" || exit 1
    done
fi
st=0
while [ $# -ge 3 ]; do
    case $2 in
        w) mkdir -p "$(dirname "$1")" && printf '%s' "$3" > "$1" || st=1 ;;
        rm) rm -f -- "$1" || st=1 ;;
    esac
    shift 3
done
exit $st`, "sh", configHome, job.op === "restore" ? "restore" : plan.fresh ? "fresh" : "apply"].concat(args);
        writer.running = true;
    }

    Process {
        id: writer

        property var job: null
        property var backup: null

        onExited: code => {
            if (code !== 0)
                console.warn(`Lucerna: não consegui gravar todos os arquivos da escala pelos apps (código ${code})`);
            root.announce(writer.job, writer.backup);
            root.finish();
        }
    }

    // Depois de gravar: o Hyprland (a seção do arquivo e o mesmo Lua na hora),
    // o cursor e o xrdb.
    function announce(job: var, backup: var): void {
        const theme = Quickshell.env("HYPRCURSOR_THEME") || Quickshell.env("XCURSOR_THEME") || "default";
        if (job.op === "apply") {
            const lua = hyprLua(job.f, ThemeManager.hyprland);
            HyprFile.setSection("scale", lua);
            Hypr.evalLua(lua);
            Quickshell.execDetached(["hyprctl", "setcursor", theme, String(Math.round(24 * job.f))]);
            if (hasXrdb)
                Quickshell.execDetached(["xrdb", "-merge", `${configHome}/${xresourcesFile}`]);
        } else {
            HyprFile.setSection("scale", "");
            Hypr.evalLua(restoreLua(backup));
            Quickshell.execDetached(["hyprctl", "setcursor", theme, String(backup?.env?.XCURSOR_SIZE || 24)]);
            if (hasXrdb)
                Quickshell.execDetached(["sh", "-c", 'printf "Xft.dpi: %s\\n" "$1" | xrdb -merge', "sh", String(backup?.xftDpi || 96)]);
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "command -v xrdb > /dev/null"]
        onExited: code => root.hasXrdb = code === 0
    }
}
