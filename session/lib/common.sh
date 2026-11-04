# shellcheck shell=bash
# shellcheck disable=SC2034 # as variáveis são usadas por quem carrega
# O comum do lucerna-session: as pastas da sessão, o log e o JSON. Carregado
# (source) pelo session/bin/lucerna-session; não roda sozinho.

# As raízes do sistema. Os testes (ci/tests/test_session.py) trocam por pastas
# falsas; na sessão de verdade, são as do sistema.
sysfs=${LUCERNA_SYSFS:-/sys}
etc=${LUCERNA_ETC:-/etc}
usr_share=${LUCERNA_USR_SHARE:-/usr/share}
run_root=${LUCERNA_RUN:-/run}
# Os nós de dispositivo (/dev/dri/cardN). Os de /dev/dri da sessão continuam
# com o caminho /dev/dri no session.json e no AQ_DRM_DEVICES.
devfs=${LUCERNA_DEVFS:-/dev}

# As pastas do usuário: o estado da execução, o log e a configuração.
runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/lucerna"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/lucerna"
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/lucerna"
log_file="$state_dir/session.log"

# log MENSAGEM...: uma linha com a hora no session.log (e nada se a pasta não
# puder ser criada: o log nunca derruba a sessão).
log() {
    mkdir -p "$state_dir" 2> /dev/null || return 0
    printf '%s [%s] %s\n' "$(date '+%F %T')" "${subcommand:-session}" "$*" >> "$log_file" 2> /dev/null || true
}

# have PROGRAMA: está no PATH.
have() {
    command -v "$1" > /dev/null 2>&1
}

# json_str TEXTO: o texto como string JSON (aspas, barra invertida e
# caracteres de controle escapados).
json_str() {
    local s=$1
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    s=${s//$'\n'/\\n}
    s=${s//$'\t'/\\t}
    s=${s//$'\r'/\\r}
    s=$(printf '%s' "$s" | tr -d '\000-\010\013\014\016-\037')
    printf '"%s"' "$s"
}

# json_list ITEM...: os itens como lista JSON de strings.
json_list() {
    local out="" item
    for item in "$@"; do
        out+="${out:+, }$(json_str "$item")"
    done
    printf '[%s]' "$out"
}

# write_file CAMINHO TEXTO: grava por cima, de uma vez (arquivo temporário e mv).
write_file() {
    mkdir -p "$(dirname "$1")" && printf '%s\n' "$2" > "$1.tmp" && mv -f "$1.tmp" "$1"
}
