# O conteúdo dos painéis na janela da forma

**Data:** 2026-10-28
**Repositório:** `lucerna-shell`
**Parte de:** a `main` com o PR #61 (9afba51: o tipo da animação pelo `targetValue` e a altura da central animada).
**Referência:** o Caelestia Shell (`~/Documentos/projetos/caelestia-lab/shell`, só leitura): `modules/drawers/ContentWindow.qml` (uma janela por monitor, sempre mapeada, com a forma e o conteúdo dos painéis), `modules/drawers/Panels.qml` e os painéis em `modules/*/Wrapper.qml` (o painel desliza da borda com `offsetScale` e `opacity = 1 - offsetScale`, a mesma mola na ida e na volta).
**Spec anterior:** `docs/superpowers/specs/2026-10-27-paineis-moldura-design.md`.
**Investigação:** relatórios e tiras de quadros no scratchpad da sessão (`sheet-dash-open-*`, `sheet-central-open-slow5x.png`, `qs-timing.out`).

## Por quê

Hoje a forma da moldura é desenhada na janela da barra (uma por monitor), e o conteúdo do painel superior, da central e do OSD fica numa janela própria de cada painel (`OverlayPanel`), criada a cada abertura. Isso causa:

- **O painel "aparece pronto":** o fundo cresce vazio e o conteúdo só entra quando a forma passa de ~70% (`Frame.contentStart`), nos últimos ~6 quadros. O conteúdo entra tarde de propósito, para esconder o descompasso entre as duas janelas.
- **Engasgo no começo:** cada abertura cria uma janela e um contexto GL novos; o primeiro quadro trava o processo do shell inteiro por 43–51 ms no painel superior e ~20 ms na central.
- **Descompasso:** o conteúdo às vezes chega à tela 5–14 ms depois da forma.
- **Custo:** duas superfícies redesenhando a cada quadro; a central gasta perto do dobro de CPU da `main` antiga ao abrir, e a moldura em geral está 3–9 FPS abaixo da `main` antiga.

O usuário quer a fluidez do Caelestia, e o desempenho pesa muito para ele (monitor de 144 Hz).

## Decisões do usuário

