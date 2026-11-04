#!/usr/bin/env bash
# Análise estática: qmllint (com a árvore de módulos do Quickshell), shellcheck,
# ruff, a sintaxe dos .lua da sessão (luac) e os JSON de tema. Roda todas as
# partes e falha se alguma falhar.
# Saída em $CI_OUT: um <parte>.log por parte e o summary.md; do qmllint, também
# qmllint.json (saída crua), qmllint.txt (arquivo:linha:coluna: [categoria]
# mensagem) e qmllint-categorias.txt (N categoria, da maior para a menor).
# Só chamando este script direto (o ci/run.sh não as repassa):
#   QS_BIN     o qs usado para gerar a árvore de módulos (padrão: qs)
#   LINT_TREE  onde deixar a árvore, para depuração (padrão: pasta temporária)
set -uo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=ci/lib.sh
. "$repo/ci/lib.sh"

# Caminhos relativos valem a partir de onde o script foi chamado: resolvidos
# aqui, antes do cd para o repositório.
out=${CI_OUT:-$repo/ci-out}
mkdir -p "$out" || exit 1
out=$(cd "$out" && pwd) || exit 1
if [ -n "${LINT_TREE:-}" ] && [ "${LINT_TREE#/}" = "$LINT_TREE" ]; then
    LINT_TREE=$PWD/$LINT_TREE
fi
work=$(mktemp -d) || exit 1
trap 'rm -rf "$work"' EXIT
status=0
summary="$out/summary.md"
printf '## Análise estática\n\n' > "$summary"

# part <nome> <comando...>: roda, guarda o log e anota o resultado.
part() {
    local name=$1
    shift
    echo "== $name"
    if "$@" > "$out/$name.log" 2>&1; then
        tail -n 3 "$out/$name.log"
        printf -- '- %s: ok\n' "$name" >> "$summary"
    else
        cat "$out/$name.log"
        echo "FALHOU: $name"
        printf -- '- %s: **falhou** (veja %s.log)\n' "$name" "$name" >> "$summary"
        status=1
    fi
}

# nonempty <quantidade> <mensagem>: falha com a mensagem se a lista está vazia.
# Sem isso, o ruff sem arquivos analisaria a pasta atual e o shellcheck erraria
# sem dizer por quê.
# shellcheck disable=SC2329 # chamada pelas funções das partes
nonempty() {
    [ "$1" -gt 0 ] && return 0
    echo "ERRO: $2"
    return 1
}

cd "$repo" || exit 1
# Os .sh e, da sessão, também os scripts sem extensão de session/bin
# (o lucerna-session).
mapfile -t scripts < <({ find ci dev services/scripts session -name '*.sh' && find session/bin -type f; } | sort)
mapfile -t pyfiles < <(find ci dev -name '*.py' | sort)
mapfile -t luafiles < <(find session -name '*.lua' | sort)

# shellcheck disable=SC2329 # chamadas pela part, lá embaixo
shellcheck_run() {
    nonempty "${#scripts[@]}" "nenhum .sh achado em ci/, dev/, services/scripts/ e session/" &&
        shellcheck "${scripts[@]}"
}
# shellcheck disable=SC2329
ruff_check_run() {
    nonempty "${#pyfiles[@]}" "nenhum .py achado em ci/ e dev/" &&
        ruff check --no-cache "${pyfiles[@]}"
}
# shellcheck disable=SC2329
ruff_format_run() {
    nonempty "${#pyfiles[@]}" "nenhum .py achado em ci/ e dev/" &&
        ruff format --no-cache --check "${pyfiles[@]}"
}
# shellcheck disable=SC2329
luac_run() {
    nonempty "${#luafiles[@]}" "nenhum .lua achado em session/" || return 1
    local f rc=0
    for f in "${luafiles[@]}"; do
        luac -p "$f" || rc=1
    done
    [ "$rc" -eq 0 ] && echo "luac: ${#luafiles[@]} arquivos sem erro de sintaxe"
}

