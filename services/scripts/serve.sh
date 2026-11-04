#!/bin/sh
# Sobe o serviço de um app do Lucerna (`<programa> serve`), quando ninguém
# atende no socket dele: o passo 2 de "Serviço sem systemd" do spec do
# protocolo (lucerna-sdk), o mesmo do ServeCommand::spawn do lucerna-ipc.
# Cria a pasta do log, recomeça o log quando ele passa de 1 MiB (o LOG_MAX do
# SDK), roda na pasta / com o stdin em /dev/null e o stdout e o stderr
# acrescentados ao log. Quem chama (services/lucerna/ServeLauncher.qml) o roda
# solto, pelo Quickshell.execDetached, que já o põe numa sessão própria.
#   services/scripts/serve.sh <programa> <log>
set -u

program=${1:?uso: serve.sh <programa> <log>}
log=${2:?uso: serve.sh <programa> <log>}

case $log in
*/*) mkdir -p -- "${log%/*}" || exit 1 ;;
esac
if [ -f "$log" ] && [ "$(wc -c < "$log")" -gt 1048576 ]; then
    : > "$log"
fi
cd / || exit 1
exec "$program" serve < /dev/null >> "$log" 2>&1
