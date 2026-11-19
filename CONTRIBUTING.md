# Como contribuir

Este guia diz como o código é organizado, como rodar o CI na sua máquina, como
escrever um teste e como um PR chega ao `main`.

## Camadas e regras

O código é organizado por feature, com camadas que só olham para baixo (o
desenho completo está em [`Lucerna — Proposta.md`](<Lucerna — Proposta.md>)):

| Camada | Pode importar |
| --- | --- |
| `features/<feature>/ui` | o `state` da própria feature e o `core`; nunca `qs.services` |
| `features/<feature>/state` | `qs.services` e o `core` |
| `services/` | só o Quickshell e o sistema (convenção: o `rules` não confere) |
| `core/` | só o Quickshell; nunca `qs.features` nem `qs.services` |

Uma feature não importa outra: quando precisam conversar, a conversa passa pelo
`core` (por exemplo, o `Panels`) ou pelos `services`.

O check `rules` (`ci/rules.py`) confere, além das camadas:

- **acentos**: palavras comuns sem acento em strings, comentários e
  documentação (a lista, com o critério de cada palavra, está no script);
- **espaços**: sem tab, sem espaço no fim da linha, com quebra de linha no fim
  do arquivo e sem CRLF;
- **gerados em dia**: os `.qsb` iguais ao que o `dev/shaders.sh` compila e os
  `themes/*.json` iguais ao que o `dev/themes.py` gera. Mudou um `.frag` ou uma
  paleta? Rode o gerador e faça commit do resultado;
- **supressões do qmllint**: só as três registradas no spec do CI
  (`// qmllint disable unqualified` nas margens de três janelas); outra
  supressão reprova, e a exceção nova entra no spec e na lista do `ci/rules.py`;
- **links locais**: imagens e arquivos citados nos `.md` existem.

O QML segue o estilo compacto do resto do código
(`Behavior on x { Anim { type: Anim.FastSpatial } }` numa linha); não use
`qmlformat`. Tudo em português do Brasil, com acentos: textos da interface,
comentários, documentação e mensagens de commit.

## Lint do QML

O `qmllint` não aceita nenhum aviso (`MaxWarnings=0`, todas as categorias em
`warning` no `ci/.qmllint.ini`): nada de import sem uso, acesso não qualificado
ou propriedade que ele não conhece.

- Nenhuma supressão do qmllint (`// qmllint disable ...`) sem entrada no spec
  (`docs/superpowers/specs/2026-09-26-ci-design.md`). As únicas que existem são
  as três das margens do `PanelWindow`, em `MonitorConfirm.qml`, `Osd.qml` e
  `NotificationPopups.qml` (falso positivo do grupo `margins`).
- Onde há componentes aninhados, use `pragma ComponentBehavior: Bound` no topo
  do arquivo e declare `required property` (`modelData`, `index`) nos
  delegates, qualificando os ids nos acessos.

## Rodar o CI na sua máquina

Os mesmos scripts de `ci/` rodam no GitHub e aqui, no mesmo container do
GitHub (`archlinux:latest`; precisa de Docker), com o ambiente refeito do zero:
o que passa aqui passa lá.

```sh
dev/ci.sh              # os quatro checks: lint, rules, unit, smoke
dev/ci.sh unit         # só um
dev/ci.sh shell lint   # um bash no container de um check, com o repositório em /src
```

Os contêineres levam o nome do worktree (`lucerna-ci-<check>-<pasta>-<hash>`):
dois worktrees podem rodar o `dev/ci.sh` ao mesmo tempo sem um derrubar o
outro. A saída de cada check fica em `ci-out/<check>/`: os logs, o `summary.md`, o
`qmllint.txt` do `lint`, o relatório de cobertura e as capturas da fumaça.
A fumaça compila o `lucernad` na revisão de `dev/lucernad.rev` (o volume
`lucerna-ci-lucernad-<revisão>`, um por revisão, guarda o binário); para trocar
de revisão, mude esse arquivo.
A fumaça sobe um PipeWire próprio (com um sink nulo, sem os dispositivos de
áudio) e um mpv tocando ruído nele, para conferir o espectro; nada sai nos
alto-falantes.

