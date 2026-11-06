-- A base do Hyprland da sessão Lucerna (só leitura; instalada em
-- /usr/share/lucerna/hypr/). O lucerna-session sobe o Hyprland com
-- `-c <esta base>`. Ela põe os padrões, os binds fixos da sessão e a escala
-- automática, e carrega por cima o ~/.config/lucerna/hypr/settings.lua (o
-- arquivo do shell) e o ~/.config/hypr/hyprland.lua (o do usuário). O shell
-- nunca escreve aqui nem no arquivo do usuário.

-- 1. Contra a reentrada: o hyprland.lua do usuário pode incluir a base de
-- novo, e esse include volta logo. A marca só fica ligada enquanto as
-- camadas carregam (passo 6, sob pcall, então sempre é limpa): se o Hyprland
-- mantiver o estado Lua entre os reloads, um reload carrega a base inteira.
if LUCERNA_BASE_LOADING then
    return
end

local home = os.getenv("HOME") or ""
local config_home = os.getenv("XDG_CONFIG_HOME")
if not config_home or config_home == "" then
    config_home = home .. "/.config"
end

-- A pasta de dados: LUCERNA_DATA_DIR (o lucerna-session a põe: a pasta
-- session/ do repositório ou /usr/share/lucerna), senão a pasta acima desta
-- base, senão a instalada.
local function data_dir()
    local dir = os.getenv("LUCERNA_DATA_DIR")
    if dir and dir ~= "" then
        return dir
    end
    local source = debug and debug.getinfo and debug.getinfo(1, "S").source or ""
    local here = source:match("^@(.*)/hypr/[^/]*$")
    return here or "/usr/share/lucerna"
end

-- Os módulos da base (lucerna.*) e, depois, os do usuário: com o -c na base,
-- o require do hyprland.lua do usuário não acharia os arquivos ao lado dele.
package.path = data_dir() .. "/hypr/?.lua;" .. config_home .. "/hypr/?.lua;" .. package.path

local scale = require("lucerna.scale")
local claims_mod = require("lucerna.claims")

-- 2. O envoltório que anota as regras das outras camadas, e a regra genérica
-- da base pelo original (não reivindica nada). O install tira um envoltório
-- de um carregamento anterior, se o estado Lua ficou.
local claims = claims_mod.install(hl)
claims.original({ output = "", mode = "highrr", position = "auto", scale = 1 })

-- 3. Os padrões.
local function env_or(name, default)
    local value = os.getenv(name)
    if value == nil or value == "" then
        return default
    end
    return value
end

hl.config({
    input = {
        kb_layout = env_or("LUCERNA_KB_LAYOUT", "us"),
        kb_variant = env_or("LUCERNA_KB_VARIANT", ""),
        kb_model = env_or("LUCERNA_KB_MODEL", ""),
        kb_options = env_or("LUCERNA_KB_OPTIONS", ""),
        touchpad = { tap_to_click = true, natural_scroll = true },
    },
    general = { gaps_in = 4, gaps_out = 10, border_size = 2 },
    misc = {
        allow_session_lock_restore = true,
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        force_default_wallpaper = 0,
        key_press_enables_dpms = true,
        mouse_move_enables_dpms = true,
    },
    xwayland = { force_zero_scaling = true },
    ecosystem = { no_update_news = true, no_donation_nag = true },
})

-- 4. O ambiente dos apps: Wayland primeiro, X11 de reserva.
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("SDL_VIDEODRIVER", "wayland,x11")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("_JAVA_AWT_WM_NONREPARENTING", "1")

-- 5. Os binds fixos da sessão, que valem mesmo sem o shell. No
-- desenvolvimento (LUCERNA_DEV=1, Hyprland aninhado), o mod é ALT, para não
-- brigar com os atalhos do desktop do host.
local mod = os.getenv("LUCERNA_DEV") == "1" and "ALT" or "SUPER"
hl.bind(mod .. " + Return", hl.dsp.exec_cmd("lucerna-session open terminal"))
hl.bind("CTRL + ALT + Delete", hl.dsp.exec_cmd("lucerna-session power"))
hl.bind("CTRL + ALT + SHIFT + Escape", hl.dsp.exec_cmd("lucerna-session logout"))

-- 6. As camadas de cima: o arquivo do shell e o do usuário. Um arquivo que
-- não existe é pulado; um erro vira uma notificação, e a sessão segue.
local function notify(text)
    io.stderr:write(text .. "\n")
    pcall(hl.notification.create, { text = text, timeout = 15000 })
end

local function load_layer(path)
    local file = io.open(path, "r")
    if not file then
        return
    end
    file:close()
    local ok, err = pcall(dofile, path)
    if not ok then
        notify("Lucerna: erro em " .. path .. ": " .. tostring(err))
    end
end

LUCERNA_BASE_LOADING = true
load_layer(config_home .. "/lucerna/hypr/settings.lua")
load_layer(config_home .. "/hypr/hyprland.lua")
LUCERNA_BASE_LOADING = nil

-- 7. A escala automática, para cada monitor sem regra de outra camada. No
-- modo "Escala pelos apps" (a seção scale do settings.lua põe o global
-- lucerna_scale_mode = "apps"), o compositor fica em 1 e os apps escalam.
local function scale_monitor(m)
    if type(m) ~= "table" and type(m) ~= "userdata" then
        return
    end
    if not m.name or claims_mod.claimed(claims, m) then
        return
    end
    local s = 1
    if lucerna_scale_mode ~= "apps" then
        s = scale.scale_for(m.width, m.height, m.physical_width, m.physical_height)
    end
    claims.original({ output = m.name, mode = "highrr", position = "auto", scale = s })
end

local function scale_all()
    for _, m in ipairs(hl.get_monitors() or {}) do
        scale_monitor(m)
    end
end

-- safe_scale(m): a escala sem derrubar quem chama. Um erro aqui vira aviso
-- (stderr e notificação), e os monitores ficam na regra genérica (escala 1).
local function safe_scale(m)
    local ok, err
    if m and m.name then
        ok, err = pcall(scale_monitor, m)
    else
        ok, err = pcall(scale_all)
    end
    if not ok then
        notify("Lucerna: erro na escala automática: " .. tostring(err))
    end
end

-- Os eventos. Se o estado Lua ficar entre os reloads, as inscrições do
-- carregamento anterior são tiradas antes, para não empilhar.
for _, subscription in ipairs(LUCERNA_BASE_SUBSCRIPTIONS or {}) do
    pcall(subscription.remove, subscription)
end
LUCERNA_BASE_SUBSCRIPTIONS = {
    hl.on("hyprland.start", function()
        safe_scale()
        -- 8. Avisa o lucerna-session que o compositor está de pé, mesmo com
        -- erro na escala: sem o ready, o shell não sobe.
        hl.exec_cmd("lucerna-session ready")
    end),
    hl.on("monitor.added", safe_scale),
    hl.on("config.reloaded", function()
        safe_scale()
    end),
}
