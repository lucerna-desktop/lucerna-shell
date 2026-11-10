-- A escala automática pelo tamanho físico do monitor. Puro (sem o hl): os
-- testes rodam no lua comum (session/hypr/tests/scale_test.lua).
local M = {}

-- A densidade de referência: 110 ppi é a escala 1.
local REFERENCE_PPI = 110

-- Tamanhos de EDID que só codificam a razão de aspecto, não a medida de
-- verdade (projetores e TVs costumam mandar assim; o mutter faz o mesmo no
-- meta_monitor_has_aspect_as_size). Com eles, não há tamanho físico.
local ASPECT_AS_SIZE = {
    { 16, 9 }, { 16, 10 },
    { 160, 90 }, { 160, 100 },
    { 1600, 900 }, { 1600, 1000 },
}

-- aspect_as_size(a, b): o par (maior, menor) é um dos tamanhos falsos acima.
local function aspect_as_size(long_mm, short_mm)
    for _, size in ipairs(ASPECT_AS_SIZE) do
        if long_mm == size[1] and short_mm == size[2] then
            return true
        end
    end
    return false
end

-- M.scale_for(largura_px, altura_px, largura_mm, altura_mm) → escala.
-- Sem tamanho físico (mm ≤ 0, um tamanho que só codifica a razão de aspecto,
-- ou a razão de aspecto do mm mais de 20% diferente da dos pixels: EDID de
-- projetor/TV falso), dá 1. Senão, ppi = largura_px / (largura_mm / 25,4), o
-- alvo é ppi / 110 e a escala é o passo de 0,25 mais próximo entre 1 e 3 em
-- que largura_px / s e altura_px / s são inteiros (o de baixo em empate).
-- Monitor girado: as medidas são comparadas pelo lado maior e pelo menor, já
-- que o EDID dá o tamanho sem a rotação.
function M.scale_for(width_px, height_px, width_mm, height_mm)
    width_px, height_px = tonumber(width_px) or 0, tonumber(height_px) or 0
    width_mm, height_mm = tonumber(width_mm) or 0, tonumber(height_mm) or 0
    if width_px <= 0 or height_px <= 0 or width_mm <= 0 or height_mm <= 0 then
        return 1
    end
    local long_px, short_px = math.max(width_px, height_px), math.min(width_px, height_px)
    local long_mm, short_mm = math.max(width_mm, height_mm), math.min(width_mm, height_mm)
    if aspect_as_size(long_mm, short_mm) then
        return 1
    end
    local ratio = (long_mm / short_mm) / (long_px / short_px)
    if math.abs(ratio - 1) > 0.2 then
        return 1
    end
    local target = (long_px / (long_mm / 25.4)) / REFERENCE_PPI
    -- Os passos em quartos: s = k / 4, com k de 4 (1) a 12 (3). A resolução
    -- dividida por s é inteira quando 4 * px é múltiplo de k.
    local best, best_dist = 4, math.huge
    for k = 4, 12 do
        if (4 * width_px) % k == 0 and (4 * height_px) % k == 0 then
            local dist = math.abs(k / 4 - target)
            -- Estritamente menor: em empate, fica o passo de baixo (vindo antes).
            if dist < best_dist - 1e-9 then
                best, best_dist = k, dist
            end
        end
    end
    return best / 4
end

return M
