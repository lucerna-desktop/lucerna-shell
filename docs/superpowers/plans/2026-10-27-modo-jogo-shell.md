# Modo jogo no shell — plano de implementação

> **Para agentes:** SUB-SKILL OBRIGATÓRIO: use superpowers:subagent-driven-development (recomendado) ou superpowers:executing-plans para implementar este plano tarefa por tarefa. Os passos usam checkbox (`- [ ]`) para acompanhamento.

**Objetivo:** o shell lendo o modo jogo do `lucernad` e aplicando a parte dele (papel de parede, não perturbe com resumo, barra, ociosidade, ícone e avisos), com a chave no Painel, o atalho e a página "Modo jogo" nas Configurações.

**Arquitetura:** o `lucernad` é a fonte da verdade (`game.state`). O serviço novo `services/GameMode.qml` é o adaptador (dono `"game"`): assina os tópicos, manda o `game.configure` inteiro das preferências e expõe `active`/`since`/`reasons`/`effects`. Cada feature **deriva** o comportamento dele (nada do modo jogo é gravado no `Config` além das preferências). Lógica nos `state/` e no serviço; os `ui/` só mostram.

**Tecnologia:** QML do Quickshell 0.3.2, Qt 6; testes em `tests/*.test.js` pelo `tests/runner.qml`; fumaça no `sway` headless (`ci/smoke.sh`); conferência visual no container `lucerna-polish` (Hyprland 0.56.2).

**Spec:** `lucernad/docs/superpowers/specs/2026-10-27-modo-jogo-design.md` (no repositório do `lucernad`; leia inteiro, em especial "Decisões do assistente" D2, D13–D15, D17, D19–D22 e "Lado do shell"). **Depende de:** o plano `lucernad/docs/superpowers/plans/2026-10-27-modo-jogo.md`, seção "Formato" (o contrato). As Tarefas 1–5 só dependem do Formato e podem andar em paralelo com o `lucernad`; a Tarefa 6 precisa do SHA do merge do `lucernad` (`<LUCERNAD_REV>`).

## Global Constraints

- **Branch:** `feat/modo-jogo` (já criada a partir da `origin/main`, com este plano), no checkout principal (o `dev/test.sh` monta esse checkout). Merge do controlador por merge commit, depois da revisão final (Opus) e do CI verde (`lint`/`rules`/`unit`/`smoke`).
- Regras do shell: `qmllint` com 0 avisos; camadas do `ci/rules.py` (`features/*/ui` não importa `qs.services`; uma feature não importa outra; `core/` não importa `features` nem `services`); funções declaradas como `function nome(...) {` numa linha; 100% das funções do escopo do `tests/coverage.json` chamadas pelos testes (o `services/GameMode.qml` entra em `serviços` com todas as funções dele); um teste que muda um singleton restaura o estado no fim; **todo dado que chega do daemon passa por `Array.from` antes de `map`/`filter`/`find`**; os testes mandam os dados pelo caminho real (`client.received(tópico, JSON.parse(JSON.stringify(…)))`, a resposta pelo `client.receive` do `wired()`, como em `tests/web.test.js`); **disponível = `client.connected && error === ""`**.
- **Nada do modo jogo gravado no `Config`** além das preferências `game*` (D2, anti-objetivo): o `Config.doNotDisturb` nunca é escrito por ele. Teste: `quiet_never_writes_config` (Tarefa 2).
- Preferências novas no `core/config/Config.qml` (alias + `JsonAdapter`), com estes padrões (D17): `gameAutoFullscreen: true`, `gameAutoGames: true`, `gameAlways: []`, `gameNever: []`, `gameEffects: true`, `gameVrr: true`, `gameTearing: false`, `gameProfile: true`, `gameGamemode: true`, `gameLight: true`, `gameWallpaper: true`, `gameQuiet: true`, `gameBar: true`, `gameIdle: true`, `gameNotices: true`.
- Textos em pt-BR com acentos; nomes de código em inglês; commits no estilo `Modo jogo: o adaptador do lucernad`. Ícone do modo: `sports_esports` (Material Symbols).
- Verificação de toda tarefa: `dev/ci.sh lint rules unit` verde (e `smoke` na Tarefa 6).

