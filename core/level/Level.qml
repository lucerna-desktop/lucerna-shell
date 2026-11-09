pragma Singleton

import QtQuick
import Quickshell

// As contas da barra de porcentagem (core/widgets/LevelSlider), fora do
// componente para os testes de unidade: a fração do valor, o passo (snap), o
// valor sob o ponteiro, o passo do teclado e da roda e a largura da parte cheia.
Singleton {
    // A fração de `value` entre from e to, de 0 a 1 (0 num intervalo vazio).
    function fraction(value: real, from: real, to: real): real {
        if (to === from)
            return 0;
        return Math.max(0, Math.min(1, (value - from) / (to - from)));
    }

    // `v` dentro do intervalo e, com step > 0, no passo mais próximo contado
    // a partir de from. O arredondamento do passo não passa de to (0,2 + 28 ×
    // 0,1 dá 3,0000000000000004).
    function snap(v: real, from: real, to: real, step: real): real {
        const clamped = Math.max(from, Math.min(to, v));
        if (step <= 0)
            return clamped;
        return Math.min(to, Math.round((clamped - from) / step) * step + from);
    }

    // O valor sob o ponto x de uma barra de largura `width`, já no passo.
    function valueAt(x: real, width: real, from: real, to: real, step: real): real {
        const f = width > 0 ? Math.max(0, Math.min(1, x / width)) : 0;
        return snap(from + f * (to - from), from, to, step);
    }

    // Um passo do teclado (setas) ou da roda: dir 1 sobe, -1 desce. Sem
    // step, 5% do intervalo.
    function stepped(value: real, dir: int, from: real, to: real, step: real): real {
        return snap(value + dir * (step > 0 ? step : (to - from) / 20), from, to, step);
    }

    // A largura da parte cheia de uma barra em pílula de largura `width` e
    // altura `h`, com a fração f: f × width, mas nunca menos que h (o círculo
    // da ponta, que cobre o ícone dentro da barra). Sem valor, 0.
    function fillWidth(f: real, width: real, h: real): real {
        if (f <= 0)
            return 0;
        return Math.max(h, Math.min(1, f) * width);
    }
}
