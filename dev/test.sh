#!/usr/bin/env bash
# Harness da conferência visual: sobe o Lucerna num container próprio
# (lucerna-polish, da imagem lucerna-dev do dev/run.sh), com o Hyprland aninhado
# numa janela na tela do usuário, e dá os comandos para reiniciar o shell, ler o
# log, chamar IPC, mudar a config e capturar a tela. Nunca toca o container
# lucerna-dev (o do dev/run.sh, que é do usuário).
#   dev/test.sh up                (re)cria o container e espera o shell carregar
#   dev/test.sh down               remove o container
#   dev/test.sh restart            reinicia o qs e espera carregar
#   dev/test.sh log [N]            as N últimas linhas do log (padrão 40), sem ruído
#   dev/test.sh errs               só os avisos e erros do log
#   dev/test.sh ipc ARGS...        qs -c lucerna ipc call ARGS...
#   dev/test.sh setc 'dict(...)'   mescla o dicionário (Python) no config.json do shell
#   dev/test.sh shot NOME          captura a tela em $LUCERNA_TEST_OUT/NOME.png
#   dev/test.sh see PREFIXO ARGS...  ipc call ARGS, 1 s, captura PREFIXO-ARGS.png, fecha
#   dev/test.sh run 'COMANDO'      roda um comando na sessão (notify-send, hyprctl...)
# LUCERNA_TEST_OUT: pasta das capturas (padrão /tmp/lucerna-test).
# LUCERNA_TEST_GPU="/dev/dri/renderDN /dev/dri/cardN": força a GPU repassada.
# LUCERNA_TEST_HOST_BUS=1 (no up): o shell usa o barramento de sessão do host,
# para ver os players MPRIS de fora (o Spotify aberto no host). Opcional porque
# o resto do shell também vai para o host: o servidor de notificações não pega
# o nome org.freedesktop.Notifications (o do desktop do host continua com ele),
# então os popups e a lista de notificações não funcionam nesse modo, e um
# notify-send no container fica sem servidor. E se o desktop do host largar o
# nome (o plasmashell reiniciando), o shell do container o pega: faça o up sem
# ela de novo depois do teste. E o container passa a poder chamar qualquer
# serviço da sessão do host (o chaveiro, os portais, o systemd --user): o modo
# é só para desenvolvimento. Vale até o próximo up sem ela.
# Um `hyprctl reload` ou fechar a janela derruba a saída do Hyprland aninhado
# (ele cai no monitor FALLBACK e as capturas saem vazias): dev/test.sh up de novo.
# LUCERNA_TEST_KWIN=0: no up, não posiciona a janela de teste. Com o host KDE
# (qdbus6 e o serviço org.kde.KWin), o up manda a janela (resourceClass
# aquamarine) para o primeiro monitor de escala 1 (devicePixelRatio) em que caiba o tamanho, tira
# a maximização e a borda e a centraliza nesse tamanho; sem monitor assim, ela
# fica onde está. Em escala fracionária a imagem sai borrada. Fora do KDE, não faz nada.
# LUCERNA_TEST_SIZE=LARGURAxALTURA: o tamanho da janela (padrão 1920x1080).
# O lucernad sobe com o Hyprland (dev/hyprland.lua). Para ver o shell sem ele:
# `dev/test.sh run 'pkill -x lucernad'`; para voltar (sempre pelo `run`, que põe
# o WAYLAND_DISPLAY do Hyprland aninhado, e sempre com a raiz falsa do brilho:
# o container monta o D-Bus do sistema do host e vê o /sys dele):
# `dev/test.sh run 'bash ~/.config/quickshell/lucerna/ci/power-root.sh /tmp/lucerna-power && setsid -f env LUCERNAD_POWER_ROOT=/tmp/lucerna-power LUCERNA_IDLE_TIMEOUT_MS=86400000 lucernad serve'`
#
# Teclas com modificador pelo wtype: o Hyprland aninhado resolve os binds pelo
# keycode do keymap real, e o wtype numera as teclas do keymap dele na ordem em
# que os caracteres aparecem, a partir do 1, que é o Esc (`wtype -M alt c`
# chega como Alt+Esc, o menu de energia). Mande antes caracteres de enchimento
# distintos (só ASCII: o locale do container não aceita acento no wtype), tantos
# quanto o código evdev da tecla menos 1 (c = 46, KEY_C: 45; n = 49, KEY_N: 48):
#   pad=$(printf '%s' {A..Z} {a..z} | tr -d c | cut -c1-45)
#   dev/test.sh run "wtype '$pad' -M alt c -m alt"; sleep 1; dev/test.sh ipc panels get
# O enchimento é digitado na janela em foco: faça isso num workspace vazio.
#
# Binds do shell: com a config em Lua, o `hyprctl binds -j` mostra
# `dispatcher: __lua` e o id da função, não o `action run ...`; não dá para
# achar a ação por grep. Confira a tecla (`key`, `modmask`) no JSON e aperte-a
# com o wtype como acima, olhando o `panels get`:
#   dev/test.sh run 'hyprctl binds -j' | python3 -c 'import json,sys; [print(b["modmask"], b["key"]) for b in json.load(sys.stdin)]'
#
# Roteiro de referência ("antes-*", a linha de base capturada antes das
# correções das Tarefas 21 a 28; regenerar a partir do repositório, com o
# container de pé):
#   p=antes
#   dev/test.sh see $p panels open launcher
#   dev/test.sh see $p launcher open files ""
#   for tab in overview media performance weather; do dev/test.sh see $p dashboard open "$tab"; done
#   for e in "" rede bluetooth som energia microfone notificacoes; do dev/test.sh see $p central open "$e"; done
#   for t in appearance wallpaper displays idle nightlight launcher clipboard capture mouse keyboard glass \
#       notifications panels bar dashboard power shortcuts about; do dev/test.sh see $p settings open "$t"; done
#   dev/test.sh see $p panels open themes
#   dev/test.sh see $p panels open power
#   dev/test.sh see $p clipboard open
#   dev/test.sh see $p capture open shot
#   dev/test.sh ipc session lock; sleep 1; dev/test.sh shot $p-bloqueio; dev/test.sh run 'wtype lucerna && wtype -k Return'
#   dev/test.sh run 'notify-send "Teste do Lucerna" "Corpo da notificação, comprido o bastante para quebrar em duas linhas"'; sleep 1; dev/test.sh shot $p-popup
#   # Brilho: antes de qualquer tecla, confira que o lucernad tem a raiz falsa (o
#   # D-Bus do sistema do host está montado); se não vier
#   # LUCERNAD_POWER_ROOT=/tmp/lucerna-power, pare. A tela é a integrada falsa
#   # (lucerna_teste); o arquivo brightness dela muda, o do host não.
#   dev/test.sh run 'tr "\0" "\n" < /proc/$(pgrep -xo lucernad)/environ | grep ^LUCERNAD_POWER_ROOT='
#   dev/test.sh run 'lucernad brilho'
#   dev/test.sh ipc brightness up; dev/test.sh shot $p-osd; dev/test.sh ipc brightness down
#   dev/test.sh run 'cat /tmp/lucerna-power/sys/class/backlight/lucerna_teste/brightness'
#   for e in pill island; do dev/test.sh setc "dict(barStyle='$e')"; sleep 1; dev/test.sh shot $p-barra-$e; done; dev/test.sh setc "dict(barStyle='pill')"
#   for e in compact full grid; do dev/test.sh setc "dict(launcherStyle='$e')"; dev/test.sh see $p-$e launcher open apps ""; done; dev/test.sh setc "dict(launcherStyle='compact')"
#   # Nesta imagem, o Hyprland (0.56.2, config Lua) não aceita mais o
#   # `hyprctl dispatch exec "[workspace N silent] CMD"` clássico (dá erro de
#   # parser Lua); use a forma hl.dsp abaixo.
#   dev/test.sh run "hyprctl dispatch 'hl.dsp.exec_cmd(\"[workspace 2 silent] kitty\")'"
#   dev/test.sh run "hyprctl dispatch 'hl.dsp.exec_cmd(\"[workspace 3 silent] foot\")'"; sleep 2; dev/test.sh see $p overview toggle
#
#   Extras para as Tarefas 22, 24, 26 e 27 (telas que essas conferências
#   comparam e que o roteiro acima não cobre):
#   dev/test.sh run 'notify-send "Teste do Lucerna" "Corpo da notificação, comprido o bastante para quebrar em duas linhas"'
#   dev/test.sh see $p-caixa central open notificacoes
#   # `None` (null) é a forma canônica de voltar ao tema, a mesma do `resetGlass`; o
#   # `dict()` só deixava uma chave vazia ({}) no config, com o mesmo efeito.
#   dev/test.sh setc 'dict(transparencyOverride=dict(enabled=True))'; dev/test.sh see $p-vidro settings open glass; dev/test.sh setc 'dict(transparencyOverride=None)'
#   dev/test.sh setc "dict(launcherStyle='full')"; dev/test.sh see $p-full-busca launcher open apps kitty; dev/test.sh setc "dict(launcherStyle='compact')"
#   # Copiar sem o wl-clipboard: o lucernad-selecao, só pelo `run` (o WAYLAND_DISPLAY
#   # do Hyprland aninhado). O container também tem o socket do host como
#   # wayland-host: antes de copiar, confira que o lucernad está no aninhado
#   # (wayland-<número>; se vier wayland-host, pare).
#   dev/test.sh run 'tr "\0" "\n" < /proc/$(pgrep -xo lucernad)/environ | grep ^WAYLAND_DISPLAY='
#   dev/test.sh run 'printf "texto de teste" | setsid -f lucernad-selecao oferecer "text/plain;charset=utf-8" text/plain > /dev/null'
#   dev/test.sh see $p-clipboard clipboard open
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
name=lucerna-polish
image=lucerna-dev
out=${LUCERNA_TEST_OUT:-/tmp/lucerna-test}
# "dropped operation" fica de fora: é o sintoma do bug do Config (spec linha
# 112); se voltar, tem que aparecer no log e no errs, não ser filtrado.
noise='portal'

