# shellcheck shell=bash
# shellcheck disable=SC2154 # as pastas, o self e o shell_log_dir vêm do common.sh, do lucerna-session e do supervise.sh
# A tela de emergência (lucerna-session emergency), o Ctrl+Alt+Delete
# (lucerna-session power) e o desligar e reiniciar. Carregado (source) pelo
# session/bin/lucerna-session depois do supervise.sh; não roda sozinho.
#
# A emergência é o session/emergency/shell.qml, uma config própria do
# Quickshell (qs -p), feita sem nada do shell. Se ela não abrir (o qs sai em
# menos de 2 s com erro), o recurso é uma notificação do Hyprland, que não
# depende do Quickshell.

emergency_pid_file="$runtime_dir/emergency.pid"

# emergency_qml: a config da tela (o LUCERNA_DATA_DIR é definido depois de
# carregar este arquivo).
emergency_qml() {
    printf '%s' "$LUCERNA_DATA_DIR/emergency/shell.qml"
}

emergency_alive() {
    pid_matches "$emergency_pid_file" '*qs -p *emergency*'
}

# latest_log: o registro do shell mais novo (ou nada).
latest_log() {
    # shellcheck disable=SC2012 # os nomes são nossos (qs-AAAAMMDD-HHMMSS.log)
    ls -1t "$shell_log_dir"/qs-*.log 2> /dev/null | head -n 1
}

# lua_str TEXTO: o texto como string Lua entre aspas.
lua_str() {
    local s=$1
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    s=${s//$'\n'/\\n}
    printf '"%s"' "$s"
}

# emergency_notify REGISTRO: a notificação do Hyprland, de um dia (no 0.56,
# timeout = 0 some na hora), com as saídas que não dependem do shell (o mod é
# o da base: Alt no desenvolvimento).
emergency_notify() {
    local mod=Super text
    [ "${LUCERNA_DEV:-}" = 1 ] && mod=Alt
    text="O Lucerna não conseguiu iniciar. $mod+Enter abre um terminal; Ctrl+Alt+Shift+Esc sai da sessão. Registro: ${1:-nenhum}"
    hyprctl eval "hl.notification.create({ text = $(lua_str "$text"), timeout = 86400000 })" > /dev/null 2>&1 \
        || log "a notificação de recurso da emergência falhou"
}

# close_emergency: fecha a tela de emergência aberta (o shell voltou).
close_emergency() {
    if emergency_alive; then
        log "fecha a tela de emergência"
        rm -f "$emergency_pid_file"
        kill -TERM "$pid" 2> /dev/null
    fi
}

# emergency_state: o modo da tela de emergência aberta (crashed|power), pelo
# IPC dela; vazio se ela não responde em 2 s.
emergency_state() {
    timeout 2 qs -p "$(emergency_qml)" ipc call emergency state 2> /dev/null | tail -n 1
}

# replace_emergency: fecha a tela aberta (close_emergency) e espera o qs dela
# sair (até 5 s; depois, KILL), para a nova não abrir por cima.
replace_emergency() {
    local old
    emergency_alive || return 0
    old=$pid
    close_emergency
    for _ in $(seq 50); do
        kill -0 "$old" 2> /dev/null || return 0
        sleep 0.1
    done
    log "a tela de emergência ($old) não fechou em 5 s; KILL"
    kill -KILL "$old" 2> /dev/null || true
}

# cmd_emergency [--mode crashed|power]: a tela de emergência; espera ela fechar.
# Com a do modo power aberta, o modo crashed a troca (replace_emergency).
cmd_emergency() {
    local mode=crashed qs_log start status elapsed emergency_qs
    while [ $# -gt 0 ]; do
        case "$1" in
            --mode)
                mode=${2:-}
                shift 2 || usage
                ;;
            *) usage ;;
        esac
    done
    case "$mode" in
        crashed | power) ;;
        *) usage ;;
    esac
    mkdir -p "$runtime_dir"
    if emergency_alive; then
        # A queda com a tela do Ctrl+Alt+Delete (power) aberta: ela não tem o
        # "Tentar de novo" nem o registro, e o supervisor espera o shell start.
        # A power fecha e a crashed abre no lugar. Uma tela que não responde
        # ao `state` também é trocada.
        if [ "$mode" = crashed ] && [ "$(emergency_state)" != crashed ]; then
            log "a tela de emergência aberta ($pid) é a do Ctrl+Alt+Delete; troco pela da queda"
            replace_emergency
        else
            log "a tela de emergência já está aberta ($pid)"
            exit 0
        fi
    fi
    qs_log=${LUCERNA_EMERGENCY_LOG:-$(latest_log)}
    log "a tela de emergência abre (modo $mode)"
    start=$(now_ms)
    # O qs da emergência, como o do shell: sem o QT_SCALE_FACTOR e sem o
    # tratador de quedas do Quickshell (o pid fica o mesmo).
    env -u QT_SCALE_FACTOR -u LUCERNA_SAFE_MODE QS_DISABLE_CRASH_HANDLER=1 \
        LUCERNA_EMERGENCY_MODE="$mode" LUCERNA_EMERGENCY_LOG="$qs_log" LUCERNA_SESSION_BIN="$self" \
        qs -p "$(emergency_qml)" > "$state_dir/emergency.log" 2>&1 < /dev/null &
    emergency_qs=$!
    write_file "$emergency_pid_file" "$emergency_qs"
    wait "$emergency_qs"
    status=$?
    elapsed=$(($(now_ms) - start))
    if [ "$(cat "$emergency_pid_file" 2> /dev/null)" = "$emergency_qs" ]; then
        rm -f "$emergency_pid_file"
    fi
    # Fechada pelo botão, o qs sai com 0; fechada pelo close_emergency, com o
    # TERM (143). Um erro em menos de 2 s é a tela que não abriu.
    if [ "$elapsed" -lt 2000 ] && [ "$status" != 0 ] && [ "$status" != 143 ]; then
        log "a tela de emergência não abriu (código $status em $elapsed ms; veja $state_dir/emergency.log); aviso do Hyprland"
        emergency_notify "$qs_log"
        exit 1
    fi
    log "a tela de emergência fechou (código $status)"
}

