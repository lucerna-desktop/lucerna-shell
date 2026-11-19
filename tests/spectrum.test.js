// Testes de services/Spectrum: o adaptador do spectrum.bands e do
// spectrum.status do lucernad; a captura e a análise ficaram no daemon, com os
// testes em Rust.
function run(t) {
    const S = t.Spectrum;

    // Guarda o estado de antes para restaurar no fim (a suíte roda no mesmo
    // processo que as seguintes).
    const original = { active: S.active, values: S.values, moduleAvailable: S.moduleAvailable };

    function frame(n, v) {
        return { bands: Array.from({ length: n }, () => v) };
    }

    t.test("spectrum: tópicos conforme o pedido", () => {
        t.eq(S.wantedTopics(false), ["spectrum.status"]);
        t.eq(S.wantedTopics(true), ["spectrum.status", "spectrum.bands"]);
    });

    t.test("spectrum: as faixas de duas em duas, pelo maior", () => {
        t.eq(S.pairMax([0.1, 0.9, 0.4, 0.2]), [0.9, 0.4]);
        t.eq(S.pairMax([0.5, 0.1, 0.3]), [0.5, 0.3], "ímpar: a última sozinha");
        t.eq(S.pairMax([]), []);
        const bands = [];
        for (let i = 0; i < S.bars; i++)
            bands.push(i / S.bars);
        const paired = S.pairMax(bands);
        t.eq(paired.length, Math.ceil(S.bars / 2));
        t.eq(paired[0], bands[1], "o par dos graves");
    });

    t.test("spectrum: o player vai como nome ou null", () => {
        t.eq(S.playerParam("org.mpris.MediaPlayer2.spotify"), "org.mpris.MediaPlayer2.spotify");
        t.eq(S.playerParam(""), null);
    });

    t.test("spectrum: o quadro só vale pedindo", () => {
        try {
            S.active = true;
            S.apply("spectrum.bands", frame(S.bars, 0.5));
            t.eq(S.values.length, S.bars);
            t.eq(S.values[0], 0.5);
            S.apply("spectrum.bands", frame(32, 0.9));
            t.eq([S.values.length, S.values[0]], [S.bars, 0.5], "quadro de outro tamanho não vale");
            S.apply("spectrum.bands", { bands: "x" });
            t.eq(S.values.length, S.bars, "sem array não vale");
            const bad = frame(S.bars, 0.7);
            bad.bands[3] = "0.7";
            S.apply("spectrum.bands", bad);
            t.eq(S.values[0], 0.5, "faixa que não é número não vale");
            bad.bands[3] = NaN;
            S.apply("spectrum.bands", bad);
            t.eq(S.values[0], 0.5, "NaN não vale");
            bad.bands[3] = null;
            S.apply("spectrum.bands", bad);
            t.eq(S.values[0], 0.5, "null não vale");
            S.active = false;
            t.eq(S.values, [], "desligado, zera");
            S.apply("spectrum.bands", frame(S.bars, 0.5));
            t.eq(S.values, [], "desligado, o quadro não entra");
        } finally {
            S.active = original.active;
        }
    });

    t.test("spectrum: o quadro pelo sinal do cliente", () => {
        try {
            S.active = true;
            // A mesma passagem dos dados do daemon: o JSON vira lista do QML.
            S.client.received("spectrum.bands", JSON.parse(JSON.stringify(frame(S.bars, 0.25))));
            t.eq(S.values.length, S.bars, "o quadro real entra");
            t.eq(S.values[S.bars - 1], 0.25);
            S.client.received("spectrum.bands", { bands: "x" });
            t.eq(S.values.length, S.bars, "sem lista não vale");
        } finally {
            S.active = original.active;
        }
    });

    t.test("spectrum: estado do módulo", () => {
        S.applyStatus({ available: false, capturing: false, player: null, error: "x" });
        t.eq(S.moduleAvailable, false);
        S.applyStatus({ available: true, capturing: false, player: null, error: null });
        t.eq(S.moduleAvailable, true);
        S.moduleAvailable = original.moduleAvailable;
    });

    t.test("spectrum: a conexão caída zera", () => {
        S.moduleAvailable = true;
        S.values = [0.1];
        S.connectionChanged(false);
        t.eq([S.moduleAvailable, S.values], [false, []]);
        S.moduleAvailable = original.moduleAvailable;
        S.values = original.values;
    });

    t.test("spectrum: sincronizar e configurar sem conexão só guardam", () => {
        S.sync();
        t.eq(S.client.owners.spectrum, S.wantedTopics(S.active));
        const before = [S.client.nextId, Object.keys(S.client.pending).length];
        S.configure();
        t.eq([S.client.nextId, Object.keys(S.client.pending).length], before, "sem conexão, nada é pedido");
    });

    t.test("spectrum: conectado, configure manda o player", () => {
        const c = S.client;
        const saved = { pending: c.pending, nextId: c.nextId, connected: c.connected };
        const last = () => {
            const ids = Object.keys(c.pending).map(Number);
            return c.pending[ids[ids.length - 1]];
        };
        try {
            c.connected = true;
            const sent = last();
            t.eq(sent.method, "spectrum.configure", "a conexão nova configura");
            t.eq(sent.params, { player: S.playerParam(S.player) });
            c.pending = {};
            S.configure();
            const again = last();
            t.eq([again.method, again.params], ["spectrum.configure", { player: S.playerParam(S.player) }]);
        } finally {
            c.connected = saved.connected;
            c.pending = saved.pending;
            c.nextId = saved.nextId;
        }
    });

    t.test("spectrum: trocar de player manda o nome dele", () => {
        const c = S.client;
        const saved = { pending: c.pending, nextId: c.nextId, connected: c.connected };
        const last = () => {
            const ids = Object.keys(c.pending).map(Number);
            return c.pending[ids[ids.length - 1]];
        };
        try {
            c.connected = true;
            c.pending = {};
            S.player = "org.mpris.MediaPlayer2.spotify";
            t.eq([last().method, last().params], ["spectrum.configure", { player: "org.mpris.MediaPlayer2.spotify" }], "o onPlayerChanged configura com o player");
            S.player = "org.mpris.MediaPlayer2.mpv";
            t.eq(last().params, { player: "org.mpris.MediaPlayer2.mpv" });
            c.pending = {};
            S.player = "";
            t.eq([last().method, last().params], ["spectrum.configure", { player: null }], "sem player, null");
        } finally {
            S.player = Qt.binding(() => t.Media.active?.dbusName ?? "");
            c.connected = saved.connected;
            c.pending = saved.pending;
            c.nextId = saved.nextId;
        }
    });

    t.test("spectrum: null e tópico desconhecido não mudam nada", () => {
        try {
            S.active = true;
            S.apply("spectrum.bands", frame(S.bars, 0.5));
            S.apply("spectrum.bands", null);
            S.apply("spectrum.status", null);
            S.apply("spectrum.xyz", { available: true });
            t.eq([S.values.length, S.moduleAvailable], [S.bars, original.moduleAvailable]);
        } finally {
            S.active = original.active;
            S.moduleAvailable = original.moduleAvailable;
        }
    });

    t.test("spectrum: estado original restaurado", () => {
        S.active = original.active;
        S.values = original.values;
        S.moduleAvailable = original.moduleAvailable;
        t.eq([S.active, S.values, S.moduleAvailable], [false, [], false]);
    });
}
