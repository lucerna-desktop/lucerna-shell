#!/usr/bin/env bash
# Roda os checks do CI na máquina local, no mesmo container do GitHub
# (archlinux:latest), com os mesmos scripts de ci/. Cada job roda num container
# próprio e descartável (lucerna-ci-<job>-<worktree>), com o cache do pacman num
# volume por job (lucerna-ci-pacman-<job>), como o cache por job do GitHub. O
# sufixo <worktree> (o nome da pasta do repositório e um hash do caminho) deixa
# dois worktrees rodarem ao mesmo tempo sem um derrubar o contêiner do outro.
# Nenhum container de desenvolvimento (lucerna-dev, lucerna-polish) é tocado.
#   dev/ci.sh                 os quatro: lint, rules, unit, smoke
#   dev/ci.sh unit smoke      só esses
#   dev/ci.sh shell [job]     um bash no container do job (padrão: lint), com o
#                             repositório montado com escrita em /src; lá dentro,
#                             `bash ci/run.sh <job>` roda o job com o ambiente limpo
# Saída de cada job em ci-out/<job>/. Com LUCERNA_CI_PULL=0, não atualiza a imagem.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
image=archlinux:latest
# O sufixo dos contêineres deste repositório: o nome da pasta (só os caracteres
# que o Docker aceita, até 40) e 8 dígitos do sha256 do caminho, para duas
# pastas de mesmo nome em lugares diferentes não colidirem.
base=$(printf '%s' "${repo##*/}" | tr -c 'a-zA-Z0-9_.-' - | cut -c1-40)
suffix="${base}-$(printf '%s' "$repo" | sha256sum | cut -c1-8)"

if [ "${LUCERNA_CI_PULL:-1}" != 0 ]; then
    docker pull -q "$image" > /dev/null || echo "aviso: não consegui atualizar $image; sigo com a cópia local" >&2
fi

# opts <job>: as opções do docker run comuns aos jobs, no array `common`.
# Na fumaça, o volume lucerna-ci-lucernad-<rev12> guarda o lucernad compilado
# (o dev/lucernad.sh não recompila a mesma revisão). Um volume por revisão do
# dev/lucernad.rev: dois worktrees com revisões diferentes rodando ao mesmo
# tempo não trocam o binário um do outro no meio da fumaça.
opts() {
    common=(--user root -e CI=true -e CI_UID="$(id -u)" -e CI_OUT=/out -e CI_JOB="$1"
        -v "lucerna-ci-pacman-$1:/var/cache/pacman/pkg" -w /src)
    if [ "$1" = smoke ]; then
        common+=(-v "lucerna-ci-lucernad-$(cut -c1-12 "$repo/dev/lucernad.rev"):/opt/lucernad")
    fi
}

# Só os contêineres lucerna-ci-<job>-<sufixo> e lucerna-ci-shell-<sufixo> deste
# repositório: nunca os de outro worktree, o lucerna-dev nem o lucerna-polish.
# O `docker run` roda com o bash como PID 1, que ignora o SIGINT repassado; por
# isso o Ctrl-C remove o contêiner daqui, e cada execução começa removendo um
# sobrado da anterior neste worktree (senão vira "name already in use").
current=""
# shellcheck disable=SC2329 # chamada pelo trap
interrupted() {
    [ -z "$current" ] || docker rm -f "$current" > /dev/null 2>&1 || true
    exit 130
}
trap interrupted INT TERM

if [ "${1:-}" = shell ]; then
    job=${2:-lint}
    mkdir -p "$repo/ci-out/$job"
    opts "$job"
    docker rm -f "lucerna-ci-shell-$suffix" > /dev/null 2>&1 || true
    # shellcheck disable=SC2016 # as variáveis expandem dentro do container
    exec docker run --rm -it --name "lucerna-ci-shell-$suffix" "${common[@]}" \
        -v "$repo:/src" -v "$repo/ci-out/$job:/out" "$image" \
        bash -c 'bash ci/setup.sh "$CI_JOB" && exec runuser -u "$(id -nu "$CI_UID")" -- bash'
fi

jobs=("$@")
[ ${#jobs[@]} -gt 0 ] || jobs=(lint rules unit smoke)
failed=()
for job in "${jobs[@]}"; do
    case "$job" in
        lint | rules | unit | smoke) ;;
        *)
            echo "job desconhecido: $job (use lint, rules, unit, smoke ou shell)" >&2
            exit 2
            ;;
    esac
    out="$repo/ci-out/$job"
    rm -rf "$out"
    mkdir -p "$out"
    echo "==> $job"
    opts "$job"
    current="lucerna-ci-$job-$suffix"
    docker rm -f "$current" > /dev/null 2>&1 || true
    # Em segundo plano com `wait`: o bash só roda o trap depois do comando em
    # primeiro plano, e o docker run não termina com o SIGINT.
    # shellcheck disable=SC2016 # as variáveis expandem dentro do container
    docker run --rm --name "$current" "${common[@]}" \
        -v "$repo:/src:ro" -v "$out:/out" "$image" \
        bash -c 'bash ci/setup.sh "$CI_JOB" && runuser -u "$(id -nu "$CI_UID")" -- bash ci/run.sh "$CI_JOB"' &
    if wait "$!"; then
        echo "==> $job: ok"
    else
        echo "==> $job: FALHOU (saída em ci-out/$job)"
        failed+=("$job")
    fi
    docker rm -f "$current" > /dev/null 2>&1 || true
    current=""
done

if [ ${#failed[@]} -gt 0 ]; then
    echo "falharam: ${failed[*]}"
    exit 1
fi
echo "todos passaram: ${jobs[*]}"