- **O conteúdo desliza junto com o fundo desde o primeiro quadro, como no Caelestia:** o painel (fundo e conteúdo) sai da borda como uma peça só; não há mais fundo vazio crescendo e conteúdo surgindo no fim.
- **O fechamento é o mesmo movimento ao contrário, estilo Caelestia:** a mesma mola desliza o painel de volta para a borda (não mais o fechamento rápido EmphasizedAccel de 200 ms que o PR #61 deixou).
- **Aprovado o resumo:** o conteúdo passa a morar na mesma janela da forma, uma por monitor e sempre aberta; o teclado só é pego enquanto houver painel aberto que precise dele, e fora disso os cliques passam para as janelas de baixo; os painéis centralizados ficam como estão; o sucesso se mede em FPS, igual ou melhor que hoje, sem redesenho com tudo parado.

## Objetivos

- Uma janela por monitor com a forma (moldura, barra fundida, fundos) e o conteúdo dos painéis da moldura: painel superior (dashboard, a barra que vira painel), central (borda direita) e OSD de volume e brilho (borda direita, no meio).
- Forma e conteúdo sempre no mesmo quadro: nenhum quadro com conteúdo fora do fundo ou fundo sem o conteúdo que deveria ter.
- Abrir um painel não cria janela nem contexto GL: nenhum engasgo no primeiro quadro.
- Abrir e fechar com a mesma mola (a Spatial de hoje, salvo ajuste para parecer o Caelestia), o conteúdo deslizando com o fundo; a barra fundida que vira o painel superior continua como hoje (a aba se alarga e cresce, o conteúdo da barra esmaece e o da aba entra), só que agora com o conteúdo do painel vindo junto.
- A cascata da central (Ações, depois Notificações crescendo a partir delas, do PR #61) continua, dentro da mesma janela.
- Desempenho: FPS e CPU iguais ou melhores que a `main` no commit em que esta branch começar (com o PR #61), nos casos: abrir/fechar o dashboard, a central e o OSD (aberturas repetidas); dashboard aberto com papel animado; central aberta com uma janela mudando atrás; tudo parado com e sem painel aberto. Nada redesenha com tudo parado; memória sem crescer em aberturas repetidas.
- O desfoque (opções Desempenho/Completo/Desligado, `xray` nas camadas `lucerna-panel-*`) continua funcionando na área da forma, inclusive nos cantos côncavos.

## Não objetivos

- O desfoque da tela inteira com a barra em repouso ou revelada (decisão do usuário, 2026-10-28: fica para depois, num PR próprio medido). A janela única fica em tela cheia, como no Caelestia; os itens "A barra em repouso ainda custa o desfoque da tela inteira" e "A barra revelada pelo mouse custa mais que na `main`" continuam abertos nas Pendências, com a nota atualizada.
- Mudar os painéis centralizados (launcher, configurações, área de transferência, menu de energia, seletor de temas, visão geral, captura).
- Mudar o visual da moldura, da barra ou dos painéis além do movimento.
- Navegação por teclado nova.
- Os popups de notificação (continuam cartões soltos, fora da moldura).

## Anti-objetivos

- Cliques ou teclado "presos": a janela sempre aberta não pode engolir cliques fora da forma nem pegar o teclado sem painel que precise dele (o usuário digitando numa janela comum não pode perder teclas).
- Redesenho constante com tudo parado (a janela sempre aberta não pode virar uma superfície que pinta todo quadro).
- Piorar o desempenho em qualquer caso medido.
- Desfoque da tela inteira com um painel pequeno aberto (a área de entrada e a região de desfoque acompanham a forma).
- Painel preso ao monitor errado; a correção de tamanho de tela do PR #60 (`Frame.measure`/`Frame.sizeOn`) não pode regredir.

## Restrições

- Quickshell/QML, organização feature-first + core + MVVM do repo; as regras do `ci/rules.py` (incluindo a nova regra de animações do PR #61); `dev/ci.sh` verde (lint, rules, unit, coverage, smoke).
- Hyprland 0.56 com config em Lua; regras de camada enviadas pelo shell (não à mão).
- Testes não tocam hardware, D-Bus real, a sessão real do usuário. Verificação visual no container `lucerna-polish`, com tiras de quadros antes/depois de aberturas e fechamentos repetidos (não só o primeiro).

## Decisões minhas (o usuário pode revisar)

- **Medição:** não existe hoje um bench de FPS dos painéis (`dev/bench-blur.sh` mede CPU/GPU por nível de desfoque; `dev/bench-game.sh` é do modo jogo). A primeira tarefa do plano é um `dev/bench-paineis.sh` no padrão dos outros, que roda os casos acima no container `lucerna-polish` e conta FPS e CPU; roda-se na `main` de partida (a base) e na branch no fim. A sessão real do usuário é KDE, então só o container mede; deixar o comando para o usuário medir a 144 Hz quando usar o Hyprland.
- **Ordem das camadas:** fica como hoje para quem olha. Os painéis centralizados continuam acima da moldura e dos painéis dela. Os popups de notificação continuam escondidos com a central aberta (decisão do spec anterior), então não disputam lugar com ela; com o painel superior ou o OSD à mostra, os painéis da moldura ficam acima dos popups, como hoje. Como a janela única é criada no início, o construtor garante essa ordem (camada diferente ou outro meio) sem mudar o comportamento sobre apps em tela cheia.

## O que fica para o construtor

- A organização interna: se a janela da barra vira a janela única (barra + forma + conteúdo) ou se nasce uma nova, e como os painéis viram componentes dentro dela em vez de `OverlayPanel` próprios.
- Como o teclado é pego (o `WlrLayershell.keyboardFocus` por estado, como o Caelestia, ou outro meio), desde que respeite o anti-objetivo.
- A área de entrada (máscara) e a região de desfoque acompanhando a forma, e como evitar redesenho parado.
- O que fazer com `Frame.contentStart`/`contentInset` (provavelmente somem).
- A mola exata e o deslocamento/opacidade do conteúdo durante o deslize, ajustados para parecer o Caelestia.
- Os testes de unidade da lógica nova e o que a fumaça confere.
- Atualizar o item "O conteúdo dos painéis na mesma janela da forma" nas Pendências e os itens que ele resolve.
