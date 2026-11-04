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
-- spec.output em claims e chama o original. claims.original é o hl.monitor
-- de verdade (a base o usa para as próprias regras, que não reivindicam
-- nada). Cada install recomeça as reivindicações do zero.
function M.install(hl)
    local original = wrapped[hl.monitor] or hl.monitor
    local claims = { original = original }
    local function wrapper(spec, ...)
        if type(spec) == "table" and type(spec.output) == "string" then
            claims[spec.output] = true
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
    if claims[""] then
        return true
    end
    if monitor.name and claims[monitor.name] then
        return true
    end
    local description = monitor.description
    if type(description) ~= "string" or description == "" then
        return false
    end
    for key in pairs(claims) do
        if type(key) == "string" and key:sub(1, 5) == "desc:" then
            local prefix = trim(key:sub(6))
            if prefix ~= "" and description:sub(1, #prefix) == prefix then
                return true
            end
        end
    end
    return false
end

return M
