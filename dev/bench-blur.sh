#!/usr/bin/env bash
# Compara o custo dos níveis do desfoque na sua sessão Hyprland, com o Lucerna
# rodando (qs -c lucerna). Para cada nível (full, performance, off), troca pelo
# IPC (`blur set`), abre o painel superior, espera 2 s e mede por N segundos o
# uso de CPU do Hyprland e do qs (pelo /proc) e, se houver como ler, o da GPU
# (intel_gpu_top, nvidia-smi ou o gpu_busy_percent da AMD). No fim (e no
# Ctrl+C), devolve o nível que estava antes e fecha o painel. Não mexe em
# nada além do nível do desfoque, que é do shell: nenhum hyprctl keyword/eval.
# Olhe a fluidez a olho durante as fases.
#   dev/bench-blur.sh [segundos]   (padrão 20 por nível)
set -euo pipefail

secs=${1:-20}
[[ $secs =~ ^[0-9]+$ ]] && [ "$secs" -gt 0 ] || { echo "uso: dev/bench-blur.sh [segundos]" >&2; exit 2; }
[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || { echo "ERRO: rode dentro da sessão Hyprland (sem HYPRLAND_INSTANCE_SIGNATURE)" >&2; exit 1; }

ipc() { qs -c lucerna ipc call "$@"; }
# A última linha: o qs pode avisar antes (locale) na mesma saída.
before=$(ipc blur get 2> /dev/null | tail -n1)
[ -n "$before" ] || { echo "ERRO: o Lucerna (qs -c lucerna) não respondeu ao IPC" >&2; exit 1; }

hypr_pid=$(pgrep -xo Hyprland || pgrep -xo Hyprland-bin || true)
qs_pid=$(pgrep -fo 'qs -c lucerna$' || pgrep -xo qs || true)
[ -n "$hypr_pid" ] || { echo "ERRO: não achei o processo do Hyprland" >&2; exit 1; }
[ -n "$qs_pid" ] || { echo "ERRO: não achei o processo do qs" >&2; exit 1; }
hz=$(getconf CLK_TCK)

# shellcheck disable=SC2329 # chamada pelo trap
restore() {
    ipc panels close > /dev/null 2>&1 || true
    ipc blur set "$before" > /dev/null 2>&1 || true
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

# gpu_sample <segundos>: uso médio da GPU no intervalo, em %, ou "-".
gpu_sample() {
    local s=$1 busy f total=0 n=0
    if command -v intel_gpu_top > /dev/null; then
        timeout $((s + 2)) intel_gpu_top -J -s 1000 2> /dev/null | python3 -c '
import json, sys
text = sys.stdin.read().strip().rstrip(",")
if not text.startswith("["):
    text = "[" + text + "]"
try:
    data = json.loads(text if text.endswith("]") else text + "]")
except ValueError:
    print("-"); sys.exit()
vals = [max(e.get("busy", 0) for e in d.get("engines", {}).values()) for d in data if d.get("engines")]
print(f"{sum(vals) / len(vals):.1f}" if vals else "-")' || echo "-"
        return
    fi
    if command -v nvidia-smi > /dev/null; then
        for _ in $(seq "$s"); do
            busy=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2> /dev/null | head -n1) || break
            total=$((total + busy)) n=$((n + 1))
            sleep 1
        done
    else
        f=$(compgen -G '/sys/class/drm/card*/device/gpu_busy_percent' | head -n1 || true)
        [ -n "$f" ] || { sleep "$s"; echo "-"; return; }
        for _ in $(seq "$s"); do
            total=$((total + $(< "$f"))) n=$((n + 1))
            sleep 1
        done
    fi
    if [ "$n" -gt 0 ]; then echo "$((total / n))"; else echo "-"; fi
}

printf '%-12s %10s %10s %8s\n' nível "Hyprland %" "qs %" "GPU %"
for mode in full performance off; do
    ipc blur set "$mode" > /dev/null
    ipc panels open dashboard > /dev/null
    sleep 2
    h0=$(ticks "$hypr_pid") q0=$(ticks "$qs_pid") t0=$(date +%s%N)
    gpu=$(gpu_sample "$secs")
    h1=$(ticks "$hypr_pid") q1=$(ticks "$qs_pid") t1=$(date +%s%N)
    ipc panels close > /dev/null
    ms=$(((t1 - t0) / 1000000))
    printf '%-12s %10s %10s %8s\n' "$mode" \
        "$(awk -v d=$((h1 - h0)) -v hz="$hz" -v ms="$ms" 'BEGIN { printf "%.1f", d / hz / (ms / 1000) * 100 }')" \
        "$(awk -v d=$((q1 - q0)) -v hz="$hz" -v ms="$ms" 'BEGIN { printf "%.1f", d / hz / (ms / 1000) * 100 }')" \
        "$gpu"
    sleep 1
done
echo "nível de volta: $before"
