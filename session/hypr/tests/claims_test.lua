-- Testes do lucerna/claims.lua, com um hl falso. Rodados pelo
-- ci/tests/test_hypr_lua.py, com session/hypr/?.lua no LUA_PATH.
local claims_mod = require("lucerna.claims")

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

-- fake_hl(): um hl com o monitor que só guarda as specs recebidas.
local function fake_hl()
    local hl = { calls = {} }
    function hl.monitor(spec)
        table.insert(hl.calls, spec)
    end
    return hl
end

local edp = { name = "eDP-1", description = "AU Optronics 0x1234" }
local dp = { name = "DP-2", description = "Dell Inc. DELL U2720Q ABC123" }

case("claims: regra do usuário vence a automática", function()
    local hl = fake_hl()
    -- A regra genérica da base vem antes do install: não reivindica nada.
    hl.monitor({ output = "", mode = "highrr", position = "auto", scale = 1 })
    local claims = claims_mod.install(hl)
    assert(not claims_mod.claimed(claims, edp), "a regra genérica da base, antes do install, não reivindica o eDP-1")
    assert(not claims_mod.claimed(claims, dp), "a regra genérica da base, antes do install, não reivindica o DP-2")

    hl.monitor({ output = "desc:AU Optronics 0x1234", scale = 1.5 })
    assert(claims_mod.claimed(claims, edp), "a regra pela descrição reivindica o monitor com essa descrição")
    assert(not claims_mod.claimed(claims, dp), "a regra pela descrição não reivindica outro monitor")

    local by_name = claims_mod.install(fake_hl())
    assert(not claims_mod.claimed(by_name, edp), "sem regra, nada é reivindicado")
    local hl2 = fake_hl()
    local claims2 = claims_mod.install(hl2)
    hl2.monitor({ output = "eDP-1", scale = 2 })
    assert(claims_mod.claimed(claims2, edp), "a regra pelo nome reivindica o eDP-1")
    assert(not claims_mod.claimed(claims2, dp), "a regra pelo nome não reivindica o DP-2")

    local hl3 = fake_hl()
    local claims3 = claims_mod.install(hl3)
    hl3.monitor({ output = "", scale = 1 })
    assert(claims_mod.claimed(claims3, dp), "uma regra genérica de outra camada (depois do install) reivindica todos")
end)

case("claims: o original continua sendo chamado", function()
    local hl = fake_hl()
    local before = hl.monitor
    local claims = claims_mod.install(hl)
    assert(claims.original == before, "claims.original é o hl.monitor de antes do install")
    assert(hl.monitor ~= before, "o install troca o hl.monitor pelo envoltório")
    local spec = { output = "DP-2", mode = "highrr" }
    hl.monitor(spec)
    assert(#hl.calls == 1, "o envoltório chama o original uma vez")
    assert(hl.calls[1] == spec, "o original recebe a mesma spec")
    claims.original({ output = "HDMI-A-1" })
    assert(#hl.calls == 2, "chamar o original direto também chega a ele")
    assert(not claims_mod.claimed(claims, { name = "HDMI-A-1", description = "" }),
        "uma regra pelo original (a da escala automática) não reivindica")
end)

print(string.format("SUITE claims casos=%d", cases))
