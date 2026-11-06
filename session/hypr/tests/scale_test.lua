-- Testes do lucerna/scale.lua (puro, sem o hl). Rodados pelo
-- ci/tests/test_hypr_lua.py, com session/hypr/?.lua no LUA_PATH.
local scale = require("lucerna.scale")

local cases = 0

-- case(nome, função): roda um caso; um assert que falha derruba o arquivo
-- com o nome do caso na mensagem.
local function case(name, fn)
    local ok, err = pcall(fn)
    if not ok then
        error(name .. ": " .. tostring(err), 0)
    end
    cases = cases + 1
    print("ok - " .. name)
end

local function expect(got, want, what)
    assert(got == want, what .. ": esperava " .. tostring(want) .. ", veio " .. tostring(got))
end

case("scale: 15,6\" 1920x1080 (344x194 mm) dá 1,25", function()
    expect(scale.scale_for(1920, 1080, 344, 194), 1.25, "1920x1080 em 344x194 mm")
end)

case("scale: 27\" 2560x1440 (597x336) dá 1", function()
    expect(scale.scale_for(2560, 1440, 597, 336), 1, "2560x1440 em 597x336 mm")
end)

case("scale: 27\" 3840x2160 (597x336) dá 1,5", function()
    expect(scale.scale_for(3840, 2160, 597, 336), 1.5, "3840x2160 em 597x336 mm")
end)

case("scale: 14\" 2880x1800 (302x189) dá 2,25", function()
    expect(scale.scale_for(2880, 1800, 302, 189), 2.25, "2880x1800 em 302x189 mm")
end)

case("scale: ultrawide 2560x1080 (673x284) dá 1", function()
    expect(scale.scale_for(2560, 1080, 673, 284), 1, "2560x1080 em 673x284 mm")
end)

case("scale: sem mm ou mm absurdo (160x90 numa 1920x1080 de 0x0, 1600x900 mm de TV) dá 1", function()
    expect(scale.scale_for(1920, 1080, 0, 0), 1, "sem tamanho físico (0x0 mm)")
    expect(scale.scale_for(1920, 1080, -1, 194), 1, "mm negativo")
    expect(scale.scale_for(1920, 1080, 160, 90), 1, "EDID só com a razão de aspecto (160x90 mm)")
    expect(scale.scale_for(3840, 2160, 16, 9), 1, "EDID só com a razão de aspecto (16x9 mm)")
    expect(scale.scale_for(2560, 1600, 160, 100), 1, "EDID só com a razão de aspecto (160x100 mm)")
    expect(scale.scale_for(3840, 2160, 1600, 900), 1, "1600x900 mm de TV")
    expect(scale.scale_for(3840, 2160, 300, 300), 1, "razão de aspecto do mm mais de 20% diferente")
end)

case("scale: o monitor girado usa o mesmo tamanho físico", function()
    expect(scale.scale_for(1080, 1920, 344, 194), 1.25, "1080x1920 (girado) em 344x194 mm")
end)

case("scale: só passos em que a resolução fica inteira", function()
    -- 2256x1504 em 13,5" (285x190 mm): alvo ≈1,83; 1,75 não divide 2256, e o
    -- 2 (1128x752) é o mais próximo que divide.
    expect(scale.scale_for(2256, 1504, 285, 190), 2, "2256x1504 em 285x190 mm")
    -- 4K em 15,6" (344x194 mm): alvo ≈2,58; 2,5 dá 1536x864.
    expect(scale.scale_for(3840, 2160, 344, 194), 2.5, "3840x2160 em 344x194 mm")
end)

print(string.format("SUITE scale casos=%d", cases))
