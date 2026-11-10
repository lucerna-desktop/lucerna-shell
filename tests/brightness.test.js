// Testes de services/Brightness: o adaptador do módulo power do lucernad (os
// tópicos power.screens e power.status, os métodos power.set e power.change,
// a tela em foco, o valor otimista durante o arrasto e o erro 1003 da linha).
// Ler, juntar e escrever o brilho ficou no daemon, com os testes em Rust. Cada
// caso que conecta usa um cliente da fábrica t.lucernaClient() posto em
// B.client (o socket nunca abre: os pedidos ficam no pending), e os dados
// chegam pelo caminho real (o sinal received e a resposta pelo receive()).
function run(t) {
    const B = t.Brightness;

    // O estado de antes, restaurado e conferido no fim de cada caso (a suíte
    // roda no mesmo processo que as seguintes).
    const fields = ["client", "screens", "remote", "error", "lastId", "holds", "value"];
    const original = {};
    for (const f of fields)
        original[f] = B[f];

    function restore() {
        // O client por último: as outras trocas ainda caem no cliente do caso.
        for (const f of fields)
            if (f !== "client")
                B[f] = original[f];
        B.client = original.client;
    }

    function restored() {
        return fields.every(f => f === "client" ? B.client === original.client : JSON.stringify(B[f]) === JSON.stringify(original[f]));
    }

    // A resposta JSON-RPC de sucesso, numa linha.
    function ok(id, result) {
        return JSON.stringify({ jsonrpc: "2.0", id: id, result: result });
    }

    // As chaves de c.pending, como números.
    function ids(c) {
        return Object.keys(c.pending).map(Number);
    }

    // Os métodos pendentes, na ordem dos ids.
    function methods(c) {
        return ids(c).map(id => c.pending[id].method);
    }

    // O último pedido pendente de um método.
    function last(c, method) {
        const list = ids(c).filter(id => c.pending[id].method === method);
        return list.length ? Object.assign({ id: list[list.length - 1] }, c.pending[list[list.length - 1]]) : null;
    }

    // A resposta do hello do lucernad com o módulo power.
    function hello(topics) {
        return { protocol: "1.0", app: "lucernad", version: "0.1.0", topics: topics, streams: [], methods: [] };
    }

    // Um cliente novo em B.client, com o socket "aberto" e o hello respondido
    // pelo receive() (o greeted() de verdade liga o connected).
    function wired() {
        const c = t.lucernaClient();
        B.client = c;
        c.opened();
        c.receive(ok(ids(c)[0], hello(["power.screens", "power.status"])));
        return c;
    }

    // Um caso com o cliente do wired(), restaurado e destruído no fim, mesmo
    // com exceção.
    function withClient(name, body) {
        t.test(name, () => {
            const c = wired();
            try {
                body(c);
            } finally {
                restore();
                c.destroy();
                t.check(restored(), "estado original restaurado");
            }
        });
    }

    // As telas no formato do tópico power.screens.
    const panel = { id: "backlight", kind: "backlight", output: "eDP-1", name: "Tela integrada", value: 9600, max: 19200, percent: 50 };
    const lg = { id: "ddc:HDMI-A-1", kind: "ddc", output: "HDMI-A-1", name: "LG ULTRAWIDE", value: 70, max: 100, percent: 70 };
    const noAccess = "Sem acesso ao barramento do monitor: instale a regra udev do lucernad (veja o README).";
    const dp = { id: "ddc:DP-1", kind: "ddc", output: "DP-1", name: "Monitor DP-1", value: null, max: null, percent: null, error: noAccess };

    function daemon(list) {
        return { screens: list };
    }

    // Um tópico pelo sinal do cliente, como chega do socket (JSON de verdade).
    function send(c, topic, data) {
        c.received(topic, JSON.parse(JSON.stringify(data)));
    }

    // Uma linha com erro no lugar da tela.
    function broken(screen, text) {
        return Object.assign({}, screen, { value: null, max: null, percent: null, error: text });
    }

    withClient("brilho: tópicos", c => {
        t.eq(B.wantedTopics(), ["power.status", "power.screens"]);
        t.eq(c.owners.power, ["power.status", "power.screens"], "o dono power");
        const subscribe = last(c, "lucerna.subscribe");
        t.check(subscribe !== null, "um subscribe pendente");
        t.eq(Array.from(subscribe.params.topics).sort(), ["power.screens", "power.status"]);
    });

    withClient("brilho: as telas pelo sinal real", c => {
        send(c, "power.screens", daemon([panel, lg, dp]));
        t.eq(B.screens.length, 3);
        t.eq(B.screens[0], { id: "backlight", kind: "backlight", label: "Tela integrada", output: "eDP-1", value: 0.5, error: "" });
        t.eq(B.screens[1], { id: "ddc:HDMI-A-1", kind: "ddc", label: "LG ULTRAWIDE", output: "HDMI-A-1", value: 0.7, error: "" });
        t.eq([B.screens[2].value, B.screens[2].error], [0, noAccess], "sem leitura, 0 e o erro");
        t.near(B.value, 0.5, 1e-9, "o valor da integrada");
        send(c, "power.screens", daemon([lg]));
        t.eq([B.hasPanel, B.value], [false, 0.5], "sem integrada, fica o último valor");
        t.eq(B.toScreen({ id: "x", kind: "ddc", name: "X", value: null, max: null, percent: null }), { id: "x", kind: "ddc", label: "X", output: "", value: 0, error: "" });
    });

    withClient("brilho: a tela em foco", c => {
        send(c, "power.screens", daemon([panel, lg, dp]));
        t.eq(B.focusedId(), "backlight", "sem monitor do Hyprland, a integrada");
        t.eq(B.focusedScreen.id, "backlight");
        send(c, "power.screens", daemon([broken(panel, "Não consegui ler o brilho da tela integrada: x."), lg, dp]));
        t.eq(B.focusedId(), "ddc:HDMI-A-1", "a integrada com erro sai do foco");
        send(c, "power.screens", daemon([dp]));
        t.eq([B.focusedId(), B.focusedScreen], ["", null], "só a de erro: nada em foco");
    });

    withClient("brilho: ajuste sai pelo fio e fica otimista", c => {
        send(c, "power.screens", daemon([panel, lg]));
        let adjusted = 0;
        const count = () => adjusted++;
        B.adjusted.connect(count);
        try {
            c.pending = {};
            B.setScreen("ddc:HDMI-A-1", 0.4);
            t.eq(methods(c), ["power.set"]);
            t.eq(last(c, "power.set").params, { id: "ddc:HDMI-A-1", percent: 40 });
            t.near(B.screens[1].value, 0.4, 1e-9, "otimista");
            t.eq([adjusted, B.lastId, B.shownValue], [1, "ddc:HDMI-A-1", 0.4]);
            B.setScreen("backlight", 0);
            t.eq(last(c, "power.set").params, { id: "backlight", percent: 1 }, "o mínimo é 1%");
            B.set(1.5);
            t.eq(last(c, "power.set").params, { id: "backlight", percent: 100 }, "set é a integrada, até 100%");
            t.eq([adjusted, B.value], [3, 1]);
            t.eq(B.withValue(B.screens, "ddc:nada", 0.3), B.screens, "id desconhecido não muda a lista");
        } finally {
            B.adjusted.disconnect(count);
        }
    });

    withClient("brilho: as teclas mandam o delta", c => {
        send(c, "power.screens", daemon([panel, lg]));
        B.lastId = "ddc:HDMI-A-1";
        c.pending = {};
        B.change(0.05);
        t.eq(methods(c), ["power.change"]);
        t.eq(last(c, "power.change").params, { id: "backlight", delta: 5 });
        t.near(B.value, 0.55, 1e-9, "otimista");
        t.eq(B.lastId, "backlight");
        t.near(B.shownValue, 0.55, 1e-9, "o OSD mostra a tela da tecla");
        B.change(-2);
        t.eq(last(c, "power.change").params, { id: "backlight", delta: -100 }, "delta limitado a ±100");
        t.near(B.value, 0.01, 1e-9, "não passa do mínimo");
        send(c, "power.screens", daemon([dp]));
        c.pending = {};
        B.change(0.05);
        t.eq(methods(c), [], "sem tela em foco, nada sai");
    });

    withClient("brilho: o daemon não volta o slider no meio do arrasto", c => {
        send(c, "power.screens", daemon([panel, lg]));
        B.setScreen("ddc:HDMI-A-1", 0.4);
        send(c, "power.screens", daemon([Object.assign({}, panel, { percent: 60 }), lg]));
        t.near(B.screens[1].value, 0.4, 1e-9, "o LG fica com o valor local");
        t.near(B.screens[0].value, 0.6, 1e-9, "a outra tela segue o daemon");
        const now = Date.now();
        const incoming = [B.toScreen(panel), B.toScreen(lg)];
        t.near(B.merged(incoming, B.screens, { "ddc:HDMI-A-1": now - 2000 }, now)[1].value, 0.7, 1e-9, "passado o holdMs, vale o daemon");
        t.near(B.merged(incoming, B.screens, { "ddc:HDMI-A-1": now - 500 }, now)[1].value, 0.4, 1e-9, "dentro do holdMs, o local");
    });

    withClient("brilho: a linha com erro responde 1003", c => {
        send(c, "power.screens", daemon([panel, lg]));
        c.pending = {};
        B.setScreen("ddc:HDMI-A-1", 0.4);
        const failing = last(c, "power.set");
        c.receive(JSON.stringify({ jsonrpc: "2.0", id: failing.id, error: { code: 1003, message: noAccess } }));
        t.eq(B.screens[1].error, noAccess, "o texto da linha");
        t.eq(B.focusedId(), "backlight");
        t.eq(B.answered("backlight", { error: { code: 1001, message: "Essa tela não existe." } }), "Brightness: o ajuste de backlight falhou: Essa tela não existe.", "outro erro vai para o log");
        t.eq(B.screens[0].error, "", "outro erro não marca a linha");
        t.eq(B.answered("backlight", { error: { code: -1, message: "Sem conexão com o teste." } }), "", "sem conexão, nada no log");
        B.released();
        t.eq(B.screens[1].error, noAccess, "o erro da linha sobrevive ao fim do hold");
        B.setScreen("backlight", 0.3);
        c.receive(ok(last(c, "power.set").id, {}));
        t.eq([B.screens[0].error, B.screens[0].value], ["", 0.3], "sucesso não muda nada");
    });

    withClient("brilho: o power.list de antes de uma publicação não a desfaz", c => {
        send(c, "power.screens", daemon([panel, lg]));
        B.applyStatus({ available: false, error: "x" });
        c.pending = {};
        send(c, "power.status", { available: true, error: null });
        const list = last(c, "power.list");
        send(c, "power.screens", daemon([Object.assign({}, panel, { percent: 80 }), lg]));
        c.receive(ok(list.id, daemon([panel])));
        t.eq([B.screens.length, B.screens[0].value], [2, 0.8], "a publicação que chegou antes da resposta vale");
        B.reload();
        c.receive(ok(last(c, "power.list").id, daemon([panel])));
        t.eq(B.screens.map(s => s.value), [0.5], "sem publicação no meio, vale a resposta");
    });

    // O slider da central: o resto de um arrasto fica na tela em que ele
    // começou, mesmo que um 1003 a tire do foco.
    withClient("brilho: o arrasto que leva 1003 não passa à próxima tela", c => {
        const K = t.ControlsState;
        send(c, "power.screens", daemon([panel, lg]));
        c.pending = {};
        K.setBrightness(0.4, true);
        const failing = last(c, "power.set");
        t.eq(failing.params, { id: "backlight", percent: 40 });
        c.receive(JSON.stringify({ jsonrpc: "2.0", id: failing.id, error: { code: 1003, message: noAccess } }));
        t.eq(K.screenBrightness?.id, "ddc:HDMI-A-1", "a integrada sai do foco");
        c.pending = {};
        K.setBrightness(0.3, true);
        t.eq(last(c, "power.set"), null, "o resto do arrasto não mexe no LG");
        K.dropBrightness();
        K.setBrightness(0.3, true);
        t.eq(last(c, "power.set").params, { id: "ddc:HDMI-A-1", percent: 30 }, "um arrasto novo vai à tela em foco");
        K.dropBrightness();
        c.pending = {};
        K.setBrightness(0.2, false);
        t.eq(last(c, "power.set").params, { id: "ddc:HDMI-A-1", percent: 20 }, "teclado e roda: a tela em foco");
    });

    withClient("brilho: a publicação dentro do hold vale quando ele acaba", c => {
        send(c, "power.screens", daemon([panel, lg]));
        B.setScreen("ddc:HDMI-A-1", 0.4);
        t.check(B.holding, "o hold corre");
        send(c, "power.screens", daemon([panel, Object.assign({}, lg, { value: 42, percent: 42 })]));
        t.near(B.screens[1].value, 0.4, 1e-9, "dentro do hold, o local");
        // O hold acabou (o timer chama o released()).
        B.holds = { "ddc:HDMI-A-1": Date.now() - 2000 };
        B.released();
        t.near(B.screens[1].value, 0.42, 1e-9, "a publicação final do daemon");
        t.near(B.shownValue, 0.42, 1e-9, "e o OSD também");
    });

    withClient("brilho: queda e erro da integrada não abrem o OSD", c => {
        send(c, "power.screens", daemon([panel, lg]));
        let changes = 0;
        const count = () => changes++;
        B.valueChanged.connect(count);
        try {
            B.connectionChanged(false);
            t.eq([changes, B.hasPanel, B.value], [0, false, 0.5], "a queda não mexe no valor");
            send(c, "power.screens", daemon([panel, lg]));
            t.eq([changes, B.hasPanel], [0, true], "a volta com o mesmo valor também não");
            send(c, "power.screens", daemon([broken(panel, "Não consegui ler o brilho da tela integrada: x."), lg]));
            t.eq([changes, B.hasPanel, B.value], [0, false, 0.5], "a integrada com erro também não");
            send(c, "power.screens", daemon([Object.assign({}, panel, { percent: 80 }), lg]));
            t.eq([changes, B.value], [1, 0.8], "uma mudança de verdade sim");
        } finally {
            B.valueChanged.disconnect(count);
        }
    });

    withClient("brilho: o fim do hold com o mesmo percentual não abre o OSD", c => {
        send(c, "power.screens", daemon([panel, lg]));
        B.change(0.05);
        t.eq(B.value, 0.55, "o valor local é o percentual inteiro (0,5 + 0,05 dá 0,55000000000000004)");
        B.setScreen("backlight", 0.333);
        t.eq(B.value, 0.33, "o slider também");
        let changes = 0;
        const count = () => changes++;
        B.valueChanged.connect(count);
        try {
            send(c, "power.screens", daemon([Object.assign({}, panel, { value: 330, percent: 33 }), lg]));
            B.holds = { backlight: Date.now() - 2000 };
            B.released();
            t.eq([changes, B.value], [0, 0.33], "a publicação final com o mesmo percentual não mexe no valor");
        } finally {
            B.valueChanged.disconnect(count);
        }
    });

    withClient("brilho: estado e queda", c => {
        send(c, "power.screens", daemon([panel, lg]));
        B.applyStatus({ available: false, error: "x" });
        t.eq([B.available, B.error, B.screens.length], [false, "x", 0], "o módulo parado leva as telas");
        c.pending = {};
        send(c, "power.status", { available: true, error: null });
        t.eq([B.available, B.error], [true, ""]);
        const list = last(c, "power.list");
        t.check(list !== null, "o módulo de volta relê as telas");
        c.receive(ok(list.id, daemon([panel, lg])));
        t.eq(B.screens.map(s => s.id), ["backlight", "ddc:HDMI-A-1"], "pelo power.list");
        c.pending = {};
        send(c, "power.status", { available: true, error: null });
        t.eq(last(c, "power.list"), null, "sem erro antes, não relê");
        send(c, "power.screens", daemon([panel]));
        c.want("power", []);
        B.connectionChanged(false);
        t.eq([B.screens, B.error], [[], ""], "a queda leva as telas");
        t.eq(c.owners.power, ["power.status", "power.screens"], "e pede os tópicos de novo");
    });

    withClient("brilho: null e tópico desconhecido não mudam nada", c => {
        send(c, "power.screens", daemon([panel]));
        B.apply("power.screens", null);
        B.apply("power.status", null);
        B.apply("power.xyz", { screens: [], available: false, error: "x" });
        t.eq([B.screens.length, B.error], [1, ""]);
    });
}
