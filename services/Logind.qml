pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// A escuta do logind: os sinais Lock e Unlock da nossa sessão (loginctl
// lock-session e unlock-session), o PrepareForSleep (antes de dormir e ao
// acordar) e a tampa (LidClosed), lidos de um `gdbus monitor`. E o inibidor
// delay de sono: a máquina só dorme depois de o shell soltar o inibidor (a
// Session solta com o bloqueio na tela) ou do prazo do logind
// (InhibitDelayMaxUSec), se o shell estiver lento ou morto.
// No modo de desenvolvimento (LUCERNA_DEV=1) o barramento do sistema é o do
// host: o serviço só liga com LUCERNA_LOGIND_BUS, o barramento privado do
// logind falso (ci/logind-fake.sh). Com LUCERNA_LOGIND=off (a unidade), fica
// desligado sempre: nenhum gdbus nem inibidor roda.
Singleton {
    id: root

    readonly property string busOverride: Quickshell.env("LUCERNA_LOGIND_BUS") ?? ""
    readonly property bool off: Quickshell.env("LUCERNA_LOGIND") === "off"
    readonly property bool enabled: !off && (!DevMode.active || busOverride !== "")
    readonly property var busArgs: busOverride !== "" ? ["--address", busOverride] : ["--system"]
    readonly property string sessionId: Quickshell.env("XDG_SESSION_ID") || "auto"

    property string sessionPath: ""
    property bool lidClosed: false
    // A última mudança do lidClosed veio de um evento de verdade (a tampa
    // abriu ou fechou), e não da leitura na partida: só ela pode bloquear.
    property bool lidFromEvent: false
    // O shell quer o inibidor (o processo só roda com o serviço ligado e a
    // ferramenta achada).
    property bool holding: false

    // A ferramenta do inibidor (systemd-inhibit ou elogind-inhibit), achada uma vez.
    property string inhibitTool: ""
    property bool toolChecked: false
    // O setpriv --pdeathsig na frente do monitor e do inibidor (só um que
    // aceite a opção: o applet do BusyBox e o util-linux < 2.33 não aceitam): com o shell
    // morto (queda, kill do supervisor), eles morrem junto. Sem isso, o
    // inibidor de um shell antigo seguraria cada suspensão até o prazo.
    property string setpriv: ""
    // As esperas da volta do monitor e do inibidor: 1 s, dobrando até 30 s.
    property int monitorDelay: 1000
    property int inhibitorDelay: 1000
    property real inhibitorStartedAt: 0
    // O logind deixa hibernar (CanHibernate "yes" ou "challenge"). Sem
    // resposta (o serviço desligado, um logind que não responde), fica true:
    // a opção aparece, como antes.
    property bool canHibernate: true
    // O LockedHint pedido enquanto outro pedido ainda corre (null: nenhum).
    property var pendingHint: null

    signal lockRequested
    signal unlockRequested
    signal prepareForSleep(start: bool)
    // O LidClosed foi lido (na partida e a cada volta do monitor), mudando ou não.
    signal lidRead

    // Uma linha do `gdbus monitor --dest org.freedesktop.login1`: null ou
    // { kind: "lock"|"unlock"|"sleep"|"lid", value }. Lock e Unlock só da nossa
    // sessão (sessionPath); a tampa só do PropertiesChanged do Manager.
    function parseLine(line: string, sessionPath: string): var {
        const m = /^(\/\S*): (\S+) \((.*)\)\s*$/.exec(line ?? "");
        if (!m)
            return null;
        const [, path, member, args] = m;
        if (member === "org.freedesktop.login1.Session.Lock" || member === "org.freedesktop.login1.Session.Unlock") {
            if (!sessionPath || path !== sessionPath)
                return null;
            return member.endsWith(".Lock") ? { kind: "lock", value: true } : { kind: "unlock", value: false };
        }
        if (path !== "/org/freedesktop/login1")
            return null;
        if (member === "org.freedesktop.login1.Manager.PrepareForSleep") {
            const b = /^(true|false),?$/.exec(args.trim());
            return b ? { kind: "sleep", value: b[1] === "true" } : null;
        }
        if (member === "org.freedesktop.DBus.Properties.PropertiesChanged" && args.startsWith("'org.freedesktop.login1.Manager'")) {
            const lid = /'LidClosed': <(true|false)>/.exec(args);
            return lid ? { kind: "lid", value: lid[1] === "true" } : null;
        }
        return null;
    }

    // A resposta do `gdbus call` de um método que devolve um caminho:
    // "(objectpath '/org/…',)" → "/org/…"; outra coisa → "".
    function parseObjectPath(text: string): string {
        const m = /\(objectpath '(\/[^']*)',\)/.exec(text ?? "");
        return m ? m[1] : "";
    }

    // A resposta do Properties.Get do LidClosed: "(<true>,)" → true; outra coisa → null.
    function parseLidReply(text: string): var {
        const m = /\(<(true|false)>,\)/.exec(text ?? "");
        return m ? m[1] === "true" : null;
    }

    // A resposta de um Can* do Manager: "('yes',)" → "yes"; outra coisa → "".
    function parseCanReply(text: string): string {
        const m = /\('([a-z-]+)',\)/.exec(text ?? "");
        return m ? m[1] : "";
    }

    // Hibernar pela resposta do CanHibernate: "yes", ou "challenge" (o polkit
    // pede a senha); "no" e "na" (sem swap que caiba a memória) não. Sem
    // resposta, como antes: pode.
    function canHibernateFrom(reply: string): bool {
        return reply === "" || reply === "yes" || reply === "challenge";
    }

    // Pega o inibidor delay de sono (de novo, ao acordar). Sem nenhuma
    // ferramenta, segue sem ele (o aviso sai uma vez, na busca).
    function holdSleep(): void {
        if (holding)
            return;
        if (enabled && toolChecked && inhibitTool === "")
            return;
        holding = true;
        startInhibitor();
    }

    // Solta o inibidor: o logind pode dormir. Com um LockedHint ainda a
    // caminho, espera ele chegar (o logind vê a sessão bloqueada ao dormir).
    function releaseSleep(): void {
        holding = false;
        retryInhibitor.stop();
        if (!hint.running && inhibitor.running)
            inhibitor.running = false;
    }

    // SetLockedHint na nossa sessão (o logind mostra a sessão bloqueada).
    function setLockedHint(on: bool): void {
        if (!enabled || sessionPath === "")
            return;
        if (hint.running) {
            pendingHint = on;
            return;
        }
        hint.command = ["gdbus", "call"].concat(busArgs, ["--dest", "org.freedesktop.login1", "--object-path", sessionPath, "--method", "org.freedesktop.login1.Session.SetLockedHint", on ? "true" : "false"]);
        hint.running = true;
    }

    function startInhibitor(): void {
        if (!enabled || !holding || inhibitTool === "" || inhibitor.running)
            return;
        // O barramento do logind falso só no ambiente do inibidor (o env dá
        // lugar à ferramenta: o processo é o dela).
        const env = busOverride !== "" ? ["env", `DBUS_SYSTEM_BUS_ADDRESS=${busOverride}`] : [];
        inhibitor.command = guarded(setpriv, env.concat([inhibitTool, "--what=sleep", "--mode=delay", "--who=Lucerna", "--why=Bloquear a tela antes de dormir", "sleep", "infinity"]));
        inhibitor.running = true;
    }

    // O comando com o setpriv --pdeathsig na frente; sem setpriv (ou com um
    // que não aceita a opção), o comando puro.
    function guarded(setpriv: string, argv: var): var {
        return setpriv ? [setpriv, "--pdeathsig", "TERM", "--"].concat(argv) : argv;
    }

    function startMonitor(): void {
        if (!enabled || !toolChecked || monitor.running)
            return;
        if (sessionPath === "")
            session.running = true;
        monitor.running = true;
        // A tampa pode estar fechada desde antes (o shell reiniciado com ela
        // fechada) ou ter mudado enquanto o monitor estava fora.
        lid.running = true;
        canHibernateCall.running = true;
    }

    function handle(event: var): void {
        if (!event)
            return;
        if (event.kind === "lock")
            lockRequested();
        else if (event.kind === "unlock")
            unlockRequested();
        else if (event.kind === "sleep")
            prepareForSleep(event.value);
        else if (event.kind === "lid") {
            lidFromEvent = true;
            lidClosed = event.value;
        }
    }

    Component.onCompleted: {
        if (!enabled) {
            console.info(off ? "Logind: desligado (LUCERNA_LOGIND=off)" : "Logind: desligado no modo de desenvolvimento sem LUCERNA_LOGIND_BUS (o barramento do sistema é o do host)");
            return;
        }
        tool.running = true;
    }

    Process {
        id: tool

        // Duas linhas: a ferramenta do inibidor e o setpriv que aceita o
        // --pdeathsig (vazias sem eles).
        command: ["sh", "-c", "command -v systemd-inhibit || command -v elogind-inhibit || echo; setpriv --pdeathsig TERM -- true > /dev/null 2>&1 && command -v setpriv || echo"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [inhibit, setpriv] = text.split("\n").map(l => l.trim());
                root.inhibitTool = inhibit ?? "";
                root.setpriv = setpriv ?? "";
                root.toolChecked = true;
                if (!setpriv)
                    console.warn("Logind: sem um setpriv com --pdeathsig; numa queda do shell, o inibidor e o monitor antigos podem sobrar");
                root.startMonitor();
                if (root.inhibitTool === "") {
                    console.warn("Logind: sem systemd-inhibit nem elogind-inhibit; a máquina pode dormir antes de a tela bloquear");
                    root.holding = false;
                    return;
                }
                root.startInhibitor();
            }
        }
    }

    Process {
        id: session

        command: ["gdbus", "call"].concat(root.busArgs, ["--dest", "org.freedesktop.login1", "--object-path", "/org/freedesktop/login1", "--method", "org.freedesktop.login1.Manager.GetSession", root.sessionId])
        stdout: StdioCollector {
            onStreamFinished: {
                const path = root.parseObjectPath(text);
                if (path !== "")
                    root.sessionPath = path;
                else
                    console.warn(`Logind: a sessão "${root.sessionId}" não foi achada; o Lock e o Unlock do logind ficam de fora até a próxima tentativa`);
            }
        }
    }

    // O CanHibernate do Manager: sem swap (ou sem suporte), a opção de
    // hibernar some. Lido na partida e a cada volta do monitor.
    Process {
        id: canHibernateCall

        command: ["gdbus", "call"].concat(root.busArgs, ["--dest", "org.freedesktop.login1", "--object-path", "/org/freedesktop/login1", "--method", "org.freedesktop.login1.Manager.CanHibernate"])
        stdout: StdioCollector {
            onStreamFinished: {
                const reply = root.parseCanReply(text);
                if (reply === "")
                    console.warn("Logind: o CanHibernate não foi lido; a opção de hibernar fica como está");
                else
                    root.canHibernate = root.canHibernateFrom(reply);
            }
        }
    }

    Process {
        id: lid

        command: ["gdbus", "call"].concat(root.busArgs, ["--dest", "org.freedesktop.login1", "--object-path", "/org/freedesktop/login1", "--method", "org.freedesktop.DBus.Properties.Get", "org.freedesktop.login1.Manager", "LidClosed"])
        stdout: StdioCollector {
            onStreamFinished: {
                const closed = root.parseLidReply(text);
                if (closed === null) {
                    console.warn("Logind: o estado da tampa (LidClosed) não foi lido; fica o último conhecido");
                    return;
                }
                root.lidFromEvent = false;
                root.lidClosed = closed;
                root.lidRead();
            }
        }
    }

    Process {
        id: monitor

        command: root.guarded(root.setpriv, ["gdbus", "monitor"].concat(root.busArgs, ["--dest", "org.freedesktop.login1"]))
        stdout: SplitParser {
            onRead: line => {
                root.monitorDelay = 1000;
                root.handle(root.parseLine(line, root.sessionPath));
            }
        }
        onExited: code => {
            console.warn(`Logind: o gdbus monitor saiu (código ${code}); de volta em ${root.monitorDelay / 1000} s`);
            retryMonitor.interval = root.monitorDelay;
            root.monitorDelay = Math.min(root.monitorDelay * 2, 30000);
            retryMonitor.start();
        }
    }

    Timer {
        id: retryMonitor

        onTriggered: root.startMonitor()
    }

    // O inibidor: o processo segura o fd do logind enquanto vive; o
    // systemd-inhibit mata o `sleep` filho quando morre.
    Process {
        id: inhibitor

        onStarted: root.inhibitorStartedAt = Date.now()
        onExited: code => {
            if (!root.holding)
                return;
            // Um inibidor que durou é uma queda nova: a espera recomeça.
            if (Date.now() - root.inhibitorStartedAt > 30000)
                root.inhibitorDelay = 1000;
            if (root.inhibitorDelay === 1000)
                console.warn(`Logind: o inibidor saiu (código ${code}); tentando de novo`);
            retryInhibitor.interval = root.inhibitorDelay;
            root.inhibitorDelay = Math.min(root.inhibitorDelay * 2, 30000);
            retryInhibitor.start();
        }
    }

    Timer {
        id: retryInhibitor

        onTriggered: root.startInhibitor()
    }

    Process {
        id: hint

        onExited: code => {
            if (code !== 0)
                console.warn(`Logind: o SetLockedHint falhou (código ${code})`);
            if (!root.holding && inhibitor.running)
                inhibitor.running = false;
            if (root.pendingHint !== null) {
                const on = root.pendingHint;
                root.pendingHint = null;
                root.setLockedHint(on);
            }
        }
    }
}
