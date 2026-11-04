-- A camada do usuário do Hyprland aninhado do container de teste. É montada
-- só pelo dev/test.sh, como ~/.config/hypr/hyprland.lua; o dev/hyprland.lua é
-- a config do lucerna-dev do usuário (dev/run.sh), mantido como na main. A
-- sessão entra pelo lucerna-session, que sobe o Hyprland com a base
-- (session/hypr/hyprland.lua): ela põe os padrões, os binds fixos (com
-- LUCERNA_DEV=1, o mod é ALT, para não brigar com os atalhos do KDE no host;
-- ALT + Return abre o terminal) e, no hyprland.start, chama o
-- `lucerna-session ready`, que sobe o shell. Aqui fica só o do container.

hl.monitor({
    output   = "",
    mode     = "1920x1080",
    position = "auto",
    scale    = 1,
})

-- O logind falso (ci/logind-fake.sh) num barramento privado, antes do shell:
-- o shell escuta o logind só nele (LUCERNA_LOGIND_BUS, do dev/test.sh); o
-- barramento do sistema montado é o do host. Roda ao carregar a config, antes
-- do hyprland.start (que chama o ready e sobe o shell), e espera o nome
-- org.freedesktop.login1 (até 10 s). Com o falso já de pé, só confere. Se
-- falhar, o shell sobe assim mesmo, sem o logind.
os.execute([[bash ~/.config/quickshell/lucerna/ci/logind-fake.sh start /run/user/1000 > /dev/null]])

hl.on("hyprland.start", function()
    -- Sem systemd no container, o lucernad sobe aqui, com o Hyprland, e não
    -- encerra por ociosidade (24 h). Só com o WAYLAND_DISPLAY do Hyprland
    -- aninhado (wayland-<número>): o container recebe o socket do compositor do
    -- host como wayland-host, e um lucernad nele observaria (e tomaria) a área
    -- de transferência de verdade do usuário. E sempre com a raiz falsa do
    -- brilho (ci/power-root.sh, LUCERNAD_POWER_ROOT): o container monta o
    -- D-Bus do sistema do host e vê o /sys dele; sem ela, um ajuste de brilho
    -- aqui mudaria o brilho de verdade do host (o lucernad em container sem a
    -- raiz deixa o módulo indisponível, mas a defesa não depende só dele).
    hl.exec_cmd([[sh -c 'case "$WAYLAND_DISPLAY" in wayland-[0-9]*) bash ~/.config/quickshell/lucerna/ci/power-root.sh /tmp/lucerna-power && exec env LUCERNAD_POWER_ROOT=/tmp/lucerna-power LUCERNA_IDLE_TIMEOUT_MS=86400000 lucernad serve ;; *) echo "hyprland.lua: o lucernad não sobe: WAYLAND_DISPLAY=$WAYLAND_DISPLAY não é o do Hyprland aninhado (wayland-<número>)" >&2 ;; esac']])
end)

-- O teclado do container (a base usa o detectado, que aqui é us).
hl.config({
    input = {
        kb_layout = "br",
    },
})

local mod = "ALT"
local ipc = "qs -c lucerna ipc call "

hl.bind(mod .. " + Q",         hl.dsp.window.close())
hl.bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd("lucerna-session shell restart"))
hl.bind(mod .. " + SHIFT + E", hl.dsp.exit())

-- Os atalhos do Lucerna (painéis, bloqueio, som, mídia e brilho) ficam com o
-- próprio shell: Configurações → Atalhos. Aqui, só os do Hyprland.

-- Volume e brilho sem teclas de mídia (no host, elas ficam com o KDE)
hl.bind(mod .. " + Up",    hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { repeating = true })
hl.bind(mod .. " + Down",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { repeating = true })
hl.bind(mod .. " + M",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
hl.bind(mod .. " + Right", hl.dsp.exec_cmd(ipc .. "brightness up"),   { repeating = true })
hl.bind(mod .. " + Left",  hl.dsp.exec_cmd(ipc .. "brightness down"), { repeating = true })

for i = 1, 5 do
    hl.bind(mod .. " + " .. i,         hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))