## Review Focus

1. **O `lucernad` cai com o modo ativo** (o shell perde a conexão): na hora, o papel volta, o não perturbe do modo some, a barra volta a se revelar, a ociosidade volta, sem OSD nem resumo. Teste: `connection_lost_turns_shell_side_off_silently` (Tarefa 1).
2. **O shell reinicia com o modo ativo** (o `qs` recarregado no meio do jogo): o primeiro estado religa a parte do shell sem OSD de "ligado", e ao sair o resumo ainda conta as notificações do jogo inteiro (pelo `since` e o `receivedAt` persistido). Testes: `first_state_after_connect_shows_no_notice` (Tarefa 4) e `summary_counts_from_since_after_restart` (Tarefa 4).
3. **O usuário liga o não perturbe dele durante o jogo e o modo sai:** o não perturbe continua ligado (é dele). Teste: `user_dnd_survives_game_exit` (Tarefa 2).
4. **Notificação crítica durante o jogo:** aparece como popup (como hoje com o não perturbe) e não entra no resumo. Teste: `critical_pops_and_is_not_summarized` (Tarefa 4).
5. **Listas sempre/nunca com lixo** (classe repetida, com espaços, vazia, mais de 100): o `configure` manda só classes válidas, únicas, aparadas e até 100, e a página não deixa acrescentar a mesma de novo. Teste: `configure_cleans_class_lists` (Tarefa 1).

---

### Task 1: O adaptador `services/GameMode.qml` e as preferências

**Files:**
- Create: `services/GameMode.qml`, `tests/gamemode.test.js`
- Modify: `core/config/Config.qml` (as preferências `game*`), `tests/runner.qml` (o `GameMode` e a suíte), `tests/coverage.json`

**Interfaces:**
- Produces (`GameMode`, singleton, no padrão do `services/Web.qml`): `property var client: Lucernad.client`; `error: string`; `readonly available`; `active: bool`; `manual: string` (`"on"`, `"off"` ou `""`); `reasons: var` (lista); `windows: var`; `since: real` (ms, 0 sem); `effects: var` (objeto do Formato); `unavailableNote: string`; as preferências que o configure usa como propriedades (`autoFullscreen`, `autoGames`, `always`, `never`, `effectsOn`, `vrr`, `tearing`, `profile`, `gamemode`, `light`), ligadas ao `Config` por `Binding`s no próprio `GameMode` (não há uma feature dona, ao contrário do `Web`, ligado pelo `DashboardState`); os testes trocam as propriedades direto, como no `web.test.js`.
- Funções: `wantedTopics(): var` (`["game.state", "game.status"]`), `sync()`, `cleanClasses(list: var): var` (aparadas, minúsculas, sem vazias nem repetidas, até 100, cada uma até 128 caracteres), `configureParams(): var` (o objeto do Formato), `configure()`, `apply(topic, data)`, `applyState(data)`, `applyStatus(data)`, `connectionChanged(connected: bool)` (ao cair: `active` falso, `since` 0, `reasons`/`windows` vazios, `effects` todos `"off"`), `set(on: bool)` (`game.set`), `toggle()` (`game.toggle`); sinal `changedByDaemon(active: bool)` emitido só quando `active` muda por um `game.state` recebido **depois** do primeiro estado da conexão (D19).

- [ ] **Step 1: Testes que falham** (`tests/gamemode.test.js`, com `t.lucernaClient()` e o `wired()` do `web.test.js`): `wanted_topics`, `configure_on_connect_and_on_change` (uma preferência mudada → um `game.configure` novo com o objeto inteiro), `configure_cleans_class_lists` (`[" Steam ", "steam", "", "x".repeat(129), …101 classes]` → `["steam", …]` com até 100), `applies_state_from_daemon` (`active`, `manual`, `reasons`, `since`, `effects`), `null_state_changes_nothing`, `status_error_makes_unavailable`, `connection_lost_turns_shell_side_off_silently` (ativo, conexão cai: `active` falso e `changedByDaemon` **não** emitido), `changed_signal_only_after_first_state`, `set_and_toggle_call_daemon`; e restaura o estado (`restored()`).
- [ ] **Step 2:** `dev/ci.sh unit` → falha.
- [ ] **Step 3: Implementar** o serviço, as preferências e o registro no `runner.qml` e no `coverage.json`.
- [ ] **Step 4:** `dev/ci.sh lint rules unit` → verde.
- [ ] **Step 5: Commit** `Modo jogo: o adaptador do lucernad e as preferências`.

