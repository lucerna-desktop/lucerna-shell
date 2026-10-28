pragma Singleton

import QtQuick
import Quickshell

// A moldura da tela e o que sai dela: uma forma só por monitor, desenhada
// pelo core/widgets/FrameShape (união suave por SDF) na janela da forma
// (core/widgets/FrameWindow, uma por tela, sempre aberta). O conteúdo dos
// painéis que saem da borda (a barra, o painel superior, a central, o OSD e
// os popups de notificação) fica na mesma janela, por cima da forma, e
// desliza com o fundo desde o 1º quadro.
//
// Cada pedaço da forma é um FrameBlob, registrado aqui: a pílula da barra e o
// fundo de cada painel que sai de uma borda (o painel superior, a central e o
// OSD; os popups de notificação são cartões soltos, fora da forma). A moldura
// nos quatro lados aparece com os pedaços "da moldura" (`framed`: a barra, o
// painel superior e a central): engrossa de 0 até `thickness` junto com a
// abertura deles e some quando fecham; a barra é uma aba fundida à borda de
// cima dela, e o painel superior é essa aba transformada (`fromBar`): ela se
// alarga e cresce para baixo, e o conteúdo da barra esmaece.
//
// A janela da forma fica sempre aberta e muda de largura só entre quatro
// níveis (extentOn): 1 px na borda direita sem nada à mostra, a coluna, a
// coluna larga e a tela inteira. Ela recebe o mouse só nas áreas de entrada
// (FrameInput) ativas da tela, e o teclado só com uma delas pedindo.
Singleton {
    id: root

    // Espessura da moldura aberta, raio dos cantos de dentro e a suavização
    // (o raio do arco que funde dois pedaços; os cantos dos pedaços seguem o
    // raio grande do tema, no FrameBlob).
    readonly property real thickness: 8
    readonly property real radius: 24
    readonly property real smoothing: 22
    // Até onde o arco de uma união chega da beira (a suavização e um pixel de
    // borda): o shader descarta além disso, e as faixas têm essa folga.
    readonly property real reach: smoothing + 2
    // A margem mínima de um cartão solto no canto da tela (os popups) para
    // ficar fora do arco do canto de dentro da moldura, com qualquer raio de
    // canto no cartão (o pior é o canto reto, na diagonal do arco).
    readonly property real cornerClear: thickness + radius * (1 - Math.SQRT1_2)
    // Quanto um lado preso a uma borda passa dela: os cantos desse lado ficam
    // fora da tela, e a junção com a borda vira o arco côncavo.
    readonly property real overhang: 64
    // Quantos pedaços a forma desenha numa tela (o shader tem um tanto fixo).
    readonly property int slotCount: 6
    // Quantas faixas a forma usa no máximo (um ShaderEffect cada; ver regions).
    readonly property int regionCount: 16
    // A coluna da direita, onde o OSD sai sem a moldura, e a coluna larga,
    // onde cabem os popups de notificação: a janela da forma encolhe para
    // elas, e para 1 px sem nada à mostra (ver extentOn).
    readonly property real column: 128
    readonly property real wideColumn: 420
    readonly property real idleWidth: 1

    // De que borda cada um sai.
    readonly property var edges: ({
            dashboard: "top",
            central: "right",
            osd: "right"
        })

    property var blobs: []
    // As janelas da forma (uma por tela), com `targetScreen`, `visible` e `parts`.
    property var windows: []
    // As áreas de entrada (FrameInput) da janela da forma, de todas as telas.
    property var inputs: []

    function register(blob: var): void {
        blobs = blobs.concat([blob]);
    }

    function unregister(blob: var): void {
        blobs = blobs.filter(b => b !== blob);
    }

    function registerInput(input: var): void {
        inputs = inputs.concat([input]);
    }

    function unregisterInput(input: var): void {
        inputs = inputs.filter(i => i !== input);
    }

    // As áreas de entrada ativas de uma tela: a máscara da janela da forma.
    function inputsOn(screen: var): var {
        return inputs.filter(i => i.screen === screen && i.active);
    }

    // Alguma área ativa da tela pede o teclado (um painel que digita).
    function keyboardOn(screen: var): bool {
        return inputsOn(screen).some(i => i.keyboard);
    }

    // Aberto, ou ainda animando o fechamento.
    function isActive(blob: var): bool {
        return blob.open || blob.progress > 0;
    }

    // Os pedaços ativos de uma tela, a pílula primeiro.
    function blobsOn(screen: var): var {
        const on = blobs.filter(b => b.screen === screen && isActive(b));
        return on.filter(b => b.role === "pill").concat(on.filter(b => b.role !== "pill"));
    }

    // O retângulo da pílula da barra dessa tela; vazio se ela não está à mostra.
    function pillOn(screen: var): rect {
        const pill = blobsOn(screen).find(b => b.role === "pill");
        return pill ? pill.rect : Qt.rect(0, 0, 0, 0);
    }

    // Quanto da moldura aparece (0 a 1): o mais aberto dos painéis da moldura
    // nessa tela. A mola passa do alvo; a moldura não.
    function progressOn(screen: var): real {
        return progressIn(blobsOn(screen));
    }

    // O mesmo, sobre os pedaços já separados de uma tela (a janela da forma
    // separa uma vez por quadro e deriva tudo deles).
    function progressIn(parts: var): real {
        return clamp(Math.max(0, ...parts.filter(b => b.framed).map(b => b.progress)));
    }

    // Quanto a barra dessa tela já virou painel (0 a 1): o mais aberto dos
    // pedaços `fromBar` (o painel superior).
    function morphOn(screen: var): real {
        return morphIn(blobsOn(screen));
    }

    function morphIn(parts: var): real {
        return clamp(Math.max(0, ...parts.filter(b => b.fromBar).map(b => b.progress)));
    }

    // O conteúdo da barra esmaece logo no começo da transformação (até 40%)
    // e volta só no fim do recolhimento.
    function barContentOpacity(morph: real): real {
        return 1 - clamp(morph / 0.4);
    }

    // Algum painel da moldura (fora a própria barra) aberto nessa tela: a barra
    // fica à mostra. A barra fica de fora antes de ler o `open` dela, que vem
    // daqui (senão o binding dela ficaria em laço).
    function fusedOn(screen: var): bool {
        return blobs.some(b => b.role !== "pill" && b.framed && b.open && b.screen === screen);
    }

    // A tela precisa da janela da forma.
    function wantedOn(screen: var): bool {
        return blobsOn(screen).length > 0;
    }

    function addWindow(window: var): void {
        windows = windows.concat([window]);
    }

    function removeWindow(window: var): void {
        windows = windows.filter(w => w !== window);
    }

    // O tamanho de cada tela (pelo nome) medido pelas janelas em tela cheia
    // dela (a da forma e as dos painéis da moldura), com o tamanho que a tela
    // informava na hora: { screenWidth, screenHeight, width, height }. A tela
    // do Qt pode ficar velha quando a saída muda de tamanho (o Hyprland
    // aninhado não manda o tamanho lógico novo), mas a janela mapeada depois
    // recebe o de verdade; a forma, numa janela, e o conteúdo, na outra, se
    // medem pelo mesmo número.
    property var measured: ({})

    // Grava o tamanho de uma janela em tela cheia dessa tela. Escondida, a
    // janela tem 0 x 0: não mede. Largura 0 com altura (a janela da forma
    // estreita, na coluna da direita) mede só a altura.
    function measure(screen: var, width: real, height: real): void {
        if (!screen || (width <= 0 && height <= 0))
            return;
        const old = sizeIn(measured[screen.name], screen);
        const entry = {
            screenWidth: screen.width,
            screenHeight: screen.height,
            width: width > 0 ? width : old.width,
            height: height > 0 ? height : old.height
        };
        const prev = measured[screen.name];
        if (prev && prev.screenWidth === entry.screenWidth && prev.screenHeight === entry.screenHeight && prev.width === entry.width && prev.height === entry.height)
            return;
        const next = Object.assign({}, measured);
        next[screen.name] = entry;
        measured = next;
    }

    // O tamanho de layout da tela: o medido pelas janelas, ou o informado.
    function sizeOn(screen: var): size {
        return sizeIn(screen ? measured[screen.name] : undefined, screen);
    }

    // A medida vale enquanto a tela informa o mesmo tamanho de quando foi
    // tomada: se a tela mudou (outra resolução ou escala, avisada), a nova
    // manda até uma janela medir de novo.
    function sizeIn(entry: var, screen: var): size {
        const width = screen?.width ?? 0, height = screen?.height ?? 0;
        const valid = !!entry && entry.screenWidth === width && entry.screenHeight === height;
        return Qt.size(valid && entry.width > 0 ? entry.width : width, valid && entry.height > 0 ? entry.height : height);
    }

    function clamp(value: real): real {
        return Math.max(0, Math.min(1, value));
    }

    // A espessura da moldura com a abertura `p`.
    function thicknessAt(p: real): real {
        return thickness * clamp(p);
    }

    // A suavização de um pedaço com a abertura `p`: cresce junto, e chega à
    // cheia na metade (fixa, faria um calombo com o painel fechado).
    function smoothingAt(p: real): real {
        return smoothing * clamp(p * 2);
    }

    // O retângulo esticado para fora da tela pelos lados presos à borda
    // (`edge`: "top", "right", "bottom", "left", "top-right"...).
    function attach(r: rect, edge: string): rect {
        const sides = edge.split("-");
        let x = r.x, y = r.y, w = r.width, h = r.height;
        if (sides.includes("top")) {
            y -= overhang;
            h += overhang;
        }
        if (sides.includes("bottom"))
            h += overhang;
        if (sides.includes("left")) {
            x -= overhang;
            w += overhang;
        }
        if (sides.includes("right"))
            w += overhang;
        return Qt.rect(x, y, w, h);
    }

    // A largura da janela da forma (presa à direita), num dos quatro níveis:
    // a tela inteira com a moldura à mostra; senão, a menor coluna (a do OSD
    // ou a larga, dos popups) que cobre todos os pedaços (com a folga do
    // arco) e todas as áreas de entrada; a tela inteira se nenhuma cobre; e
    // 1 px sem nada. O Hyprland desfoca e recompõe a cada quadro só a janela,
    // e ela não muda de tamanho a cada quadro, só na troca de nível.
    function extentOn(parts: var, inputs: var, frame: real, size: size): real {
        if (frame > 0)
            return size.width;
        if (!parts.length && !inputs.length)
            return idleWidth;
        const left = Math.min(...parts.map(b => b.rect.x - reach), ...inputs.map(i => i.rect.x));
        for (const width of [column, wideColumn])
            if (left >= size.width - width)
                return width;
        return size.width;
    }

    // A área que a forma ocupa na janela (tamanho `size`): a janela toda com a
    // moldura à mostra; senão, os pedaços com a folga da suavização.
    function bounds(on: var, frame: real, size: size): rect {
        if (frame > 0)
            return Qt.rect(0, 0, size.width, size.height);
        if (!on.length)
            return Qt.rect(0, 0, 0, 0);
        const pad = reach;
        const x0 = Math.max(0, Math.min(...on.map(b => b.rect.x)) - pad);
        const y0 = Math.max(0, Math.min(...on.map(b => b.rect.y)) - pad);
        const x1 = Math.min(size.width, Math.max(...on.map(b => b.rect.x + b.rect.width)) + pad);
        const y1 = Math.min(size.height, Math.max(...on.map(b => b.rect.y + b.rect.height)) + pad);
        return Qt.rect(x0, y0, Math.max(0, x1 - x0), Math.max(0, y1 - y0));
    }

    // As faixas da janela (tamanho `size`) onde a forma pode ter cor, sem
    // sobreposição: cada uma é um ShaderEffect com as mesmas uniforms, que
    // desenha o seu pedaço da mesma forma, sem costura (sobrepostas, a cor
    // somaria duas vezes). Com a moldura à mostra, as quatro bordas na
    // espessura dela, mais o canto arredondado e a folga do arco; e cada
    // pedaço com a folga da suavização. O resto da janela fica sem shader.
    // Passando de `regionCount`, a área inteira (bounds) numa faixa só.
    function regions(on: var, frame: real, size: size): var {
        const pad = reach;
        const boxes = [];
        if (frame > 0) {
            const band = thicknessAt(frame) + radius * clamp(frame) + pad;
            boxes.push([0, 0, size.width, band], [0, size.height - band, size.width, band]);
            boxes.push([0, 0, band, size.height], [size.width - band, 0, band, size.height]);
        }
        for (const b of on)
            if (b.rect.width > 0 && b.rect.height > 0)
                boxes.push([b.rect.x - pad, b.rect.y - pad, b.rect.width + pad * 2, b.rect.height + pad * 2]);
        const out = disjoint(boxes, size);
        if (out.length <= regionCount)
            return out;
        const all = bounds(on, frame, size);
        return [all];
    }

    // Os retângulos ([x, y, largura, altura]), arredondados para fora em
    // pixels inteiros e cortados na janela, refeitos sem sobreposição: em
    // faixas horizontais entre as bordas de cima e de baixo de todos, com os
    // trechos de cada faixa unidos, e a faixa igual à de cima emendada nela.
    function disjoint(boxes: var, size: size): var {
        const clipped = [];
        for (const b of boxes) {
            const x0 = Math.max(0, Math.floor(b[0])), y0 = Math.max(0, Math.floor(b[1]));
            const x1 = Math.min(size.width, Math.ceil(b[0] + b[2])), y1 = Math.min(size.height, Math.ceil(b[1] + b[3]));
            if (x1 > x0 && y1 > y0)
                clipped.push([x0, y0, x1, y1]);
        }
        const ys = [...new Set(clipped.map(b => b[1]).concat(clipped.map(b => b[3])))].sort((a, b) => a - b);
        const out = [];
        let above = null;
        for (let i = 0; i + 1 < ys.length; i++) {
            const y0 = ys[i], y1 = ys[i + 1];
            const spans = clipped.filter(b => b[1] <= y0 && b[3] >= y1).map(b => [b[0], b[2]]).sort((a, b) => a[0] - b[0]);
            const merged = [];
            for (const s of spans) {
                const last = merged[merged.length - 1];
                if (last && s[0] <= last[1])
                    last[1] = Math.max(last[1], s[1]);
                else
                    merged.push([s[0], s[1]]);
            }
            const same = above && above.bottom === y0 && above.spans.length === merged.length && above.spans.every((s, k) => s[0] === merged[k][0] && s[1] === merged[k][1]);
            if (same) {
                for (const r of above.rects)
                    r.height += y1 - y0;
                above.bottom = y1;
                continue;
            }
            const rects = merged.map(s => ({ x: s[0], y: y0, width: s[1] - s[0], height: y1 - y0 }));
            out.push(...rects);
            above = merged.length ? { bottom: y1, spans: merged, rects: rects } : null;
        }
        return out.map(r => Qt.rect(r.x, r.y, r.width, r.height));
    }

    // Os pedaços nas vagas do shader: rects[i] = [x, y, largura, altura] e
    // props[i] = [raio, suavização, em uso]. A pílula funde com a moldura
    // (`fuse`); os outros, com o que já estiver ali, pela própria abertura. O
    // raio e a suavização ficam até a metade do menor lado à mostra na tela
    // (`size`; o que passa da borda não conta): o arco não come um pedaço
    // estreito, como o OSD, nem um que ainda está saindo.
    function slots(on: var, fuse: real, size: size): var {
        const rects = [], props = [];
        for (let i = 0; i < slotCount; i++) {
            const b = on[i];
            if (!b || b.rect.width <= 0 || b.rect.height <= 0) {
                rects.push([0, 0, 0, 0]);
                props.push([0, 0, 0]);
                continue;
            }
            rects.push([b.rect.x, b.rect.y, b.rect.width, b.rect.height]);
            const shownWidth = Math.min(size.width, b.rect.x + b.rect.width) - Math.max(0, b.rect.x);
            const shownHeight = Math.min(size.height, b.rect.y + b.rect.height) - Math.max(0, b.rect.y);
            const half = Math.max(0, Math.min(shownWidth, shownHeight) / 2);
            props.push([Math.min(b.radius, half), Math.min(smoothingAt(b.role === "pill" ? fuse : b.progress), half), 1]);
        }
        return { rects: rects, props: props };
    }
}