# As categorias que o ci/.qmllint.ini pode desligar (disable): os três falsos
# positivos e a exceção medida, cada um com o motivo no .ini. Qualquer outra
# categoria que não esteja em warning reprova.
qmllint_disabled=(BadSignalHandlerParameters CompilerWarnings UncreatableType UnresolvedType)

# ini_pairs ARQUIVO: "categoria nível" de cada linha da seção [Warnings].
# shellcheck disable=SC2329 # chamada pela qmllint_run
ini_pairs() {
    sed -n '/^\[Warnings\]/,/^\[/s/^\([A-Za-z.]*\)=[[:space:]]*\([^[:space:]]*\).*$/\1 \2/p' "$1" | LC_ALL=C sort
}

# ini_keys ARQUIVO: só as categorias da seção [Warnings].
# shellcheck disable=SC2329 # chamada pela qmllint_run
ini_keys() {
    ini_pairs "$1" | cut -d' ' -f1
}

# qml_list RAIZ: os .qml de RAIZ (caminhos relativos, ./...), ordenados.
# shellcheck disable=SC2329 # chamada pela qmllint_run
qml_list() {
    repo_files "$1" | tr '\0' '\n' | grep '\.qml$' | LC_ALL=C sort
}

# same_file A B: B é um arquivo comum com o mesmo conteúdo de A (o cmp é do
# diffutils, que o job lint não instala).
# shellcheck disable=SC2329 # chamada pela qmllint_run
same_file() {
    [ -f "$2" ] && [ "$(sha256sum < "$1")" = "$(sha256sum < "$2")" ]
}

# check_levels: cada categoria do ci/.qmllint.ini está em warning, fora as da
# qmllint_disabled, que podem estar em warning ou disable.
# shellcheck disable=SC2329 # chamada pela qmllint_run
check_levels() {
    local key level bad=""
    while read -r key level; do
        [ "$level" = warning ] && continue
        if [ "$level" = disable ] && [[ " ${qmllint_disabled[*]} " == *" $key "* ]]; then
            continue
        fi
        bad+="$key=$level"$'\n'
    done < <(ini_pairs "$repo/ci/.qmllint.ini")
    if [ -n "$bad" ]; then
        echo "ERRO: no ci/.qmllint.ini, toda categoria fica em warning; só ${qmllint_disabled[*]} podem ficar em disable (com o motivo no .ini). Fora do lugar:"
        printf '%s' "$bad"
        return 1
    fi
}

# qmllint_warnings JSON PREFIXO: os avisos da saída --json do qmllint, um por
# linha (arquivo:linha:coluna: [categoria] mensagem), sem o PREFIXO no nome.
# shellcheck disable=SC2329 # chamada pelas funções do qmllint
qmllint_warnings() {
    python3 - "$1" "$2" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
for f in data.get("files", []):
    name = f["filename"].removeprefix(sys.argv[2])
    for w in f.get("warnings", []):
        if w.get("type") != "info":
            print(f"{name}:{w.get('line', 0)}:{w.get('column', 0)}: [{w.get('id')}] {w.get('message')}")
PY
}

