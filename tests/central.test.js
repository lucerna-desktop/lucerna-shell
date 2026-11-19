// Testes da central (features/central/state): a página que cada entrada
// abre, a volta ao estado inicial, os tiles do painel de Ações, a linha de
// estado da bateria e os popups de notificação com a central aberta. Abre
// pelo Panels, como a barra e os atalhos; cada caso fecha a central e devolve
// os painéis abertos ao que eram.
function run(t) {
    const S = t.CentralState;
    const P = t.Panels;
    const opened0 = P.opened;

    // Roda o corpo e, mesmo com exceção, fecha e restaura os painéis.
    function scenario(name, body) {
        t.test(name, () => {
            try {
                body();
            } finally {
                P.close();
                P.opened = opened0;
            }
        });
    }

    // O que existe na máquina: tudo, nada, ou tudo menos um recurso.
    const all = { wifi: true, bluetooth: true, output: true, input: true, power: true };
    const none = { wifi: false, bluetooth: false, output: false, input: false, power: false };
    const without = key => Object.assign({}, all, { [key]: false });

    t.test("central: a página de cada entrada", () => {
        const entries = ["rede", "bluetooth", "som", "energia", "microfone", "notificacoes", ""];
        t.eq(entries.map(e => S.pageFor(e, all)), ["wifi", "bluetooth", "output", "battery", "input", "", ""]);
        t.eq(entries.map(e => S.pageFor(e, none)), ["", "", "", "", "", "", ""], "sem o recurso, o estado inicial");
        t.eq([S.pageFor("rede", without("wifi")), S.pageFor("som", without("output")), S.pageFor("energia", without("power")), S.pageFor("microfone", without("input")), S.pageFor("bluetooth", without("bluetooth"))], ["", "", "", "", ""], "só o recurso da entrada falta");
        t.eq([S.pageFor("som", without("wifi")), S.pageFor("wifi", all), S.pageFor("sound", all)], ["output", "", ""], "outro recurso faltando não muda; nome antigo ou desconhecido, estado inicial");
    });

    t.test("central: a página volta ao estado inicial quando o recurso some", () => {
        const pages = ["", "wifi", "bluetooth", "output", "input", "battery"];
        t.eq(pages.map(p => S.pageIfPresent(p, all)), pages, "com tudo, a página fica");
        t.eq(pages.map(p => S.pageIfPresent(p, none)), ["", "", "", "", "", ""]);
        t.eq([S.pageIfPresent("wifi", without("wifi")), S.pageIfPresent("bluetooth", without("bluetooth")), S.pageIfPresent("output", without("output")), S.pageIfPresent("input", without("input")), S.pageIfPresent("battery", without("power"))], ["", "", "", "", ""], "o recurso da página sumiu");
        t.eq([S.pageIfPresent("output", without("wifi")), S.pageIfPresent("battery", without("input"))], ["output", "battery"], "outro recurso sumiu: a página fica");
        t.eq(S.pageIfPresent("x", all), "", "página desconhecida");
    });

    // A bateria simulada controla o recurso da página "battery": com ela, a
    // entrada "energia" abre a página; sem ela (nem perfil), não.
    scenario("central: a entrada escolhe a página", () => {
        const B = t.Battery;
        const simulated0 = B.simulated;
        const profiles0 = B.profilesReported;
        try {
            B.simulated = { percentage: 0.5, onBattery: true };
            P.openActions("energia");
            t.eq([S.actionsOpen, P.centralEntry, S.page], [true, "energia", "battery"]);
            for (const entry of ["notificacoes", ""]) {
                P.openActions(entry);
                t.eq(S.page, "", `entrada "${entry}": o estado inicial`);
            }
            P.openCentral("energia");
            t.eq([S.actionsOpen, S.notificationsOpen, S.page], [true, true, "battery"], "o central com entrada também");
            P.openCentral("");
            t.eq(S.page, "battery", "o central sem entrada não troca a página");
            B.simulated = null;
            B.profilesReported = false;
            if (t.PowerState.devices.length === 0) {
                P.openActions("energia");
                t.eq([P.centralEntry, S.page], ["energia", ""], "sem bateria, perfil e dispositivos: o estado inicial");
            }
        } finally {
            B.simulated = simulated0;
            B.profilesReported = profiles0;
        }
    });

    scenario("central: o recurso da página aberta some e ela volta ao estado inicial", () => {
        const B = t.Battery;
        const simulated0 = B.simulated;
        const profiles0 = B.profilesReported;
        try {
            B.simulated = null;
            B.profilesReported = true;
            P.openActions("");
            S.setPage("battery");
            t.eq(S.page, "battery");
            B.profilesReported = false;
            if (t.PowerState.devices.length === 0)
                t.eq(S.page, "", "sem bateria, perfil e dispositivos");
            S.setPage("output");
            B.profilesReported = true;
            t.eq(S.page, S.has.output ? "output" : "", "outro recurso mudou: a página só sai se o dela faltar");
        } finally {
            B.simulated = simulated0;
            B.profilesReported = profiles0;
        }
    });

    scenario("central: entrada desconhecida abre o estado inicial", () => {
        P.openActions("wifi");
        t.eq([S.actionsOpen, P.centralEntry, S.page], [true, "", ""], "o nome antigo do IPC");
    });

    scenario("central: a reabertura começa do zero", () => {
        P.openCentral("rede");
        S.setPage("battery");
        P.toggleCentral("rede");
        t.eq([S.actionsOpen, P.centralEntry, S.page], [false, "", "battery"], "na saída, a página fica até o painel sumir");
        P.open("central");
        t.eq([S.actionsOpen, P.centralEntry, S.page], [true, "", ""], "aberta sem entrada (panels open central)");
    });

    scenario("central: só as ações voltam ao estado inicial", () => {
        P.openActions("rede");
        S.setPage("bluetooth");
        P.openNotifications();
        t.eq(S.page, "bluetooth", "abrir as notificações não mexe na página");
        P.closeNotifications();
        t.eq(S.page, "bluetooth", "nem fechá-las");
        P.openNotifications();
        P.closeActions();
        t.eq([S.actionsOpen, S.notificationsOpen, S.open, S.page], [false, true, true, "bluetooth"], "fechar as ações deixa a página até o painel sumir");
        P.toggleActions("");
        t.eq([S.actionsOpen, S.page], [true, ""], "reabertas com as notificações abertas, começam do zero");
    });

    scenario("central: a busca de redes só com a página do Wi-Fi nas ações", () => {
        const N = t.Network;
        P.openNotifications();
        t.eq(N.scanning, false, "só as notificações");
        P.openActions("");
        S.setPage("wifi");
        t.eq(N.scanning, true, "a página do Wi-Fi");
        P.closeActions();
        t.eq([S.notificationsOpen, N.scanning], [true, false], "as ações fecharam, as notificações não");
    });

    scenario("central: trocar de entrada troca a página", () => {
        P.openCentral("rede");
        S.setPage("bluetooth");
        P.openCentral("notificacoes");
        t.eq(S.page, "");
    });

    scenario("central: outro painel fecha a central e esquece a página", () => {
        P.openCentral("rede");
        S.setPage("bluetooth");
        P.open("launcher");
        t.eq([S.open, S.actionsOpen, S.notificationsOpen, P.centralEntry], [false, false, false, ""]);
        P.openActions("");
        t.eq(S.page, "", "reaberta, começa do zero");
    });

    const K = t.ControlsState;
    const C = t.Config;
    const extras = { nightlight: true, awake: true };
    const ids = has => K.tilesFor(Object.assign({}, extras, has)).map(x => x.id);

    t.test("ações: os tiles e o que some", () => {
        t.eq(ids(all), ["wifi", "bluetooth", "output", "battery", "input", "nightlight", "dnd", "awake"], "tudo, na ordem");
        t.eq(ids(without("power")), ["wifi", "bluetooth", "output", "input", "nightlight", "dnd", "awake"], "sem bateria, perfil e dispositivos");
        t.eq(ids(without("input")), ["wifi", "bluetooth", "output", "battery", "nightlight", "dnd", "awake"], "sem microfone");
        t.eq(ids(without("output")), ["wifi", "bluetooth", "battery", "input", "nightlight", "dnd", "awake"], "sem saída de áudio");
        t.eq(ids(without("bluetooth")), ["wifi", "output", "battery", "input", "nightlight", "dnd", "awake"], "sem adaptador Bluetooth");
        t.eq(ids(without("wifi")), ["network", "bluetooth", "output", "battery", "input", "nightlight", "dnd", "awake"], "sem placa Wi-Fi, vira Rede");
        t.eq(K.tilesFor(Object.assign({}, all, { nightlight: false, awake: true })).map(x => x.id), ["wifi", "bluetooth", "output", "battery", "input", "dnd", "awake"], "sem o hyprsunset");
        t.eq(K.tilesFor(Object.assign({}, all, { nightlight: true, awake: false })).map(x => x.id), ["wifi", "bluetooth", "output", "battery", "input", "nightlight", "dnd"], "com a ociosidade do shell desligada");
        t.eq(K.tilesFor(Object.assign({}, none, { nightlight: false, awake: false })).map(x => x.id), ["network", "dnd"], "o mínimo");
    });

    t.test("ações: título, página e liga/desliga de cada tile", () => {
        const tiles = K.tilesFor(Object.assign({}, extras, all));
        t.eq(tiles.map(x => [x.id, x.title, x.page, x.toggles]), [
            ["wifi", "Wi-Fi", "wifi", true],
            ["bluetooth", "Bluetooth", "bluetooth", true],
            ["output", "Saída de áudio", "output", false],
            ["battery", t.PowerState.title, "battery", false],
            ["input", "Microfone", "input", true],
            ["nightlight", "Luz noturna", "", true],
            ["dnd", "Não perturbe", "", true],
            ["awake", "Não apagar a tela", "", true]
        ]);
        const net = K.tilesFor(Object.assign({}, extras, without("wifi")))[0];
        t.eq([net.title, net.page, net.toggles, net.clickable, net.checked], ["Rede", "", false, false, false], "Rede: sem página e sem clique");
        t.eq(tiles.filter(x => x.id === "output" || x.id === "battery").map(x => x.checked), [false, false], "sem liga/desliga, sempre neutros");
        t.check(tiles.every(x => x.clickable && typeof x.status === "string" && x.icon !== ""), "os outros clicáveis, com linha de estado e ícone");
    });

    t.test("ações: ligado e desligado", () => {
        const dnd0 = C.doNotDisturb;
        const idle0 = C.idleEnabled;
        const awake0 = C.idleInhibit;
        const tile = id => K.tilesFor(Object.assign({}, extras, all)).find(x => x.id === id);
        try {
            C.idleEnabled = true;
            C.idleInhibit = false;
            C.doNotDisturb = false;
            t.eq([tile("dnd").checked, tile("dnd").status, tile("awake").checked, tile("awake").status], [false, "Desligado", false, "Desligado"]);
            K.activate("dnd");
            K.activate("awake");
            t.eq([C.doNotDisturb, C.idleInhibit], [true, true]);
            t.eq([tile("dnd").checked, tile("dnd").status, tile("awake").checked, tile("awake").status], [true, "Ligado", true, "Ligado"], "cheios");
            t.eq(K.tiles.find(x => x.id === "dnd")?.checked, true, "a lista viva acompanha");
            C.idleEnabled = false;
            t.eq(K.tiles.some(x => x.id === "awake"), false, "a lista viva sem a ociosidade do shell");
        } finally {
            C.doNotDisturb = dnd0;
            C.idleEnabled = idle0;
            C.idleInhibit = awake0;
        }
    });

    t.test("ações: bateria baixa pinta o ícone do tile", () => {
        const B = t.Battery;
        const simulated0 = B.simulated;
        const level0 = C.batteryLowLevel;
        const battery = () => K.tilesFor(Object.assign({}, extras, all)).find(x => x.id === "battery");
        try {
            C.batteryLowLevel = 20;
            B.simulated = { percentage: 0.1, onBattery: true };
            t.eq([battery().alert, battery().checked], [true, false], "pouca carga, na bateria: alerta, mas neutro");
            B.simulated = { percentage: 0.1, onBattery: false };
            t.eq(battery().alert, false, "carregando");
            B.simulated = { percentage: 0.6, onBattery: true };
            t.eq(battery().alert, false, "acima do limite");
            B.simulated = null;
            t.eq(battery().alert, false, "sem bateria");
        } finally {
            B.simulated = simulated0;
            C.batteryLowLevel = level0;
        }
    });

    scenario("ações: o corpo dos tiles sem liga/desliga abre a página", () => {
        P.openActions("");
        K.activate("output");
        t.eq(S.page, "output");
        K.activate("battery");
        t.eq(S.page, "battery");
        K.activate("network");
        t.eq(S.page, "battery", "a Rede não tem clique");
    });

    scenario("ações: a engrenagem abre as configurações e fecha a central", () => {
        P.openCentral("");
        K.openSettings();
        t.eq([P.opened, S.open, S.actionsOpen, S.notificationsOpen], [["settings"], false, false, false]);
    });

    const E = t.PowerState;
    const B = t.Battery;

    t.test("energia: o que aparece sem bateria, sem perfil e sem dispositivos", () => {
        const simulated0 = B.simulated;
        const profiles0 = B.profilesReported;
        try {
            B.simulated = null;
            B.profilesReported = false;
            t.eq([E.hasBattery, E.profilesAvailable, E.devices.length, E.any], [false, false, 0, false], "desktop sem nada: o painel some");
            B.profilesReported = true;
            t.eq([E.hasBattery, E.any], [false, true], "só o perfil");
            t.eq(E.profileButtons.map(b => b.value), B.hasPerformance ? [0, 1, 2] : [0, 1], "desempenho só se o daemon tiver");
            B.profilesReported = false;
            B.simulated = { percentage: 0.78, onBattery: true };
            t.eq([E.hasBattery, E.any, E.batteryNote], [true, true, ""], "na bateria, sem o tempo (a simulada não tem)");
            B.simulated = { percentage: 0.5, onBattery: false };
            t.eq(E.batteryNote, "Carregando");
            B.simulated = { percentage: 1, onBattery: false };
            t.eq(E.batteryNote, "Carregada");
        } finally {
            B.simulated = simulated0;
            B.profilesReported = profiles0;
        }
    });

    t.test("energia: a linha de estado do tile", () => {
        const battery = (extra) => Object.assign({ hasBattery: true, percentage: 0.78, full: false, charging: false, timeRemaining: 0, profilesAvailable: true, profile: 1, devices: 0 }, extra);
        t.eq(E.statusLine(battery({ timeRemaining: 6720 })), "78% · 1 h 52 min", "com o tempo");
        t.eq(E.statusLine(battery({})), "78%", "sem estimativa");
        t.eq(E.statusLine(battery({ percentage: 0.4, charging: true, timeRemaining: 3600 })), "40% · Carregando", "carregando");
        t.eq(E.statusLine(battery({ percentage: 1, full: true })), "100% · Carregada", "carregada");
        const desktop = (extra) => Object.assign(battery({ hasBattery: false }), extra);
        t.eq([0, 1, 2].map(profile => E.statusLine(desktop({ profile }))), ["Economia", "Equilibrado", "Turbo"], "sem bateria, o perfil");
        t.eq([E.statusLine(desktop({ profilesAvailable: false, devices: 2 })), E.statusLine(desktop({ profilesAvailable: false, devices: 1 }))], ["2 dispositivos", "1 dispositivo"], "só dispositivos");
    });

    t.test("energia: o tile pela bateria simulada", () => {
        const simulated0 = B.simulated;
        const profiles0 = B.profilesReported;
        try {
            B.simulated = { percentage: 0.78, onBattery: true };
            t.eq([E.title, E.status], ["Bateria", "78%"], "a simulada não tem o tempo");
            B.simulated = { percentage: 0.5, onBattery: false };
            t.eq(E.status, "50% · Carregando");
            B.simulated = null;
            B.profilesReported = true;
            t.eq([E.title, E.status], ["Energia", E.statusLine({ hasBattery: false, profilesAvailable: true, profile: B.profile, devices: E.devices.length })], "sem bateria, Energia com o perfil");
        } finally {
            B.simulated = simulated0;
            B.profilesReported = profiles0;
        }
    });

    t.test("energia: bateria baixa pelo limite das configurações", () => {
        const simulated0 = B.simulated;
        const level0 = C.batteryLowLevel;
        try {
            C.batteryLowLevel = 20;
            t.eq(B.low, 0.2, "o limite segue Config.batteryLowLevel");
            B.simulated = { percentage: 0.2, onBattery: true };
            t.eq([B.isLow, E.low], [true, true], "no limite, na bateria (como o aviso)");
            B.simulated = { percentage: 0.204, onBattery: true };
            t.eq(B.isLow, true, "arredonda como o aviso (20%)");
            B.simulated = { percentage: 0.21, onBattery: true };
            t.eq([B.isLow, E.low], [false, false], "acima do limite");
            B.simulated = { percentage: 0.1, onBattery: false };
            t.eq([B.isLow, E.low], [false, false], "carregando não é baixa");
        } finally {
            B.simulated = simulated0;
            C.batteryLowLevel = level0;
        }
    });

    t.test("energia: bateria dos dispositivos Bluetooth", () => {
        const list = E.withBattery([
            { name: "WH-1000", address: "AA", icon: "audio-headset", connected: true, batteryAvailable: true, battery: 0.82 },
            { name: "", address: "BB", icon: "input-mouse", connected: true, batteryAvailable: true, battery: 0.41 },
            { name: "Teclado", address: "CC", icon: "input-keyboard", connected: true, batteryAvailable: false, battery: 0 },
            { name: "Caixa", address: "DD", icon: "audio-card", connected: false, batteryAvailable: true, battery: 0.9 }
        ]);
        t.eq(list, [{ name: "WH-1000", icon: "headset_mic", battery: 0.82 }, { name: "BB", icon: "mouse", battery: 0.41 }], "conectados e com bateria; sem nome, o endereço");
        t.eq(E.withBattery([]), []);
        t.eq(E.withBattery(null), []);
    });

    t.test("energia: a cor do card pela carga", () => {
        t.eq([0.78, 0.51, 1].map(p => E.band(p, false, false)), ["accent", "accent", "accent"], "acima de 50%: o destaque");
        t.eq([0.5, 0.3, 0.2, 0.505].map(p => E.band(p, false, false)), ["warning", "warning", "warning", "accent"], "de 50% para baixo: aviso; arredonda como a %");
        t.eq(E.band(0.1, false, true), "danger", "bateria baixa: erro");
        t.eq([E.band(0.4, true, false), E.band(0.1, true, false), E.band(0.9, true, false)], ["success", "success", "success"], "carregando: verde");
    });

    t.test("energia: os pontos do gráfico de consumo", () => {
        const at = (time, value) => ({ time, value });
        t.eq(E.chartPoints([at(1000, 5), at(2800, 10), at(4600, 5)], 4600, 3600), [{ x: 0, y: 0.5 }, { x: 0.5, y: 1 }, { x: 1, y: 0.5 }], "a hora inteira, o maior valor no topo");
        t.eq(E.chartPoints([at(0, 8), at(2800, 4)], 4600, 3600), [{ x: 0, y: 1 }, { x: 0.5, y: 0.5 }, { x: 1, y: 0.5 }], "o anterior à janela entra na borda; o último vai até agora");
        t.eq(E.chartPoints([at(4000, 6)], 4600, 3600), [{ x: 0.8333333333333334, y: 1 }, { x: 1, y: 1 }], "um ponto só: até agora");
        t.eq(E.chartPoints([at(1000, 0), at(4600, 0)], 4600, 3600), [{ x: 0, y: 0 }, { x: 1, y: 0 }], "tudo zero: no chão");
        t.eq(E.chartPoints([at(4600, 3)], 4600, 3600), [], "um ponto agora: sem linha");
        t.eq(E.chartPoints([], 4600, 3600), [], "sem histórico");
        t.eq(E.chartPoints([at(5000, 3), at(4600, 2)], 4600, 3600), [], "do futuro fica de fora");
    });

    t.test("energia: o gráfico só com as amostras da fase atual", () => {
        const list = [{ time: 1, value: 9, state: 2 }, { time: 2, value: 25, state: 1 }, { time: 3, value: 8, state: 6 }, { time: 4, value: 20, state: 5 }, { time: 5, value: 1, state: 0 }, { time: 6, value: 1, state: 4 }];
        t.eq(E.phase(list, false).map(p => p.time), [1, 3], "descarregando: as de descarga");
        t.eq(E.phase(list, true).map(p => p.time), [2, 4], "carregando: as de carga");
        t.eq(E.phase([], true), []);
    });

    t.test("energia: o consumo ao lado do gráfico", () => {
        t.eq(E.consumption(8.146, false), "8,1 W", "na bateria");
        t.eq(E.consumption(25.3, true), "Carregando · 25,3 W", "carregando, a potência de carga");
        t.eq([E.consumption(0, true), E.consumption(0, false)], ["Carregando", ""], "sem a medida");
    });

    scenario("energia: o histórico só é pedido com a página da bateria aberta", () => {
        const saved = { simulated: B.simulated, history: B.history, historyAt: B.historyAt, upowerHistory: B.upowerHistory };
        try {
            B.simulated = { percentage: 0.5, onBattery: true };
            t.eq(B.historyActive, false, "fechada");
            P.openActions("energia");
            t.eq(B.historyActive, true, "a página da bateria");
            S.setPage("");
            t.eq(B.historyActive, false, "voltou aos tiles");
            P.openNotifications();
            S.setPage("battery");
            t.eq(B.historyActive, true, "as notificações abertas junto não mudam nada");
            P.closeActions();
            t.eq(B.historyActive, false, "as ações fecharam, as notificações não");
            P.openActions("energia");
            P.close();
            t.eq(B.historyActive, false, "a central fechou");
        } finally {
            B.simulated = saved.simulated;
            B.history = saved.history;
            B.historyAt = saved.historyAt;
            B.upowerHistory = saved.upowerHistory;
        }
    });

    // Os popups ficam no canto das ações: escondidos com qualquer um dos dois
    // aberto; a fila só é limpa ao abrir e ao fechar as notificações.
    scenario("notificações: os popups com a central aberta", () => {
        const N = t.Notifications;
        const Q = t.NotificationsState;
        const popups0 = N.popups;
        try {
            N.popups = ["a"];
            t.eq([Q.popupsHidden, N.popups], [false, ["a"]], "fechada: à mostra");
            P.openActions("som");
            t.eq([Q.popupsHidden, N.popups], [true, ["a"]], "só as ações: escondidos, na fila");
            N.popups = ["b", "a"];
            t.eq(N.popups, ["b", "a"], "o que chega com só as ações espera");
            P.closeActions();
            t.eq([Q.popupsHidden, N.popups], [false, ["b", "a"]], "as ações fecharam: voltam");
            P.openActions("");
            P.openNotifications();
            t.eq([Q.popupsHidden, N.popups], [true, []], "abrir as notificações limpa");
            N.popups = ["c"];
            t.eq(N.popups, [], "o que chega com as notificações abertas já está na lista");
            P.closeNotifications();
            t.eq([Q.popupsHidden, N.popups], [true, []], "fechadas, as ações ainda escondem");
            N.popups = ["d"];
            P.close();
            t.eq([Q.popupsHidden, N.popups], [false, ["d"]], "fechar só as ações não limpa a fila");
        } finally {
            N.popups = popups0;
        }
    });

    t.test("notificações: o prazo do popup para enquanto ele está escondido", () => {
        const card = t.card({ popup: true, held: true, timeout: 5000 });
        try {
            t.eq([card.counting, card.remaining], [false, 1], "chegou escondido: o prazo fica cheio");
            card.held = false;
            t.eq(card.counting, true, "à mostra, corre");
            card.held = true;
            t.eq(card.counting, false, "escondido de novo, para");
        } finally {
            card.destroy();
        }
    });
}