# cmd_power: o Ctrl+Alt+Delete. O menu de energia do shell; com o shell morto
# ou travado (o ipc não responde em 2 s), a emergência no modo power. Com a
# emergência já aberta, ela volta à tela inteira (se estava recolhida).
cmd_power() {
    if emergency_alive; then
        log "Ctrl+Alt+Delete: a tela de emergência já está aberta"
        timeout 2 qs -p "$(emergency_qml)" ipc call emergency expand > /dev/null 2>&1 \
            || log "a tela de emergência não respondeu ao expand"
        exit 0
    fi
    if timeout 2 qs -c "${LUCERNA_SHELL_CONFIG:-lucerna}" ipc call panels open power > /dev/null 2>&1; then
        log "Ctrl+Alt+Delete: o menu de energia do shell"
        exit 0
    fi
    log "Ctrl+Alt+Delete: o shell não respondeu; a tela de emergência"
    cmd_emergency --mode power
}

# cmd_power_action poweroff|reboot: desliga ou reinicia (systemctl com
# systemd, loginctl sem). No desenvolvimento (LUCERNA_DEV=1), só registra e
# avisa: nunca chega à máquina de verdade.
cmd_power_action() {
    local action=$1 label
    case "$action" in
        poweroff) label=Desligar ;;
        reboot) label=Reiniciar ;;
    esac
    if [ "${LUCERNA_DEV:-}" = 1 ]; then
        log "$label: ação simulada (LUCERNA_DEV=1)"
        # Com o shell caído não há servidor de notificações: o aviso do Hyprland.
        notify-send "Lucerna" "$label: ação simulada." > /dev/null 2>&1 \
            || hyprctl eval "hl.notification.create({ text = $(lua_str "$label: ação simulada."), timeout = 5000 })" > /dev/null 2>&1 \
            || true
        return 0
    fi
    detect_init
    log "$label (init: $init)"
    if [ "$init" = systemd ]; then
        systemctl "$action"
    else
        loginctl "$action"
    fi
}