### Task 2: A parte do shell: papel, não perturbe, ociosidade e barra

**Files:**
- Modify: `features/wallpaper/state/WallpaperState.qml`, `services/Notifications.qml` (só se precisar do segundo interruptor), `features/notifications/state/NotificationsState.qml`, `features/idle/state/IdleState.qml`, `features/bar/state/BarState.qml`, `core/input/InputActions.qml`, `features/input/state/InputState.qml`, `features/settings/state/ShortcutsState.qml`
- Test: `tests/wallpaper.test.js`, `tests/notifications.test.js`, `tests/bar.test.js`, `tests/input.test.js`, `tests/inputactions.test.js` (e uma suíte `tests/idle.test.js` nova se a lógica sair do `IdleState` para uma função pura)

**Interfaces:**
- Consumes: `GameMode.active`, `Config.game*`.
- Produces: `WallpaperState.gamePauses(active: bool, enabled: bool): bool` (puro) usado no começo do `shouldAnimate` (pausa antes de tudo, sem salto: o mesmo caminho da pausa de hoje).
- Produces: no `NotificationsState`, o `Binding` do `Notifications.doNotDisturb` passa a `quietFor(userDnd: bool, gameActive: bool, gameQuiet: bool): bool` (puro: `userDnd || (gameActive && gameQuiet)`); o `Config.doNotDisturb` continua só do usuário.
- Produces: `IdleState.held` ganha `(Config.gameIdle && GameMode.active)` e o `holdReason` "O modo jogo está ligado" (depois do "Não apagar a tela" e antes de "Há mídia tocando").
- Produces: `BarState.decide(s)` ganha `s.gameLocked` (`GameMode.active && Config.gameBar`): com ele, `revealed` pelo mouse e `peeking` não mostram; `s.pinned` (revelada pelo atalho) mostra sempre, fora do `fused`/`panelOpen`. Novo `property var pinnedScreen: null` e `function togglePinned(screen: var): void` (segundo toque esconde; o mouse que entra e sai da barra esconde como hoje). `reveal(screen)` e `peek(screen)` não fazem nada com o `gameLocked`.
- Produces: ações novas no `InputActions` (`{ id: "game", group: "Lucerna", label: "Ligar/desligar o modo jogo", icon: "sports_esports", kind: "shell" }` e `{ id: "bar", group: "Lucerna", label: "Mostrar/esconder a barra", icon: Icons.toolbar, kind: "shell" }`), no `InputState.run` (`"game"` → `GameMode.toggle()`; `"bar"` → `Panels.requestBarToggle(Hypr.focusedScreen)`, porque a feature `input` não pode importar a `bar`: o `core/panels/Panels.qml` ganha `signal barToggleRequested(var screen)` e `function requestBarToggle(screen: var): void`, e o `BarState` escuta o sinal e chama o `togglePinned`) e no grupo "Painéis e sessão" do `ShortcutsState`, sem tecla padrão.

- [ ] **Step 1: Testes que falham:** `game_pauses_wallpaper` e `game_pause_respects_setting`; `quiet_follows_game_and_user`, `quiet_never_writes_config` (`Config.doNotDisturb` igual antes e depois de o modo ligar e desligar), `user_dnd_survives_game_exit`; `idle_held_by_game` (com `gameIdle` falso, não segura) e o texto do motivo; `bar_mouse_and_peek_locked_in_game`, `bar_pinned_shows_in_game`, `bar_pinned_toggles_off`, `bar_without_game_unchanged` (os casos atuais do `decide` continuam); `game_action_toggles` (cliente de teste recebe `game.toggle`), `bar_action_emits_toggle_request`, `new_actions_listed_without_default_keys`.
- [ ] **Step 2:** `dev/ci.sh unit` → falha.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4:** `dev/ci.sh lint rules unit` → verde.
- [ ] **Step 5: Commit** `Modo jogo: papel, não perturbe, ociosidade e barra seguindo o modo`.