fail() {
    echo "ERRO: $*" >&2
    exit 1
}

# A GPU repassada: o primeiro nó de render que não é da NVIDIA (o container não
# tem os drivers dela) e o card do mesmo dispositivo PCI.
gpu() {
    local node dev card
    if [ -n "${LUCERNA_TEST_GPU:-}" ]; then
        echo "$LUCERNA_TEST_GPU"
        return 0
    fi
    for node in /sys/class/drm/renderD*; do
        [ -e "$node/device/vendor" ] || continue
        [ "$(cat "$node/device/vendor")" = 0x10de ] && continue
        dev=$(readlink -f "$node/device")
        for card in /sys/class/drm/card[0-9]*; do
            case "${card##*/}" in *-*) continue ;; esac
            if [ "$(readlink -f "$card/device")" = "$dev" ]; then
                echo "/dev/dri/${node##*/} /dev/dri/${card##*/}"
                return 0
            fi
        done
    done
    return 1
}

# ex 'COMANDO': roda no container com o ambiente da sessão do Hyprland (D-Bus,
# instância e o socket Wayland do Hyprland aninhado, achado pelo nome).
ex() {
    docker exec -i "$name" bash -c '
        pid=$(pgrep -x Hyprland) || { echo "ERRO: o Hyprland não está rodando no container" >&2; exit 3; }
        export "$(tr "\0" "\n" < "/proc/$pid/environ" | grep ^DBUS_SESSION_BUS_ADDRESS=)"
        HYPRLAND_INSTANCE_SIGNATURE=$(ls -t "$XDG_RUNTIME_DIR/hypr" | head -n 1)
        WAYLAND_DISPLAY=$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -type s -name "wayland-[0-9]*" -printf "%f\n" | sort | head -n 1)
        export HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY
        '"$1"
}

