// Testes de services/Logind: a leitura das linhas do `gdbus monitor` e do
// GetSession (as linhas guardadas do logind falso, ci/logind-fake.py). Só as
// funções puras e o estado do inibidor: na unidade o serviço fica desligado
// (LUCERNA_LOGIND=off, do ci/lib.sh) e nenhum gdbus ou systemd-inhibit roda.
function run(t) {
    const L = t.Logind;
    const ours = "/org/freedesktop/login1/session/_31";
    const other = "/org/freedesktop/login1/session/_7";

    t.test("logind: desligado na unidade", () => {
        t.check(!L.enabled, "LUCERNA_LOGIND=off desliga o serviço");
    });

    t.test("logind: Lock da nossa sessão bloqueia e de outra não", () => {
        const line = "/org/freedesktop/login1/session/_31: org.freedesktop.login1.Session.Lock ()";
        t.eq(L.parseLine(line, ours), { kind: "lock", value: true }, "a nossa");
        t.eq(L.parseLine(line, other), null, "de outra sessão");
        t.eq(L.parseLine(line, ""), null, "sem o caminho da sessão");
    });

    t.test("logind: Unlock", () => {
        const line = "/org/freedesktop/login1/session/_31: org.freedesktop.login1.Session.Unlock ()";
        t.eq(L.parseLine(line, ours), { kind: "unlock", value: false }, "a nossa");
        t.eq(L.parseLine(line, other), null, "de outra sessão");
    });

    t.test("logind: PrepareForSleep true e false", () => {
        t.eq(L.parseLine("/org/freedesktop/login1: org.freedesktop.login1.Manager.PrepareForSleep (true,)", ours), { kind: "sleep", value: true }, "true");
        t.eq(L.parseLine("/org/freedesktop/login1: org.freedesktop.login1.Manager.PrepareForSleep (false,)", ours), { kind: "sleep", value: false }, "false");
        t.eq(L.parseLine("/org/freedesktop/login1: org.freedesktop.login1.Manager.PrepareForSleep (false,)", ""), { kind: "sleep", value: false }, "sem o caminho da sessão também");
    });

    t.test("logind: LidClosed no PropertiesChanged", () => {
        const head = "/org/freedesktop/login1: org.freedesktop.DBus.Properties.PropertiesChanged ('org.freedesktop.login1.Manager', ";
        t.eq(L.parseLine(`${head}{'LidClosed': <true>}, @as [])`, ours), { kind: "lid", value: true }, "<true>");
        t.eq(L.parseLine(`${head}{'LidClosed': <false>}, @as [])`, ours), { kind: "lid", value: false }, "<false>");
        t.eq(L.parseLine(`${head}{'Docked': <true>, 'LidClosed': <true>}, @as [])`, ours), { kind: "lid", value: true }, "junto de outra");
        t.eq(L.parseLine(`${head}{'Docked': <true>}, @as [])`, ours), null, "sem LidClosed");
        t.eq(L.parseLine("/org/freedesktop/login1/session/_31: org.freedesktop.DBus.Properties.PropertiesChanged ('org.freedesktop.login1.Session', {'LockedHint': <true>}, @as [])", ours), null, "o LockedHint da sessão");
    });

    t.test("logind: lixo e linha vazia dão null", () => {
        t.eq(L.parseLine("", ours), null, "vazia");
        t.eq(L.parseLine("Monitoring signals from all objects owned by org.freedesktop.login1", ours), null, "o cabeçalho");
        t.eq(L.parseLine("The name org.freedesktop.login1 is owned by :1.1", ours), null, "o dono");
        t.eq(L.parseLine("qualquer coisa: Lock ()", ours), null, "lixo");
        t.eq(L.parseLine("/org/freedesktop/login1: org.freedesktop.login1.Manager.PrepareForSleep (talvez,)", ours), null, "PrepareForSleep sem booleano");
    });

    t.test("logind: o caminho do GetSession", () => {
        t.eq(L.parseObjectPath("(objectpath '/org/freedesktop/login1/session/_31',)\n"), ours, "a resposta do gdbus call");
        t.eq(L.parseObjectPath("(objectpath '/org/freedesktop/login1/session/c2',)"), "/org/freedesktop/login1/session/c2", "outro id");
        t.eq(L.parseObjectPath(""), "", "vazia");
        t.eq(L.parseObjectPath("Error: GDBus.Error:org.freedesktop.login1.NoSuchSession: ..."), "", "erro");
    });

    t.test("logind: segurar e soltar o inibidor (desligado: só o estado)", () => {
        const before = L.holding;
        L.releaseSleep();
        t.check(!L.holding, "solto");
        L.holdSleep();
        t.check(L.holding, "seguro");
        L.holdSleep();
        t.check(L.holding, "segurar de novo não muda");
        L.releaseSleep();
        t.check(!L.holding, "solto de novo");
        L.holding = before;
    });
}
