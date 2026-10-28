# O conteúdo dos painéis na janela da forma — plano de implementação

> **Para agentes:** SUB-SKILL OBRIGATÓRIO: use superpowers:subagent-driven-development (o método já escolhido) para implementar este plano tarefa por tarefa. Os passos usam checkbox (`- [ ]`) para acompanhamento.

**Objetivo:** uma janela por monitor, sempre mapeada, com a forma da moldura e o conteúdo da barra, do painel superior, da central, do OSD e dos popups. O painel desliza com o fundo desde o primeiro quadro e fecha com a mesma mola. Abrir não cria janela nem contexto GL.

**Arquitetura:** a janela nova `core/widgets/FrameWindow.qml` (uma por tela) desenha a `FrameShape` no fundo e recebe como filhos os itens das features. A composição fica no `shell.qml`, porque uma feature não importa outra (`ci/rules.py`, regra `camadas`). Cada feature vira um `Item` por tela (`required property var screen`), visível só onde o painel dela está (`here = State.screen === screen`). A máscara de entrada é a união dos `FrameInput` ativos da tela, registrados no `Frame` como os `FrameBlob`. O teclado fica em `OnDemand` só enquanto há uma entrada com `keyboard` na tela. O clique fora fecha pelo `HyprlandFocusGrab` do `Panels`, que passa a valer também para os painéis da moldura. Sem nada à mostra, a janela encolhe para 1 px na borda direita (`Frame.extentOn`) e para de pagar o desfoque da tela inteira. Ela muda de tamanho só na troca de nível (1 px, coluna, coluna larga, tela cheia), nunca a cada quadro.

**Tecnologia:** QML do Quickshell 0.3.2, Qt 6; testes em `tests/*.test.js` pelo `tests/runner.qml`; fumaça no `sway` headless (`ci/smoke.sh`); medição e conferência visual no container `lucerna-polish` (Hyprland 0.56 aninhado, `dev/test.sh`).

**Spec:** `docs/superpowers/specs/2026-10-28-conteudo-janela-forma-design.md` (leia inteiro); o anterior, `docs/superpowers/specs/2026-10-27-paineis-moldura-design.md`. **Referência (só leitura):** `~/Documentos/projetos/caelestia-lab/shell/modules/drawers/ContentWindow.qml` (janela única, `HyprlandFocusGrab`, máscara por regiões, popups na mesma janela), `drawers/Panels.qml`, `dashboard/Wrapper.qml` (`offsetScale`, `opacity = 1 - offsetScale`).

## Global Constraints

