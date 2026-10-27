#!/usr/bin/env bash
# Teste de fumaça: sobe o sway headless (o Hyprland não sobe sem GPU), um
# D-Bus de sessão, um PipeWire e um WirePlumber próprios (o som isolado, com o
# sink nulo de ci/audio/), um mpv tocando nele um arquivo de ruído com título e
# artista (o player MPRIS; o arquivo é gerado pelo ffmpeg), o servidor falso de
# letras e clima (ci/web-fake.py, em 127.0.0.1) e o lucernad (dev/lucernad.sh,
# compilado no ci/setup.sh, com o LUCERNAD_WEB_BASE apontando para o servidor
# falso: nada vai à internet), roda o shell
# instrumentado numa cópia do repositório (copy_repo, do ci/lib.sh), abre cada
# painel por IPC, confere o `panels get`, tira uma captura de cada estado e
# reprova com aviso ou erro fora do ci/tolerated.txt. Duas fases do lucernad:
# com ele, o shell precisa conectar ("lucerna: conectado ao lucernad" no log em
# 10 s); depois do último passo, ele é parado ("lucernad fora"), o shell precisa
# notar ("lucerna: sem conexão com o lucernad" em 10 s) e as abas Desempenho,
# Painel e Clima são abertas e capturadas de novo, com o "indisponível". Antes disso, a
# fase "espectro": com a aba Mídia aberta, o lucernad precisa capturar o mpv,
# as bandas precisam mexer, e com o painel fechado o fluxo de captura some.
# E a fase "área de transferência", antes do painel dela: o lucernad sobe sem
# WAYLAND_DISPLAY (a sessão chega pelo clipboard.configure do shell), e o
# lucernad-selecao (o exemplo do lucernad, no lugar do wl-clipboard) copia um
# texto, a primeira captura (image/png) e uma senha marcada; o histórico
# precisa trazer o texto (5 s) e a imagem com miniatura, e não a senha (1 s);
# a busca "fumaca" acha o texto com o trecho marcado, e o `lucernad copiar`
# põe o texto de volta na seleção (lido pelo lucernad-selecao). O painel da
# área de transferência é capturado com os dois itens.
# Depois dela, a fase "brilho": o lucernad sobe com LUCERNAD_POWER_ROOT numa
# árvore falsa (ci/power-root.sh: uma tela integrada de teste com 1000 de
# máximo e 500 de valor; nada de logind, DDC ou /sys de verdade); o `lucernad
# brilho` precisa mostrar a `backlight` em 50% (5 s), a tecla `brightness up`
# precisa levar o arquivo da árvore a 550 (2 s, com a captura do OSD) e dez
# teclas seguidas, a 1000 (2 s, a rajada juntada no limite); a central é
# capturada com o slider. Depois do brilho, a fase "rede": a busca de cidade
# "Cacau" pelo IPC weather (o servidor falso responde três cidades) e a escolha
# da primeira, que precisa ser "Cacaulândia, Rondônia, BR" (5 s); com a aba
# Clima aberta, o web.weather do `lucernad --json status` precisa chegar a
# ready com 7 dias (5 s, com a captura); com a aba Mídia aberta, o web.lyrics
# precisa trazer a letra da faixa do mpv (found, lrclib, 4 linhas, em 5 s, com
# a captura); e o log do servidor falso precisa ter ao menos um pedido de cada
# fonte (LRCLIB, previsão, busca de cidade). Na fase "lucernad fora", a página
# Tela e ociosidade das configurações também é capturada, com o brilho
# "Indisponível", e a aba Clima, com o "Indisponível".
# O som nunca alcança um alto-falante: o PipeWire da fumaça é próprio, sem os
# monitores de hardware, e o mpv toca só no sink nulo. A unidade roda de novo
# numa cópia separada (unit_suites e unit_run, do ci/lib.sh), e a cobertura de
# todas as funções (unidade + fumaça) sai junto, sem bloquear.
#
# Reprova com: função fora do padrão na instrumentação --all (arquivo:linha),
# sway, D-Bus, som isolado (sem o sink nulo em 10 s), mpv (sem o nome MPRIS em
# 10 s), lucernad ou shell que não sobe (sem "Configuration Loaded" no log),
# shell que não conecta ao lucernad ou não nota a saída dele, o lucernad que não
# captura o mpv com a aba Mídia aberta (10 s), bandas paradas (nenhum quadro
# com valor acima de 0,05 em 5 s), fluxo de captura que sobra com o painel
# fechado (5 s), a área de transferência (texto que não entra em 5 s, imagem
# sem miniatura, senha que entra, busca sem o texto ou sem o trecho, colar de
# volta que não devolve o texto), o brilho (lucernad sem o aviso da árvore de
# teste no log, a tela falsa que não aparece em 50% em 5 s, a tecla que não
# leva o arquivo a 550 ou a rajada que não chega a 1000, cada uma em 2 s), a rede
# (o servidor falso que não grava o porto em 10 s, o lucernad sem o aviso "a rede é
# de teste" no log, a cidade escolhida diferente de "Cacaulândia, Rondônia, BR",
# a previsão que não chega a ready com 7 dias, a letra que não chega a found da
# lrclib com 4 linhas, cada uma em 5 s, ou o log do servidor falso sem um pedido
# de cada fonte), `ipc call`
# com código diferente de 0, `panels get` diferente do esperado, painel que não
# fecha, shell que cai (inclusive no repouso de 5 s depois do último passo),
# shell que não encerra limpo com `qs kill` (código 0 em 10 s), aviso ou erro
# fora do ci/tolerated.txt no log final (conferido depois do encerramento), a
# unidade da cópia separada que falha e todo `ipc call` ou grim que passa de
# 10 s (timeout, com o fim do shell.log na saída).
#
# Só encerra os próprios processos (os grupos do shell, dos lucernad-selecao,
# do mpv, do lucernad, do servidor falso, do WirePlumber, do PipeWire, do D-Bus e
# do sway, por PID), nunca por nome:
# rodada fora do container, não derruba a sessão do usuário.
#
# O que a fumaça não confere por IPC: a aba do painel superior, a página da
# central e o tópico das configurações que ficaram abertos. Os IPCs dashboard,
# central e settings não devolvem o estado atual; uma aba, página ou tópico
# que não abre só aparece como erro no log (o logcheck) e na captura.
#
# Saída em $CI_OUT: shell.log, sway.log, dbus.log, pipewire.log,
# wireplumber.log, mpv.log, web-fake.log, lucernad.log, kill.log, unit-smoke.log, shots/NN-<passo>.png,
# coverage.md e summary.md (tabela passo, esperado, veio).
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=ci/lib.sh
. "$repo/ci/lib.sh"

