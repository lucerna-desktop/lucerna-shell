# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154 # as raízes vêm do common.sh; o resultado é usado por quem carrega
# A detecção do lucerna-session: a GPU (e o ambiente que ela pede), o modeset
# da NVIDIA, o teclado e o init. Só lê arquivos (sob as raízes do common.sh);
# nunca o D-Bus (nada de localectl). Carregado pelo session/bin/lucerna-session
# depois do common.sh.

# O resultado, preenchido pela detect_all:
#   gpu            intel|amd|nvidia|hybrid|other|none
#   drm            os /dev/dri/cardN, na ordem da numeração
#   nvidia_modeset true|false|null
#   gpu_env        "NOME=valor" do ambiente que a GPU pede
#   kb_layout, kb_variant, kb_model, kb_options
#   init           systemd|other
gpu=none
drm=()
nvidia_modeset=null
gpu_env=()
kb_layout=us
kb_variant=""
kb_model=""
kb_options=""
init=other

# vendor_of PLACA: o fabricante pelo device/vendor.
vendor_of() {
    local id=""
    [ -r "$1/device/vendor" ] && id=$(tr -d '[:space:]' < "$1/device/vendor")
    case "$id" in
        0x10de) echo nvidia ;;
        0x8086) echo intel ;;
        0x1002) echo amd ;;
        *) echo other ;;
    esac
}

# real_display PLACA: a placa é uma GPU PCI de verdade (tem device/vendor, o
# device/class é de vídeo, 0x03xxxx, e o driver não é de quadro simples nem
# de tela USB). O simpledrm (o quadro do firmware, que fica como card0 numa
# máquina só com NVIDIA quando o driver dela não o tira), o evdi (DisplayLink)
# e outros assim não desenham a sessão: não contam como integrada.
real_display() {
    local class driver=""
    [ -r "$1/device/vendor" ] || return 1
    class=$(tr -d '[:space:]' < "$1/device/class" 2> /dev/null) || return 1
    case "$class" in 0x03*) ;; *) return 1 ;; esac
    [ -e "$1/device/driver" ] && driver=$(basename "$(readlink -f "$1/device/driver")")
    case "$driver" in simpledrm | simplefb | efidrm | vesadrm | ofdrm | evdi | udl | gud) return 1 ;; esac
    return 0
}

# detect_gpu: as placas card[0-9]* (sem hífen: card0-eDP-1 é um conector) de
# class/drm que têm o nó /dev/dri/cardN (num container, o /sys mostra as
# placas do host, mas só as repassadas têm o nó). Só NVIDIA: o ambiente da
# NVIDIA. NVIDIA com outra GPU de verdade (híbrida): a integrada desenha,
# então só o AQ_DRM_DEVICES com ela antes da NVIDIA. As placas que não são
# GPU (real_display) ficam na lista drm, mas não fazem uma híbrida: NVIDIA com
# simpledrm ou evdi é só NVIDIA. Sem NVIDIA e sem GPU de verdade, other.
detect_gpu() {
    local path name number vendor first_other="" boot_other="" first_nvidia="" others=0 nvidias=0 pseudo=0
    local -a cards=()
    for path in "$sysfs"/class/drm/card[0-9]*; do
        [ -e "$path" ] || continue
        name=${path##*/}
        case "$name" in *-*) continue ;; esac
        number=${name#card}
        case "$number" in *[!0-9]*) continue ;; esac
        [ -e "$devfs/dri/$name" ] || continue
        cards+=("$number")
    done
    gpu=none
    drm=()
    gpu_env=()
    [ "${#cards[@]}" -gt 0 ] || return 0
    mapfile -t cards < <(printf '%s\n' "${cards[@]}" | sort -n)
    for number in "${cards[@]}"; do
        path="$sysfs/class/drm/card$number"
        drm+=("/dev/dri/card$number")
        vendor=$(vendor_of "$path")
        if ! real_display "$path"; then
            pseudo=$((pseudo + 1))
        elif [ "$vendor" = nvidia ]; then
            nvidias=$((nvidias + 1))
            [ -n "$first_nvidia" ] || first_nvidia="/dev/dri/card$number"
        else
            others=$((others + 1))
            if [ -z "$first_other" ]; then
                first_other="/dev/dri/card$number"
                gpu=$vendor
            fi
            if [ -z "$boot_other" ] && [ "$(tr -d '[:space:]' < "$path/device/boot_vga" 2> /dev/null)" = 1 ]; then
                boot_other="/dev/dri/card$number"
                gpu=$vendor
            fi
        fi
    done
    if [ "$nvidias" -gt 0 ] && [ "$others" -eq 0 ]; then
        gpu=nvidia
        gpu_env=(LIBVA_DRIVER_NAME=nvidia __GLX_VENDOR_LIBRARY_NAME=nvidia NVD_BACKEND=direct)
    elif [ "$nvidias" -gt 0 ]; then
        gpu=hybrid
        gpu_env=("AQ_DRM_DEVICES=${boot_other:-$first_other}:$first_nvidia")
    elif [ "$others" -eq 0 ] && [ "$pseudo" -gt 0 ]; then
        gpu=other
    fi
}