### Task 3: A chave no Painel e o IPC

**Files:**
- Modify: `features/dashboard/state/OverviewState.qml`, `features/dashboard/ui/OverviewPage.qml` (só se a chave precisar de algo que as outras não têm), `features/input/state/InputState.qml` (o `IpcHandler` `game`)
- Test: `tests/overview.test.js`, `tests/input.test.js`

**Interfaces:**
- Produces: `OverviewState.togglesFor(has)` recebe `has.game` (`GameMode.available`) e `has.gameOn` (`GameMode.active`) e põe `{ id: "game", label: "Modo jogo", icon: "sports_esports", on: <ativo>, enabled: <disponível> }` depois do "Não perturbe"; sem o `lucernad`, `label` "Modo jogo: indisponível sem o lucernad" e `enabled: false`. `toggle("game")` → `GameMode.toggle()`.
- Produces: `IpcHandler { target: "game" }` com `toggle()`, `on()`, `off()` e `get(): string` (`"ligado (manual)"`, `"ligado (tela cheia, jogo)"`, `"desligado"` ou `"indisponível"`; os motivos em pt-BR na ordem do Formato). Fica no `InputState` (já é o dono do `action`); se o `ci/rules.py` reclamar, num `features/settings/state/GameModeState.qml` da Tarefa 5 (decidir lá e mover).

- [ ] **Step 1: Testes que falham:** `game_toggle_listed_when_available`, `game_toggle_disabled_without_lucernad`, `toggle_game_calls_daemon`; `ipc_get_texts` (os quatro textos), `ipc_on_off_call_set`.
- [ ] **Step 2:** `dev/ci.sh unit` → falha.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4:** `dev/ci.sh lint rules unit` → verde.
- [ ] **Step 5: Commit** `Modo jogo: a chave no Painel e o IPC game`.

### Task 4: O ícone, os avisos e o resumo das notificações

**Files:**
- Modify: `features/bar/state/BarState.qml`, `features/bar/ui/Actions.qml` (o ícone à esquerda do sino), `features/osd/state/OsdState.qml`, `features/osd/ui/Osd.qml` (o tipo `game`), `features/notifications/state/NotificationsState.qml`, `features/notifications/ui/NotificationPopups.qml` (o cartão de resumo)
- Test: `tests/bar.test.js`, `tests/osd.test.js`, `tests/notifications.test.js`

**Interfaces:**
- Produces: `BarState.gameIcon: bool` (= `GameMode.active`) e `BarState.gameTooltip: string` ("Modo jogo ligado: <motivos>. Clique para desligar."); `BarState.stopGame()` → `GameMode.set(false)`.
- Produces: `OsdState.showGame(on: bool): void` (tipo `"game"`, ícone `sports_esports`, texto "Modo jogo ligado"/"Modo jogo desligado", sem valor nem barra), chamado no `GameMode.changedByDaemon` com `Config.gameNotices`; os outros tipos não mudam.
- Produces: `NotificationsState.summaryOf(list: var, since: real, now: real): var` (puro; conta as não críticas com `receivedAt ≥ since`; `{ count, apps: [até 3 nomes únicos na ordem de chegada], more: <outros apps> }`, ou `null` com zero) e `NotificationsState.summary: var` (o cartão à mostra, ou `null`), preenchido quando o `changedByDaemon(false)` chega com `Config.gameNotices` e o `since` que estava valendo (guardado no `GameMode` antes de zerar); some depois do `Notifications.defaultTimeout` ou no clique, que abre o painel de notificações (`Panels.toggleNotifications()` pelo caminho que o state já usa). Texto: "Enquanto você jogava: 4 notificações — Discord, Steam e mais 1".

