#!/usr/bin/env bash
# Sobe o Hyprland aninhado com o Lucerna montado em ~/.config/quickshell/lucerna.
#   dev/run.sh           constrói a imagem (se preciso) e abre a janela
#   dev/run.sh --build   força reconstruir a imagem
#   dev/run.sh shell     abre um bash no container em execução
#   dev/run.sh log       segue o log do Quickshell
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
image=lucerna-dev
name=lucerna-dev

case "${1:-}" in
    shell) exec docker exec -it "$name" bash ;;
    log)   exec docker exec -it "$name" sh -c 'tail -F "$XDG_RUNTIME_DIR"/quickshell/by-id/*/log.qslog 2>/dev/null || qs -c lucerna log -f' ;;
esac

: "${WAYLAND_DISPLAY:?precisa de uma sessão Wayland no host}"
runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

# A imagem é refeita quando falta ou quando o lucernad dela é de outra revisão.
rev=$(cat "$repo/dev/lucernad.rev")
if [[ "${1:-}" == --build ]] || ! docker image inspect "$image" &>/dev/null \
    || [[ "$(docker image inspect -f '{{ index .Config.Labels "lucernad.rev" }}' "$image")" != "$rev" ]]; then
    docker build --build-arg UID="$(id -u)" --build-arg GID="$(id -g)" --build-arg LUCERNAD_REV="$rev" -t "$image" "$repo/dev"
fi

# Só a GPU Intel é repassada: o container não tem os drivers da NVIDIA.
intel_render="$(readlink -f /dev/dri/by-path/pci-0000:00:02.0-render)"
intel_card="$(readlink -f /dev/dri/by-path/pci-0000:00:02.0-card)"

# PipeWire e D-Bus do sistema vêm do host, para volume, bateria e rede reais.
# LUCERNA_DEV=1 faz o shell só simular suspender/reiniciar/desligar: com o
# D-Bus do sistema montado, essas ações chegariam ao host.
extra=()
[[ -S "$runtime/pipewire-0" ]] && extra+=(-v "$runtime/pipewire-0:/run/user/1000/pipewire-0")
[[ -S /run/dbus/system_bus_socket ]] && extra+=(-v /run/dbus/system_bus_socket:/run/dbus/system_bus_socket)

exec docker run --rm -it \
    --name "$name" \
    --user "$(id -u):$(id -g)" \
    --device "$intel_render" --device "$intel_card" \
    -e WAYLAND_DISPLAY=wayland-host \
    -e LUCERNA_DEV=1 \
    -v /etc/localtime:/etc/localtime:ro \
    -v "$runtime/$WAYLAND_DISPLAY:/run/user/1000/wayland-host" \
    -v "$repo:/home/dev/.config/quickshell/lucerna" \
    -v "$repo/dev/hyprland.lua:/home/dev/.config/hypr/hyprland.lua:ro" \
    "${extra[@]}" \
    "$image"