# Sobe o shell; com o barramento do host montado (LUCERNA_TEST_HOST_BUS=1 no
# up), ele usa esse barramento no lugar do da sessão do container.
start_shell() {
    # shellcheck disable=SC2016 # expande dentro do container, não aqui
    ex 'pkill -x qs; sleep 0.5
        if [ -S "$XDG_RUNTIME_DIR/host-bus" ]; then
            export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/host-bus"
        fi
        setsid -f qs -c lucerna > /dev/null 2>&1 < /dev/null'
}

running() {
    [ "$(docker inspect -f '{{.State.Running}}' "$name" 2> /dev/null)" = true ] \
        || fail "o container $name não está de pé: rode dev/test.sh up"
}

# Espera o "Configuration Loaded" da instância atual do shell (até 60 s).
wait_loaded() {
    for _ in $(seq 120); do
        if ex 'qs -c lucerna log 2> /dev/null' 2> /dev/null | grep -q "Configuration Loaded"; then
            return 0
        fi
        sleep 0.5
    done
    ex 'qs -c lucerna log 2>&1 | tail -n 30' || true
    fail "o shell não carregou em 60 s (log acima)"
}

setc() {
    running
    docker exec -i -e SETC="$1" "$name" python3 -c '
import glob, json, os, sys, time

pattern = os.path.expanduser("~/.local/state/quickshell/by-shell/*/config.json")
for _ in range(40):
    paths = glob.glob(pattern)
    if paths:
        break
    time.sleep(0.25)
if len(paths) != 1:
    sys.exit(f"ERRO: esperava um config.json em {pattern}, achei {len(paths)}")
with open(paths[0], encoding="utf-8") as f:
    data = json.load(f)
# Expressão do próprio usuário na linha de comando; só dict e as constantes.
names = {"__builtins__": {}, "dict": dict, "True": True, "False": False, "None": None}
data.update(eval(os.environ["SETC"], names))
with open(paths[0], "w", encoding="utf-8") as f:
    json.dump(data, f, indent=4, ensure_ascii=False)
print("config:", os.environ["SETC"])
'
}