- [ ] **Step 1: Testes que falham:** `bar_shows_game_icon_and_tooltip`, `bar_click_stops_game`; `osd_game_on_off_texts`, `osd_quiet_when_notices_off`; `summary_counts_non_critical_since` (3 normais e 1 crítica depois do `since`, 1 antes → `count` 3), `critical_pops_and_is_not_summarized` (a crítica abre popup com o modo ativo), `summary_groups_apps_with_more`, `summary_none_when_zero`, `summary_counts_from_since_after_restart` (o `receivedAt` vem do `PersistentProperties`; o `since` do tópico depois de reconectar: conta as de antes do reinício), `first_state_after_connect_shows_no_notice` (nem OSD nem resumo).
- [ ] **Step 2:** `dev/ci.sh unit` → falha.
- [ ] **Step 3: Implementar** (os `ui/` só ligam o que o state expõe).
- [ ] **Step 4:** `dev/ci.sh lint rules unit` → verde.
- [ ] **Step 5: Commit** `Modo jogo: o ícone na barra, os avisos e o resumo das notificações`.

### Task 5: A página "Modo jogo" nas Configurações

**Files:**
- Create: `features/settings/ui/GameModePage.qml`, `features/settings/state/GameModeState.qml`
- Modify: `features/settings/state/SettingsState.qml` (tópico `{ id: "game", icon: "sports_esports", label: "Modo jogo", description: "Jogos sem efeitos nem interrupções" }`, depois de "Energia e bateria"), `features/settings/ui/Settings.qml` (a página no `Loader`/roteamento de hoje)
- Test: `tests/gamemodestate.test.js` (nova) e `tests/runner.qml`

**Interfaces:**
- Consumes: `GameMode`, `Config.game*`, `Hypr.toplevels` (as janelas abertas, para acrescentar à lista).
- Produces (`GameModeState`): `statusLine: string` ("Ligado desde 21:14 — tela cheia, jogo" / "Desligado" / o `unavailableNote`); `effectRows: var` (`[{ id, label, state }]` para compositor, VRR, tearing, perfil, GameMode, `lucernad` leve, com `state` em pt-BR: "ativo", "desligado", "não instalado"/"indisponível", "erro: …"); `openClasses: var` (classes das janelas abertas, sem as que já estão nas listas, ordenadas); `addClass(list: string, cls: string): void` e `removeClass(list: string, cls: string): void` (`list` = `"always"`/`"never"`; acrescentar numa tira da outra; passa pelo `GameMode.cleanClasses`); `set(key: string, on: bool): void` (as preferências `game*`); `toggleNow(): void`.
- Página (seções, no padrão das outras páginas): **Agora** (a linha de estado, o botão Ligar/Desligar, as linhas do `effectRows`); **Entrada** (tela cheia de verdade; jogos detectados; o atalho, com um link para a página Atalhos); **Apps** (Sempre / Nunca, cada um com a lista, remover e "Acrescentar" pelas janelas abertas ou digitando a classe); **Compositor** (desligar desfoque, sombras e animações; VRR em tela cheia; tearing, com a descrição "Menos atraso, mas a imagem pode rasgar"); **Shell** (pausar o papel animado; não perturbe com resumo ao sair; barra presa no topo; não apagar a tela; avisos ao entrar e sair); **Sistema** (perfil de desempenho; GameMode da Feral; `lucernad` mais leve). Sem o `lucernad`, o aviso "Indisponível" do core no topo e as seções desabilitadas.

- [ ] **Step 1: Testes que falham:** `status_line_texts`, `effect_rows_translate_states` (os quatro tipos de estado), `open_classes_exclude_listed`, `add_to_always_removes_from_never`, `add_is_cleaned_and_unique`, `remove_class`, `set_writes_config` (e restaura), `toggle_now_calls_daemon`.
- [ ] **Step 2:** `dev/ci.sh unit` → falha.
- [ ] **Step 3: Implementar** o state e a página; conferir no container `lucerna-polish` (captura da página com o modo ligado e desligado, e com o `lucernad` parado) e mostrar as capturas no PR.
- [ ] **Step 4:** `dev/ci.sh lint rules unit` → verde.
- [ ] **Step 5: Commit** `Modo jogo: a página nas Configurações`.

