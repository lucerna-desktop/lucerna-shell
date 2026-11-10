# shellcheck shell=bash
# shellcheck disable=SC2154 # as pastas e o self vêm do common.sh e do lucerna-session
# O supervisor do shell (lucerna-session supervise) e o subcomando shell
# (stop, start, restart, status). Carregado (source) pelo
# session/bin/lucerna-session depois do common.sh; não roda sozinho.
#
# A política de quedas, com variáveis só para os testes:
#   LUCERNA_CRASH_WINDOW  a janela em segundos (30);
#   LUCERNA_CRASH_DELAYS  as pausas antes de cada reinício (1 2 4);
#   LUCERNA_SAFE_TRIES    as quedas no modo de segurança até a emergência (2).
# O qs que sai com o `hold` (o shell stop) não é queda: o supervisor espera o
# SIGUSR1 do shell start. O qs que sai porque o compositor saiu (o
# `hyprctl -j version` falha) encerra o supervisor, sem reinício. O resto é
# queda: com n quedas na janela, reinicia depois da n-ésima pausa; passada a
# última pausa, entra no modo de segurança (LUCERNA_SAFE_MODE=1, a config com
# os padrões); lá, LUCERNA_SAFE_TRIES quedas na janela abrem a tela de
# emergência (power.sh) e o supervisor espera o shell start, que a fecha.

crash_window=${LUCERNA_CRASH_WINDOW:-30}
read -ra crash_delays <<< "${LUCERNA_CRASH_DELAYS:-1 2 4}"
safe_tries=${LUCERNA_SAFE_TRIES:-2}
shell_log_dir="$state_dir/shell"
keep_logs=5

supervisor_pid_file="$runtime_dir/supervisor.pid"
qs_pid_file="$runtime_dir/qs.pid"
hold_file="$runtime_dir/hold"
# O estado do supervisor para o shell status: running, held, safe ou emergency.
supervisor_state_file="$runtime_dir/supervisor.state"
crash_file="$runtime_dir/crash.json"
safe_config="$runtime_dir/config.safe.json"

# pid_matches ARQUIVO PADRÃO: o pid do arquivo, em `pid`, se o processo está
# vivo e o cmdline dele casa com o padrão (glob). Um pid antigo reaproveitado
# por outro programa não casa: nunca se manda sinal a um processo que não é
# nosso.
pid_matches() {
    local cmdline
    pid=""
    [ -r "$1" ] || return 1
    read -r pid < "$1" 2> /dev/null || true
    [[ $pid =~ ^[0-9]+$ ]] || return 1
    [ -r "/proc/$pid/cmdline" ] || return 1
    cmdline=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2> /dev/null) || return 1
    # shellcheck disable=SC2053 # o padrão é um glob de propósito
    [[ $cmdline == $2 ]]
}

supervisor_alive() {
    pid_matches "$supervisor_pid_file" '*lucerna-session supervise*'
}

qs_alive() {
    pid_matches "$qs_pid_file" '*qs -c *'
}

set_state() {
    write_file "$supervisor_state_file" "$1"
}

# now_ms: o relógio em milissegundos (para a janela das quedas).
now_ms() {
    date +%s%3N
}

# new_log: um arquivo novo em ~/.local/state/lucerna/shell/, em `qs_log`, e
# apaga os mais antigos (ficam os 5 últimos, contando o novo).
new_log() {
    local base n=1 old
    local -a logs=()
    mkdir -p "$shell_log_dir"
    base="$shell_log_dir/qs-$(date +%Y%m%d-%H%M%S)"
    qs_log="$base.log"
    while [ -e "$qs_log" ]; do
        qs_log="$base-$n.log"
        n=$((n + 1))
    done
    : > "$qs_log"
    mapfile -t logs < <(ls -1t "$shell_log_dir"/qs-*.log 2> /dev/null)
    for old in "${logs[@]:keep_logs}"; do
        rm -f "$old"
    done
}

# write_crash N SAFE: o crash.json que o shell novo lê (o aviso da queda).
write_crash() {
    write_file "$crash_file" "{\"time\": $(json_str "$(date -Iseconds)"), \"log\": $(json_str "$qs_log"), \"count\": $1, \"safe\": $2}"
}

# pause SEGUNDOS: espera, mas acorda com o TERM e o SIGUSR1.
pause() {
    sleep "$1" &
    sleep_pid=$!
    wait "$sleep_pid" 2> /dev/null
    kill "$sleep_pid" 2> /dev/null
    sleep_pid=""
}