Para conferir uma mudança visual no Hyprland de verdade, use o `dev/test.sh`
(um container próprio, `lucerna-polish`, com a janela na sua tela):
`dev/test.sh up`, `dev/test.sh see antes panels open launcher`, `dev/test.sh errs`.

## Escrever um teste

Os testes de unidade rodam no próprio `qs`, pelo harness `tests/runner.qml`.
Cada unidade tem um arquivo `tests/<unidade>.test.js`:

```js
// Testes de core/format/Format.
function run(t) {
    t.test("format: bytes em KiB", () => {
        t.eq(t.Format.bytes(1536), "1,5 KiB");
    });
}
```

- `t.test(nome, corpo)` roda um caso; `t.check(condição, mensagem)`,
  `t.eq(real, esperado, mensagem)` e
  `t.near(real, esperado, tolerância, mensagem)` conferem.
- Prefira `t.eq`. Ele compara por `JSON.stringify`, então dois QtObjects
  distintos viram ambos `"{}"` e passariam como iguais. Para comparar a
  identidade de um objeto, use `t.check(a === b)`: é a única exceção à
  preferência por `t.eq`. `t.object()` cria um QtObject novo, para testes que
  registram objetos.
- Os singletons vêm em `t` (`t.Format`, `t.Panels`, `t.Monitors`…); os enums
  usados nos testes, em `t.enums`. O `state` de uma feature também pode vir,
  quando o teste é do fluxo dela (`t.ThemeSwitcherState`): o runner importa o
  módulo da feature, e o `rules` não confere `tests/`.
- Registre o arquivo no `tests/runner.qml`: um
  `import "<unidade>.test.js" as <Unidade>Test` e um item
  `["<unidade>", <Unidade>Test]` em `suites`, com o nome do arquivo. O runner
  imprime `SUITE <unidade> casos=N`, e o `ci/unit.sh` reprova arquivo de teste
  que não está importado, que ficou fora de `suites` ou que não rodou nenhum caso.
- Nada de hora real: passe datas fixas às funções
  (`new Date(2026, 0, 10, 12, 0)`). O `ci/unit.sh` fixa
  `TZ=America/Sao_Paulo`.
- Se um caso muda o estado de um singleton (`Config`, `Brightness`,
  `SystemStats`…), guarde o valor antes e restaure o original no fim do caso.

## Cobertura

A cobertura é por função, e o escopo que bloqueia está em `tests/coverage.json`:

- toda a lógica de `core/`, menos `core/widgets` (interface) e `core/config`
  (dado); um arquivo novo em `core/` entra sozinho;
- as funções puras dos serviços, listadas por nome: as que não chamam
  processo, arquivo, D-Bus, PipeWire, rede nem Hyprland.

**100% das funções do escopo precisam ser chamadas pelos testes**: função nova
no escopo sem teste reprova o PR. Uma função do escopo que não tem como ser
testada (um handler de IPC que só repassa a chamada, um sinal do Hyprland)
entra em `exceções`, com o motivo. Função de serviço nova e pura entra na lista
de `serviços`, com teste. Declare as funções como `function nome(...) {` numa
linha só: é o padrão que a instrumentação reconhece.

A fumaça mede, sem bloquear, a cobertura de todas as funções do shell
(unidade e fumaça juntas); o relatório fica no resumo do check `smoke`.

## Fluxo de PR

1. Crie uma branch a partir do `main` (`feat/<assunto>`, `fix/<assunto>`).
2. Rode `dev/ci.sh` antes de abrir o PR.
3. Abra o PR para o `main` preenchendo o modelo: resumo, como foi testado e o
   checklist.
4. Os quatro checks (`lint`, `rules`, `unit`, `smoke`) precisam passar, a
   branch precisa estar em dia com o `main` e as conversas do PR, resolvidas.
5. O merge é sempre por merge commit, com o título e a descrição do PR.
   Ninguém empurra direto no `main`.

Vulnerabilidade de segurança não vai em issue nem em PR: veja o
[`SECURITY.md`](SECURITY.md).