# detect_modeset: o parâmetro modeset do nvidia_drm. Sem NVIDIA, null; com
# NVIDIA e sem o arquivo, false.
detect_modeset() {
    case "$gpu" in
        nvidia | hybrid) ;;
        *)
            nvidia_modeset=null
            return 0
            ;;
    esac
    case "$(tr -d '[:space:]' < "$sysfs/module/nvidia_drm/parameters/modeset" 2> /dev/null)" in
        Y | y | 1) nvidia_modeset=true ;;
        *) nvidia_modeset=false ;;
    esac
}

# xorg_option ARQUIVO NOME: o valor de `Option "NOME" "valor"`.
xorg_option() {
    sed -n 's/^[[:space:]]*Option[[:space:]]*"'"$2"'"[[:space:]]*"\([^"]*\)".*$/\1/p' "$1" | head -n 1
}

# shell_var ARQUIVO NOME: o valor de NOME=valor (sem as aspas em volta).
shell_var() {
    sed -n 's/^[[:space:]]*'"$2"'=[[:space:]]*//p' "$1" | head -n 1 | sed -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'\$/\1/"
}

# detect_keyboard: o teclado do sistema, nesta ordem: o xorg.conf.d, o
# /etc/default/keyboard, o KEYMAP do vconsole.conf traduzido pelo
# kbd-model-map do systemd, e por fim us.
detect_keyboard() {
    local file keymap line
    kb_layout="" kb_variant="" kb_model="" kb_options=""
    file="$etc/X11/xorg.conf.d/00-keyboard.conf"
    if [ -r "$file" ]; then
        kb_layout=$(xorg_option "$file" XkbLayout)
        kb_variant=$(xorg_option "$file" XkbVariant)
        kb_model=$(xorg_option "$file" XkbModel)
        kb_options=$(xorg_option "$file" XkbOptions)
        [ -n "$kb_layout" ] && return 0
    fi
    file="$etc/default/keyboard"
    if [ -r "$file" ]; then
        kb_layout=$(shell_var "$file" XKBLAYOUT)
        kb_variant=$(shell_var "$file" XKBVARIANT)
        kb_model=$(shell_var "$file" XKBMODEL)
        kb_options=$(shell_var "$file" XKBOPTIONS)
        [ -n "$kb_layout" ] && return 0
    fi
    kb_layout="" kb_variant="" kb_model="" kb_options=""
    file="$etc/vconsole.conf"
    if [ -r "$file" ] && [ -r "$usr_share/systemd/kbd-model-map" ]; then
        keymap=$(shell_var "$file" KEYMAP)
        if [ -n "$keymap" ]; then
            # Colunas: o keymap do console, layout, modelo, variante, opções
            # ("-" é vazio).
            line=$(grep -v '^[[:space:]]*#' "$usr_share/systemd/kbd-model-map" |
                while read -r console layout model variant options _; do
                    if [ "$console" = "$keymap" ]; then
                        printf '%s\t%s\t%s\t%s\n' "$layout" "$model" "$variant" "$options"
                        break
                    fi
                done)
            if [ -n "$line" ]; then
                IFS=$'\t' read -r kb_layout kb_model kb_variant kb_options <<< "$line"
                [ "$kb_model" = - ] && kb_model=""
                [ "$kb_variant" = - ] && kb_variant=""
                [ "$kb_options" = - ] && kb_options=""
                [ "$kb_layout" = - ] && kb_layout=""
                [ -n "$kb_layout" ] && return 0
            fi
        fi
    fi
    kb_layout=us kb_variant="" kb_model="" kb_options=""
}

# detect_init: systemd quando o sistema subiu por ele e o systemctl --user
# responde (há um gerente do usuário); senão other.
detect_init() {
    if [ -d "$run_root/systemd/system" ] && have systemctl && systemctl --user show-environment > /dev/null 2>&1; then
        init=systemd
    else
        init=other
    fi
}

detect_all() {
    detect_gpu
    detect_modeset
    detect_keyboard
    detect_init
}

# session_json: o session.json da detecção.
session_json() {
    printf '{"gpu": %s, "drm": %s, "nvidiaModeset": %s, "keyboard": {"layout": %s, "variant": %s, "model": %s, "options": %s}, "init": %s}' \
        "$(json_str "$gpu")" "$(json_list "${drm[@]}")" "$nvidia_modeset" \
        "$(json_str "$kb_layout")" "$(json_str "$kb_variant")" "$(json_str "$kb_model")" "$(json_str "$kb_options")" \
        "$(json_str "$init")"
}