# wait_start: espera o SIGUSR1 do shell start (ou o TERM). O start_requested
# é zerado logo que o qs sai, antes de o estado (held, emergency) ser
# publicado: um shell start que vem logo depois não se perde.
wait_start() {
    while [ "$start_requested" = 0 ] && [ "$terminating" = 0 ]; do
        pause 60
    done
}

# wait_hold: parado pelo shell stop, espera o hold sumir (o shell start o
# apaga antes do SIGUSR1, que só encurta a espera). Olhar o arquivo, e não só
# o sinal, não perde um start que chegou antes de a espera começar.
wait_hold() {
    while [ -e "$hold_file" ] && [ "$terminating" = 0 ]; do
        pause 1
    done
}

# emergency: a tela de emergência (lucerna-session emergency --mode crashed),
# fora do supervisor, com o registro da última queda. O supervisor não espera
# por ela: segue para o wait_start.
emergency() {
    log "o shell caiu de novo no modo de segurança: emergência"
    setsid -f env LUCERNA_EMERGENCY_LOG="$qs_log" "$self" emergency --mode crashed > /dev/null 2>&1 < /dev/null
}

# shellcheck disable=SC2329 # chamada pelo trap
on_term() {
    terminating=1
    [ -n "$qs_pid" ] && kill -TERM "$qs_pid" 2> /dev/null
    [ -n "$sleep_pid" ] && kill "$sleep_pid" 2> /dev/null
}

# shellcheck disable=SC2329 # chamada pelo trap
on_start() {
    start_requested=1
    [ -n "$sleep_pid" ] && kill "$sleep_pid" 2> /dev/null
}

# run_qs: sobe o qs e espera ele sair; o código fica em `qs_status`. Sem o
# QT_SCALE_FACTOR (a escala do shell é a interna) e sem o tratador de quedas
# do próprio Quickshell (QS_DISABLE_CRASH_HANDLER): com ele, o qs se relança
# sozinho num processo novo (sem o -c no cmdline) e o supervisor não vê a
# queda; a política de quedas é a daqui. O LUCERNA_SUPERVISED=1 diz ao shell
# que ele é o do supervisor: na sessão Lucerna, um qs sem ela (um exec_cmd no
# hyprland.lua da pessoa) sai logo, para não haver dois shells.
run_qs() {
    local -a safe_env=()
    [ "$safe" = 1 ] && safe_env=(LUCERNA_SAFE_MODE=1)
    new_log
    log "o shell sobe (${LUCERNA_SHELL_CONFIG:-lucerna}${safe_env[*]:+, modo de segurança}; registro em $qs_log)"
    env -u QT_SCALE_FACTOR -u LUCERNA_SAFE_MODE QS_DISABLE_CRASH_HANDLER=1 LUCERNA_SUPERVISED=1 "${safe_env[@]}" qs -c "${LUCERNA_SHELL_CONFIG:-lucerna}" >> "$qs_log" 2>&1 < /dev/null &
    qs_pid=$!
    write_file "$qs_pid_file" "$qs_pid"
    # O wait volta antes do fim quando chega um sinal (o SIGUSR1); o qs segue.
    while :; do
        wait "$qs_pid"
        qs_status=$?
        if [ "$qs_status" -gt 128 ] && kill -0 "$qs_pid" 2> /dev/null; then
            continue
        fi
        break
    done
    qs_pid=""
    rm -f "$qs_pid_file"
}

