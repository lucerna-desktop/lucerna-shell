-- As reivindicações de monitor: quais saídas têm uma regra de outra camada (o
-- settings.lua do shell, o hyprland.lua do usuário, o include antigo). A
-- escala automática da base não toca nesses monitores, para a regra do
-- usuário valer.
local M = {}

-- Os envoltórios já instalados → o hl.monitor de verdade que cada um chama.
-- Se o Hyprland mantiver o estado Lua entre os reloads, a base roda de novo
-- com o envoltório do carregamento anterior no hl.monitor; com esta tabela, o
-- install tira o velho em vez de empilhar outro por cima.
local wrapped = setmetatable({}, { __mode = "k" })

local function trim(text)
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- M.install(hl) → claims: troca o hl.monitor por um envoltório que anota o
-- spec.output em claims.outputs e chama o original. claims.original é o
-- hl.monitor de verdade (a base o usa para as próprias regras, que não
-- reivindicam nada); as saídas ficam numa tabela à parte, para um monitor
-- chamado "original" não se misturar com ele. claims.auto guarda as regras
-- automáticas já mandadas (M.auto). Cada install recomeça tudo do zero.
function M.install(hl)
    local original = wrapped[hl.monitor] or hl.monitor
    local claims = { original = original, outputs = {}, auto = {} }
    local function wrapper(spec, ...)
        if type(spec) == "table" and type(spec.output) == "string" then
            claims.outputs[spec.output] = true
        end
        return original(spec, ...)
    end
    wrapped[wrapper] = original
    hl.monitor = wrapper
    return claims
end

-- M.claimed(claims, monitor) → boolean: há uma regra pelo nome do monitor,
-- pela descrição ou uma regra genérica ("") de outra camada. O desc:<x> casa
-- como no Hyprland: pelo começo da descrição (<x> sem os espaços das pontas),
-- então vale a descrição encurtada (desc:AU Optronics) e a descrição com o
-- sufixo do conector ("... (eDP-1)").
function M.claimed(claims, monitor)
    local outputs = claims.outputs
    if outputs[""] then
        return true
    end
    if monitor.name and outputs[monitor.name] then
        return true
    end
    local description = monitor.description
    if type(description) ~= "string" or description == "" then
        return false
    end
    for key in pairs(outputs) do
        if type(key) == "string" and key:sub(1, 5) == "desc:" then
            local prefix = trim(key:sub(6))
            if prefix ~= "" and description:sub(1, #prefix) == prefix then
                return true
            end
        end
    end
    return false
end

-- M.auto(claims, spec) → boolean: a regra automática da base pelo original,
-- só se ela mudou para essa saída. O Hyprland acumula as regras de monitor, e
-- a base escala de novo a cada monitor.added e config.reloaded: sem isto,
-- cada evento empilharia uma regra igual à anterior.
function M.auto(claims, spec)
    local key = string.format("%s|%s|%s", tostring(spec.mode), tostring(spec.position), tostring(spec.scale))
    if claims.auto[spec.output] == key then
        return false
    end
    claims.auto[spec.output] = key
    claims.original(spec)
    return true
end

return M