out=${CI_OUT:-$repo/ci-out}
mkdir -p "$out/shots"
out=$(cd "$out" && pwd)
work=$(mktemp -d)
# O sway, o D-Bus, o PipeWire, o WirePlumber, o mpv, o servidor falso, o
# lucernad e o shell
# rodam cada um no próprio grupo de processos (setsid), e só esses grupos são
# encerrados: nada é morto por nome, para a fumaça rodada fora do container
# nunca derrubar o shell, o sway ou o som de verdade do usuário.
sway_pid=""
dbus_pid=""
pipewire_pid=""
wireplumber_pid=""
mpv_pid=""
lucernad_pid=""
web_pid=""
selecao_pids=()
qs_pid=""
shell_pid=""
logs_checked=0
# clean_log: o log do shell (a saída crua do qs) sem cores, em $CI_OUT.
clean_log() {
    if [ -f "$work/raw.log" ]; then
        sed 's/\x1b\[[0-9;]*m//g' "$work/raw.log" > "$out/shell.log"
    fi
}
# stop_group <pid>: encerra o grupo de processos que <pid> lidera (TERM; KILL
# se sobrar alguém depois de 5 s) e o recolhe.
stop_group() {
    local pid=$1
    [ -n "$pid" ] || return 0
    kill -TERM -- "-$pid" 2> /dev/null || true
    for _ in $(seq 20); do
        kill -0 -- "-$pid" 2> /dev/null || break
        sleep 0.25
    done
    kill -KILL -- "-$pid" 2> /dev/null || true
    wait "$pid" 2> /dev/null || true
}
# shellcheck disable=SC2329 # chamada pelo trap
cleanup() {
    stop_group "$qs_pid"
    local pid
    for pid in "${selecao_pids[@]}"; do
        stop_group "$pid"
    done
    stop_group "$mpv_pid"
    stop_group "$lucernad_pid"
    stop_group "$web_pid"
    stop_group "$wireplumber_pid"
    stop_group "$pipewire_pid"
    stop_group "$dbus_pid"
    stop_group "$sway_pid"
    # O que o shell escreveu até o fim (inclusive depois de uma falha) vai para
    # o artefato.
    clean_log || true
    rm -rf "$work"
}
trap cleanup EXIT

summary="$out/summary.md"
{
    printf '## Fumaça\n\n'
    printf '| Passo | Esperado | Veio |\n| --- | --- | --- |\n'
} > "$summary"

# fail <mensagem>: reprova. Antes da conferência final do log, mostra também os
# avisos e erros do log até aqui que o ci/tolerated.txt não cobre (a causa de
# um painel que não abriu costuma estar lá).
fail() {
    echo "ERRO: $*" >&2
    printf '\n**Falhou:** %s\n' "$*" >> "$summary"
    if [ "$logs_checked" = 0 ] && [ -f "$work/raw.log" ]; then
        clean_log
        echo "--- avisos e erros do log até aqui, fora do ci/tolerated.txt ---" >&2
        python3 "$repo/ci/logcheck.py" "$repo/ci/tolerated.txt" "$out/shell.log" "$out/sway.log" >&2 || true
        # O fim do log é o trecho de um travamento (o que o shell fazia quando parou).
        echo "--- últimas linhas do shell.log ---" >&2
        tail -n 15 "$out/shell.log" >&2 2> /dev/null || true
    fi
    exit 1
}

# why <código>: o texto do código de saída de um comando com `timeout`; o 124 é
# o timeout (o shell travou ou o comando não respondeu).
why() {
    if [ "$1" -eq 124 ]; then
        echo "timeout de $CMD_TIMEOUT s (o shell travou ou não respondeu; o shell.log tem o trecho)"
    else
        echo "código $1"
    fi
}

# row <passo> <esperado> <veio>: uma linha da tabela do summary.md.
row() {
    printf '| %s | %s | %s |\n' "$1" "$2" "$3" >> "$summary"
}

export XDG_RUNTIME_DIR="$work/run" XDG_CONFIG_HOME="$work/config" XDG_STATE_HOME="$work/state" XDG_CACHE_HOME="$work/cache"
install -d -m 700 "$XDG_RUNTIME_DIR"
cfg="$XDG_CONFIG_HOME/quickshell/lucerna"
copy_repo "$cfg" || fail "não consegui copiar o repositório para a pasta de configuração do shell"
# Com --all, toda função de todos os .qml precisa estar no padrão
# `function nome(...) {` numa linha: o coverage.py lista cada uma fora dele como
# "arquivo:linha: função fora do padrão" e sai com 1. Nada é pulado.
python3 "$repo/ci/coverage.py" instrument "$cfg" --all \
    || fail "a instrumentação (--all) achou função fora do padrão \"function nome(...) {\" numa linha (arquivo:linha acima): ponha a declaração inteira numa linha no .qml"

# sway headless com uma saída de 1920x1080. Sem o Xwayland e sem o swaybg (o
# fundo é do próprio shell): o container não tem nenhum dos dois, e o sway
# registraria um ERROR para cada um. O socket é o primeiro wayland-* que ele
# abrir (o nome muda com o que já existe no XDG_RUNTIME_DIR), detectado, não
# fixo.
printf '%s\n' 'output HEADLESS-1 resolution 1920x1080' 'xwayland disable' 'swaybg_command -' > "$work/sway.cfg"
# Num script, o filho em segundo plano não lidera grupo: o setsid cria a sessão
# sem outro fork, e o PID do sway é o do grupo.
WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 \
    setsid sway -c "$work/sway.cfg" > "$out/sway.log" 2>&1 &