# shot NOME: captura a saída do Hyprland aninhado em $out/NOME.png. Com
# timeout: se a janela do host estiver escondida ou minimizada, o Hyprland
# aninhado para de desenhar e o grim trava esperando um frame que não vem.
shot() {
    running
    ex 'hyprctl monitors | grep -q "^Monitor WAYLAND-1 "' \
        || fail "a saída WAYLAND-1 sumiu (Hyprland no FALLBACK, depois de um reload ou da janela fechada): rode dev/test.sh up"
    mkdir -p "$out"
    ex 'timeout 10 grim -o WAYLAND-1 /tmp/lucerna-shot.png' \
        || fail "a captura travou: a janela de teste está escondida ou minimizada? Traga-a para a frente (não precisa de foco) e tente de novo."
    docker cp -q "$name:/tmp/lucerna-shot.png" "$out/$1.png"
    echo "$out/$1.png"
}

# Posiciona a janela do container (resourceClass aquamarine) no KDE do host,
# por um script do KWin. Não faz nada fora do KDE nem com LUCERNA_TEST_KWIN=0, e
# nunca derruba o up: a janela pode demorar a aparecer, então tenta por ~5 s,
# até a saída do Hyprland aninhado ter o tamanho pedido.
place_window() {
    [ "${LUCERNA_TEST_KWIN:-1}" = 0 ] && return 0
    local size=${LUCERNA_TEST_SIZE:-1920x1080} qd w h script id
    qd=$(command -v qdbus6 || command -v qdbus) || return 0
    [[ $size =~ ^([0-9]+)x([0-9]+)$ ]] || { echo "aviso: LUCERNA_TEST_SIZE inválido ($size), esperava LARGURAxALTURA" >&2; return 0; }
    w=${BASH_REMATCH[1]} h=${BASH_REMATCH[2]}
    "$qd" org.kde.KWin /KWin org.kde.KWin.supportInformation &> /dev/null || return 0
    script=$(mktemp --suffix=.js)
    cat > "$script" << JS
for (const win of workspace.windowList()) {
    if (win.resourceClass === "aquamarine") {
        const out = workspace.screens.find(o => o.devicePixelRatio === 1 && o.geometry.width >= $w && o.geometry.height >= $h);
        if (out) workspace.sendClientToScreen(win, out);
        win.setMaximize(false, false);
        win.noBorder = true;
        const g = out ? out.geometry : win.frameGeometry;
        win.frameGeometry = { x: g.x + Math.round((g.width - $w) / 2), y: g.y + Math.round((g.height - $h) / 2), width: $w, height: $h };
    }
}
JS
    for _ in 1 2 3 4 5; do
        id=$("$qd" org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$script" "lucerna-test-$$") || break
        "$qd" org.kde.KWin "/Scripting/Script$id" org.kde.kwin.Script.run &> /dev/null || true
        "$qd" org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript "lucerna-test-$$" &> /dev/null || true
        sleep 1
        if ex "hyprctl monitors | grep -q '^Monitor WAYLAND-1 ' && hyprctl monitors | grep -q '${w}x${h}@'" &> /dev/null; then
            break
        fi
    done
    rm -f "$script"
    return 0
}

up() {
    : "${WAYLAND_DISPLAY:?precisa de uma sessão Wayland no host}"
    local runtime=${XDG_RUNTIME_DIR:-/run/user/$(id -u)} devices render card
    devices=$(gpu) || fail "nenhuma GPU utilizável em /sys/class/drm (a da NVIDIA não funciona no container); use LUCERNA_TEST_GPU"
    read -r render card <<< "$devices"
    # A imagem é refeita quando falta ou quando o lucernad dela é de outra revisão.
    local rev
    rev=$(cat "$repo/dev/lucernad.rev")
    if ! docker image inspect "$image" &> /dev/null \
        || [ "$(docker image inspect -f '{{ index .Config.Labels "lucernad.rev" }}' "$image")" != "$rev" ]; then
        docker build --build-arg UID="$(id -u)" --build-arg GID="$(id -g)" --build-arg LUCERNAD_REV="$rev" -t "$image" "$repo/dev"
    fi
    local extra=()
    if [ -S "$runtime/pipewire-0" ]; then
        extra+=(-v "$runtime/pipewire-0:/run/user/1000/pipewire-0")
    fi
    if [ -S /run/dbus/system_bus_socket ]; then
        extra+=(-v /run/dbus/system_bus_socket:/run/dbus/system_bus_socket)
    fi
    local host_bus=0
    if [ "${LUCERNA_TEST_HOST_BUS:-}" = 1 ]; then
        [ -S "$runtime/bus" ] || fail "LUCERNA_TEST_HOST_BUS=1, mas não há barramento de sessão em $runtime/bus"
        extra+=(-v "$runtime/bus:/run/user/1000/host-bus")
        host_bus=1
    fi
    # Os outros discos montados no host, só para leitura, para o card de Disco
    # ver os mesmos discos (e a troca por clique) que o shell vê fora do container.
    local target
    while read -r target; do
        extra+=(-v "$target:$target:ro")
    done < <(findmnt -rno SOURCE,TARGET | awk '$1 ~ "^/dev/" && $1 !~ "^/dev/(loop|zram)" && $2 != "/" { print $2 }')
    docker rm -f "$name" &> /dev/null || true
    docker run -d --name "$name" \
        --user "$(id -u):$(id -g)" \
        --device "$render" --device "$card" \
        -e WAYLAND_DISPLAY=wayland-host \
        -e LUCERNA_DEV=1 \
        -v /etc/localtime:/etc/localtime:ro \
        -v "$runtime/$WAYLAND_DISPLAY:/run/user/1000/wayland-host" \
        -v "$repo:/home/dev/.config/quickshell/lucerna" \
        -v "$repo/dev/hyprland.lua:/home/dev/.config/hypr/hyprland.lua:ro" \
        "${extra[@]}" \
        "$image" > /dev/null
    wait_loaded
    if [ "$host_bus" = 1 ]; then
        start_shell
        wait_loaded
        echo "barramento de sessão: o do host (MPRIS de fora; sem as notificações do shell)"
    fi
    # Sem isso a ociosidade apaga a tela em 5 min e as capturas saem pretas.
    setc 'dict(idleEnabled=False)'
    echo "de pé: $name (GPU $render), capturas em $out"
    place_window
}

case "${1:-}" in
    up) up ;;
    down) docker rm -f "$name" > /dev/null && echo "removido: $name" ;;
    restart)
        running
        start_shell
        wait_loaded
        echo "shell reiniciado"
        ;;
    log)
        running
        ex 'qs -c lucerna log 2>&1' | sed 's/\x1b\[[0-9;]*m//g' | grep -vE "$noise" | tail -n "${2:-40}"
        ;;
    errs)
        running
        found=$(ex 'qs -c lucerna log 2>&1' | sed 's/\x1b\[[0-9;]*m//g' | grep -E 'WARN|ERROR|caused' | grep -vE "$noise" || true)
        if [ -n "$found" ]; then
            echo "$found"
        else
            echo "sem avisos nem erros"
        fi
        ;;
    ipc)
        running
        shift
        [ $# -gt 0 ] || fail "uso: dev/test.sh ipc ALVO FUNÇÃO [ARGUMENTOS...]"
        ex "qs -c lucerna ipc call $(printf '%q ' "$@")"
        ;;
    setc)
        [ -n "${2:-}" ] || fail "uso: dev/test.sh setc 'dict(chave=valor, ...)'"
        setc "$2"
        ;;
    shot)
        [ -n "${2:-}" ] || fail "uso: dev/test.sh shot NOME"
        shot "$2"
        ;;
    see)
        running
        [ $# -ge 3 ] || fail "uso: dev/test.sh see PREFIXO ALVO FUNÇÃO [ARGUMENTOS...]"
        # O prefixo passa pela mesma sanitização do resto do nome, para não
        # gravar fora de $out (ex.: um prefixo com "/" ou "..").
        prefix=$(printf '%s' "$2" | tr -cd 'a-z0-9-')
        shift 2
        ex "qs -c lucerna ipc call $(printf '%q ' "$@")" > /dev/null
        sleep 1
        shot "$prefix-$(printf '%s-' "$@" | tr -cd 'a-z0-9-' | sed 's/-*$//')"
        ex 'qs -c lucerna ipc call panels close' > /dev/null
        ;;
    run)
        running
        [ -n "${2:-}" ] || fail "uso: dev/test.sh run 'COMANDO'"
        ex "$2"
        ;;
    *)
        sed -n '2,41p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
        exit 2
        ;;
esac