- **Branch:** `feat/conteudo-janela-forma` (já existe, com o spec em `d2d71bb` sobre a `main` `9afba51`), no checkout principal (o `dev/test.sh` monta o checkout de onde é chamado). Merge pelo controlador, por merge commit, depois da revisão final (Opus) e do CI verde.
- **Nunca tocar** o container `lucerna-dev` nem o repositório `caelestia-lab`. **Sem `hyprctl reload`** no container (derruba a saída aninhada). Testes sem hardware, sem D-Bus real, sem a sessão real do usuário. **Sem áudio:** o OSD é disparado pelo brilho falso (`ipc brightness up/down`), nunca pelo volume.
- Regras do shell: `qmllint` com 0 avisos; camadas do `ci/rules.py`; a regra `animações` (nada de `type: cond ? … : …` num `Behavior` fora do `targetValue`); funções numa linha `function nome(...) {`; 100% das funções do escopo do `tests/coverage.json` (`core/`, fora `core/widgets/` e `core/config/`) chamadas pelos testes; um teste que muda um singleton restaura o estado no fim.
- **Não regredir:** `Frame.measure`/`Frame.sizeOn` (PR #60: forma e conteúdo pelo mesmo tamanho medido); a cascata da central (PR #61: Ações e depois as Notificações crescendo a partir delas); o desfoque com `xray` nos três níveis, inclusive nos cantos côncavos; `WallpaperState.blurCovers` (pausa o papel só com painel que não é a pílula, pelo `Frame.windows` com `targetScreen`, `visible` e `parts`).
- **Ordem das camadas para quem olha:** os centralizados (launcher, configurações, área de transferência, energia, temas, visão geral, captura) acima de tudo da moldura, porque são criados ao abrir; dentro da janela da forma, de baixo para cima: forma, popups, OSD, central, barra, painel superior. Os popups continuam escondidos com a central aberta (`NotificationsState.popupsHidden`).
- **O movimento:** o conteúdo desliza com o fundo desde o 1º quadro, com opacidade `Frame.clamp(progresso)`; a abertura e o fechamento do painel superior, da central e do OSD usam `Anim.Spatial` (a mesma mola). A passagem do zero na volta da mola só esconde o pedaço (`visible: progresso > 0`, `Frame.isActive`). A barra (revelar e esconder) fica como está.
- **Teclado:** `WlrKeyboardFocus.OnDemand` só com uma entrada `keyboard` ativa na tela (o painel superior e a central abertos); fora disso `None`. Nunca `Exclusive` na janela da forma (o Hyprland mandaria todo clique para ela, mesmo fora da máscara).
- **Nada redesenha parado:** com tudo parado, a janela da forma não apresenta quadros (o bench conta).
- Textos e comentários em pt-BR com acentos; nomes de código em inglês; commits no estilo `Moldura: o OSD na janela da forma`.
- Verificação de toda tarefa: `dev/ci.sh lint rules unit` verde. Na Tarefa 8, também `smoke`.

## Review Focus

1. **Digitar num app logo depois de fechar um painel** (Esc ou atalho, com o fechamento ainda animando): as teclas vão para o app. O teclado sai no começo do fechamento, não no fim da mola. Teste: `frame: o teclado só com painel que precisa` (Tarefa 2: entrada ativa fechando, com `keyboard` falso, dá `None`), mais a conferência no container da Tarefa 4.
2. **Clicar em qualquer lugar com nada aberto** (a janela sempre mapeada por cima de tudo): o clique cai no app de baixo. Teste: `frame: sem nada à mostra, nenhuma entrada e a janela de 1 px` (Tarefa 2), mais o clique num `kitty` no container (Tarefa 2).
3. **OSD repetido rápido** (brilho segurado: o OSD reabre no meio do fechamento): a janela não muda de tamanho a cada quadro e o OSD não pisca. Teste: `frame: o OSD deslizando fica na coluna` (Tarefa 2), mais a tira de quadros com reabertura na Tarefa 3.
4. **Duas telas:** o painel aberto na A não aparece nem pega o teclado na B, e o mouse passando para a B no meio da animação não o leva junto. Teste: `frame: cada tela só vê as próprias entradas` (Tarefa 2).
5. **A tela muda de tamanho com a janela encolhida** (1 px ou coluna): a altura continua medida e a largura medida antes fica (PR #60). Teste: `frame: a janela estreita não apaga a largura medida` (Tarefa 2).

---

### Task 1: O bench dos painéis e a medição de base

**Files:**
- Create: `dev/bench-paineis.sh`, `dev/bench-paineis.py` (o leitor do log e dos vídeos, só a biblioteca padrão), `dev/tira.sh`, `docs/superpowers/bench/2026-10-28-paineis-base.txt`

**Interfaces:**
- Produces: `dev/bench-paineis.sh [ciclos] [segundos]` (padrão 10 e 10), rodado **dentro** da sessão Hyprland com o Lucerna. No container: `dev/test.sh run 'bash ~/.config/quickshell/lucerna/dev/bench-paineis.sh 10 10'`. No padrão do `dev/bench-blur.sh`: exige `HYPRLAND_INSTANCE_SIGNATURE`; acha os PIDs do Hyprland e do `qs`; CPU pelo `/proc/<pid>/stat`; `trap` que restaura tudo. Não faz `hyprctl keyword`/`eval`/`reload`.
  - Reinicia o `qs` com `QT_LOGGING_RULES='qt.scenegraph.time.renderloop.debug=true'` e a saída em `$BENCH_OUT/qs.log` (padrão `/tmp/lucerna-bench`), e espera o IPC responder (`panels get`). No fim (e no Ctrl+C): `panels close`, devolve o `blur get` e o `wallpaper get` guardados, mata o `kitty` dele e sobe o `qs` normal (`setsid -f qs -c lucerna > /dev/null 2>&1 < /dev/null`, como o `restart` do `dev/test.sh`).
  - Cada caso marca o número de linhas do log antes e depois de cada trecho, e o `.py` lê só as linhas do trecho.
  - Os casos, nesta ordem:
    - `painel-superior`: N ciclos de `panels open dashboard` e `panels close`, segurando 1,2 s.
    - `central`: N ciclos de `central open ""` e `panels close`.
    - `osd`: N ciclos de `brightness up` com 2,5 s de espera, alternando com `brightness down`. Sem tela no `brightness list`, a linha sai com `-`.
    - `papel`: `wallpaper mode animated` e o painel superior aberto por S s.
    - `janela`: um `kitty` com o laço de 16 ms do `dev/bench-game.sh` e a central aberta por S s.
    - `parado`: nada aberto por S s.
    - `parado-painel`: o painel superior aberto e parado; mede S s depois de 2 s.
  - Nos casos de ciclo, cada abertura e cada fechamento é uma fatia de 0,6 s logo depois do IPC.
  - Colunas da tabela (uma linha por caso):
    - `FPS shell`: média, sobre as fatias, do maior número de `frame rendered` de uma janela do `qs` (`[window 0x…]`) dividido pela duração. Nos casos contínuos, sobre o caso inteiro.
    - `FPS mín`: a pior fatia.
    - `pior ms`: o maior entre o `frame rendered in Xms` e a soma `polish+lock+blockedForSync+animations` do `Frame prepared`.
    - `longos`: quantos quadros têm mais de 20 ms.
    - `quadros`: o total de quadros do `qs` no caso. Nos casos `parado*`, o critério do "sem redesenho parado".
    - `qs %` e `Hyprland %`: CPU.
    - `FPS tela`: os quadros que o `wf-recorder` (sem `-D`, guiado por dano) grava por segundo nas fatias, contados pelo `ffprobe`; `-` sem `wf-recorder`.
  - Na última linha, o RSS do `qs` (`VmRSS`) antes do primeiro caso e depois do último.
  - Com `BENCH_REC=1`, só grava os três casos de ciclo em `$BENCH_OUT/<caso>.mkv`, sem medir.
- Produces: `dev/tira.sh VIDEO SAIDA.png INÍCIO DURAÇÃO [colunas]`: a tira de quadros numerados (o `strip.sh` da investigação: `ffprobe` conta os quadros, `ffmpeg … tile`). Roda no host, sobre o vídeo copiado com `docker cp lucerna-polish:/tmp/lucerna-bench/<caso>.mkv`.

- [ ] **Step 1:** escrever os três arquivos. `bash -n` e `shellcheck` sem aviso; `python3 -I dev/bench-paineis.py --self-test` confere o leitor com umas linhas de log de exemplo embutidas (o formato de `qt.scenegraph.time.renderloop`: `[window 0x7f9cb4a318c0][render thread …] syncAndRender: frame rendered in 3ms, sync=0, render=2, swap=1`).
- [ ] **Step 2:** rodar na branch atual (igual à `main` no código) para validar o bench: `dev/test.sh up`, depois o comando acima. Esperado: a tabela completa, `parado` com 0 a 2 quadros, e o `qs` de volta (`dev/test.sh ipc panels get` responde).
- [ ] **Step 3: A base.** Num worktree em `9afba51` no scratchpad (`git worktree add <scratchpad>/base 9afba51`), copiar os três arquivos (sem commit lá), rodar `<scratchpad>/base/dev/test.sh up` (ele monta o worktree no `lucerna-polish`) e o bench duas vezes. Guardar as duas tabelas, com o blur e o tamanho da janela de teste, em `docs/superpowers/bench/2026-10-28-paineis-base.txt`. Depois, `dev/test.sh up` de novo pelo checkout principal e `git worktree remove`.
- [ ] **Step 4:** `dev/ci.sh lint rules` → verde (`shellcheck` e `ruff` passam nos arquivos novos).
- [ ] **Step 5: Commit** `Bench: FPS e CPU dos painéis da moldura, com a base da main`.

### Task 2: A janela da forma em `core` e a barra dentro dela

**Files:**
- Create: `core/widgets/FrameWindow.qml`, `core/frame/FrameInput.qml`, `features/bar/ui/BarLayer.qml` (de `BarWindow.qml`, com `git mv`)
- Modify: `core/frame/Frame.qml`, `core/panels/Panels.qml`, `core/widgets/FrameShape.qml` (só os comentários do `compactOn`), `features/bar/ui/Bar.qml` (só os `BarTrigger`), `features/bar/ui/PillLayout.qml` (o `Region` sai), `features/bar/state/BarState.qml` (saem `registerSurface`/`unregisterSurface`), `features/themeSwitcher/state/ThemeSwitcherState.qml` (`noAnimLua`), `shell.qml`
- Test: `tests/frame.test.js`, `tests/panels.test.js`, `tests/themeswitcher.test.js`

**Interfaces:**
- Produces (`FrameInput`, `QtObject`, no molde do `FrameBlob`): `property var screen`, `property bool active`, `property rect rect` (coordenadas da tela), `property bool keyboard: false`; registra no `Component.onCompleted` (`Frame.registerInput`) e sai no `onDestruction`.
- Produces (`Frame`):
  - `property var inputs: []`, `registerInput(input: var): void`, `unregisterInput(input: var): void`;
  - `inputsOn(screen: var): var` (as ativas daquela tela);
  - `keyboardOn(screen: var): bool` (alguma entrada ativa da tela com `keyboard`);
  - `readonly property real idleWidth: 1`, `readonly property real wideColumn: 420`;
  - `extentOn(parts: var, inputs: var, frame: real, size: size): real` no lugar do `compactOn`. Devolve:
    - `size.width` com `frame > 0`;
    - senão, o menor entre `column` e `wideColumn` que cobre todo `part.rect.x - reach` e todo `input.rect.x`;
    - `size.width` se nenhum dos dois cobre;
    - `idleWidth` sem pedaço nem entrada.
- Produces (`FrameWindow`, `PanelWindow`):
  - `required property var targetScreen`; `readonly property var parts` (`Frame.blobsOn`), `fuse` (`Frame.progressIn`), `extent` (`Frame.extentOn(parts, Frame.inputsOn(targetScreen), fuse, screenSize)`), `full` (`extent >= screenSize.width`);
  - `default property alias content` num `Item` em coordenadas da tela (`x: width - screenSize.width`, tamanho `screenSize`), por cima da `FrameShape`;
  - sempre `visible`; âncoras `top`/`bottom`/`right` e `left: full`; `implicitWidth: extent`;
  - `WlrLayer.Overlay`, namespace `lucerna-panel-frame`, `ExclusionMode.Ignore`;
  - `mask`: um `Region` cuja lista `regions` são as `instances` de um `Variants` sobre `Frame.inputsOn(targetScreen)`, cada uma com o `rect` menos a origem da janela;
  - `WlrLayershell.keyboardFocus: Frame.keyboardOn(targetScreen) ? OnDemand : None`;
  - mede como a `BarWindow` (`Frame.measure(targetScreen, full ? width : 0, height)`);
  - `Frame.addWindow` e `Panels.register` na criação, e o contrário na destruição.
  - Sem funções próprias (fica em `core/widgets`, fora da cobertura, como o `OverlayPanel`).
- Produces (`Panels`): `readonly property var framedPanels: ["dashboard", "central"]`; `grabWanted(opened: var): bool` (algum aberto, e todo modal aberto está em `framedPanels`); o `HyprlandFocusGrab` com `active: root.grabWanted(root.opened) && !root.rearming`.
- Produces (`BarLayer`, `Item`): `required property var screen`, com o que a `BarWindow` tinha de barra: o `progress` e o `Behavior` dele sem mudar, o `FrameBlob` da pílula e o `PillLayout`. A `Row` do `PillLayout` fica com `enabled: morph <= 0`. Tem um `FrameInput { active: shown && morph <= 0; rect: layout.shape }`. Saem o `lingering`, o `Timer` e o `Connections` do `frameSwapped`.
- `shell.qml`: um `Variants` sobre `Quickshell.screens` com um `FrameWindow` por tela e, dentro dele, o `BarLayer { screen: … }`. As tarefas seguintes põem os outros itens na ordem da seção Global Constraints.
- `noAnimLua()` → `hl.layer_rule({ match = { namespace = "^lucerna-(panel-frame|frame-.*)$" }, no_anim = true })` (o `frame-.*` sai na Tarefa 7).

- [ ] **Step 1: Testes que falham** (`tests/frame.test.js`, no `scenario` de hoje, que também restaura o `F.inputs`):
  - `frame: as entradas de cada tela` (`inputsOn` filtra a tela e o `active`).
  - `frame: cada tela só vê as próprias entradas` (uma entrada com teclado na A: `keyboardOn("A")` verdadeiro, `keyboardOn("B")` falso, `inputsOn("B")` vazio).
  - `frame: o teclado só com painel que precisa` (só a pílula: falso; o painel superior com `keyboard`: verdadeiro; o mesmo fechando, `active` e `keyboard` falso: falso).
  - `frame: sem nada à mostra, nenhuma entrada e a janela de 1 px` (`extentOn([], [], 0, size)` = `F.idleWidth`, `inputsOn` vazio).
  - `frame: a largura da janela da forma`, no lugar do teste do `compactOn`:
    - o OSD na coluna dá `column`;
    - os popups com `rect.x = size.width - 404` dão `wideColumn`;
    - os popups e o OSD juntos dão `wideColumn`;
    - com moldura, ou com um pedaço fora das colunas, dá `size.width`.
  - `frame: o OSD deslizando fica na coluna` (o `rect` do OSD com o `grown` de 0,05 a 1,1, como no `Osd.qml`, dá sempre `column`).
  - `frame: a janela estreita não apaga a largura medida` (`measure(A, 1920, 1080)` e depois `measure(A, 0, 1000)` com a mesma tela informada: `sizeOn` = 1920 × 1000).
  - Em `tests/panels.test.js`: `panels: o grab também nos painéis da moldura`. `grabWanted([])` falso; `["dashboard"]` e `["central"]` verdadeiros; `["launcher"]` e `["settings"]` (base sozinha, modal) falsos; com `panelsTogether: ["dashboard"]`, `["settings", "dashboard"]` verdadeiro. Restaura `opened` e a config.
  - Em `tests/themeswitcher.test.js`: a regra `no_anim` traz `panel-frame`.
- [ ] **Step 2:** `dev/ci.sh unit` → falha.
- [ ] **Step 3: Implementar** o `Frame`, o `FrameInput`, o `FrameWindow`, o `Panels`, o `BarLayer` e o `shell.qml`; apagar o `compactOn` e o teste dele.
- [ ] **Step 4:** `dev/ci.sh lint rules unit smoke` → verde (a fumaça confere o `click_pill` e o `hover_pill` com a barra na janela nova).
- [ ] **Step 5: Conferir no container** (`dev/test.sh up`):
  - a barra aparece e some pelo topo e pela troca de workspace, igual à `main`;
  - o clique na hora abre o painel superior (ainda na janela antiga, por cima);
  - com nada aberto, um clique num `kitty` em tela cheia, no meio e no canto de cima à direita, cai no `kitty`;
  - o `hyprctl layers` mostra o `lucerna-panel-frame` com 1 px de largura em repouso;
  - o bench, só os casos `parado` e `papel`, não fica pior que a base.
- [ ] **Step 6: Commit** `Moldura: a janela da forma sempre mapeada, com a barra dentro`.

### Task 3: O OSD na janela da forma

**Files:**
- Modify: `features/osd/ui/Osd.qml` (vira `Item`), `shell.qml`
- Test: `tests/osd.test.js` (só se a lógica do estado mudar; a do `here` fica na UI)

**Interfaces:**
- Consumes: `FrameWindow` (o item filho, em coordenadas da tela), `Frame.clamp`.
- Produces (`Osd`, `Item`): `required property var screen`, `readonly property bool here: OsdState.screen === screen`. O `shown` usa `OsdState.shown && here`, com `Behavior { Anim { type: Anim.Spatial } }` nos dois sentidos. O `FrameBlob` fica com `screen: root.screen`. O conteúdo vai em coordenadas da tela, com `x` saindo da borda direita como hoje, e `opacity: Frame.clamp(shown)`. Sem `FrameInput` (não recebe cliques). Saem o `PanelWindow`, o `mask`, o namespace e o `Frame.isReady`.

- [ ] **Step 1:** mudar o `Osd.qml` e pôr o `Osd { screen: … }` no `FrameWindow` do `shell.qml`, entre os popups (ainda fora) e a barra, na ordem da seção Global Constraints.
- [ ] **Step 2:** `dev/ci.sh lint rules unit` → verde.
- [ ] **Step 3: Conferir no container** com o `BENCH_REC=1` só do `osd` e uma tira (`dev/tira.sh`) de 3 ciclos.
  - **Esperado:** desde o 1º quadro, o número e a trilha saem da borda junto com o fundo, sem fundo vazio. O fechamento é a mesma mola ao contrário. Nenhum quadro com conteúdo fora do fundo.
  - Repetir com `brightness up` três vezes em 0,3 s (reabrindo no meio do fechamento): sem piscar.
  - `hyprctl layers`: a janela fica na coluna durante o OSD e volta a 1 px depois.
- [ ] **Step 4: Commit** `Moldura: o OSD na janela da forma, deslizando com o fundo`.

### Task 4: O painel superior na janela da forma

**Files:**
- Modify: `features/dashboard/ui/Dashboard.qml` (vira `Item`), `shell.qml`

**Interfaces:**
- Consumes: `FrameInput` (com `keyboard`), `Panels.grabWanted` (o clique fora fecha pelo grab), `Frame.pillOn`, `Frame.clamp`.
- Produces (`Dashboard`, `Item`): `required property var screen` e `here: DashboardState.screen === screen`.
  - `open: DashboardState.open && here`. O `progress` sai do `Behavior` antigo do `OverlayPanel`, agora `Anim.Spatial` nos dois sentidos.
  - O `FrameBlob` fica com `screen: root.screen`.
  - O `drawer` cresce da aba como hoje. O conteúdo (`contentScope`) fica preso **ao pé** do `drawer` (`y = drawer.height - altura cheia`), recortado por ele, com `opacity: Frame.clamp(progress)`: ele desce com o fundo desde o 1º quadro. Sai o `inset` (`Frame.contentInset`).
  - O véu (`dim` do `OverlayPanel`: `ThemeManager.dark ? 0.4 : 0.22`, vezes o progresso) cobre a tela inteira por baixo do `drawer`, só com o painel modal (`Panels.isModal("dashboard")`). Fica como hoje, por cima da forma.
  - `FrameInput { screen: root.screen; active: open || progress > 0; rect: <o drawer em coordenadas da tela>; keyboard: open }`.
  - O `contentScope` ganha `Keys.onEscapePressed: DashboardState.close()` e o `forceActiveFocus()` ao abrir.

- [ ] **Step 1:** mudar o `Dashboard.qml` e pô-lo no topo do `FrameWindow` no `shell.qml`.
- [ ] **Step 2:** `dev/ci.sh lint rules unit` → verde.
- [ ] **Step 3: Conferir o teclado e o clique no container**, com um `kitty` focado num workspace com janela:
  - `panels open dashboard`, depois `wtype` de Tab (com o enchimento do `dev/test.sh`, se a tecla precisar): a aba muda, e o Esc fecha.
  - Logo depois do Esc, `wtype abc`: o `abc` chega ao `kitty`, mesmo com o fechamento ainda animando.
  - Um clique na moldura fora do painel (`vclick` ou `wtype`/`ydotool` do container) fecha o painel.
  - Com o painel acompanhante (`setc 'dict(panelsTogether=["dashboard"])'`): abrir as Configurações e depois o painel superior. Anotar no relatório que ele fica **abaixo** das Configurações (decisão do spec: os centralizados acima), com uma captura.
  - **Se o teclado não chegar ao painel pelo grab, pare e reporte ao controlador; não troque para `Exclusive`.**
- [ ] **Step 4: Conferir o movimento:** a tira de 3 ciclos do `painel-superior` (`BENCH_REC=1`). Esperado: a aba alarga e desce, e o cabeçalho e as páginas descem com o pé do fundo desde o 1º quadro. O conteúdo da barra esmaece como hoje. O fechamento é a mesma mola ao contrário, sem corte seco no fim.
- [ ] **Step 5: Commit** `Moldura: o painel superior na janela da forma, deslizando com o fundo`.

### Task 5: A central na janela da forma

**Files:**
- Modify: `features/central/ui/Central.qml` (vira `Item`), `features/central/ui/CentralPanel.qml`, `shell.qml`
- Test: `tests/central.test.js` (se a lógica do `sync` sair para o estado; senão, nada novo)

**Interfaces:**
- Produces (`Central`, `Item`): `required property var screen` e `here: CentralState.screen === screen`.
  - O `sync()` lê `actionsWanted = CentralState.actionsOpen && here` e `inboxWanted = CentralState.notificationsOpen && here` no lugar do estado cru. Assim a central só entra na tela dela, e a cascata do PR #61 (`both`, `reserve`, `reveal`) fica igual.
  - O `reserveAnim` passa a usar `Anim.Spatial` nos dois sentidos.
  - O `FrameBlob` fica com `screen: root.screen`.
  - Duas `FrameInput` com `active: <painel>.visible`, o `rect` de cada painel (`x`, `y`, `width`, `shownHeight`) e `keyboard: CentralState.open && here`.
  - O `focusSink` ganha o `Keys.onEscapePressed: CentralState.close()` e fica com o foco ao abrir, como hoje.
- Produces (`CentralPanel`): `opacity: Frame.clamp(shown)`; o `leaving` com `Anim.Spatial`. O resto (o `enter` reaberto no meio da saída, a ordem e os 40 ms da cascata) fica como está.

- [ ] **Step 1:** mudar os dois arquivos e pôr `Central { screen: … }` entre o OSD e a barra no `shell.qml`.
- [ ] **Step 2:** `dev/ci.sh lint rules unit` → verde.
- [ ] **Step 3: Conferir no container:**
  - a tira de 3 ciclos da `central`: os dois painéis entram deslizando com o fundo desde o 1º quadro, em cascata, e as Notificações crescem a partir das Ações;
  - `controls toggle ""` com as Notificações abertas: elas sobem com mola, sem pular;
  - o clique na hora da barra com a central aberta abre o painel superior (como no `click_pill` da fumaça);
  - o Esc fecha;
  - o clique fora fecha;
  - com a central aberta, os popups continuam escondidos.
- [ ] **Step 4: Commit** `Moldura: a central na janela da forma, deslizando com o fundo`.

### Task 6: Os popups na janela da forma, abaixo dos painéis

**Files:**
- Modify: `features/notifications/ui/NotificationPopups.qml` (vira `Item`), `ci/rules.py` (saem as duas entradas do `QMLLINT_ALLOWED` desse arquivo e a do `Osd.qml`), `shell.qml`

**Interfaces:**
- Produces (`NotificationPopups`, `Item`): `required property var screen` e `here: NotificationsState.screen === screen`.
  - A coluna da direita em coordenadas da tela: 380 de largura, a `Frame.thickness + ThemeManager.spacing.small` da borda de cima e da direita, até o pé da tela.
  - O `ListView` fica com `model` só no `here` e com os popups à mostra (`hasPopups || linger.running`, e não `popupsHidden`). Fora disso, `[]`, sem delegados duplicados nas outras telas.
  - `FrameInput { active: <à mostra>; rect: <o contentItem da lista, mapeado para a tela> }`.
  - Sem o namespace próprio: o desfoque passa a vir do `lucerna-panel-frame` (a mesma regra `lucerna-panel-*`, com o mesmo `ignore_alpha`).
  - É o primeiro filho do `FrameWindow` (o mais baixo). Com os popups sozinhos, a janela fica na `wideColumn` (Tarefa 2).

- [ ] **Step 1:** mudar o arquivo, o `shell.qml` e o `ci/rules.py`.
- [ ] **Step 2:** `dev/ci.sh lint rules unit` → verde.
- [ ] **Step 3: Conferir no container:**
  - `notify-send` três vezes: os cartões entram e saem deslizando como na `main`, com o desfoque atrás, e o clique numa ação do cartão funciona;
  - `hyprctl layers`: a janela fica na coluna larga e volta a 1 px depois do `linger`;
  - com `LUCERNA_TEST_SIZE=1366x768` no `up` e o painel superior aberto, um `notify-send` aparece **por baixo** do painel (captura);
  - o mesmo com o OSD, com 6 popups empilhados até o meio da tela;
  - o resumo do modo jogo (cartão do topo) ainda abre as notificações no clique.
- [ ] **Step 4: Commit** `Moldura: os popups na janela da forma, abaixo dos painéis`.

### Task 7: A limpeza do caminho antigo e as Pendências

**Files:**
- Modify:
  - `core/widgets/OverlayPanel.qml`: sai todo o caminho da moldura (`frameScreen`, `framed`, `area` pelo `Frame.sizeOn`, `pillMask`, `measure`, o namespace `lucerna-frame-*`, o `Frame.isReady`) e o import `qs.core.frame`, se sobrar sem uso.
  - `core/frame/Frame.qml`: saem `contentStart`, `contentInset`, `contentOpacity` e `isReady`; os comentários do topo passam a descrever a janela única. Ficam `windows`, `addWindow` e `removeWindow` (o `WallpaperState` usa).
  - `features/themeSwitcher/state/ThemeSwitcherState.qml`: `noAnimLua` → `"^lucerna-panel-frame$"`.
  - `Lucerna — Pendências.md`.
- Test: `tests/frame.test.js` (saem as partes do `isReady` e do `contentOpacity`), `tests/themeswitcher.test.js`

- [ ] **Step 1:** `grep -rn "contentOpacity\|contentStart\|contentInset\|isReady\|frameScreen\|lucerna-frame-\|BarWindow\|compactOn" core features tests shell.qml ci` → só o que esta tarefa apaga. Apagar, e ajustar os testes e os comentários que citam o caminho antigo (`FrameShape`, `FrameBlob`, `Central`, `CentralPanel`, `PillLayout`).
- [ ] **Step 2:** `dev/ci.sh lint rules unit` → verde. A cobertura continua 100% sem exceção nova.
- [ ] **Step 3: Pendências:**
  - Marcar `[x]` no "O conteúdo dos painéis na mesma janela da forma", com o resumo e a referência à branch.
  - Marcar `[x]` no "A janela da forma volta à tela inteira quando o OSD acaba" e no "O `lingering` da `BarWindow`…" (os dois somem com a janela sempre mapeada).
  - Atualizar a nota de "A barra revelada pelo mouse custa mais que na `main`" e de "A barra em repouso ainda custa o desfoque da tela inteira": continuam abertos (fora do escopo, decisão do usuário); a janela agora é `lucerna-panel-frame` e encolhe a 1 px só sem nada à mostra.
  - Reler o "O Esc na central aberta pelo atalho com uma janela focada por baixo": agora vai pelo grab, e o item é conferido na Tarefa 8.
  - Novo item, se a Tarefa 4 confirmou: "O painel superior acompanhante fica abaixo das Configurações".
- [ ] **Step 4: Commit** `Moldura: sem o caminho antigo das janelas dos painéis`.

### Task 8: Medição final, tiras de quadros, fumaça e PR

**Files:**
- Create: `docs/superpowers/bench/2026-10-28-paineis-final.txt`
- Modify: `ci/smoke.sh` (só se um passo quebrar por causa da janela única, explicando), `Lucerna — Pendências.md` (sobras da revisão)

- [ ] **Step 1:** `dev/ci.sh lint rules unit smoke` → verde. Na fumaça, o `click_pill` e o `hover_pill` continuam passando.
- [ ] **Step 2: Medição final:** `dev/test.sh up` e o bench duas vezes, com o mesmo blur e o mesmo tamanho da base. Gravar em `…-final.txt` com uma tabela base × final por caso.
  - **Critério:** `FPS shell`, `FPS mín` e `FPS tela` iguais ou maiores; `pior ms` abaixo de 20 nos casos de ciclo (sem o engasgo de 43–51 ms); `qs %` e `Hyprland %` iguais ou menores, com tolerância de ±1 ponto de ruído; `quadros` dos `parado*` em 0 a 2; o RSS final sem crescer além de 5 MB do inicial.
  - **Se algum caso piorar, pare e reporte ao controlador com a tabela:**
    - não ajuste o bench para passar;
    - um `parado` com quadros indica uma animação viva em item escondido: achar o item e prendê-la a `here && progresso > 0`.
- [ ] **Step 3: Tiras de quadros** (`BENCH_REC=1` com 3 ciclos cada; `dev/tira.sh` da 2ª e da 3ª abertura e de um fechamento de cada um), na pasta de capturas do PR:
  - **Painel superior, central e OSD:** em cada quadro, o conteúdo dentro do fundo, deslizando desde o 1º quadro; o fechamento com a mesma mola.
  - **Central em câmera lenta:** com `Config.animationScale` 5, a cascata.
  - **Desfoque nos três níveis** (`blur set full|performance|off`): captura com a central aberta, cantos côncavos inclusive.
- [ ] **Step 4:** a revisão final da branch (Opus) e as sobras dela nas Pendências.
- [ ] **Step 5: Commit** `Bench: a medição final dos painéis na janela da forma`, `git push` e o PR (`gh pr create`, conta `EduardoSA8006`, repositório da org `lucerna-desktop`). No corpo: a tabela base × final, as tiras, e o que fica para a máquina real (144 Hz, o grab no Hyprland de verdade, o `hyprctl reload`).