sway_pid=$!
socket=""
for _ in $(seq 100); do
    socket=$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -type s -name 'wayland-*' -printf '%f\n' | sort | head -n 1)
    [ -n "$socket" ] && break
    kill -0 "$sway_pid" 2> /dev/null || break
    sleep 0.2
done
[ -n "$socket" ] || fail "o sway não abriu nenhum socket wayland-* em $XDG_RUNTIME_DIR em 20 s (veja sway.log)"
row "sway headless" "um socket wayland-*" "$socket"
export WAYLAND_DISPLAY=$socket QT_QPA_PLATFORM=wayland QT_QUICK_BACKEND=software

# O D-Bus de sessão, o PipeWire e o WirePlumber da fumaça, todos no
# XDG_RUNTIME_DIR dela: o lucernad, o mpv e o shell usam o mesmo barramento
# (o daemon acha o player pelo nome MPRIS) e o mesmo PipeWire. Nunca os do
# host: o PIPEWIRE_REMOTE herdado sai, e o PipeWire próprio não tem os
# monitores de hardware (o wireplumber.conf de ci/audio/), só o sink nulo.
unset PIPEWIRE_REMOTE
export PIPEWIRE_RUNTIME_DIR=$XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus
setsid dbus-daemon --session --nofork --nopidfile --address="$DBUS_SESSION_BUS_ADDRESS" > "$out/dbus.log" 2>&1 &
dbus_pid=$!
for _ in $(seq 50); do
    [ -S "$XDG_RUNTIME_DIR/bus" ] && break
    kill -0 "$dbus_pid" 2> /dev/null || break
    sleep 0.2
done
if [ ! -S "$XDG_RUNTIME_DIR/bus" ]; then
    row "D-Bus de sessão" "socket em 10 s" "(não veio)"
    fail "o dbus-daemon não abriu $XDG_RUNTIME_DIR/bus em 10 s (veja dbus.log)"
fi
row "D-Bus de sessão" "socket em 10 s" "bus"

install -D -m 644 "$repo/ci/audio/pipewire.conf" "$XDG_CONFIG_HOME/pipewire/pipewire.conf.d/pipewire.conf"
install -D -m 644 "$repo/ci/audio/wireplumber.conf" "$XDG_CONFIG_HOME/wireplumber/wireplumber.conf.d/wireplumber.conf"
setsid pipewire > "$out/pipewire.log" 2>&1 &
pipewire_pid=$!
setsid wireplumber > "$out/wireplumber.log" 2>&1 &
wireplumber_pid=$!
sink=0
for _ in $(seq 50); do
    if wpctl status 2> /dev/null | grep -q lucerna-nulo; then
        sink=1
        break
    fi
    sleep 0.2
done
if [ "$sink" = 0 ]; then
    row "som isolado" "sink nulo em 10 s" "(não veio)"
    fail "o sink lucerna-nulo não apareceu no wpctl status em 10 s (veja pipewire.log e wireplumber.log)"
fi
row "som isolado" "sink nulo em 10 s" "lucerna-nulo"

# O player: o mpv tocando sem fim 20 s de ruído rosa com título e artista (a
# faixa que o servidor falso conhece: o lucernad não busca letra de faixa sem
# artista), só no sink nulo, com o MPRIS do mpv-mpris no barramento da fumaça.
# O nome leva o sufixo da instância (org.mpris.MediaPlayer2.mpv.instance-<id>,
# do mpv-mpris novo): a fumaça guarda o nome que veio.
ffmpeg -loglevel error -f lavfi -i anoisesrc=color=pink:amplitude=0.5 -t 20 \
    -metadata title="Canção da Fumaça" -metadata artist="Lucerna" "$work/fumaca.ogg" \
    || fail "o ffmpeg não gerou o arquivo de ruído com as etiquetas ($work/fumaca.ogg)"
setsid mpv --no-video --vo=null --no-terminal --ao=pipewire --audio-device=pipewire/lucerna-nulo \
    --loop-file=inf "$work/fumaca.ogg" > "$out/mpv.log" 2>&1 &
mpv_pid=$!
mpris=""
for _ in $(seq 50); do
    mpris=$(dbus-send --session --print-reply --dest=org.freedesktop.DBus / org.freedesktop.DBus.ListNames 2> /dev/null \
        | grep -oE '"org\.mpris\.MediaPlayer2\.mpv(\.[^"]*)?"' | tr -d '"' | head -n 1 || true)
    [ -n "$mpris" ] && break
    kill -0 "$mpv_pid" 2> /dev/null || break
    sleep 0.2
done
if [ -z "$mpris" ]; then
    row "player de teste" "org.mpris.MediaPlayer2.mpv* em 10 s" "(não veio)"
    fail "o mpv não registrou um nome org.mpris.MediaPlayer2.mpv* em 10 s (veja mpv.log)"
fi
row "player de teste" "org.mpris.MediaPlayer2.mpv* em 10 s" "$mpris"

# O lucernad no próprio grupo, como o sway, com a ociosidade em 10 min (a
# fumaça inteira cabe nela); o socket dele fica no XDG_RUNTIME_DIR da fumaça.
# Sem WAYLAND_DISPLAY: a área de transferência observa a sessão que o shell
# manda no clipboard.configure (o caminho do daemon sem sessão no ambiente).
# O brilho é o de uma árvore falsa (LUCERNAD_POWER_ROOT, criada pelo
# ci/power-root.sh): a fumaça rodada fora do container nunca toca o brilho de
# verdade.
# O servidor falso de letras e clima (ci/web-fake.py), no próprio grupo: grava
# o porto livre que pegou em 127.0.0.1, e o lucernad vai a ele pelo
# LUCERNAD_WEB_BASE (nunca às fontes de verdade).
setsid python3 -I "$repo/ci/web-fake.py" "$work/web-porto" > "$out/web-fake.log" 2>&1 &
web_pid=$!
for _ in $(seq 50); do
    [ -s "$work/web-porto" ] && break
    kill -0 "$web_pid" 2> /dev/null || break
    sleep 0.2
