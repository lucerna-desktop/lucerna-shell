// Testes de services/Battery: o histórico de consumo e a sonda dos perfis
// vêm do módulo power do lucernad (os tópicos power.history, power.profiles e
// power.status). Cada caso que conecta usa um cliente da fábrica
// t.lucernaClient() posto em B.client (o socket nunca abre: os pedidos ficam
// no pending), e os dados chegam pelo caminho real (o sinal received).
function run(t) {
    const B = t.Battery;
    const P = t.PowerState;

    // O estado de antes, restaurado e conferido no fim de cada caso (a suíte
    // roda no mesmo processo que as seguintes).
    const fields = ["client", "historyActive", "history", "historyAt", "historyError", "profilesReported", "powerError"];
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

    function ok(id, result) {
        return JSON.stringify({ jsonrpc: "2.0", id: id, result: result });
    }

    function ids(c) {
        return Object.keys(c.pending).map(Number);
    }

    // O último pedido pendente de um método.
    function last(c, method) {
        const list = ids(c).filter(id => c.pending[id].method === method);
        return list.length ? Object.assign({ id: list[list.length - 1] }, c.pending[list[list.length - 1]]) : null;
    }

    function hello() {
        return { protocol: "1.0", app: "lucernad", version: "0.1.0", topics: ["power.status", "power.screens", "power.history", "power.profiles"], streams: [], methods: [] };
    }

    // Um cliente novo em B.client, com o socket "aberto" e o hello respondido.
    function wired() {
        const c = t.lucernaClient();
        B.client = c;
        c.opened();
        c.receive(ok(ids(c)[0], hello()));
        return c;
    }

    // Um tópico pelo sinal do cliente, como chega do socket (JSON de verdade).
    function send(c, topic, data) {
        c.received(topic, JSON.parse(JSON.stringify(data)));
    }

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

    withClient("bateria: tópicos conforme a página", c => {
        t.eq(B.wantedTopics(false), ["power.status", "power.profiles"]);
        t.eq(B.wantedTopics(true), ["power.status", "power.profiles", "power.history"]);
        t.eq(c.owners.battery, ["power.status", "power.profiles"], "o dono battery");
        B.historyActive = true;
        t.eq(c.owners.battery, ["power.status", "power.profiles", "power.history"], "a página aberta assina o histórico");
        const subscribe = last(c, "lucerna.subscribe");
        t.check(subscribe !== null, "um subscribe pendente");
        t.check(Array.from(subscribe.params.topics).includes("power.history"), "pede o power.history");
    });

    withClient("bateria: o histórico pelo sinal real", c => {
        send(c, "power.history", { points: [{ time: 2, rate: 7.5, state: 1 }, { time: 1, rate: 5, state: 2 }] });
        t.eq(B.history, [{ time: 1, value: 5, state: 2 }, { time: 2, value: 7.5, state: 1 }], "do mais antigo ao mais novo");
        t.check(B.historyAt > 0, "quando foi lido");
        t.eq(B.historyError, "");
        send(c, "power.history", { points: [{ time: 3, rate: "x", state: 1 }, { time: "y", rate: 3, state: 1 }, { time: 4, rate: -1, state: 1 }, { time: 5, rate: 2 }] });
        t.eq(B.history, [{ time: 5, value: 2, state: 0 }], "sem número ou com taxa negativa fica de fora");
        send(c, "power.history", { points: [], error: "e" });
        t.eq([B.history, B.historyError], [[], "e"], "o erro do daemon");
        send(c, "power.history", { points: [] });
        t.eq(B.historyError, "", "sem erro, limpa");
    });

    withClient("bateria: perfis do daemon", c => {
        // Sem o power-profiles-daemon no D-Bus do teste, o PowerProfiles do
        // Quickshell não tem o perfil de desempenho: o "performance: true" do
        // lucernad não pode ligar o Turbo.
        send(c, "power.profiles", { available: true, performance: true });
        t.eq(B.profilesAvailable, true);
        t.eq(B.hasPerformance, false, "o Turbo continua do Quickshell, não do daemon");
        send(c, "power.profiles", { available: false, performance: false });
        t.eq(B.profilesAvailable, false, "o daemon diz que não há");
    });

    t.test("bateria: sem o daemon desde a partida, os perfis pelo Quickshell", () => {
        t.eq([B.profilesFrom(null, true), B.profilesFrom(null, false)], [true, false], "sem amostra, o Turbo do Quickshell diz que o serviço responde");
        t.eq([B.profilesFrom(false, true), B.profilesFrom(true, false)], [false, true], "com amostra, vale o daemon");
        const reported0 = B.profilesReported;
        try {
            B.profilesReported = null;
            t.eq(B.profilesAvailable, B.hasPerformance, "a propriedade segue a regra");
        } finally {
            B.profilesReported = reported0;
        }
    });

    withClient("bateria: queda não esconde os perfis", c => {
        send(c, "power.profiles", { available: true, performance: true });
        send(c, "power.history", { points: [{ time: 1, rate: 5, state: 2 }] });
        send(c, "power.status", { available: true, error: "parou" });
        t.eq([B.powerError, B.powerAvailable], ["parou", false], "o módulo parou");
        B.historyError = "e";
        B.connectionChanged(false);
        t.eq([B.history, B.historyError, B.powerError], [[], "", ""], "a queda zera o histórico e os erros");
        t.eq(B.profilesAvailable, true, "os perfis ficam com o último valor");
        send(c, "power.status", { available: true, error: null });
        t.eq(B.powerError, "");
        t.eq(B.powerAvailable, c.connected, "disponível é conectado e sem erro");
        send(c, "power.profiles", { available: false, performance: false });
        t.eq(B.profilesAvailable, false, "com conexão, vale o daemon");
    });

    t.test("bateria: o gráfico diz por que não há pontos", () => {
        const c = t.lucernaClient();
        B.client = c;
        try {
            B.history = [];
            t.eq(P.chartNote, "Indisponível: sem conexão com o lucernad.", "desconectado");
            c.opened();
            c.receive(ok(ids(c)[0], hello()));
            t.eq(P.chartNote, "Medindo", "sem erro");
            B.historyError = "x";
            t.eq(P.chartNote, "Indisponível: x", "o erro do histórico");
            B.powerError = "módulo parado";
            t.eq(P.chartNote, "Indisponível: módulo parado", "o erro do módulo vale mais");
            B.powerError = "";
            B.historyError = "";
            B.history = [{ time: 1, value: 5, state: 2 }, { time: 2, value: 6, state: 2 }];
            B.historyAt = 3;
            t.eq(P.chartNote, P.chart.length > 0 ? "" : "Medindo", "com pontos no gráfico, nada");
        } finally {
            restore();
            c.destroy();
        }
        t.check(restored(), "estado original restaurado");
    });

    withClient("bateria: null e tópico desconhecido não mudam nada", c => {
        send(c, "power.profiles", { available: true, performance: true });
        B.apply("power.history", null);
        B.apply("power.profiles", null);
        B.apply("power.status", undefined);
        B.apply("power.screens", { screens: [] });
        t.eq([B.history, B.profilesAvailable, B.powerError, B.historyError], [[], true, "", ""]);
    });

    t.test("bateria: estado original restaurado", () => {
        t.check(restored(), "client, histórico, perfis e erros como antes");
    });
}