# O qmllint precisa da árvore de módulos que o Quickshell monta (a VFS). Uma
# cópia gravável da config com um .qmlls.ini vazio faz o `qs -p` preencher o
# buildDir, mesmo abortando sem backend de PanelWindow (código 255). A VFS é
# copiada seguindo os links (com symlinks o qmllint não acha o qmldir).
# shellcheck disable=SC2329 # chamada pela part, logo abaixo
qmllint_run() {
    local cfg="$work/cfg" tree=${LINT_TREE:-$work/tree} vfs defaults missing extra rc=0
    local -a files
    # Toda categoria do qmllint instalado precisa estar no ci/.qmllint.ini: uma
    # versão nova pode trazer uma categoria desligada por padrão, que passaria calada.
    mkdir -p "$work/defaults"
    (cd "$work/defaults" && /usr/lib/qt6/bin/qmllint --write-defaults > /dev/null 2>&1)
    if [ ! -s "$work/defaults/.qmllint.ini" ]; then
        echo "ERRO: o qmllint --write-defaults não gerou a lista de categorias do qmllint instalado"
        return 1
    fi
    defaults=$(ini_keys "$work/defaults/.qmllint.ini")
    if [ -z "$defaults" ]; then
        echo "ERRO: não achei nenhuma categoria na seção [Warnings] do .qmllint.ini do qmllint --write-defaults (o formato mudou?); sem elas, a checagem de categorias passaria calada"
        return 1
    fi
    missing=$(LC_ALL=C comm -23 <(printf '%s\n' "$defaults") <(ini_keys "$repo/ci/.qmllint.ini"))
    if [ -n "$missing" ]; then
        echo "ERRO: o ci/.qmllint.ini não cita estas categorias do qmllint instalado; acrescente cada uma em warning (ou como exceção, com o motivo):"
        echo "$missing"
        return 1
    fi
    check_levels || return 1
    export XDG_RUNTIME_DIR="$work/run"
    install -d -m 700 "$XDG_RUNTIME_DIR"
    copy_repo "$cfg" || return 1
    : > "$cfg/.qmlls.ini"
    QT_QPA_PLATFORM=offscreen timeout 30 "${QS_BIN:-qs}" -p "$cfg/shell.qml" > "$work/vfs.log" 2>&1
    vfs=$(sed -n 's/^buildDir="\(.*\)"$/\1/p' "$cfg/.qmlls.ini")
    if [ -z "$vfs" ] || [ ! -f "$vfs/qs/shell.qml" ]; then
        echo "ERRO: o qs não gerou a árvore de módulos (o .qmlls.ini ficou sem buildDir válido). Saída do qs:"
        cat "$work/vfs.log"
        return 1
    fi
    rm -rf "$tree"
    if ! cp -rL "$vfs" "$tree"; then
        echo "ERRO: não consegui copiar a árvore de módulos de $vfs para $tree"
        return 1
    fi
    # Os .js que os .qml importam (os testes) também precisam estar na árvore.
    if ! (cd "$cfg" && find . -name '*.js' -exec cp --parents -t "$tree/qs/" {} +); then
        echo "ERRO: não consegui copiar os .js do repositório para a árvore de módulos"
        return 1
    fi
    # A árvore do qs só tem o que o shell.qml alcança pelos imports; o harness
    # dos testes (tests/runner.qml) não é alcançado e entra como os .js. Os
    # imports qs.* dele resolvem pelo -I da árvore.
    if [ -d "$cfg/tests" ] && ! (cd "$cfg" && find tests -name '*.qml' -exec cp --parents -t "$tree/qs/" {} +); then
        echo "ERRO: não consegui copiar os .qml de tests/ para a árvore de módulos"
        return 1
    fi
    # Sem o .ini na árvore, o qmllint usaria os níveis padrão (com categorias
    # desligadas) e poderia passar.
    if ! cp "$repo/ci/.qmllint.ini" "$tree/qs/.qmllint.ini" ||
        ! same_file "$repo/ci/.qmllint.ini" "$tree/qs/.qmllint.ini"; then
        echo "ERRO: o .qmllint.ini da árvore de módulos não é igual ao ci/.qmllint.ini"
        return 1
    fi
    # A árvore precisa ter os mesmos .qml do repositório: uma VFS vazia, pela
    # metade ou com outros arquivos faria o qmllint analisar outra coisa e passar.
    # Sem os de session/ (a tela de emergência, fora do shell: a qmllint_emergency_run).
    qml_list "$repo" | grep -v '^\./session/' > "$work/qml-repo.txt"
    (cd "$tree/qs" && find . -name '*.qml' | LC_ALL=C sort) > "$work/qml-tree.txt"
    mapfile -t files < "$work/qml-tree.txt"
    if [ ! -s "$work/qml-repo.txt" ]; then
        echo "ERRO: nenhum .qml achado no repositório: o qmllint não teria o que analisar"
        return 1
    fi
    missing=$(LC_ALL=C comm -23 "$work/qml-repo.txt" "$work/qml-tree.txt")
    extra=$(LC_ALL=C comm -13 "$work/qml-repo.txt" "$work/qml-tree.txt")
    if [ -n "$missing" ] || [ -n "$extra" ]; then
        echo "ERRO: a árvore de módulos não tem os mesmos .qml do repositório; o qmllint analisaria outra coisa."
        [ -z "$missing" ] || printf 'Faltam na árvore:\n%s\n' "$missing"
        [ -z "$extra" ] || printf 'Sobram na árvore (não estão no repositório):\n%s\n' "$extra"
        return 1
    fi
    # Caminhos absolutos: com caminho relativo (./core/config/Config.qml), o
    # qmllint 6.12 não liga o arquivo à entrada `singleton` do qmldir da árvore
    # (que o qs gera certa) e acusa [import] "not declared as singleton in qmldir"
    # em todo singleton. O 6.11 aceitava os dois.
    # Normalizado (sem barra no fim, symlink nem ..), para o prefixo que a
    # saída tira bater com o caminho que o qmllint devolve.
    local qsdir
    qsdir=$(realpath "$tree/qs") || return 1
    files=("${files[@]/#./$qsdir}")
    (cd "$qsdir" && /usr/lib/qt6/bin/qmllint -I "$tree" -I /usr/lib/qt6/qml --json "$out/qmllint.json" "${files[@]}") || rc=$?
    qmllint_warnings "$out/qmllint.json" "$qsdir/" > "$out/qmllint.txt" || return 1
    cat "$out/qmllint.txt"
    # As categorias têm letras maiúsculas e pontos (Quick.attached-property-reuse).
    sed -nE 's/^[^[]*\[([^]]+)\] .*/\1/p' "$out/qmllint.txt" | sort | uniq -c | sort -rn > "$out/qmllint-categorias.txt"
    echo "qmllint: ${#files[@]} arquivos, $(wc -l < "$out/qmllint.txt") avisos; por categoria:"
    cat "$out/qmllint-categorias.txt"
    [ "$rc" -eq 0 ] && [ ! -s "$out/qmllint.txt" ]
}