### Task 6: Fumaça, `lucernad` fixado, medição e PR

**Files:**
- Create: `ci/hypr-fake.py`, `dev/bench-game.sh`
- Modify: `dev/lucernad.rev` (`<LUCERNAD_REV>`, o merge do `lucernad`), `ci/smoke.sh` (fase "modo jogo"), `ci/tolerated.txt` (só se um aviso novo for esperado e explicado), `README.md` (o modo jogo, o atalho, o `qs ipc call game`), `Lucerna — Pendências.md`

**Interfaces:**
- `ci/hypr-fake.py <pasta>`: serve `<pasta>/hypr/fumaca/.socket.sock` e `.socket2.sock` só com a biblioteca padrão; responde `j/getoption` das cinco opções a partir de um estado em memória, aplica o `eval` do `hl.config` simples que o `lucernad` manda (só as cinco opções; outro texto → `ok` sem mudar), `j/clients` `[]`, `j/monitors` com um monitor, `version`; grava cada pedido num arquivo de log; escreve o estado atual em `<pasta>/estado.json` a cada mudança.
- Fase "modo jogo" do `ci/smoke.sh`, depois da fase "brilho": sobe o `lucernad` com `XDG_RUNTIME_DIR` da fumaça e `HYPRLAND_INSTANCE_SIGNATURE=fumaca` só no ambiente dele (o shell no `sway` não vê o fake); `lucernad jogo ligar` → em 5 s, o `estado.json` com as três opções em falso e `qs -c lucerna ipc call game get` começando com `ligado`; `lucernad jogo desligar` → o `estado.json` igual ao do começo e o `get` `desligado`. Reprova com mensagem própria em cada passo.
- `dev/bench-game.sh [SEGUNDOS]` (padrão 20), rodado dentro de uma sessão Hyprland (o container ou uma máquina real): guarda o `getoption` das cinco opções; abre um `kitty` em tela cheia com um laço que escreve a hora a cada 16 ms; mede a CPU do Hyprland, do `qs` e do `lucernad` pelo `/proc` com o modo desligado e ligado (`lucernad jogo ligar`/`desligar`); imprime a tabela; desliga, fecha o `kitty`, e compara o `getoption` final com o guardado (diferença → sai 1 e diz qual opção).

- [ ] **Step 1:** pôr o `<LUCERNAD_REV>` no `dev/lucernad.rev` e reconstruir o container (`dev/test.sh`) e a fumaça local.
- [ ] **Step 2:** escrever o `ci/hypr-fake.py` e a fase; `dev/ci.sh smoke` → verde, e reprova se o `lucernad` não restaurar (conferir trocando à mão a resposta do fake uma vez, sem commitar).
- [ ] **Step 3:** escrever o `dev/bench-game.sh`; rodar no `lucerna-polish` e guardar a tabela para o PR. Esperado: Hyprland e `lucernad` abaixo com o modo ligado; o `getoption` final igual.
- [ ] **Step 4: Conferência no container**, com janela na tela do usuário (memória `lucerna-test-windows`), sem mexer no `lucerna-dev`: tela cheia → ícone, OSD, papel parado, barra sem revelar pelo topo e revelada pela ação `bar`; uma notificação durante o jogo (`notify-send`) não aparece e entra no resumo ao sair; `qs` reiniciado com o modo ligado volta sem OSD; o `lucernad` parado → tudo volta em silêncio. Capturas no PR; o que depende de clique fica para o usuário, listado no PR e nas Pendências ("Testes que precisam da máquina real").
- [ ] **Step 5:** README e Pendências (sobras da revisão, se houver); `dev/ci.sh lint rules unit smoke` → verde.
- [ ] **Step 6: Commit** `Modo jogo: a fumaça com o Hyprland falso, a medição e o lucernad novo` e abrir o PR (`gh pr create`, conta `EduardoSA8006`), com a tabela da medição e as capturas.
