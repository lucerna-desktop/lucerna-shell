#!/bin/sh
# Grava os arquivos do modo "Escala pelos apps" (services/AppsScale.qml).
#   apps-scale-write.sh <config_home> <fresh|apply|restore> <cópias> [<nome> <w|rm> <texto>]...
# Os nomes são relativos à <config_home>. Em "fresh" (a primeira aplicação,
# sem o scale-backup.json), cada nome das <cópias> (um por linha) que existe
# ganha um <nome>.lucerna-bak: o estado de antes do modo. Uma cópia que já
# existe nunca é sobrescrita (com o JSON perdido no meio do modo, a cópia nova
# seria a versão do modo).
# Cada arquivo é gravado inteiro num .lucerna-tmp ao lado e trocado pelo mv
# (uma queda ou o disco cheio no meio não deixa o arquivo da pessoa pela
# metade). Um link simbólico (dotfiles com stow) é gravado no lugar, para o
# link continuar apontando para o arquivo dela. Com um original, o temporário
# nasce só para o dono (umask 077, depois de apagar um que tenha sobrado) e
# ganha as permissões dele antes do mv: nunca fica um instante aberto aos
# outros. Um arquivo novo segue o umask da sessão.
# Sai com 1 se algum arquivo não foi gravado (os outros seguem).
cd "$1" || exit 1
mode=$2
copies=$3
shift 3
if [ "$mode" = fresh ]; then
    printf '%s\n' "$copies" | while IFS= read -r n; do
        [ -n "$n" ] && [ -f "$n" ] && [ ! -e "$n.lucerna-bak" ] || continue
        cp -pL -- "$n" "$n.lucerna-bak" || exit 1
    done || exit 1
fi
st=0
while [ $# -ge 3 ]; do
    case $2 in
        w) if ! mkdir -p "$(dirname "$1")"; then
            st=1
        elif [ -L "$1" ]; then
            printf '%s' "$3" > "$1" || st=1
        elif rm -f -- "$1.lucerna-tmp" && (if [ -e "$1" ]; then umask 077; fi; printf '%s' "$3" > "$1.lucerna-tmp"); then
            [ -e "$1" ] && chmod --reference="$1" "$1.lucerna-tmp" 2> /dev/null
            mv -f -- "$1.lucerna-tmp" "$1" || { rm -f -- "$1.lucerna-tmp"; st=1; }
        else
            rm -f -- "$1.lucerna-tmp"
            st=1
        fi ;;
        rm) rm -f -- "$1" || st=1 ;;
    esac
    shift 3
done
exit $st
