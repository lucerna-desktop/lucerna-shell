# shellcheck shell=bash
# Funções comuns aos scripts do CI. Carregue com:
#   . "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
#
# O contrato da cópia do repositório, o mesmo para o qmllint (Tarefa 7), os
# testes de unidade (Tarefa 8), a cobertura (Tarefa 16) e a fumaça (Tarefa 18):
# todo script que copia o repositório usa a copy_repo, e todo script que lista
# arquivos do repositório usa a repo_files, para a cópia e a lista verem os
# mesmos arquivos e nada que só existe na máquina local (o que o .gitignore
# lista) mudar o resultado em relação ao GitHub.
#
#   REPO_EXCLUDES
#       Pastas que ficam de fora, em qualquer nível: o .git, a saída do CI e o
#       que o .gitignore lista como pasta. O .git sai por nome, qualquer que
#       seja o tipo: num git worktree ou submódulo ele é um arquivo (gitdir: …).
#   REPO_EXCLUDE_FILES
#       Arquivos que ficam de fora, em qualquer nível (padrões do find -name):
#       os gerados que o .gitignore lista.
#   repo_files <raiz>
#       Os arquivos (e links) de <raiz>, sem os de cima, com caminho relativo
#       (./pasta/arquivo), separados por NUL. Pastas não entram na lista: uma
#       pasta vazia não é copiada (como no GitHub, onde o git não guarda pasta
#       vazia).
#   copy_repo <destino>
#       Copia os arquivos da repo_files do repositório (a pasta acima de ci/)
#       para <destino>, que é criado se não existir e fica gravável: o script
#       trabalha na cópia e nunca escreve no repositório (no dev/ci.sh ele é
#       montado só leitura). Falha se <destino> não for informado ou se a cópia
#       falhar.
#
# Os testes de unidade, os mesmos para o ci/unit.sh e para a rodada da unidade
# que a fumaça faz numa cópia separada (para juntar a cobertura). As duas
# funções põem o motivo de uma falha em UNIT_ERROR e retornam 1; quem chama
# decide como reprovar (ex.: `unit_run "$cfg" "$log" || fail "$UNIT_ERROR"`).
#
#   unit_suites <cópia>
#       Confere que cada tests/<nome>.test.js da <cópia> está importado no
#       tests/runner.qml (import "<nome>.test.js" as <Módulo>) e na lista suites
#       (item ["<nome>", <Módulo>]; fora dela, o arquivo nunca roda) e põe os
#       nomes em UNIT_NAMES.
#   unit_run <cópia> <log>
#       Põe o runner e os testes ao lado do shell.qml da <cópia> (para os
#       imports qs.* resolverem), roda o qs (TZ=America/Sao_Paulo, offscreen,
#       60 s de limite) e grava a saída, sem cores, em <log>. Passa só com
#       código 0, a linha "RESULT passed=N failed=0" com N > 0 (fica em
#       UNIT_RESULT) e uma linha "SUITE <nome> casos=N" (N > 0) para cada nome
#       de UNIT_NAMES (chame a unit_suites antes). O XDG_RUNTIME_DIR,
#       XDG_STATE_HOME, XDG_CACHE_HOME e XDG_CONFIG_HOME do qs são pastas
#       próprias ao lado da <cópia>, e o qs roda sem WAYLAND_DISPLAY: nada da sessão de quem chama
#       (a fumaça tem um shell rodando) é tocado.

REPO_EXCLUDES=(.git ci-out .superpowers .cache __pycache__ .ruff_cache)
REPO_EXCLUDE_FILES=('*.qmlc' '*.jsc' .qmlls.ini)
# O que a unit_suites e a unit_run devolvem, lido por quem chama.
# shellcheck disable=SC2034 # lidas pelos scripts que carregam este arquivo
UNIT_NAMES=() UNIT_RESULT="" UNIT_ERROR=""