done
if [ ! -s "$work/web-porto" ]; then
    row "servidor falso de letras e clima" "porto em 10 s" "(não veio)"
    fail "o ci/web-fake.py não gravou o porto em 10 s (veja web-fake.log)"
fi
web_base="http://127.0.0.1:$(cat "$work/web-porto")"
row "servidor falso de letras e clima" "porto em 10 s" "$web_base"

lucernad_sock="$XDG_RUNTIME_DIR/lucerna/lucernad.sock"
power_root="$XDG_RUNTIME_DIR/power"
bash "$repo/ci/power-root.sh" "$power_root" || fail "o ci/power-root.sh não criou a árvore falsa do brilho em $power_root"
power_file="$power_root/sys/class/backlight/lucerna_teste/brightness"
LUCERNAD_WEB_BASE=$web_base LUCERNAD_POWER_ROOT=$power_root LUCERNA_IDLE_TIMEOUT_MS=600000 setsid env -u WAYLAND_DISPLAY lucernad serve > "$out/lucernad.log" 2>&1 &
lucernad_pid=$!
for _ in $(seq 50); do
    [ -S "$lucernad_sock" ] && break
    kill -0 "$lucernad_pid" 2> /dev/null || break
    sleep 0.2
done
if [ ! -S "$lucernad_sock" ]; then
    row "lucernad" "socket em 10 s" "(não veio)"
    fail "o lucernad não abriu $lucernad_sock em 10 s (veja lucernad.log)"
fi
row "lucernad" "socket em 10 s" "lucerna/lucernad.sock"
grep -qF "LUCERNAD_POWER_ROOT=$power_root: o brilho é de teste" "$out/lucernad.log" \
    || fail "o lucernad não avisou que o brilho é o da árvore de teste ($power_root; veja lucernad.log)"
row "lucernad" "brilho da árvore de teste" "LUCERNAD_POWER_ROOT=power"
grep -qF "LUCERNAD_WEB_BASE=$web_base: a rede é de teste" "$out/lucernad.log" \
    || fail "o lucernad não avisou que a rede é de teste ($web_base; veja lucernad.log)"
row "lucernad" "rede de teste" "LUCERNAD_WEB_BASE=$web_base"

# O shell grava o próprio PID (o bash do meio dá lugar ao qs com exec, e o
# grupo é o dele): é por ele que a fumaça confere que o shell continua vivo e o
# encerra no fim.
# shellcheck disable=SC2016 # o $$ e o $1 expandem no bash de dentro
setsid bash -c 'echo "$$" > "$1" && exec qs -c lucerna' _ "$work/qs.pid" > "$work/raw.log" 2>&1 &
qs_pid=$!
for _ in $(seq 120); do
    [ -z "$shell_pid" ] && [ -s "$work/qs.pid" ] && shell_pid=$(cat "$work/qs.pid")
    grep -q "Configuration Loaded" "$work/raw.log" && break
    kill -0 "$qs_pid" 2> /dev/null || break
    sleep 0.5
done
[ -n "$shell_pid" ] || shell_pid=$(cat "$work/qs.pid" 2> /dev/null || true)
clean_log
if ! grep -q "Configuration Loaded" "$out/shell.log"; then
    row "shell carregado" "Configuration Loaded" "(não veio)"
    fail "o shell não carregou (sem \"Configuration Loaded\" no log: o qs saiu antes ou passaram 60 s; veja shell.log)"
fi
row "shell carregado" "Configuration Loaded" "Configuration Loaded"

# wait_log <texto>: espera até 10 s pela linha no log cru do shell.
wait_log() {
    for _ in $(seq 50); do
        grep -qF "$1" "$work/raw.log" && return 0
        sleep 0.2
    done
    return 1
}
if ! wait_log "lucerna: conectado ao lucernad"; then
    row "shell conectado ao lucernad" "em 10 s" "(não conectou)"
    fail "o shell não conectou ao lucernad em 10 s"
fi
row "shell conectado ao lucernad" "em 10 s" "lucerna: conectado ao lucernad"

[ -n "$shell_pid" ] || fail "não achei o PID do shell ($work/qs.pid vazio)"

# alive: o shell (o próprio qs) está rodando.
alive() { kill -0 "$shell_pid" 2> /dev/null; }
# Todo `ipc call` e todo grim têm timeout: sem ele, um shell travado deixaria o
# job parado até o limite do workflow, sem diagnóstico.
CMD_TIMEOUT=10
ipc() { timeout "$CMD_TIMEOUT" qs -c lucerna ipc call "$@"; }
shot() { timeout "$CMD_TIMEOUT" grim "$1"; }
n=0
shot "$out/shots/00-inicio.png" || fail "o grim não capturou a tela inicial: $(why $?)"

# step <esperado no panels get> <alvo> <função> [argumentos...]: chama o IPC,
# confere que o shell continua vivo e que o `panels get` traz o painel
# esperado, tira a captura e fecha tudo (panels close), conferindo que o
# `panels get` volta vazio.
step() {
    local expected=$1 name got
    shift
    n=$((n + 1))
    name=$(printf '%02d-%s' "$n" "$(printf '%s-' "$@" | tr -cd 'a-z0-9-' | sed 's/-*$//')")
    ipc "$@" > /dev/null || fail "ipc call $* falhou: $(why $?)"
    sleep 1
    alive || fail "o shell caiu depois de: ipc call $*"
    got=$(ipc panels get) || fail "ipc call panels get falhou: $(why $?)"
    row "ipc call $*" "$expected" "${got:-(nenhum)}"
    [ "$got" = "$expected" ] || fail "depois de \"ipc call $*\", o panels get trouxe \"$got\"; o esperado era \"$expected\""
    shot "$out/shots/$name.png" || fail "o grim não capturou $name: $(why $?)"
    ipc panels close > /dev/null || fail "ipc call panels close falhou: $(why $?)"
    got=$(ipc panels get) || fail "ipc call panels get falhou: $(why $?)"
    [ -z "$got" ] || fail "depois de \"ipc call panels close\" (passo $name), o panels get trouxe \"$got\"; o esperado era nenhum painel"
}

