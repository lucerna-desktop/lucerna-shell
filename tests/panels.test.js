// Testes de core/panels/Panels: modais, o acompanhante (dashboard), a base
// (settings) e a central (as ações, pela entrada, e as notificações).
function run(t) {
    const P = t.Panels;
    const C = t.Config;
    const together0 = C.panelsTogether;
    C.panelsTogether = ["dashboard"];

    t.test("panels: tipos de painel", () => {
        t.check(P.isCompanion("dashboard"), "o dashboard acompanha");
        t.check(P.isModal("launcher") && P.isModal("themes") && P.isModal("central"), "launcher, themes e central são modais");
        t.check(!P.isModal("settings") && !P.isCompanion("settings"), "settings é a base");
        try {
            C.panelsTogether = ["dashboard", "sidebar"];
            t.check(!P.isCompanion("sidebar"), "um sidebar velho no config não acompanha");
        } finally {
            C.panelsTogether = ["dashboard"];
        }
    });

    t.test("panels: só os nomes de painel valem no IPC", () => {
        for (const n of ["launcher", "dashboard", "central", "settings", "themes", "power", "clipboard", "capture", "overview"])
            t.check(P.isPanel(n), n + " é painel");
        t.check(!P.isPanel("sidebar"), "o sidebar antigo não é painel");
        t.check(!P.isPanel(""), "nome vazio não é painel");
        t.check(!P.isPanel("Central"), "o nome tem de ser exato");
    });

    t.test("panels: modal fica sozinho", () => {
        P.close();
        P.open("dashboard");
        P.open("launcher");
        t.eq(P.opened, ["launcher"], "o modal fecha os outros");
        P.open("dashboard");
        t.eq(P.opened, ["dashboard"], "o acompanhante fecha o modal");
        t.eq(P.current, "dashboard");
    });

    t.test("panels: acompanhante abre por cima da base", () => {
        P.open("settings");
        t.eq(P.opened, ["settings"]);
        P.open("dashboard");
        t.eq(P.opened, ["settings", "dashboard"]);
        t.check(P.isOpen("settings") && P.isOpen("dashboard"), "os dois abertos");
    });

    t.test("panels: fechar um, alternar e fechar todos", () => {
        P.dismiss("settings");
        t.eq(P.opened, ["dashboard"]);
        t.check(P.lastDisturb > 0, "dispensar marca a perturbação do grab");
        P.toggle("launcher");
        t.eq(P.opened, ["launcher"]);
        P.toggle("launcher");
        t.eq(P.opened, []);
        P.open("central");
        P.close();
        t.eq(P.opened, []);
        t.check(!P.anyOpen, "nada aberto");
    });

    // A central: [ações, notificações, entrada das ações, central no Panels].
    const central = () => [P.actionsOpen, P.notificationsOpen, P.centralEntry, P.isOpen("central")];

    t.test("panels: os sub-estados da central", () => {
        P.close();
        try {
            P.setCentral(true, false);
            t.eq([central(), P.opened], [[true, false, "", true], ["central"]], "só as ações abrem a central");
            P.setCentral(true, true);
            t.eq(central(), [true, true, "", true], "as duas");
            P.setCentral(false, true);
            t.eq([central(), P.opened], [[false, true, "", true], ["central"]], "só as notificações seguram a central aberta");
            P.setCentral(false, false);
            t.eq([central(), P.opened], [[false, false, "", false], []], "as duas fechadas fecham a central");
            P.open("central");
            t.eq(central(), [true, true, "", true], "aberta pelo nome (panels open central): as duas");
        } finally {
            P.close();
        }
    });

    t.test("panels: as ações pela entrada", () => {
        P.close();
        try {
            P.openActions("rede");
            t.eq(central(), [true, false, "rede", true]);
            P.openActions("som");
            t.eq(central(), [true, false, "som", true], "outra entrada troca, aberta");
            P.openActions("microfone");
            t.eq(P.centralEntry, "microfone", "a entrada só do IPC");
            P.openActions("sound");
            t.eq(P.centralEntry, "", "entrada desconhecida vale como a vazia");
            P.openActions("energia");
            P.closeActions();
            t.eq(central(), [false, false, "", false], "fechadas, esquecem a entrada");
        } finally {
            P.close();
        }
    });

    t.test("panels: alternar as ações", () => {
        P.close();
        try {
            P.toggleActions("rede");
            t.eq(central(), [true, false, "rede", true]);
            P.toggleActions("som");
            t.eq(central(), [true, false, "som", true], "outro ícone troca a página");
            P.toggleActions("som");
            t.eq(central(), [false, false, "", false], "o mesmo ícone fecha");
            P.toggleActions("");
            t.eq(central(), [true, false, "", true], "o atalho abre no estado inicial");
            P.toggleActions("bluetooth");
            P.toggleActions("");
            t.eq(central(), [false, false, "", false], "o atalho fecha de qualquer entrada");
            P.toggleActions("wifi");
            P.toggleActions("x");
            t.eq(central(), [false, false, "", false], "entrada desconhecida vale como o atalho");
        } finally {
            P.close();
        }
    });

    t.test("panels: as ações não mexem nas notificações", () => {
        P.close();
        try {
            P.openNotifications();
            P.toggleActions("rede");
            t.eq(central(), [true, true, "rede", true], "abrem ao lado das notificações");
            P.toggleActions("rede");
            t.eq(central(), [false, true, "", true], "o mesmo ícone fecha só as ações, e a entrada some");
            P.openActions("som");
            P.closeActions();
            t.eq(central(), [false, true, "", true]);
        } finally {
            P.close();
        }
    });

    t.test("panels: alternar as notificações", () => {
        P.close();
        try {
            P.toggleNotifications();
            t.eq(central(), [false, true, "", true], "sozinhas");
            P.toggleNotifications();
            t.eq(central(), [false, false, "", false], "e fecham a central");
            P.openActions("bluetooth");
            P.toggleNotifications();
            t.eq(central(), [true, true, "bluetooth", true], "com as ações abertas, a entrada fica");
            P.toggleNotifications();
            t.eq(central(), [true, false, "bluetooth", true], "fecham só elas");
            P.openNotifications();
            P.openNotifications();
            t.eq(central(), [true, true, "bluetooth", true], "abrir de novo não muda nada");
            P.closeNotifications();
            P.closeNotifications();
            t.eq(central(), [true, false, "bluetooth", true]);
        } finally {
            P.close();
        }
    });

    t.test("panels: o atalho geral nos quatro estados", () => {
        P.close();
        try {
            P.toggleCentral("");
            t.eq(central(), [true, true, "", true], "nenhum aberto: abre os dois");
            P.toggleCentral("");
            t.eq(central(), [false, false, "", false], "os dois abertos: fecha os dois");
            P.openActions("som");
            P.toggleCentral("");
            t.eq(central(), [true, true, "som", true], "só as ações: abre as notificações, e a página fica");
            P.closeActions();
            P.toggleCentral("");
            t.eq(central(), [true, true, "", true], "só as notificações: abre as ações no estado inicial");
        } finally {
            P.close();
        }
    });

    t.test("panels: o central com entrada", () => {
        P.close();
        try {
            P.openCentral("rede");
            t.eq(central(), [true, true, "rede", true], "abre os dois na página");
            P.openCentral("");
            t.eq(central(), [true, true, "rede", true], "sem entrada, a página fica");
            P.openCentral("notificacoes");
            t.eq(central(), [true, true, "notificacoes", true], "notificacoes: o estado inicial das ações");
            P.toggleCentral("som");
            t.eq(central(), [true, true, "som", true], "outra entrada troca a página");
            P.toggleCentral("som");
            t.eq(central(), [false, false, "", false], "a mesma entrada com os dois abertos fecha os dois");
            P.openActions("som");
            P.toggleCentral("som");
            t.eq(central(), [true, true, "som", true], "a mesma entrada com só as ações: abre o que falta");
            P.closeActions();
            P.toggleCentral("bluetooth");
            t.eq(central(), [true, true, "bluetooth", true], "com só as notificações: abre as ações na página");
            P.toggleCentral("sound");
            t.eq(central(), [false, false, "", false], "entrada desconhecida vale como o atalho geral");
        } finally {
            P.close();
        }
    });

    t.test("panels: o fechamento por fora zera os dois", () => {
        P.close();
        try {
            P.openCentral("som");
            P.dismiss("central");
            t.eq(central(), [false, false, "", false], "Esc e o clique fora");
            P.openCentral("rede");
            P.close();
            t.eq(central(), [false, false, "", false], "panels close");
            P.openActions("energia");
            P.openNotifications();
            P.open("launcher");
            t.eq([central(), P.opened], [[false, false, "", false], ["launcher"]], "outro modal");
            P.toggleNotifications();
            t.eq(central(), [false, true, "", true], "reaberta, começa do zero");
        } finally {
            P.close();
        }
    });

    t.test("panels: a central é modal", () => {
        try {
            P.open("dashboard");
            P.openActions("som");
            t.eq(P.opened, ["central"], "as ações fecham o painel superior");
            P.open("dashboard");
            t.eq([P.opened, central()], [["dashboard"], [false, false, "", false]], "o painel superior fecha a central");
            P.toggleNotifications();
            t.eq(P.opened, ["central"], "as notificações também");
            P.open("settings");
            P.openCentral("");
            t.eq(P.opened, ["central"], "fecha as configurações");
            P.open("launcher");
            t.eq([P.opened, central()], [["launcher"], [false, false, "", false]], "o launcher fecha a central");
            P.toggleActions("rede");
            t.eq(P.opened, ["central"], "e as ações fecham o launcher");
        } finally {
            P.close();
        }
    });

    t.test("panels: os ícones acesos da barra", () => {
        P.close();
        try {
            const lit = () => ["rede", "som", "energia"].filter(e => P.actionsAt(e)).concat(P.notificationsOpen ? ["sino"] : []);
            t.eq(lit(), [], "nada aberto");
            P.openActions("som");
            t.eq(lit(), ["som"], "as ações abertas pelo som");
            P.openNotifications();
            t.eq(lit(), ["som", "sino"], "e o sino com as notificações");
            P.closeActions();
            t.eq(lit(), ["sino"], "só as notificações: nenhum ícone das ações");
            P.toggleActions("rede");
            t.eq(lit(), ["rede", "sino"], "com só as notificações, a rede abre as ações");
            P.openActions("");
            t.eq(lit(), ["sino"], "ações sem entrada (o atalho): nenhum ícone");
        } finally {
            P.close();
        }
    });

    t.test("panels: aviso de abertura das ações", () => {
        const got = [];
        const listen = entry => got.push(entry);
        P.close();
        P.actionsOpened.connect(listen);
        try {
            P.openActions("bluetooth");
            P.openActions("wifi");
            P.toggleActions("bluetooth");
            P.toggleNotifications();
            P.openCentral("");
            P.openCentral("som");
            P.closeActions();
            P.toggleCentral("");
        } finally {
            P.actionsOpened.disconnect(listen);
            P.close();
        }
        t.eq(got, ["bluetooth", "", "bluetooth", "som", ""], "uma vez por abertura ou troca, com a entrada que valeu; o central sem entrada não troca a página");
    });

    t.test("panels: janelas registradas", () => {
        const w = t.object();
        P.register(w);
        t.check(P.surfaces.includes(w), "registrada");
        P.unregister(w);
        t.check(!P.surfaces.includes(w), "fora");
    });

    P.close();
    C.panelsTogether = together0;
    t.test("panels: a tela fica onde o painel abriu", () => {
        t.eq(P.screenFor("A", ["A", "B"], "B"), "A", "o foco passou para B: continua em A");
        t.eq(P.screenFor("A", ["B"], "B"), "B", "a tela A saiu: vai para a com foco");
        t.eq(P.screenFor(null, ["A", "B"], "B"), "B", "nunca aberto: a com foco");
    });

    // Os painéis da moldura, o OSD e os popups gravam a tela ao abrir e ficam
    // nela (a troca do foco de monitor é a função acima; aqui, a ligação).
    t.test("panels: o painel superior, a central, o OSD e os popups gravam a tela", () => {
        const D = t.DashboardState, K = t.CentralState, O = t.OsdState, S = t.NotificationsState, N = t.Notifications;
        const screen = t.Hypr.focusedScreen;
        const saved = [P.opened, D.openedOn, K.openedOn, O.shownOn, O.shown, O.armed, O.kind, S.shownOn, N.popups];
        try {
            P.opened = [];
            D.openedOn = null;
            K.openedOn = null;
            P.opened = ["dashboard"];
            t.check(D.openedOn === screen && D.screen === screen, "o painel superior grava a tela com foco");
            P.opened = ["central"];
            t.check(K.openedOn === screen && K.screen === screen, "a central também");
            P.opened = [];
            O.armed = true;
            O.shown = false;
            O.shownOn = null;
            O.show("volume");
            t.check(O.shownOn === screen && O.screen === screen, "o OSD grava a tela ao aparecer");
            O.shownOn = "fora";
            O.show("volume");
            t.eq(O.shownOn, "fora", "já à mostra: não troca de tela");
            N.popups = [];
            S.shownOn = null;
            N.popups = ["a"];
            t.check(S.shownOn === screen, "o primeiro popup grava a tela");
            S.shownOn = "fora";
            N.popups = ["a", "b"];
            t.eq(S.shownOn, "fora", "os seguintes ficam nela");
        } finally {
            [P.opened, D.openedOn, K.openedOn, O.shownOn, O.shown, O.armed, O.kind, S.shownOn, N.popups] = saved;
        }
    });
}
