#!/usr/bin/env bash
# Mede o custo do modo jogo na sua sessão Hyprland, com o Lucerna (qs -c
# lucerna) e o lucernad rodando. Guarda o `hyprctl -j getoption` das cinco
# opções que o modo jogo mexe; abre um kitty em tela cheia com um laço que
# escreve a hora a cada 16 ms; mede por N segundos o uso de CPU do Hyprland, do
# qs e do lucernad (pelo /proc) com o modo desligado e depois ligado
# (`lucernad jogo ligar`/`desligar`); imprime a tabela. No fim (e no Ctrl+C),
# desliga o modo, fecha o kitty e compara as cinco opções com as guardadas:
# qualquer diferença sai com 1 e diz qual. Rode-o no container de teste
# (dev/test.sh run 'bash ~/.config/quickshell/lucerna/dev/bench-game.sh') ou
# numa sessão Hyprland de verdade. Nunca mexe no perfil de energia de
# verdade: só roda com o lucernad numa raiz de teste (LUCERNAD_POWER_ROOT no
# ambiente dele, como no container), onde o perfil e o GameMode são falsos em
# arquivos. Numa máquina real, suba o lucernad assim antes (veja o dev/test.sh).
#   dev/bench-game.sh [segundos]   (padrão 20 por fase)
set -euo pipefail

secs=${1:-20}
[[ $secs =~ ^[0-9]+$ ]] && [ "$secs" -gt 0 ] || { echo "uso: dev/bench-game.sh [segundos]" >&2; exit 2; }
[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || { echo "ERRO: rode dentro da sessão Hyprland (sem HYPRLAND_INSTANCE_SIGNATURE)" >&2; exit 1; }
command -v kitty > /dev/null || { echo "ERRO: o kitty não está instalado" >&2; exit 1; }
lucernad jogo > /dev/null 2>&1 || { echo "ERRO: o lucernad não respondeu (lucernad jogo)" >&2; exit 1; }

# O lucernad numa raiz de teste (o LUCERNAD_POWER_ROOT no ambiente do
# processo): o perfil de energia e o GameMode são os falsos dela.
lucernad_root=""
for pid in $(pgrep -x lucernad || true); do
    lucernad_root=$(tr '\0' '\n' < "/proc/$pid/environ" 2> /dev/null | sed -n 's/^LUCERNAD_POWER_ROOT=//p' | head -n1)
    [ -n "$lucernad_root" ] && break
done
if [ -z "$lucernad_root" ]; then
    echo "ERRO: o lucernad não roda com o LUCERNAD_POWER_ROOT (a raiz de teste): a medição seguraria o perfil de energia de verdade" >&2
    exit 1
fi

options=(decoration:blur:enabled decoration:shadow:enabled animations:enabled misc:vrr general:allow_tearing)

# snapshot: as cinco opções, uma linha cada ("nome valor").
snapshot() {
    local o
    for o in "${options[@]}"; do
        printf '%s %s\n' "$o" "$(hyprctl -j getoption "$o" | python3 -c '
import json, sys
v = json.load(sys.stdin)
print(next((v[k] for k in ("bool", "int", "float", "str") if k in v), "?"))')"
    done
}
before=$(snapshot)

hypr_pid=$(pgrep -xo Hyprland || pgrep -xo Hyprland-bin || true)
qs_pid=$(pgrep -fo 'qs -c lucerna$' || pgrep -xo qs || true)
daemon_pid=$(pgrep -xo lucernad || true)
[ -n "$hypr_pid" ] || { echo "ERRO: não achei o processo do Hyprland" >&2; exit 1; }
[ -n "$qs_pid" ] || { echo "ERRO: não achei o processo do qs" >&2; exit 1; }
[ -n "$daemon_pid" ] || { echo "ERRO: não achei o processo do lucernad" >&2; exit 1; }
hz=$(getconf CLK_TCK)

# O kitty da medição, com uma classe própria (só ele é fechado no fim).
class=lucerna-bench-game
kitty --class "$class" -o confirm_os_window_close=0 sh -c 'while :; do date +%T.%N; sleep 0.016; done' > /dev/null 2>&1 &
kitty_pid=$!

status=0
# shellcheck disable=SC2329 # chamada pelo trap
finish() {
    lucernad jogo desligar > /dev/null 2>&1 || true
    kill "$kitty_pid" 2> /dev/null || true
    wait "$kitty_pid" 2> /dev/null || true
    # A restauração do lucernad é assíncrona: até 5 s para as opções voltarem.
    local after=""
    for _ in $(seq 25); do
        after=$(snapshot)
        [ "$after" = "$before" ] && break
        sleep 0.2
    done
    if [ "$after" = "$before" ]; then
        echo "opções de volta: iguais às de antes"
    else
        echo "ERRO: as opções não voltaram ao que eram:" >&2
        diff <(echo "$before") <(echo "$after") >&2 || true
        status=1
    fi
    exit "$status"
}
trap finish EXIT
trap 'status=130; exit 130' INT TERM

# Espera a janela do kitty e a põe em tela cheia de verdade.
for _ in $(seq 50); do
    hyprctl -j clients | grep -q "\"class\": \"$class\"" && break
    sleep 0.2
done
hyprctl dispatch "hl.dsp.focus({ window = \"class:$class\" })" > /dev/null 2>&1 || true
hyprctl dispatch 'hl.dsp.window.fullscreen()' > /dev/null 2>&1 || true

# ticks <pid>: utime + stime do processo, em ticks do relógio.
ticks() {
    local stat
    stat=$(< "/proc/$1/stat")
    stat=${stat##*) }
    # shellcheck disable=SC2086 # separar os campos é a intenção
    set -- $stat
    echo $((${12} + ${13}))
}

pct() {
    awk -v d="$1" -v hz="$hz" -v ms="$2" 'BEGIN { printf "%.1f", d / hz / (ms / 1000) * 100 }'
}

measure() {
    local h0 q0 l0 t0 h1 q1 l1 t1 ms
    h0=$(ticks "$hypr_pid") q0=$(ticks "$qs_pid") l0=$(ticks "$daemon_pid") t0=$(date +%s%N)
    sleep "$secs"
    h1=$(ticks "$hypr_pid") q1=$(ticks "$qs_pid") l1=$(ticks "$daemon_pid") t1=$(date +%s%N)
    ms=$(((t1 - t0) / 1000000))
    printf '%-10s %12s %8s %12s\n' "$1" "$(pct $((h1 - h0)) "$ms")" "$(pct $((q1 - q0)) "$ms")" "$(pct $((l1 - l0)) "$ms")"
}

printf '%-10s %12s %8s %12s\n' modo "Hyprland %" "qs %" "lucernad %"
lucernad jogo desligar > /dev/null
sleep 4
measure desligado
lucernad jogo ligar > /dev/null
sleep 2
measure ligado
