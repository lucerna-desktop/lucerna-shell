#!/usr/bin/env bash
# Compila os shaders do shell com o qsb (pacote qt6-shadertools):
#   themes/shaders/*.frag       os wallpapers animados; cada um recebe antes o
#                               trecho comum (uniforms e funções de ruído);
#   core/widgets/shaders/*.frag os dos componentes do core (a forma da moldura),
#                               como estão.
#   dev/shaders.sh          grava cada .qsb ao lado do .frag
#   dev/shaders.sh PASTA    grava em PASTA/<a mesma pasta do repositório> (o
#                           ci/rules.py compara com os do repositório)
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
out="${1:-}"
if [ -n "$out" ]; then
    mkdir -p "$out"
    out="$(cd "$out" && pwd)"
fi
QSB=$(command -v qsb || echo /usr/lib/qt6/bin/qsb)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# compile PASTA_DO_REPO PREFIXO: cada .frag da pasta, com o PREFIXO (um arquivo
# da mesma pasta, ou nada) antes do corpo.
compile() {
    local dir=$1 prefix=$2 dest frag name
    if [ -n "$out" ]; then
        dest="$out/$dir"
    else
        dest="$repo/$dir"
    fi
    mkdir -p "$dest"
    for frag in "$repo/$dir"/*.frag; do
        name=$(basename "$frag" .frag)
        if [ -n "$prefix" ]; then
            { echo "#version 440"; cat "$repo/$dir/$prefix"; cat "$frag"; } > "$tmp/$name.frag"
        else
            cp "$frag" "$tmp/$name.frag"
        fi
        # Só GLSL de desktop e SPIR-V (Vulkan): a variante GLSL ES sai com mediump,
        # e GPUs que calculam mediump em 16 bits desenham os degradês em faixas.
        "$QSB" --glsl "150,330" -O -o "$dest/$name.qsb" "$tmp/$name.frag"
        echo "$dir/$name.qsb"
    done
}

compile themes/shaders common.glsl
compile core/widgets/shaders ""
