#!/usr/bin/env bash
# A tira de quadros de um trecho de vídeo: cada quadro gravado, reduzido a 480
# px de largura e numerado, lado a lado numa imagem só (o ffprobe conta os
# quadros do trecho; o filtro tile do ffmpeg monta a grade). Para conferir o
# movimento dos painéis quadro a quadro, sobre os vídeos do
# `BENCH_REC=1 dev/bench-paineis.sh`. Roda no host, sobre o vídeo copiado:
#   docker cp lucerna-polish:/tmp/lucerna-bench/painel-superior.mkv /tmp/
#   dev/tira.sh /tmp/painel-superior.mkv /tmp/tira.png 2.0 0.6
#   dev/tira.sh VIDEO SAIDA.png INÍCIO DURAÇÃO [colunas]   (segundos; padrão 8 colunas)
set -euo pipefail

usage="uso: dev/tira.sh VIDEO SAIDA.png INÍCIO DURAÇÃO [colunas]"
[ $# -ge 4 ] || { echo "$usage" >&2; exit 2; }
video=$1 out=$2 start=$3 dur=$4 cols=${5:-8}
num='^[0-9]+([.][0-9]+)?$'
[[ $start =~ $num ]] && [[ $dur =~ $num ]] && [[ $cols =~ ^[1-9][0-9]*$ ]] || { echo "$usage" >&2; exit 2; }
[ -f "$video" ] || { echo "ERRO: não achei o vídeo $video" >&2; exit 1; }
for tool in ffprobe ffmpeg; do
    command -v "$tool" > /dev/null || { echo "ERRO: precisa do $tool" >&2; exit 1; }
done

# Os quadros do trecho pelos instantes de todos os pacotes: o -read_intervals
# começa do quadro-chave anterior (num vídeo guiado por dano, o do início).
n=$(ffprobe -v error -select_streams v -show_entries packet=pts_time -of csv=p=0 "$video" \
    | awk -F, -v a="$start" -v d="$dur" '$1 != "" && $1 != "N/A" && $1 + 0 >= a + 0 && $1 + 0 < a + d { n++ } END { print n + 0 }')
[[ $n =~ ^[0-9]+$ ]] && [ "$n" -gt 0 ] || { echo "ERRO: nenhum quadro em $start s + $dur s" >&2; exit 1; }
rows=$(((n + cols - 1) / cols))
ffmpeg -v error -y -ss "$start" -t "$dur" -i "$video" \
    -vf "scale=480:-1,drawtext=text='%{n}':x=8:y=8:fontsize=22:fontcolor=yellow:box=1:boxcolor=black@0.6,tile=${cols}x${rows}:padding=4" \
    -frames:v 1 "$out"
echo "$out: $n quadros, ${cols}x$rows"