cmd_supervise() {
    local now n delay
    local -a crashes=() recent=()
    mkdir -p "$runtime_dir"
    if supervisor_alive && [ "$pid" != "$$" ]; then
        log "já há um supervisor ($pid); saio"
        exit 0
    fi
    terminating=0 start_requested=0 safe=0 qs_pid="" sleep_pid="" qs_log=""
    trap on_term TERM INT HUP
    trap on_start USR1
    echo "$$" > "$supervisor_pid_file"
    rm -f "$hold_file"
    set_state running
    while [ "$terminating" = 0 ]; do
        # O hold é olhado antes de cada partida: um shell stop na pausa depois
        # de uma queda (sem qs para parar) também segura o shell.
        if [ -e "$hold_file" ]; then
            log "o shell está parado (shell stop); espero o shell start"
            set_state held
            wait_hold
            safe=0 crashes=()
            continue
        fi
        if [ "$safe" = 1 ]; then set_state safe; else set_state running; fi
        run_qs
        start_requested=0
        [ "$terminating" = 1 ] && break
        # Saiu pelo shell stop: não é queda (o topo do laço espera o start).
        [ -e "$hold_file" ] && continue
        if ! hyprctl -j version > /dev/null 2>&1; then
            log "o shell saiu (código $qs_status) e o compositor também: fim"
            break
        fi
        # Uma queda: só contam as da janela.
        now=$(now_ms)
        recent=()
        for n in "${crashes[@]}"; do
            [ $((now - n)) -le $((crash_window * 1000)) ] && recent+=("$n")
        done
        crashes=("${recent[@]}" "$now")
        n=${#crashes[@]}
        if [ "$safe" = 0 ] && [ "$n" -le "${#crash_delays[@]}" ]; then
            delay=${crash_delays[n - 1]}
            log "o shell caiu (código $qs_status, ${n}ª queda em ${crash_window} s); volta em $delay s"
            write_crash "$n" false
            pause "$delay"
        elif [ "$safe" = 0 ]; then
            log "o shell caiu (código $qs_status, ${n}ª queda em ${crash_window} s); volta no modo de segurança"
            safe=1 crashes=()
            rm -f "$safe_config"
            write_crash "$n" true
        elif [ "$n" -ge "$safe_tries" ]; then
            set_state emergency
            write_crash "$n" true
            emergency
            wait_start
            close_emergency
            # A emergência já foi o aviso da queda: o shell que volta ao
            # normal não avisa de novo (nem diz "modo de segurança").
            rm -f "$crash_file"
            log "o shell volta ao normal (shell start)"
            safe=0 crashes=()
        else
            delay=${crash_delays[0]}
            log "o shell caiu no modo de segurança (código $qs_status, ${n}ª queda em ${crash_window} s); volta em $delay s"
            write_crash "$n" true
            pause "$delay"
        fi
    done
    [ -n "$qs_pid" ] && wait "$qs_pid" 2> /dev/null
    rm -f "$supervisor_pid_file" "$supervisor_state_file" "$qs_pid_file"
    log "o supervisor sai"
    exit 0
}

# shell_stop: para o qs sem contar como queda (o hold) e espera ele sair (até
# 5 s; depois, KILL).
shell_stop() {
    local stopped=0
    mkdir -p "$runtime_dir"
    : > "$hold_file"
    if qs_alive; then
        stopped=1
        log "o shell para (shell stop)"
        kill -TERM "$pid" 2> /dev/null
        for _ in $(seq 50); do
            kill -0 "$pid" 2> /dev/null || break
            sleep 0.1
        done
        if kill -0 "$pid" 2> /dev/null; then
            log "o qs ($pid) não saiu em 5 s; KILL"
            kill -KILL "$pid" 2> /dev/null
        fi
    fi
    # Sem qs (na pausa depois de uma queda ou na emergência), o SIGUSR1 acorda
    # o supervisor, que acha o hold. Depois, espera o estado held, para o
    # status seguinte.
    if supervisor_alive; then
        [ "$stopped" = 1 ] || kill -USR1 "$pid" 2> /dev/null
        for _ in $(seq 50); do
            [ "$(cat "$supervisor_state_file" 2> /dev/null)" = held ] && break
            sleep 0.1
        done
    fi
}

# shell_start: tira o hold e acorda o supervisor (ou sobe um, se não há). No
# modo de segurança, para o qs antes: o start volta ao normal.
shell_start() {
    local state
    if supervisor_alive; then
        state=$(cat "$supervisor_state_file" 2> /dev/null)
        [ "$state" = safe ] && shell_stop
        rm -f "$hold_file"
        log "o shell volta (shell start)"
        supervisor_alive && kill -USR1 "$pid"
    else
        rm -f "$hold_file"
        log "sem supervisor: subo um (shell start)"
        setsid -f "$self" supervise > /dev/null 2>&1 < /dev/null
    fi
}

cmd_shell() {
    case "${1:-}" in
        stop) shell_stop ;;
        start) shell_start ;;
        restart)
            shell_stop
            shell_start
            ;;
        status)
            if supervisor_alive; then
                echo "supervised $(cat "$supervisor_state_file" 2> /dev/null || echo running)"
            else
                echo unsupervised
            fi
            ;;
        *) usage ;;
    esac
}