step launcher panels open launcher
# Nome que já foi painel (a barra lateral saiu): o IPC ignora e nada abre.
step "" panels open sidebar
step launcher launcher open files ""
for tab in overview media performance weather; do
    step dashboard dashboard open "$tab"
done

# Fase "espectro": com a aba Mídia aberta, o shell assina as bandas e diz ao
# lucernad qual player seguir; o daemon liga um fluxo de captura ao nó do mpv.
# capture_state: o `capturing` e o `player` do spectrum.status numa linha
# ("true \"<nome>\""), de uma leitura só do `lucernad --json status` (vazio
# se o daemon não responder).
capture_state() {
    timeout "$CMD_TIMEOUT" lucernad --json status 2> /dev/null | python3 -c '
import json, sys
for line in sys.stdin:
    try:
        state = json.loads(line)
    except ValueError:
        continue
    status = state.get("spectrum.status") if isinstance(state, dict) else None
    if isinstance(status, dict):
        print(json.dumps(status.get("capturing")), json.dumps(status.get("player")))
        break
' || true
}
n=$((n + 1))
ipc dashboard open media > /dev/null || fail "ipc call dashboard open media falhou: $(why $?)"
state=""
for _ in $(seq 20); do
    state=$(capture_state)
    [ "$state" = "true \"$mpris\"" ] && break
    sleep 0.5
done
row "espectro" "capturando o mpv em 10 s" "${state:-(sem resposta)}"
[ "$state" = "true \"$mpris\"" ] \
    || fail "com a aba Mídia aberta, o spectrum.status não chegou a capturing true e player \"$mpris\" em 10 s (veio \"$state\"; veja lucernad.log)"
