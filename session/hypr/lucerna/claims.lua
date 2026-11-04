-- As reivindicações de monitor: quais saídas têm uma regra de outra camada (o
-- settings.lua do shell, o hyprland.lua do usuário, o include antigo). A
-- escala automática da base não toca nesses monitores, para a regra do
-- usuário valer.
local M = {}

-- M.install(hl) → claims: troca o hl.monitor por um envoltório que anota o
-- spec.output em claims e chama o original. claims.original é o hl.monitor
-- de antes (a base o usa para as próprias regras, que não reivindicam nada).
function M.install(hl)
    local original = hl.monitor
    local claims = { original = original }
    hl.monitor = function(spec, ...)
        if type(spec) == "table" and type(spec.output) == "string" then
            claims[spec.output] = true
        end
        return original(spec, ...)
    end
    return claims
end

-- M.claimed(claims, monitor) → boolean: há uma regra pelo nome do monitor,
-- pela descrição (desc:...) ou uma regra genérica ("") de outra camada.
function M.claimed(claims, monitor)
    if claims[""] then
        return true
    end
    if monitor.name and claims[monitor.name] then
        return true
    end
    if monitor.description and claims["desc:" .. monitor.description] then
        return true
    end
    return false
end

return M
