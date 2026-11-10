import QtQuick
import qs.core.theme

// Um wallpaper animado (shader .qsb de themes/shaders). Os uniforms são os
// mesmos para todos: time, resolution e as cores base, surface, accent e text.
//
// O ritmo vem dos quadros da própria tela (FrameAnimation), não de um timer:
// a 60 fps num monitor de 60 Hz, um quadro por ciclo; a 30, um a cada dois;
// num de 144 Hz, pula ciclos para ficar em 30 ou 60. Um timer solto da tela
// daria quadros que ficam o dobro do tempo (tremidas). O tempo do efeito é o
// tempo real decorrido, então o movimento é o mesmo em qualquer taxa. Nos
// ciclos pulados nada muda na cena, e o Qt não redesenha. Parado
// (`running` falso), nada anda e o último quadro fica.
ShaderEffect {
    id: root

    property string shader
    property bool running: true
    property int fps: 30

    // Cores: as do tema ativo, ou as de outro tema (prévias).
    property color base: ThemeManager.colors.base
    property color surface: ThemeManager.colors.surface
    property color accent: ThemeManager.colors.accent
    property color text: ThemeManager.colors.text

    property real time: 0
    readonly property vector2d resolution: Qt.vector2d(width, height)
    readonly property bool ready: status === ShaderEffect.Compiled && shader !== ""
    readonly property bool failed: status === ShaderEffect.Error

    // Textura de ruído dos efeitos (themes/shaders/noise.png), repetida.
    property var noiseTex: ShaderEffectSource {
        wrapMode: ShaderEffectSource.Repeat
        hideSource: true
        sourceItem: Image {
            source: `file://${ThemeManager.directory}/shaders/noise.png`
            width: 256 // px fixo: a textura de ruído, em pixels da imagem
            height: 256 // px fixo: a textura de ruído, em pixels da imagem
            smooth: true
        }
    }

    fragmentShader: shader ? `file://${shader}` : ""
    blending: false

    FrameAnimation {
        id: clock

        // Tempo desde o último quadro desenhado do efeito.
        property real pending: 0

        running: root.running && root.visible && !root.failed
        onRunningChanged: pending = 0
        onTriggered: {
            // Uma pausa longa (tela bloqueada, janela escondida) não vira um salto.
            pending += Math.min(frameTime, 0.1);
            // Folga de 3 ms: um ciclo de 16,7 ms que chega um pouco antes não é pulado.
            if (pending >= 1 / Math.max(1, root.fps) - 0.003) {
                root.time += pending;
                pending = 0;
            }
        }
    }
}
