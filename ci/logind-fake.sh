#!/usr/bin/env bash
# Sobe e derruba o logind falso (ci/logind-fake.py) num barramento D-Bus
# privado: um dbus-daemon --session em <pasta>/lucerna-fake-system, nunca o
# barramento do sistema. O container do dev/test.sh monta o barramento do
# sistema do host: um inibidor, um `gdbus monitor` ou um sinal ali seria no
# logind de verdade. Quem fala com o falso usa o endereço que o start imprime
# (no container, LUCERNA_LOGIND_BUS; para o systemd-inhibit e outros clientes
# do sd-bus, DBUS_SYSTEM_BUS_ADDRESS só no ambiente deles).
#   ci/logind-fake.sh start <pasta>   sobe os dois, espera o nome
#                                     org.freedesktop.login1 (até 10 s) e
#                                     imprime o endereço; com o falso de pé,
#                                     só imprime o endereço
#   ci/logind-fake.sh stop <pasta>    derruba os dois
# Os pids ficam em <pasta>/lucerna-fake-system.pids e o log do falso (e do
# dbus-daemon) em <pasta>/lucerna-fake-logind.log.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
usage="uso: ci/logind-fake.sh start|stop <pasta>"
cmd=${1:?$usage}
dir=${2:?$usage}
case "$dir" in
    /*) dir=$(realpath -m -- "$dir") ;;
    *)
        echo "ci/logind-fake.sh: a pasta precisa ser um caminho absoluto, veio '$dir'" >&2
        exit 64
        ;;
esac
socket="$dir/lucerna-fake-system"
address="unix:path=$socket"
pids="$dir/lucerna-fake-system.pids"
logfile="$dir/lucerna-fake-logind.log"

# O nome do logind tem dono no barramento privado?
owned() {
    [ -S "$socket" ] &&
        gdbus call --address "$address" --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus \
            --method org.freedesktop.DBus.NameHasOwner org.freedesktop.login1 2> /dev/null | grep -q true
}

stop() {
    local pid
    if [ -f "$pids" ]; then
        while read -r pid; do
            [ -z "$pid" ] || kill "$pid" 2> /dev/null || true
        done < "$pids"
        rm -f "$pids"
    fi
    rm -f "$socket"
}

case "$cmd" in
    start)
        if owned; then
            echo "$address"
            exit 0
        fi
        # Sobra de um falso que caiu pela metade: começa do zero.
        stop
        mkdir -p "$dir"
        # O caminho do socket cabe em 107 bytes (sun_path); senão o dbus-daemon
        # recusa ("Socket name too long", no log).
        dbus_pid=$(dbus-daemon --session --address="$address" --fork --print-pid 2>> "$logfile") || {
            echo "ci/logind-fake.sh: o dbus-daemon privado não subiu em $socket (veja $logfile)" >&2
            exit 1
        }
        echo "$dbus_pid" > "$pids"
        setsid python3 -I "$here/logind-fake.py" --address "$address" >> "$logfile" 2>&1 < /dev/null &
        echo "$!" >> "$pids"
        for _ in $(seq 50); do
            if owned; then
                echo "$address"
                exit 0
            fi
            sleep 0.2
        done
        echo "ci/logind-fake.sh: o logind falso não pegou o nome em 10 s (veja $logfile)" >&2
        stop
        exit 1
        ;;
    stop) stop ;;
    *)
        echo "$usage" >&2
        exit 64
        ;;
esac