# repo_files <raiz>: veja o topo do arquivo.
repo_files() {
    local root=${1:-} name
    local -a dirs=(-false) files=(-false)
    if [ -z "$root" ]; then
        echo "ERRO: repo_files precisa da raiz" >&2
        return 2
    fi
    for name in "${REPO_EXCLUDES[@]}"; do dirs+=(-o -name "$name"); done
    for name in "${REPO_EXCLUDE_FILES[@]}"; do files+=(-o -name "$name"); done
    (cd "$root" && find . -mindepth 1 \( -name .git -o -type d \( "${dirs[@]}" \) \) -prune \
        -o -not -type d -not \( "${files[@]}" \) -print0)
}

# copy_repo <destino>: veja o topo do arquivo.
copy_repo() {
    local dest=${1:-} src
    local -a st
    if [ -z "$dest" ]; then
        echo "ERRO: copy_repo precisa da pasta de destino" >&2
        return 2
    fi
    src=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd) || return 1
    mkdir -p "$dest" && dest=$(cd "$dest" && pwd) || return 1
    repo_files "$src" | (cd "$src" && xargs -0 -r cp -P --parents -t "$dest")
    st=("${PIPESTATUS[@]}")
    if [ "${st[0]}" -ne 0 ] || [ "${st[1]}" -ne 0 ]; then
        echo "ERRO: copy_repo não conseguiu copiar o repositório para $dest" >&2
        return 1
    fi
    chmod -R u+w "$dest"
}