peak=$(timeout 5 lucernad --json watch spectrum.bands 2> /dev/null | python3 -c '
import json, sys
peak = 0.0
for line in sys.stdin:
    try:
        state = json.loads(line)
    except ValueError:
        continue
    data = state.get("data") if isinstance(state, dict) else None
    bands = data.get("bands") if isinstance(data, dict) else None
    if isinstance(bands, list) and bands:
        peak = max(peak, max(bands))
print(f"{peak:.3f}")
') || true
row "espectro" "bandas mexendo (máximo > 0,05 em 5 s)" "${peak:-(sem quadro)}"
python3 -c 'import sys; sys.exit(0 if float(sys.argv[1] or 0) > 0.05 else 1)' "${peak:-0}" \
    || fail "as bandas do spectrum.bands não passaram de 0,05 em 5 s (máximo ${peak:-nenhum}; veja lucernad.log e mpv.log)"
alive || fail "o shell caiu na fase do espectro"
shot "$out/shots/$(printf '%02d' "$n")-espectro-media.png" || fail "o grim não capturou o espectro: $(why $?)"
ipc panels close > /dev/null || fail "ipc call panels close falhou: $(why $?)"
# O pw-cli precisa responder (código 0): um PipeWire caído não passa por
# "sem fluxo".
nodes=""
for _ in $(seq 10); do
    state=$(capture_state)
    if graph=$(timeout "$CMD_TIMEOUT" pw-cli ls Node 2> /dev/null); then
        nodes=$(grep -c lucernad-espectro <<< "$graph" || true)
    else
        nodes="(pw-cli falhou)"
    fi
    [ "${state%% *}" = false ] && [ "$nodes" = 0 ] && break
    sleep 0.5
done
row "espectro" "sem fluxo com o anel fechado (5 s)" "capturing ${state%% *}, nós $nodes"
[ "${state%% *}" = false ] && [ "$nodes" = 0 ] \
    || fail "com o painel fechado, o espectro não parou em 5 s (capturing ${state%% *}, $nodes nó(s) lucernad-espectro no pw-cli)"
# Cada entrada abre a página do recurso (Wi-Fi, Bluetooth, saída de áudio,
# bateria, microfone); sem o recurso, como no CI, o estado inicial.
for entry in "" rede bluetooth som energia microfone notificacoes; do
    step central central open "$entry"
done
# Cada um dos dois painéis da central sozinho e os dois juntos: todos ficam
# no painel modal central.
step central central toggle som
step central central toggle ""
step central controls open rede
step central controls toggle ""
step central notifications open
step central notifications toggle
step central panels open central
step central panels toggle central
# A barra fundida à moldura continua clicável por cima da central: um clique
# na hora (no meio do topo) com a central aberta troca a central pelo painel
# superior (o clique não cai na central, que fecharia tudo). Aberto, o painel
# superior é a própria barra transformada: outro clique no mesmo ponto cai
# nele, e ele fica aberto. O clique vem de um ponteiro virtual.
# click_pill <esperado no panels get>
click_pill() {
    local got
    n=$((n + 1))
    timeout "$CMD_TIMEOUT" python3 -I "$repo/ci/vclick.py" 960 21 || fail "o clique na pílula falhou: $(why $?)"
    sleep 1
    alive || fail "o shell caiu depois do clique na pílula"
    got=$(ipc panels get) || fail "ipc call panels get falhou: $(why $?)"
    row "clique na barra fundida" "$1" "${got:-(nenhum)}"
    [ "$got" = "$1" ] || fail "depois do clique na hora da barra fundida, o panels get trouxe \"$got\"; o esperado era \"${1:-nenhum}\""
    shot "$out/shots/$(printf '%02d' "$n")-clique-pilula.png" || fail "o grim não capturou o clique na pílula: $(why $?)"
}
ipc central open "" > /dev/null || fail "ipc call central open falhou: $(why $?)"
sleep 1
click_pill dashboard
click_pill dashboard
ipc panels close > /dev/null || fail "ipc call panels close falhou: $(why $?)"
sleep 1
# A barra sobre as janelas: sem o "Sempre visível sem janelas", ela fica
# escondida (o clique na altura da hora não abre nada) e o mouse encostado no
# topo a traz (o clique na hora abre o painel superior). No Hyprland, isso vale
# também com uma janela maximizada (só a tela cheia de verdade segura a troca
# de workspace); o sway da fumaça não tem o Hyprland, então o teste da
# maximizada fica no roteiro do container (dev/test.sh).
# set_config <json>: mescla o objeto no config.json do shell, que vigia
# o arquivo e recarrega.
set_config() {
    local file
    file=$(find "$XDG_STATE_HOME/quickshell" -name config.json -print -quit)
    [ -n "$file" ] || fail "não achei o config.json do shell em $XDG_STATE_HOME/quickshell"
    python3 -I -c 'import json, sys; d = json.load(open(sys.argv[1])); d.update(json.loads(sys.argv[2])); json.dump(d, open(sys.argv[1], "w"), indent=4)' "$file" "$1" \
        || fail "não consegui mudar o config.json ($1)"
    sleep 1
}
# hover_pill <rótulo> <esperado no panels get> [move]: com `move`, encosta o
# mouse no topo e desce até a hora com a barra descendo, num ponteiro só (no
# sway, o ponteiro some com o processo, e a barra recolheria); clica na hora e
# confere o painel.
hover_pill() {
    local got path=("960,21" click)
    n=$((n + 1))
    timeout "$CMD_TIMEOUT" python3 -I "$repo/ci/vclick.py" 960 600 move || fail "mover o ponteiro falhou: $(why $?)"
    sleep 1
    if [ "${3:-}" = move ]; then
        path=("960,0" 0.3 "960,21" 1 click)
    fi
    timeout "$CMD_TIMEOUT" python3 -I "$repo/ci/vclick.py" --path "${path[@]}" || fail "o clique na hora falhou: $(why $?)"
    sleep 1
    alive || fail "o shell caiu depois do clique na hora ($1)"
    got=$(ipc panels get) || fail "ipc call panels get falhou: $(why $?)"
    row "$1" "$2" "${got:-(nenhum)}"
    [ "$got" = "$2" ] || fail "$1: o panels get trouxe \"$got\"; o esperado era \"${2:-nenhum}\""
    shot "$out/shots/$(printf '%02d' "$n")-barra-hover.png" || fail "o grim não capturou $1: $(why $?)"
    ipc panels close > /dev/null || fail "ipc call panels close falhou: $(why $?)"
    sleep 1
}
set_config '{"barOnEmpty": false, "barPeek": false}'
hover_pill "barra escondida: clique na hora" ""
hover_pill "mouse no topo: clique na hora" dashboard move
set_config '{"barOnEmpty": true, "barPeek": true}'
for topic in appearance wallpaper displays idle nightlight launcher clipboard capture mouse keyboard glass \
    notifications panels bar dashboard power shortcuts credits about; do
    step settings settings open "$topic"
done
step themes panels open themes
step power panels open power

# Fase "área de transferência". clip_list [BUSCA]: os itens do `lucernad --json
# historico`, um por linha (id, tipo, 1 se a miniatura existe no disco, os
# trechos marcados em JSON), de uma leitura só (vazio se o daemon não
# responder).
clip_list() {
    timeout "$CMD_TIMEOUT" lucernad --json historico "$@" 2> /dev/null | python3 -c '
import json, os, sys
for line in sys.stdin:
    try:
        page = json.loads(line)
    except ValueError:
        continue
    items = page.get("items") if isinstance(page, dict) else None
    if isinstance(items, list):
        for item in items:
            thumb = item.get("thumb")
            found = int(isinstance(thumb, str) and os.path.isfile(thumb))
            print(item.get("id"), item.get("kind"), found, json.dumps(item.get("matches"), separators=(",", ":")), sep="\t")
        break
' || true
}
# clip_count: quantos itens o histórico tem.
clip_count() { clip_list | grep -c . || true; }
# offer <arquivo> <mime>...: o lucernad-selecao vira dono da seleção com o
# conteúdo do arquivo, no próprio grupo (encerrado no cleanup; ele sai sozinho
# quando outra cópia toma a seleção).
offer() {
    local file=$1
    shift
    setsid lucernad-selecao oferecer "$@" < "$file" >> "$out/selecao.log" 2>&1 &
    selecao_pids+=("$!")
}
# wait_count <n> <tentativas>: espera o histórico chegar a n itens (0,2 s por
# tentativa); o último valor fica em $count.
wait_count() {
    for _ in $(seq "$2"); do
        count=$(clip_count)
        [ "$count" = "$1" ] && return 0
        sleep 0.2
    done
    return 1
}
printf 'olá da fumaça' > "$work/texto"
offer "$work/texto" 'text/plain;charset=utf-8' text/plain
wait_count 1 25 || true
row "área de transferência" "texto observado em 5 s" "$count item(ns)"
[ "$count" = 1 ] || fail "o texto copiado pelo lucernad-selecao não entrou no histórico em 5 s ($count itens; veja lucernad.log e selecao.log)"
text_id=$(clip_list | awk -F '\t' '$2 == "text" { print $1 }')
offer "$out/shots/00-inicio.png" image/png
wait_count 2 25 || true
thumbs=$(clip_list | awk -F '\t' '$2 == "image" && $3 == 1' | grep -c . || true)
row "área de transferência" "a captura (image/png) com miniatura em 5 s" "$count itens, $thumbs com miniatura"
[ "$count" = 2 ] && [ "$thumbs" = 1 ] \
    || fail "a captura copiada não entrou no histórico com a miniatura em 5 s ($count itens, $thumbs imagem(ns) com o thumb no disco)"
printf 'segredo' > "$work/senha"
offer "$work/senha" text/plain x-kde-passwordManagerHint
sleep 1
count=$(clip_count)
row "área de transferência" "senha de fora (ainda 2 itens em 1 s)" "$count itens"
[ "$count" = 2 ] || fail "a cópia marcada com x-kde-passwordManagerHint mexeu no histórico ($count itens; o esperado eram 2)"
found=$(clip_list fumaca)
shown=${found//$'\t'/ }
row "área de transferência" "a busca \"fumaca\" acha o texto com o trecho" "${shown:-(nada)}"
[ "$(grep -c . <<< "$found")" = 1 ] && [ "$(cut -f1 <<< "$found")" = "$text_id" ] && [[ $(cut -f4 <<< "$found") == "[["* ]] \
    || fail "a busca \"fumaca\" não trouxe só o texto ($text_id) com matches (veio \"$found\")"
timeout "$CMD_TIMEOUT" lucernad copiar "$text_id" > /dev/null || fail "lucernad copiar $text_id falhou"
pasted=""
for _ in $(seq 25); do
    pasted=$(timeout "$CMD_TIMEOUT" lucernad-selecao ler text/plain 2> /dev/null || true)
    [ "$pasted" = "olá da fumaça" ] && break
    sleep 0.2
done
row "área de transferência" "colar de volta (lucernad copiar)" "${pasted:-(nada)}"
[ "$pasted" = "olá da fumaça" ] || fail "depois do lucernad copiar $text_id, a seleção não trouxe o texto em 5 s (veio \"$pasted\")"
alive || fail "o shell caiu na fase da área de transferência"
step clipboard clipboard open
step capture capture open shot
step overview overview toggle

# Fase "brilho". backlight_percent: o percent da tela `backlight` no `lucernad
# --json brilho` (vazio se o daemon não responder ou a tela não vier).
backlight_percent() {
    timeout "$CMD_TIMEOUT" lucernad --json brilho 2> /dev/null | python3 -c '
import json, sys
for line in sys.stdin:
    try:
        page = json.loads(line)
    except ValueError:
        continue
    screens = page.get("screens") if isinstance(page, dict) else None
    if isinstance(screens, list):
        for screen in screens:
            if isinstance(screen, dict) and screen.get("id") == "backlight" and not screen.get("error"):
                print(screen.get("percent"))
        break
' || true
}
# wait_power <valor>: espera até 2 s o arquivo brightness da árvore falsa
# chegar ao valor; o último lido fica em $power.
wait_power() {
    for _ in $(seq 10); do
        power=$(cat "$power_file" 2> /dev/null || true)
        [ "$power" = "$1" ] && return 0
        sleep 0.2
    done
    return 1
}
percent=""
for _ in $(seq 25); do
    percent=$(backlight_percent)
    [ "$percent" = 50 ] && break
    sleep 0.2
done
row "brilho" "tela integrada falsa em 50% em 5 s" "${percent:-(não veio)}"
[ "$percent" = 50 ] || fail "o lucernad --json brilho não trouxe a tela backlight em 50% em 5 s (veio \"$percent\"; veja lucernad.log)"
n=$((n + 1))
ipc brightness up > /dev/null || fail "ipc call brightness up falhou: $(why $?)"
wait_power 550 || true
row "brilho" "tecla: o arquivo em 550 em 2 s" "${power:-(vazio)}"
[ "$power" = 550 ] || fail "depois do ipc call brightness up, o brightness da árvore falsa não chegou a 550 em 2 s (veio \"$power\")"
shot "$out/shots/$(printf '%02d' "$n")-osd-brilho.png" || fail "o grim não capturou o OSD do brilho: $(why $?)"
for _ in $(seq 10); do
    ipc brightness up > /dev/null || fail "ipc call brightness up (rajada) falhou: $(why $?)"
done
wait_power 1000 || true
row "brilho" "rajada de 10 teclas: o arquivo em 1000 em 2 s" "${power:-(vazio)}"
[ "$power" = 1000 ] || fail "depois de 10 ipc call brightness up, o brightness da árvore falsa não chegou a 1000 em 2 s (veio \"$power\")"
alive || fail "o shell caiu na fase do brilho"
n=$((n + 1))
ipc central open "" > /dev/null || fail "ipc call central open falhou: $(why $?)"
sleep 1
shot "$out/shots/$(printf '%02d' "$n")-central-brilho.png" || fail "o grim não capturou a central com o brilho: $(why $?)"
ipc panels close > /dev/null || fail "ipc call panels close falhou: $(why $?)"

# Fase "rede". web_state <tópico>: o resumo do web.weather ("<state> <dias>
# dias") ou do web.lyrics ("<state> <source> <linhas> linhas") no `lucernad
# --json status`, de uma leitura só (vazio se o daemon não responder).
web_state() {
    timeout "$CMD_TIMEOUT" lucernad --json status 2> /dev/null | python3 -c '
import json, sys
topic = sys.argv[1]
for line in sys.stdin:
    try:
        state = json.loads(line)
    except ValueError:
        continue
    data = state.get(topic) if isinstance(state, dict) else None
    if isinstance(data, dict):
        if topic == "web.weather":
            print(data.get("state"), len(data.get("daily") or []), "dias")
        else:
            print(data.get("state"), data.get("source") or "-", len(data.get("lines") or []), "linhas")
        break
' "$1" || true
}
# wait_web <tópico> <esperado>: espera até 5 s o web_state chegar ao esperado;
# o último fica em $web.
wait_web() {
    for _ in $(seq 25); do
        web=$(web_state "$1")
        [ "$web" = "$2" ] && return 0
        sleep 0.2
    done
    return 1
}
ipc weather search Cacau > /dev/null || fail "ipc call weather search Cacau falhou: $(why $?)"
city=""
for _ in $(seq 25); do
    city=$(ipc weather choose 0) || fail "ipc call weather choose 0 falhou: $(why $?)"
    [ -n "$city" ] && break
    sleep 0.2
done
row "rede" "cidade escolhida em 5 s" "${city:-(nenhuma)}"
[ "$city" = "Cacaulândia, Rondônia, BR" ] \
    || fail "depois do ipc call weather search Cacau, o weather choose 0 não devolveu \"Cacaulândia, Rondônia, BR\" em 5 s (veio \"$city\"; veja web-fake.log e lucernad.log)"
# A previsão só é buscada com assinante: a aba Clima aberta assina o web.weather.
n=$((n + 1))
ipc dashboard open weather > /dev/null || fail "ipc call dashboard open weather falhou: $(why $?)"
wait_web web.weather "ready 7 dias" || true
row "rede" "previsão em 5 s" "${web:-(sem resposta)}"
[ "$web" = "ready 7 dias" ] || fail "com a aba Clima aberta, o web.weather não chegou a ready com 7 dias em 5 s (veio \"$web\"; veja web-fake.log e lucernad.log)"
sleep 1
alive || fail "o shell caiu com a aba Clima aberta"
shot "$out/shots/$(printf '%02d' "$n")-clima.png" || fail "o grim não capturou a aba Clima: $(why $?)"
ipc panels close > /dev/null || fail "ipc call panels close falhou: $(why $?)"
# A letra só é buscada com assinante: a aba Mídia aberta assina o web.lyrics.
n=$((n + 1))
ipc dashboard open media > /dev/null || fail "ipc call dashboard open media falhou: $(why $?)"
wait_web web.lyrics "found lrclib 4 linhas" || true
row "rede" "letra em 5 s" "${web:-(sem resposta)}"
[ "$web" = "found lrclib 4 linhas" ] || fail "com a aba Mídia aberta, o web.lyrics não chegou a found da lrclib com 4 linhas em 5 s (veio \"$web\"; veja web-fake.log e lucernad.log)"
sleep 1
alive || fail "o shell caiu com a letra na aba Mídia"
shot "$out/shots/$(printf '%02d' "$n")-letra.png" || fail "o grim não capturou a letra: $(why $?)"
ipc panels close > /dev/null || fail "ipc call panels close falhou: $(why $?)"
for source in "/lrclib/api/get?" "/forecast/v1/forecast?" "/geocoding/v1/search?"; do
    grep -qF "\"GET $source" "$out/web-fake.log" \
        || fail "o log do servidor falso não tem nenhum pedido GET $source (veja web-fake.log)"
done
row "rede" "um pedido de cada fonte no servidor falso" "$(grep -c '"GET ' "$out/web-fake.log") pedido(s)"

# Fase "lucernad fora": o daemon para, o shell nota e as abas que leem dele
# mostram o "indisponível" (as capturas desses quatro passos).
stop_group "$lucernad_pid"
lucernad_pid=""
if ! wait_log "lucerna: sem conexão com o lucernad"; then
    row "lucernad fora" "o shell nota em 10 s" "(não notou)"
    fail "o shell não notou a saída do lucernad em 10 s"
fi
row "lucernad fora" "o shell nota em 10 s" "lucerna: sem conexão com o lucernad"
step dashboard dashboard open performance
step dashboard dashboard open overview
step dashboard dashboard open weather
step settings settings open idle

# Repouso: o shell fica parado alguns segundos depois do último passo, para o
# que chega tarde (um Timer, uma resposta assíncrona, o efeito do último
# panels close) cair no log antes do veredito.
sleep 5
alive || fail "o shell caiu no repouso depois do último passo"
ipc cov dump > "$work/hits-smoke.txt" || fail "não consegui ler a cobertura (ipc call cov dump falhou: $(why $?))"
alive || fail "o shell caiu no fim da fumaça"
row "shell vivo depois de 5 s de repouso" "sim" "sim"

# Encerra o shell antes do veredito, pelo PID dele (qs kill --pid, a saída
# limpa do Quickshell), e espera o fim: o log conferido é o final, com o
# encerramento, e é o mesmo que vai para o artefato.
qs kill --pid "$shell_pid" > "$out/kill.log" 2>&1 || true
for _ in $(seq 40); do
    alive || break
    sleep 0.25
done
if alive; then
    row "shell encerrado (qs kill)" "em 10 s, código 0" "(não encerrou)"
    fail "o shell não encerrou em 10 s depois do qs kill --pid $shell_pid"
fi
code=0
wait "$qs_pid" || code=$?
qs_pid=""
clean_log
row "shell encerrado (qs kill)" "em 10 s, código 0" "código $code"
[ "$code" -eq 0 ] || fail "o shell encerrou com código $code depois do qs kill (veja shell.log)"

# A unidade numa cópia separada (nunca na pasta de config do shell que está
# rodando), instrumentada igual (--all), para a cobertura informativa juntar as
# duas. As chaves são caminhos relativos, iguais nas duas cópias. A conferência
# (código, RESULT e SUITE de cada teste) é a mesma do ci/unit.sh.
unit="$work/unit"
copy_repo "$unit" || fail "não consegui copiar o repositório para a cópia da unidade"
python3 "$repo/ci/coverage.py" instrument "$unit" --all > /dev/null || fail "a instrumentação da cópia da unidade falhou (veja acima)"
unit_suites "$unit" || fail "unidade na cópia da fumaça: $UNIT_ERROR"
unit_run "$unit" "$out/unit-smoke.log" > /dev/null || fail "unidade na cópia da fumaça: $UNIT_ERROR"
row "unidade na cópia separada" "failed=0" "$UNIT_RESULT"

# O relatório é informativo (sem --gate): nem ele nem um coverage.md que falte
# derrubam a fumaça.
python3 "$repo/ci/coverage.py" report "$cfg" "$out/unit-smoke.log" "$work/hits-smoke.txt" --md "$out/coverage.md" \
    > "$out/coverage.txt" || echo "aviso: o relatório informativo da cobertura falhou (veja coverage.txt)" >&2
head -n 1 "$out/coverage.txt" 2> /dev/null || true
{
    printf '\n'
    cat "$out/coverage.md" 2> /dev/null || printf '**Cobertura:** o relatório não foi gerado (informativo).\n'
} >> "$summary"

logs_checked=1
python3 "$repo/ci/logcheck.py" "$repo/ci/tolerated.txt" "$out/shell.log" "$out/sway.log" \
    || fail "há avisos ou erros fora do ci/tolerated.txt (listados acima)"
echo "fumaça: ok ($n passos)"
