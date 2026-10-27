// Testes de core/frame/Frame: os pedaços da forma de cada tela, a moldura que
// aparece com os painéis da moldura, a pílula fundida, a janela da forma, a
// borda de onde cada painel sai e as vagas do shader. Os pedaços e as janelas
// são objetos soltos (as telas, textos); a lista do Frame volta ao fim.
function run(t) {
    const F = t.Frame;
    const blobs0 = F.blobs;
    const windows0 = F.windows;

    function blob(props) {
        return Object.assign({ screen: "A", role: "panel", framed: false, open: false, progress: 0, rect: Qt.rect(0, 0, 0, 0), radius: 16 }, props);
    }

    // Roda o corpo com só estes pedaços registrados e devolve a lista original.
    function scenario(name, list, body) {
        t.test(name, () => {
            try {
                F.blobs = [];
                for (const b of list)
                    F.register(b);
                body();
            } finally {
                F.blobs = blobs0;
                F.windows = windows0;
            }
        });
    }

    const pill = blob({ role: "pill", framed: true, open: true, progress: 1, rect: Qt.rect(700, 8, 480, 34), radius: 17 });
    const hiddenPill = blob({ role: "pill", framed: true, rect: Qt.rect(700, -34, 480, 34), radius: 17 });
    const dash = blob({ framed: true, open: true, progress: 0.5, rect: Qt.rect(500, 42, 920, 200) });
    const osd = blob({ open: false, progress: 0, rect: Qt.rect(1860, 400, 124, 220) });
    const other = blob({ screen: "B", framed: true, open: true, progress: 1 });

    scenario("frame: registrar e tirar", [], () => {
        F.register(pill);
        F.register(dash);
        t.eq(F.blobs.length, 2);
        F.unregister(pill);
        t.check(F.blobs.length === 1 && F.blobs[0] === dash, "sobra só o painel");
    });

    scenario("frame: os pedaços ativos de cada tela, a pílula primeiro", [dash, osd, pill, other], () => {
        t.check(F.isActive(dash) && F.isActive(pill), "abertos são ativos");
        t.check(!F.isActive(osd), "fechado e parado não é");
        t.check(F.isActive(blob({ open: false, progress: 0.2 })), "fechando ainda é");
        const on = F.blobsOn("A");
        t.check(on.length === 2 && on[0] === pill && on[1] === dash, "pílula e painel, nessa ordem; o OSD parado fica de fora");
        t.check(F.blobsOn("B").length === 1 && F.blobsOn("C").length === 0, "cada tela vê só os seus");
    });

    scenario("frame: a pílula da tela", [pill, dash], () => {
        t.eq(F.pillOn("A").width, 480);
        t.eq(F.pillOn("B").width, 0, "sem pílula: vazio");
    });

    scenario("frame: a barra traz a moldura junto", [pill], () => {
        t.eq(F.progressOn("A"), 1, "a barra à mostra: a moldura inteira");
        t.check(!F.fusedOn("A"), "mas só ela não segura a barra à mostra");
    });

    scenario("frame: a moldura segue o painel da moldura mais aberto", [hiddenPill, dash, osd], () => {
        t.near(F.progressOn("A"), 0.5, 1e-9, "metade aberta");
        t.eq(F.progressOn("B"), 0, "outra tela: sem moldura");
        dash.progress = 1.08;
        t.eq(F.progressOn("A"), 1, "a mola passa do alvo; a moldura não");
        dash.progress = 0.5;
        t.check(F.fusedOn("A") && !F.fusedOn("B"), "a pílula fica fundida só na tela do painel");
    });

    scenario("frame: o OSD e os popups não trazem a moldura", [hiddenPill, osd], () => {
        osd.open = true;
        osd.progress = 1;
        try {
            t.eq(F.progressOn("A"), 0, "o OSD sai da borda sem moldura");
            t.check(!F.fusedOn("A"), "e a pílula não se funde");
            t.check(F.wantedOn("A"), "mas a janela da forma existe");
        } finally {
            osd.open = false;
            osd.progress = 0;
        }
    });

    scenario("frame: a janela da forma", [pill, hiddenPill], () => {
        t.check(F.wantedOn("A") && !F.wantedOn("B"), "existe onde há pedaço ativo");
        F.unregister(pill);
        t.check(!F.wantedOn("A"), "a barra escondida não conta");
    });

    scenario("frame: os painéis esperam a janela da forma à mostra", [], () => {
        const w = { targetScreen: "A", visible: false };
        F.addWindow(w);
        t.check(!F.isReady("A"), "escondida, ainda não");
        w.visible = true;
        t.check(F.isReady("A") && !F.isReady("B"), "à mostra, na tela dela");
        F.removeWindow(w);
        t.check(!F.isReady("A"), "tirada, não");
    });

    t.test("frame: a moldura, a suavização e o conteúdo com a abertura", () => {
        t.eq([F.clamp(-1), F.clamp(0.4), F.clamp(2)], [0, 0.4, 1]);
        t.eq([F.thicknessAt(0), F.thicknessAt(0.5), F.thicknessAt(1.2)], [0, F.thickness / 2, F.thickness]);
        t.eq([F.smoothingAt(0), F.smoothingAt(0.25), F.smoothingAt(0.5), F.smoothingAt(1)], [0, F.smoothing / 2, F.smoothing, F.smoothing]);
        t.eq(F.contentOpacity(0.3), 0, "antes de ~60%, sem conteúdo");
        t.eq(F.contentOpacity(F.contentStart), 0);
        t.near(F.contentOpacity(0.8), 0.5, 1e-9, "entra entre 60% e 100%");
        t.eq(F.contentOpacity(1.1), 1);
    });

    t.test("frame: de que borda cada painel sai", () => {
        t.eq(F.edges.dashboard, "top");
        t.eq(F.edges.central, "right");
        t.eq(F.edges.notifications, "top-right");
        t.eq(F.edges.osd, "right");
    });

    t.test("frame: os lados presos passam da borda", () => {
        const o = F.overhang;
        const r = Qt.rect(100, 50, 200, 80);
        const box = q => [q.x, q.y, q.width, q.height];
        t.eq(box(F.attach(r, "top")), [100, 50 - o, 200, 80 + o]);
        t.eq(box(F.attach(r, "right")), [100, 50, 200 + o, 80]);
        t.eq(box(F.attach(r, "top-right")), [100, 50 - o, 200 + o, 80 + o]);
        t.eq(box(F.attach(r, "bottom-left")), [100 - o, 50, 200 + o, 80 + o]);
        t.eq(box(F.attach(r, "")), [100, 50, 200, 80], "sem borda, igual");
    });

    t.test("frame: a área que o shader cobre", () => {
        const size = Qt.size(1920, 1080);
        const box = q => [q.x, q.y, q.width, q.height];
        const pad = F.smoothing + 2;
        t.eq(box(F.bounds([pill, dash], 0.3, size)), [0, 0, 1920, 1080], "com a moldura: a janela toda");
        t.eq(box(F.bounds([], 0, size)), [0, 0, 0, 0], "nada: nada");
        t.eq(box(F.bounds([pill], 0, size)), [700 - pad, 0, 480 + pad * 2, 8 + 34 + pad], "a pílula com a folga, sem sair da janela");
    });

    t.test("frame: as vagas do shader", () => {
        const s = F.slots([pill, dash, blob({ rect: Qt.rect(0, 0, 0, 10) })], 0.5);
        t.eq(s.rects.length, F.slotCount);
        t.eq(s.rects[0], [700, 8, 480, 34]);
        t.eq(s.props[0], [17, F.smoothingAt(0.5), 1], "a pílula funde pela moldura");
        t.eq(s.props[1], [16, F.smoothingAt(0.5), 1], "o painel, pela própria abertura");
        t.eq(s.props[2], [0, 0, 0], "sem área: vaga vazia");
        t.eq(s.props[5], [0, 0, 0]);
        const many = F.slots(Array.from({ length: 8 }, () => dash), 1);
        t.eq(many.rects.length, F.slotCount, "mais pedaços que vagas: os que cabem");
    });

    scenario("frame: a barra se transforma no painel superior", [pill, dash, blob({ fromBar: true, framed: true, open: true, progress: 0.3 }), blob({ screen: "B", fromBar: true, progress: 1 })], () => {
        t.near(F.morphOn("A"), 0.3, 1e-9, "a abertura do painel que sai da barra");
        t.eq(F.morphOn("C"), 0, "sem ele, a barra é a barra");
    });

    scenario("frame: a mola não passa a transformação de 1", [blob({ fromBar: true, open: true, progress: 1.08 })], () => {
        t.eq(F.morphOn("A"), 1);
    });

    t.test("frame: o conteúdo da barra esmaece no começo da transformação", () => {
        t.eq(F.barContentOpacity(0), 1, "barra inteira");
        t.near(F.barContentOpacity(0.2), 0.5, 1e-9, "na metade do esmaecer");
        t.eq(F.barContentOpacity(0.4), 0, "some antes do conteúdo do painel entrar");
        t.eq(F.barContentOpacity(1), 0);
    });
}
