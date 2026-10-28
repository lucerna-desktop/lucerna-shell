#!/usr/bin/env bash
# Mede a fluidez e o custo dos painéis da moldura na sua sessão Hyprland, com o
# Lucerna (qs -c lucerna) rodando. Reinicia o qs com o log de tempo do render
# loop do Qt (qt.scenegraph.time.renderloop) em $BENCH_OUT/qs.log e roda os
# casos, nesta ordem:
#   painel-superior  N ciclos de `panels open dashboard` / `panels close`
#   central          N ciclos de `central open ""` / `panels close`
#   osd              N ciclos de `brightness up` / `brightness down` (2,5 s cada)
#   papel            o papel de parede animado e o painel superior aberto, S s
#   janela           um kitty que escreve a hora a cada 16 ms e a central aberta, S s
#   parado           nada aberto, S s
#   parado-painel    o painel superior aberto e parado, S s (depois de 2 s)
# Nos casos de ciclo, cada abertura e cada fechamento é uma fatia: começa logo
# antes do IPC (para pegar o 1º quadro) e termina 0,6 s depois dele. Nos casos
# contínuos, a medição começa 2 s depois de abrir. Fora do caso `papel`, o papel
# de parede fica estático (o animado redesenha sempre e esconderia o resto).
# A CPU do qs e do Hyprland vem do /proc, por caso. Depois, se houver o
# wf-recorder e o ffprobe, os três casos de ciclo rodam de novo gravando a tela
# (guiado por dano, sem -D) em $BENCH_OUT/<caso>.mkv, para a coluna `FPS tela`:
# numa passada separada, porque gravar pesa no Hyprland e mudaria a CPU e os
# quadros do qs. O dev/bench-paineis.py lê o log e os vídeos e imprime a tabela.
# No fim (e no Ctrl+C), fecha os painéis, devolve o desfoque e o modo do papel
# de parede, fecha o kitty e sobe o qs normal. Nenhum hyprctl keyword/eval/reload.
#   dev/bench-paineis.sh [ciclos] [segundos]   (padrão 10 e 10)
# No container de teste:
#   dev/test.sh run 'bash ~/.config/quickshell/lucerna/dev/bench-paineis.sh 10 10'
# BENCH_OUT: a pasta da saída (padrão /tmp/lucerna-bench).
# BENCH_REC=1: só grava os três casos de ciclo em $BENCH_OUT/<caso>.mkv, sem
# medir nem reiniciar o qs (para as tiras do dev/tira.sh).
set -euo pipefail

