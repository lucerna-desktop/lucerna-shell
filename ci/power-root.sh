#!/usr/bin/env bash
# Cria a árvore falsa do módulo de energia do lucernad (a raiz do
# LUCERNAD_POWER_ROOT): uma tela integrada de teste em
# <pasta>/sys/class/backlight/lucerna_teste (tipo raw, máximo 1000, valor 500),
# sem conectores DRM nem /dev/i2c-* (nenhum monitor externo). Com a raiz, o
# lucernad lê e grava o brilho só nessa árvore: sem logind, sem DDC, sem o
# uevent do kernel. Usado pela fumaça (ci/smoke.sh) e pelo container do
# dev/test.sh (dev/hyprland.lua), onde o D-Bus do sistema e o /sys do host
# estão à vista: sem a raiz falsa, um ajuste mudaria o brilho de verdade.
# Cria também o power-profiles-daemon falso (<pasta>/power-profiles, com o
# perfil `balanced` em `active`) e o GameMode falso (<pasta>/gamemode), que o
# lucernad usa no lugar do D-Bus com a raiz definida (os perfis da central e o
# modo jogo); sem as pastas, os dois ficam indisponíveis.
# Recria a tela, os perfis e o GameMode do zero a cada chamada.
#   ci/power-root.sh <pasta>
set -euo pipefail

root=${1:?uso: ci/power-root.sh <pasta>}
case "$root" in
    /*) root=$(realpath -m -- "$root") ;;
    *)
        echo "ci/power-root.sh: a pasta precisa ser um caminho absoluto, veio '$root'" >&2
        exit 64
        ;;
esac
# Por componente, como o lucernad: /sys, /dev e /proc e o que fica dentro.
case "$root" in
    / | /sys | /sys/* | /dev | /dev/* | /proc | /proc/*)
        echo "ci/power-root.sh: a pasta não pode ser a raiz nem ficar no /sys, no /dev ou no /proc, veio '$root'" >&2
        exit 64
        ;;
esac

screen="$root/sys/class/backlight/lucerna_teste"
rm -rf "$screen"
mkdir -p "$screen" "$root/dev"
printf 'raw\n' > "$screen/type"
printf '1000\n' > "$screen/max_brightness"
printf '500\n' > "$screen/brightness"
printf '500\n' > "$screen/actual_brightness"
rm -rf "$root/power-profiles" "$root/gamemode"
mkdir -p "$root/power-profiles" "$root/gamemode"
printf 'balanced\n' > "$root/power-profiles/active"