# A tela de emergência (session/emergency/) é uma config própria do Quickshell,
# rodada sem o shell: o qmllint a vê só com os módulos do Qt e do Quickshell
# instalados, sem a árvore do shell. Um import do shell não resolve e reprova.
# shellcheck disable=SC2329 # chamada pela part, logo abaixo
qmllint_emergency_run() {
    local dir="$work/emergency" rc=0
    local -a files
    mapfile -t files < <(qml_list "$repo" | grep '^\./session/')
    nonempty "${#files[@]}" "nenhum .qml achado em session/ (a tela de emergência)" || return 1
    mkdir -p "$dir"
    cp "$repo/ci/.qmllint.ini" "$dir/.qmllint.ini" || return 1
    (cd "$repo" && cp --parents -t "$dir" "${files[@]}") || return 1
    dir=$(realpath "$dir") || return 1
    files=("${files[@]/#./$dir}")
    (cd "$dir" && /usr/lib/qt6/bin/qmllint -I /usr/lib/qt6/qml --json "$out/qmllint-emergency.json" "${files[@]}") || rc=$?
    qmllint_warnings "$out/qmllint-emergency.json" "$dir/" > "$out/qmllint-emergency.txt" || return 1
    cat "$out/qmllint-emergency.txt"
    echo "qmllint (emergência): ${#files[@]} arquivos, $(wc -l < "$out/qmllint-emergency.txt") avisos"
    [ "$rc" -eq 0 ] && [ ! -s "$out/qmllint-emergency.txt" ]
}

part qmllint qmllint_run
part qmllint-emergency qmllint_emergency_run
part shellcheck shellcheck_run
part ruff-check ruff_check_run
part ruff-format ruff_format_run
part luac luac_run
part json python3 ci/jsoncheck.py

exit "$status"
