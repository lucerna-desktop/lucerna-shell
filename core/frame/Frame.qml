pragma Singleton

import QtQuick
import Quickshell
import qs.core.theme

// A moldura da tela e o que sai dela: uma forma só por monitor, desenhada
// pelo core/widgets/FrameShape (união suave por SDF) na janela da barra.
//
// Cada pedaço da forma é um FrameBlob, registrado aqui: a pílula da barra e o
// fundo de cada painel que sai de uma borda (o painel superior, a central, os
// popups de notificação e o OSD). O conteúdo deles fica nas próprias janelas,
// por cima. A moldura nos quatro lados aparece com os pedaços "da moldura"
// (`framed`: a barra, o painel superior e a central): engrossa de 0 até
// `thickness` junto com a abertura deles e some quando fecham; a barra é uma
// aba fundida à borda de cima dela, e o painel superior é essa aba
// transformada (`fromBar`): ela se alarga e cresce para baixo, e o conteúdo da
// barra esmaece.
//
// A janela da barra só existe enquanto há algum pedaço ativo na tela dela;
// as janelas dos painéis esperam por ela (`isReady`), para ficarem por cima
// (no Hyprland, a camada criada depois fica na frente).
Singleton {
    id: root

    // Espessura da moldura aberta, raio dos cantos de dentro e a suavização
    // (o raio do arco que funde dois pedaços).
    readonly property real thickness: 8
    readonly property real radius: ThemeManager.radius.large
    readonly property real smoothing: 18
    // O conteúdo de um painel entra quando a forma dele passa disto.
    readonly property real contentStart: 0.6
    // Quanto um lado preso a uma borda passa dela: os cantos desse lado ficam
    // fora da tela, e a junção com a borda vira o arco côncavo.
    readonly property real overhang: 64
    // Quantos pedaços a forma desenha numa tela (o shader tem um tanto fixo).
    readonly property int slotCount: 6
    // Quantas faixas a forma usa no máximo (um ShaderEffect cada; ver regions).
    readonly property int regionCount: 16

    // De que borda cada um sai.
    readonly property var edges: ({
            dashboard: "top",
            central: "right",
            notifications: "top-right",
            osd: "right"
        })

    property var blobs: []
    // As janelas da forma (a da barra de cada tela), com `targetScreen` e `visible`.
    property var windows: []

    function register(blob: var): void {
        blobs = blobs.concat([blob]);
    }

    function unregister(blob: var): void {
        blobs = blobs.filter(b => b !== blob);
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
        return clamp(Math.max(0, ...blobs.filter(b => b.framed && b.screen === screen).map(b => b.progress)));
    }

    // Quanto a barra dessa tela já virou painel (0 a 1): o mais aberto dos
    // pedaços `fromBar` (o painel superior).
    function morphOn(screen: var): real {
        return clamp(Math.max(0, ...blobs.filter(b => b.fromBar && b.screen === screen).map(b => b.progress)));
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

    // A janela da forma dessa tela já existe (à mostra).
    function isReady(screen: var): bool {
        return windows.some(w => w.targetScreen === screen && w.visible);
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

    // A opacidade do conteúdo de um painel com a forma em `p`.
    function contentOpacity(p: real): real {
        return clamp((p - contentStart) / (1 - contentStart));
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

    // A área que a forma ocupa na janela (tamanho `size`): a janela toda com a
    // moldura à mostra; senão, os pedaços com a folga da suavização.
    function bounds(on: var, frame: real, size: size): rect {
        if (frame > 0)
            return Qt.rect(0, 0, size.width, size.height);
        if (!on.length)
            return Qt.rect(0, 0, 0, 0);
        const pad = smoothing + 2;
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
        const pad = smoothing + 2;
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
    // (`fuse`); os outros, com o que já estiver ali, pela própria abertura.
    function slots(on: var, fuse: real): var {
        const rects = [], props = [];
        for (let i = 0; i < slotCount; i++) {
            const b = on[i];
            if (!b || b.rect.width <= 0 || b.rect.height <= 0) {
                rects.push([0, 0, 0, 0]);
                props.push([0, 0, 0]);
                continue;
            }
            rects.push([b.rect.x, b.rect.y, b.rect.width, b.rect.height]);
            props.push([b.radius, smoothingAt(b.role === "pill" ? fuse : b.progress), 1]);
        }
        return { rects: rects, props: props };
    }
}
