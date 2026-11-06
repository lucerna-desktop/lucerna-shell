pragma Singleton

import QtQuick
import Quickshell

// O alinhamento ao pixel físico em escala fracionária. O layout é em pixels
// lógicos; em 1,25 um lógico vale 1,25 físico, e uma posição ou uma borda que
// cai no meio de um pixel físico sai borrada (a borda de 1 px vira uma faixa
// de 2 px meio apagada; o texto, meio pixel fora da grade).
// O `dpr` de cada janela é o `Window.window.devicePixelRatio` (a escala
// fracionária que o compositor manda, 1,25); o `Screen.devicePixelRatio` e o
// da ShellScreen dão a escala inteira da saída (2 em 1,25) e não servem.
// Janela ainda sem tela: dpr 1.
Singleton {
    // `v` lógico no pixel físico mais próximo, de volta em lógico.
    function snap(v: real, dpr: real): real {
        return Math.round(v * dpr) / dpr;
    }

    // A espessura lógica de uma linha fina: a escala arredondada em pixels
    // físicos, nunca menos de 1 (1 px físico em 1 e 1,25; 2 em 1,5 e em 2).
    function hairline(dpr: real): real {
        return Math.max(1, Math.round(dpr)) / dpr;
    }
}
