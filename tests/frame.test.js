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
        try {
            dash.progress = 1.08;
            t.eq(F.progressOn("A"), 1, "a mola passa do alvo; a moldura não");
        } finally {
            dash.progress = 0.5;
        }
        t.check(F.fusedOn("A") && !F.fusedOn("B"), "a pílula fica fundida só na tela do painel");
    });

    scenario("frame: o OSD não traz a moldura", [hiddenPill, osd], () => {
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
        t.eq(F.contentOpacity(0.3), 0, "antes de ~70%, sem conteúdo");
        t.eq(F.contentOpacity(F.contentStart), 0);
        t.near(F.contentOpacity(0.85), 0.5, 1e-9, "entra entre 70% e 100%");
        t.eq(F.contentOpacity(1.1), 1);
    });

    t.test("frame: de que borda cada painel sai", () => {
        t.eq(F.edges.dashboard, "top");
        t.eq(F.edges.central, "right");
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
        const pad = F.reach;
        t.eq(box(F.bounds([pill, dash], 0.3, size)), [0, 0, 1920, 1080], "com a moldura: a janela toda");
        t.eq(box(F.bounds([], 0, size)), [0, 0, 0, 0], "nada: nada");
        t.eq(box(F.bounds([pill], 0, size)), [700 - pad, 0, 480 + pad * 2, 8 + 34 + pad], "a pílula com a folga, sem sair da janela");
    });

    // O frame.frag descarta o que fica além de `reach` da moldura e dos
    // pedaços: o arco da união (até a suavização) tem de caber nisso.
    t.test("frame: o alcance do shader segue a suavização", () => {
        t.check(F.reach > F.smoothing, "o arco cabe no alcance");
    });

    t.test("frame: as faixas do shader, sem sobreposição", () => {
        const size = Qt.size(1920, 1080);
        const box = q => [q.x, q.y, q.width, q.height];
        const pad = F.reach;
        t.eq(F.regions([], 0, size), [], "nada: nenhuma faixa");
        t.eq(F.regions([pill], 0, size).map(box), [[700 - pad, 0, 480 + pad * 2, 8 + 34 + pad]], "só a pílula: a área dela com a folga, cortada na janela");
        const band = Math.ceil(F.thickness + F.radius + pad);
        const framed = F.regions([], 1, size).map(box);
        t.eq(framed, [[0, 0, 1920, band], [0, band, band, 1080 - band * 2], [1920 - band, band, band, 1080 - band * 2], [0, 1080 - band, 1920, band]], "a moldura: as quatro bordas, sem repetir os cantos");
        // Nenhum pixel em duas faixas, e os cantos de cada pedaço cobertos.
        const all = F.regions([pill, dash], 0.5, size);
        const overlap = (a, b) => Math.max(0, Math.min(a.x + a.width, b.x + b.width) - Math.max(a.x, b.x)) * Math.max(0, Math.min(a.y + a.height, b.y + b.height) - Math.max(a.y, b.y));
        t.check(all.every((a, i) => all.every((b, j) => i === j || overlap(a, b) === 0)), "sem sobreposição");
        const covered = (x, y) => all.some(r => x >= r.x && x < r.x + r.width && y >= r.y && y < r.y + r.height);
        t.check([[0, 0], [1919, 1079], [500 - pad, 242 + pad - 1], [1419 + pad, 100], [960, 8 + 34 + pad - 1]].every(p => covered(p[0], p[1])), "a moldura e os pedaços com a folga");
        t.check(!covered(960, 700), "o meio da tela fica sem shader");
        t.check(all.length <= F.regionCount, "cabem nos ShaderEffects");
        const many = Array.from({ length: 20 }, (_, i) => blob({ open: true, progress: 1, rect: Qt.rect(i * 90, (i % 2) * 300 + 200, 40, 40) }));
        t.eq(F.regions(many, 0, size).map(box), [box(F.bounds(many, 0, size))], "faixas demais: a área inteira numa só");
        t.eq(F.disjoint([[10.5, 10.2, 5, 5], [-5, -5, 3, 3], [0, 0, 0, 9]], size).map(box), [[10, 10, 6, 6]], "arredonda para fora e descarta o que fica fora ou vazio");
    });

    t.test("frame: sem a moldura, a janela da forma encolhe para a coluna da direita", () => {
        const size = Qt.size(1920, 1080);
        const right = blob({ open: true, progress: 1, rect: Qt.rect(1920 - 60, 400, 124, 220) });
        t.check(F.compactOn([right], 0, size), "só o OSD na borda direita: a coluna");
        t.check(!F.compactOn([right], 0.2, size), "com a moldura: a tela inteira");
        t.check(!F.compactOn([right, dash], 0, size), "um pedaço fora da coluna: a tela inteira");
        t.check(!F.compactOn([], 0, size), "sem pedaço, nada a encolher");
    });

    t.test("frame: a abertura e a transformação a partir dos pedaços da tela", () => {
        const parts = [pill, blob({ framed: true, fromBar: true, progress: 0.4 }), blob({ progress: 0.9 })];
        t.eq(F.progressIn(parts), 1, "a moldura: o mais aberto dos da moldura");
        t.near(F.morphIn(parts), 0.4, 1e-9, "a transformação: o que sai da barra");
        t.eq([F.progressIn([]), F.morphIn([])], [0, 0]);
    });

    t.test("frame: as vagas do shader", () => {
        const size = Qt.size(1920, 1080);
        const s = F.slots([pill, dash, blob({ rect: Qt.rect(0, 0, 0, 10) })], 0.25, size);
        t.eq(s.rects.length, F.slotCount);
        t.eq(s.rects[0], [700, 8, 480, 34]);
        t.eq(s.props[0], [17, F.smoothingAt(0.25), 1], "a pílula funde pela moldura");
        t.eq(s.props[1], [16, F.smoothingAt(0.5), 1], "o painel, pela própria abertura");
        t.eq(s.props[2], [0, 0, 0], "sem área: vaga vazia");
        t.eq(s.props[5], [0, 0, 0]);
        const many = F.slots(Array.from({ length: 8 }, () => dash), 1, size);
        t.eq(many.rects.length, F.slotCount, "mais pedaços que vagas: os que cabem");
        // Estreito (o OSD saindo da borda direita): o arco e o raio até a
        // metade do que está à mostra; o que passa da borda não conta.
        const narrow = F.slots([blob({ open: true, progress: 1, rect: Qt.rect(1900, 400, 20 + F.overhang, 220), radius: 22 })], 1, size);
        t.eq(narrow.props[0], [10, 10, 1], "20 px à mostra: no máximo 10");
        const wide = F.slots([blob({ open: true, progress: 1, rect: Qt.rect(1860, 400, 60 + F.overhang, 220), radius: 22 })], 1, size);
        t.eq(wide.props[0], [22, F.smoothing, 1], "60 px à mostra: o raio e a suavização inteiros");
    });

    scenario("frame: a barra se transforma no painel superior", [pill, dash, blob({ fromBar: true, framed: true, open: true, progress: 0.3 }), blob({ screen: "B", fromBar: true, progress: 1 })], () => {
        t.near(F.morphOn("A"), 0.3, 1e-9, "a abertura do painel que sai da barra");
        t.eq(F.morphOn("C"), 0, "sem ele, a barra é a barra");
    });

    scenario("frame: a mola não passa a transformação de 1", [blob({ fromBar: true, open: true, progress: 1.08 })], () => {
        t.eq(F.morphOn("A"), 1);
    });

    // O cartão (canto de raio rc, a `m` da borda) fica dentro do buraco da
    // moldura (cantos de raio `radius`, a `thickness` da borda).
    t.test("frame: os popups ficam fora do arco do canto da moldura", () => {
        const inside = (m, rc) => {
            const hole = F.thickness + F.radius, card = m + rc;
            return m >= F.thickness && (card >= hole || Math.SQRT2 * (hole - card) + rc <= F.radius + 1e-9);
        };
        const margin = F.thickness + t.ThemeManager.spacing.small;
        t.check(margin >= F.cornerClear, "a margem dos popups passa da mínima");
        for (let rc = 0; rc <= F.radius; rc += 2)
            t.check(inside(F.cornerClear, rc) && inside(margin, rc), "canto de raio " + rc);
        t.check(!inside(t.ThemeManager.spacing.small, 0), "a margem antiga (só o espaço) entrava no arco");
    });

    t.test("frame: o conteúdo da barra esmaece no começo da transformação", () => {
        t.eq(F.barContentOpacity(0), 1, "barra inteira");
        t.near(F.barContentOpacity(0.2), 0.5, 1e-9, "na metade do esmaecer");
        t.eq(F.barContentOpacity(0.4), 0, "some antes do conteúdo do painel entrar");
        t.eq(F.barContentOpacity(1), 0);
    });
}