cycles=${1:-10}
secs=${2:-10}
usage="uso: dev/bench-paineis.sh [ciclos] [segundos]"
[[ $cycles =~ ^[0-9]+$ ]] && [ "$cycles" -gt 0 ] || { echo "$usage" >&2; exit 2; }
[[ $secs =~ ^[0-9]+$ ]] && [ "$secs" -gt 0 ] || { echo "$usage" >&2; exit 2; }
[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || { echo "ERRO: rode dentro da sessão Hyprland (sem HYPRLAND_INSTANCE_SIGNATURE)" >&2; exit 1; }

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
out=${BENCH_OUT:-/tmp/lucerna-bench}
rec_only=${BENCH_REC:-0}
mkdir -p "$out"
log=$out/qs.log
marks=$out/marks.tsv

# A última linha: o qs avisa antes (locale) na mesma saída.
ipc() { qs -c lucerna ipc call "$@" 2> /dev/null | tail -n1; }
blur_before=$(ipc blur get || true)
wall_before=$(ipc wallpaper get || true)
[[ $blur_before =~ ^(full|performance|off)$ ]] && [[ $wall_before =~ ^(auto|animated|static)$ ]] \
    || { echo "ERRO: o Lucerna (qs -c lucerna) não respondeu ao IPC" >&2; exit 1; }

hypr_pid=$(pgrep -xo Hyprland || pgrep -xo Hyprland-bin || true)
[ -n "$hypr_pid" ] || { echo "ERRO: não achei o processo do Hyprland" >&2; exit 1; }
hz=$(getconf CLK_TCK)
output=$(hyprctl -j monitors | python3 -c 'import json, sys; m = json.load(sys.stdin)[0]; print(m["name"], "%dx%d@%.0f" % (m["width"], m["height"], m["refreshRate"]))')
read -r output_name output_mode <<< "$output"

can_record=0
if command -v wf-recorder > /dev/null && command -v ffprobe > /dev/null; then
    can_record=1
fi
[ "$rec_only" != 1 ] || [ "$can_record" = 1 ] || { echo "ERRO: BENCH_REC=1 precisa do wf-recorder e do ffprobe" >&2; exit 1; }

class=lucerna-bench-paineis
kitty_pid=""
rec_pid=""
osd_up=0
restarted=0

# shellcheck disable=SC2329 # chamada pelo trap
restore() {
    if [ -n "$rec_pid" ]; then
        kill -INT "$rec_pid" 2> /dev/null || true
        wait "$rec_pid" 2> /dev/null || true
    fi
    if [ -n "$kitty_pid" ]; then
        kill "$kitty_pid" 2> /dev/null || true
        wait "$kitty_pid" 2> /dev/null || true
    fi
    [ "$osd_up" = 0 ] || ipc brightness down > /dev/null || true
    ipc panels close > /dev/null || true
    ipc blur set "$blur_before" > /dev/null || true
    ipc wallpaper mode "$wall_before" > /dev/null || true
    if [ "$restarted" = 1 ]; then
        # O config é gravado na hora, mas dá um respiro antes de matar o qs.
        sleep 0.5
        pkill -x qs || true
        sleep 0.5
        setsid -f qs -c lucerna > /dev/null 2>&1 < /dev/null
        echo "qs normal de volta"
    fi
}
trap restore EXIT
trap 'exit 130' INT TERM

# ticks <pid>: utime + stime do processo, em ticks do relógio.
ticks() {
    local stat
    stat=$(< "/proc/$1/stat")
    stat=${stat##*) }
    # shellcheck disable=SC2086 # separar os campos é a intenção
    set -- $stat
    echo $((${12} + ${13}))
}

lines() { wc -l < "$log"; }
now() { date +%s%N; }

# A CPU de um caso: guardada no começo, anotada no fim.
cpu_start() {
    c_h0=$(ticks "$hypr_pid") c_q0=$(ticks "$qs_pid") c_t0=$(now)
}
cpu_end() {
    local h1 q1 t1
    h1=$(ticks "$hypr_pid") q1=$(ticks "$qs_pid") t1=$(now)
    printf 'cpu\t%s\t%s\t%s\t%s\t%s\n' "$1" $((q1 - c_q0)) $((h1 - c_h0)) "$hz" $(((t1 - c_t0) / 1000000)) >> "$marks"
}

# slice <caso> IPC...: uma fatia de 0,6 s com o IPC. Medindo, anota as linhas
# do log e a duração; gravando, o começo relativo ao início do vídeo.
slice() {
    local name=$1 l0 t0 t1
    shift
    if [ "$mode" = measure ]; then l0=$(lines); fi
    t0=$(now)
    ipc "$@" > /dev/null
    sleep 0.6
    t1=$(now)
    if [ "$mode" = measure ]; then
        printf 'slice\t%s\t%s\t%s\t%s\n' "$name" "$l0" "$(lines)" $(((t1 - t0) / 1000000)) >> "$marks"
    else
        printf 'vslice\t%s\t%s\t%s\n' "$name" $(((t0 - rec_t0) / 1000000)) $(((t1 - t0) / 1000000)) >> "$marks"
    fi
}

rec_start() {
    rm -f "$out/$1.mkv"
    rec_t0=$(now)
    wf-recorder -o "$output_name" -f "$out/$1.mkv" > "$out/$1.rec.log" 2>&1 &
    rec_pid=$!
    sleep 1
    printf 'video\t%s\t%s\n' "$1" "$out/$1.mkv" >> "$marks"
}

# Com a tela parada, o wf-recorder fecha o vídeo no SIGINT mas fica esperando
# o próximo quadro para sair (até o relógio da barra mudar, ~1 min): com o
# vídeo fechado (o resumo do libx264 no log dele), pode ser morto.
rec_stop() {
    local log=$out/$1.rec.log
    sleep 0.5
    kill -INT "$rec_pid" 2> /dev/null || true
    for _ in $(seq 50); do
        kill -0 "$rec_pid" 2> /dev/null || break
        grep -q 'kb/s:' "$log" && { sleep 0.5; kill -KILL "$rec_pid" 2> /dev/null || true; break; }
        sleep 0.1
    done
    wait "$rec_pid" 2> /dev/null || true
    rec_pid=""
}

# Os três casos de ciclo, medindo (mode=measure) ou gravando (mode=record).
case_panel() {
    for _ in $(seq "$cycles"); do
        slice painel-superior panels open dashboard
        sleep 0.6
        slice painel-superior panels close
        sleep 0.6
    done
}

case_central() {
    for _ in $(seq "$cycles"); do
        slice central central open ""
        sleep 0.6
        slice central panels close
        sleep 0.6
    done
}

case_osd() {
    for _ in $(seq "$cycles"); do
        osd_up=1
        slice osd brightness up
        sleep 1.9
        osd_up=0
        slice osd brightness down
        sleep 1.9
    done
}

has_screen() { [ -n "$(ipc brightness list)" ]; }

cycle_cases() {
    local name
    for name in painel-superior central osd; do
        if [ "$name" = osd ] && ! has_screen; then
            [ "$mode" = record ] || printf 'skip\tosd\n' >> "$marks"
            continue
        fi
        if [ "$mode" = record ]; then rec_start "$name"; else cpu_start; fi
        case "$name" in
            painel-superior) case_panel ;;
            central) case_central ;;
            osd) case_osd ;;
        esac
        if [ "$mode" = record ]; then rec_stop "$name"; else cpu_end "$name"; fi
        sleep 1
    done
}