# unit_suites <cópia>: veja o topo do arquivo.
# shellcheck disable=SC2034 # UNIT_* são lidas por quem chama
unit_suites() {
    local cfg=${1:-} runner f name module
    local -a tests
    UNIT_NAMES=()
    UNIT_ERROR=""
    runner="$cfg/tests/runner.qml"
    if [ ! -f "$runner" ]; then
        UNIT_ERROR="falta o tests/runner.qml"
        return 1
    fi
    shopt -s nullglob
    tests=("$cfg"/tests/*.test.js)
    shopt -u nullglob
    if [ ${#tests[@]} -eq 0 ]; then
        UNIT_ERROR="nenhum tests/*.test.js: não há o que testar"
        return 1
    fi
    # Todo arquivo de teste precisa estar importado no runner e na lista
    # suites, com o nome do arquivo e o módulo do import (um item copiado com
    # o nome trocado rodaria outro arquivo no lugar deste).
    for f in "${tests[@]}"; do
        name=$(basename "$f" .test.js)
        # O nome vai numa regex e numa string JS: só letras, números, _ e -.
        if ! [[ "$name" =~ ^[A-Za-z0-9_-]+$ ]]; then
            UNIT_ERROR="tests/$name.test.js: nome de arquivo de teste só com letras, números, _ e -"
            return 1
        fi
        module=$(sed -nE "s/^import \"$name\\.test\\.js\" as ([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*\$/\\1/p" "$runner" | head -n 1)
        if [ -z "$module" ]; then
            UNIT_ERROR="tests/$name.test.js não está importado no tests/runner.qml (falta a linha: import \"$name.test.js\" as <Nome>Test)"
            return 1
        fi
        if ! grep -qE "^[[:space:]]*\[\"$name\", $module\],?[[:space:]]*\$" "$runner"; then
            UNIT_ERROR="tests/$name.test.js está importado como $module, mas falta o item [\"$name\", $module] em suites no tests/runner.qml (fora de suites, ele nunca roda)"
            return 1
        fi
        UNIT_NAMES+=("$name")
    done
}

# unit_run <cópia> <log>: veja o topo do arquivo.
# shellcheck disable=SC2034 # UNIT_* são lidas por quem chama
unit_run() {
    local cfg=${1:-} log=${2:-} base rc result_line passed failed name
    # O qs prefixa cada linha de console.* com a categoria e "qml:" (ex.: "  INFO
    # qml: PASS ..." e "  ERROR qml: FAIL ..."). As checagens de SUITE e RESULT
    # ancoram nesse prefixo (início da linha) e no fim dela: sem âncora, uma
    # mensagem de FAIL que citasse "SUITE x casos=3" ou "RESULT passed=0
    # failed=0" no texto passaria pela checagem sem ter rodado nada.
    local qs_line='^[[:space:]]*[A-Za-z]+ qml: '
    UNIT_RESULT=""
    UNIT_ERROR=""
    if [ -z "$cfg" ] || [ -z "$log" ]; then
        UNIT_ERROR="unit_run precisa da cópia e do log"
        return 1
    fi
    base="$cfg.qs"
    # Chamada com `|| fail`, o set -e não vale aqui dentro: cada passo que pode
    # falhar é conferido.
    if ! install -d -m 700 "$base/run" || ! mkdir -p "$base/state" "$base/cache" "$base/config" \
        || ! cp "$cfg/tests/runner.qml" "$cfg"/tests/*.test.js "$cfg/"; then
        UNIT_ERROR="não consegui preparar a cópia da unidade (as pastas do qs e o runner ao lado do shell.qml)"
        return 1
    fi
    rc=0
    # LUCERNA_LOGIND=off: o services/Logind fica desligado (nenhum gdbus nem
    # systemd-inhibit roda; os testes usam só as funções puras e o estado). Sem
    # ela, fora do modo de desenvolvimento, ele falaria com o logind do sistema.
    env -u LUCERNA_DEV -u LUCERNA_LOGIND_BUS -u WAYLAND_DISPLAY -u QT_QUICK_BACKEND \
        LUCERNA_LOGIND=off XDG_RUNTIME_DIR="$base/run" XDG_STATE_HOME="$base/state" XDG_CACHE_HOME="$base/cache" \
        XDG_CONFIG_HOME="$base/config" \
        TZ=America/Sao_Paulo QT_QPA_PLATFORM=offscreen \
        timeout -k 10 60 qs -p "$cfg/runner.qml" > "$base/raw.log" 2>&1 || rc=$?
    if ! sed 's/\x1b\[[0-9;]*m//g' "$base/raw.log" > "$log"; then
        UNIT_ERROR="não consegui gravar o log da unidade em $log"
        return 1
    fi
    grep -E 'PASS |FAIL |SUITE |RESULT ' "$log" || true

    result_line=$(grep -E "${qs_line}RESULT passed=[0-9]+ failed=[0-9]+\$" "$log" | tail -n 1 || true)
    UNIT_RESULT=$(sed -E "s/${qs_line}//" <<< "$result_line")
    if [ -z "$UNIT_RESULT" ]; then
        echo "--- $(basename "$log") ---" >&2
        tail -n 40 "$log" >&2
        UNIT_ERROR="o runner não chegou ao fim (sem a linha RESULT; código $rc: 124 é o timeout, 255 um import ou JS que não carrega). Veja $(basename "$log")"
        return 1
    fi
    passed=$(sed -E 's/.*passed=([0-9]+).*/\1/' <<< "$UNIT_RESULT")
    failed=$(sed -E 's/.*failed=([0-9]+).*/\1/' <<< "$UNIT_RESULT")
    if [ "$rc" -ne 0 ] || [ "$failed" -ne 0 ] || [ "$passed" -eq 0 ]; then
        UNIT_ERROR="testes falharam ($UNIT_RESULT, código $rc)"
        return 1
    fi
    # Todo arquivo de teste precisa ter rodado: importado e fora de suites, ou
    # sem nenhum caso, ele passaria calado.
    if [ ${#UNIT_NAMES[@]} -eq 0 ]; then
        UNIT_ERROR="nenhuma suíte a conferir: chame a unit_suites antes da unit_run"
        return 1
    fi
    for name in "${UNIT_NAMES[@]}"; do
        if ! grep -qE "${qs_line}SUITE $name casos=[1-9][0-9]*\$" "$log"; then
            UNIT_ERROR="tests/$name.test.js não rodou nenhum caso (falta \"SUITE $name casos=N\" com N > 0): confira o item [\"$name\", …] em suites no tests/runner.qml e os t.test do arquivo"
            return 1
        fi
    done
}
