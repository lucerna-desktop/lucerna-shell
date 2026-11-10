// Testes de features/displays/state/DisplaysState: a tampa lida na partida
// antes da lista dos monitores. Na unidade não há Hyprland (o hyprctl do
// Monitors.setEnabled não acha nada) e o Logind fica desligado: só o estado.
function run(t) {
    const D = t.DisplaysState;
    const M = t.Monitors;
    const L = t.Logind;
    const before = { monitors: M.monitors, lid: L.lidClosed, last: D.lastLidPlan, waits: D.lidWaitsMonitors };
    const mon = (name, enabled) => ({ name: name, key: name, enabled: enabled, description: "", width: 1920, height: 1080, refresh: 60, x: 0, y: 0, scale: 1, transform: 0, vrr: 0, tenBit: false, mirror: "", modes: [] });

    t.test("displaysstate: a tampa aberta lida com a lista vazia religa a eDP na primeira lista", () => {
        M.monitors = [];
        L.lidClosed = false;
        D.lastLidPlan = "";
        L.lidRead();
        t.check(D.lidWaitsMonitors, "lida sem monitores: espera a lista");
        t.eq(D.lastLidPlan, "", "nada mandado ainda");
        M.monitors = [mon("eDP-1", false), mon("HDMI-A-1", true)];
        t.eq(D.lastLidPlan, '[[],["eDP-1"]]', "a eDP desligada volta com a tampa aberta");
        t.check(!D.lidWaitsMonitors, "uma vez só");
    });

    t.test("displaysstate: com a tampa aberta, depois disso, um monitor que muda não mexe na eDP", () => {
        D.lastLidPlan = "";
        M.monitors = [mon("eDP-1", false), mon("HDMI-A-1", true), mon("DP-1", true)];
        t.eq(D.lastLidPlan, "", "o interno desligado nas Configurações fica desligado");
    });

    t.test("displaysstate: a tampa lida com monitores não espera a lista", () => {
        M.monitors = [mon("eDP-1", true)];
        L.lidRead();
        t.check(!D.lidWaitsMonitors, "com a lista: o plano vale na hora");
    });

    t.test("displaysstate: a lista ainda vazia continua esperando", () => {
        M.monitors = [];
        L.lidRead();
        M.monitors = [];
        t.check(D.lidWaitsMonitors, "uma lista vazia de novo não gasta a espera");
        M.monitors = [mon("eDP-1", false)];
        t.eq(D.lastLidPlan, '[[],["eDP-1"]]', "a primeira lista com monitores religa");
        t.check(!D.lidWaitsMonitors, "e a espera acaba");
    });

    M.monitors = before.monitors;
    L.lidClosed = before.lid;
    D.lastLidPlan = before.last;
    D.lidWaitsMonitors = before.waits;
}