# continuous <caso>: mede S s como uma fatia só.
continuous() {
    local l0 t0 t1
    cpu_start
    l0=$(lines) t0=$(now)
    sleep "$secs"
    t1=$(now)
    printf 'slice\t%s\t%s\t%s\t%s\n' "$1" "$l0" "$(lines)" $(((t1 - t0) / 1000000)) >> "$marks"
    cpu_end "$1"
}

rss() { awk '/^VmRSS:/ { print $2 }' "/proc/$qs_pid/status"; }

ipc panels close > /dev/null
ipc wallpaper mode static > /dev/null

if [ "$rec_only" = 1 ]; then
    : > "$marks"
    mode=record
    cycle_cases
    printf 'vídeo: %s\n' "$out"/*.mkv
    exit 0
fi

# O qs com o log do render loop.
pkill -x qs || true
sleep 0.5
restarted=1
QT_LOGGING_RULES='qt.scenegraph.time.renderloop.debug=true' setsid -f qs -c lucerna > "$log" 2>&1 < /dev/null
# Sem instância, o `ipc call` também escreve na saída: pronto é responder o
# mesmo desfoque de antes (o `panels get` sai vazio com tudo fechado).
ready() { [ "$(ipc blur get || true)" = "$blur_before" ]; }
for _ in $(seq 120); do
    ready && break
    sleep 0.5
done
ready || { echo "ERRO: o qs com o log não respondeu ao IPC em 60 s" >&2; exit 1; }
qs_pid=$(pgrep -fo 'qs -c lucerna$' || pgrep -xo qs || true)
[ -n "$qs_pid" ] || { echo "ERRO: não achei o processo do qs" >&2; exit 1; }
ipc wallpaper mode static > /dev/null
sleep 3

{
    printf 'info\tblur\t%s\n' "$blur_before"
    printf 'info\tpapel de parede\t%s (estático fora do caso papel)\n' "$wall_before"
    printf 'info\tsaída\t%s %s\n' "$output_name" "$output_mode"
    printf 'info\tciclos\t%s\n' "$cycles"
    printf 'info\tsegundos\t%s\n' "$secs"
    printf 'rss\tantes\t%s\n' "$(rss)"
} > "$marks"

mode=measure
cycle_cases

ipc wallpaper mode animated > /dev/null
ipc panels open dashboard > /dev/null
sleep 2
continuous papel
ipc panels close > /dev/null
ipc wallpaper mode static > /dev/null
sleep 1

kitty --class "$class" -o confirm_os_window_close=0 sh -c 'while :; do date +%T.%N; sleep 0.016; done' > /dev/null 2>&1 &
kitty_pid=$!
for _ in $(seq 50); do
    hyprctl -j clients | grep -q "\"class\": \"$class\"" && break
    sleep 0.2
done
ipc central open "" > /dev/null
sleep 2
continuous janela
ipc panels close > /dev/null
kill "$kitty_pid" 2> /dev/null || true
wait "$kitty_pid" 2> /dev/null || true
kitty_pid=""
sleep 2

continuous parado

ipc panels open dashboard > /dev/null
sleep 2
continuous parado-painel
ipc panels close > /dev/null
sleep 1

printf 'rss\tdepois\t%s\n' "$(rss)" >> "$marks"

if [ "$can_record" = 1 ]; then
    mode=record
    cycle_cases
fi

python3 -I "$here/bench-paineis.py" report "$marks" "$log"
