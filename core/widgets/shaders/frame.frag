#version 440
// A forma da tela (core/widgets/FrameShape): a moldura nos quatro lados, com
// os cantos de dentro arredondados, e até seis pedaços (retângulos
// arredondados: a pílula e os fundos dos painéis) fundidos a ela com a união
// suave circular, a mesma do blob.frag do Caelestia. Uma forma só, numa cor
// só: sem dupla transparência onde os pedaços se encontram.
// Coordenadas em pixels da janela.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    // A área do item na janela: x, y, largura, altura.
    vec4 area;
    // A moldura: espessura, raio dos cantos de dentro, largura e altura da tela.
    vec4 frame;
    // A cor e a da borda (rgba, sem pré-multiplicar), e a largura da borda.
    vec4 fill;
    vec4 edge;
    float outline;
    // Os pedaços: b = x, y, largura, altura; k = raio, suavização, em uso.
    vec4 b0;
    vec4 k0;
    vec4 b1;
    vec4 k1;
    vec4 b2;
    vec4 k2;
    vec4 b3;
    vec4 k3;
    vec4 b4;
    vec4 k4;
    vec4 b5;
    vec4 k5;
};

float sdRoundedBox(vec2 p, vec2 center, vec2 halfSize, float r) {
    vec2 d = abs(p - center) - halfSize + vec2(r);
    return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - r;
}

// Arco circular de raio k tangente às duas superfícies.
float smin(float a, float b, float k) {
    return max(k, min(a, b)) - length(max(vec2(k) - vec2(a, b), vec2(0.0)));
}

float blend(float u, vec2 p, vec4 b, vec4 k) {
    if (k.z < 0.5)
        return u;
    vec2 hs = b.zw * 0.5;
    float d = sdRoundedBox(p, b.xy + hs, hs, min(k.x, min(hs.x, hs.y)));
    return k.y > 0.01 ? smin(u, d, k.y) : min(u, d);
}

void main() {
    vec2 p = area.xy + qt_TexCoord0 * area.zw;
    // A moldura: fora do retângulo de dentro. Sem espessura, é só o que fica
    // fora da tela, e os pedaços presos a uma borda ganham o arco côncavo.
    vec2 sh = frame.zw * 0.5;
    vec2 ih = max(sh - vec2(frame.x), vec2(0.0));
    float u = -sdRoundedBox(p, sh, ih, min(frame.y, min(ih.x, ih.y)));
    u = blend(u, p, b0, k0);
    u = blend(u, p, b1, k1);
    u = blend(u, p, b2, k2);
    u = blend(u, p, b3, k3);
    u = blend(u, p, b4, k4);
    u = blend(u, p, b5, k5);
    float a = clamp(0.5 - u, 0.0, 1.0);
    // A borda (com o contorno do tema ligado): a faixa logo dentro da beira.
    float o = outline > 0.0 ? a - clamp(0.5 - u - outline, 0.0, 1.0) : 0.0;
    vec4 c = mix(fill, edge, o / max(a, 0.001));
    fragColor = vec4(c.rgb * c.a, c.a) * a * qt_Opacity;
}
